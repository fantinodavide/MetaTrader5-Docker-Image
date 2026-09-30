/*
 * Fixed network adapter identity for Wine, loaded with LD_PRELOAD.
 *
 * MetaTrader 5 deletes its saved accounts "due security reason" when the
 * machine's network adapters look different. Wine builds each adapter from
 * if_nameindex() (name, and the index its GUID and LUID are made of) and
 * ioctl(SIOCGIFHWADDR) (MAC address). Docker changes the MACs, the indexes
 * and even the names (eth0/eth1/eth2) on every container start.
 *
 * getifaddrs() gives it their addresses, and Docker changes the IP too.
 *
 * Inside the processes that load this library, the adapter list is always
 * lo (index 1) and eth0 (index 2), and every adapter except lo reports the
 * same MAC and IP. Sockets still use the real addresses, and the container's
 * real networking is untouched: Docker always
 * creates eth0, and Wine's other lookups (flags, MTU, statistics) go to the
 * real interface by name.
 */
#define _GNU_SOURCE
#include <arpa/inet.h>
#include <dlfcn.h>
#include <ifaddrs.h>
#include <linux/if_packet.h>
#include <net/if.h>
#include <net/if_arp.h>
#include <netinet/in.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>

static const unsigned char mt5_mac[6] = { 0x02, 0x00, 0x00, 0x4d, 0x54, 0x35 };
/* 192.168.53.5/24 and fd00:4d54:35::5 */
#define MT5_IPV4 0xc0a83505u
#define MT5_IPV4_MASK 0xffffff00u
static const unsigned char mt5_ipv6[16] = { 0xfd, 0x00, 0x4d, 0x54, 0x00, 0x35, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x05 };

static const struct {
    const char *name;
    unsigned int index;
} mt5_ifaces[] = {
    { "lo", 1 },
    { "eth0", 2 },
};

#define MT5_IFACE_COUNT (sizeof(mt5_ifaces) / sizeof(mt5_ifaces[0]))

/* Same layout as glibc's result, so glibc's if_freenameindex() frees it. */
struct if_nameindex *if_nameindex(void)
{
    static struct if_nameindex *(*real_if_nameindex)(void);
    struct if_nameindex *real, *p, *out;
    size_t i, n = 0;

    if (!real_if_nameindex)
        real_if_nameindex = dlsym(RTLD_NEXT, "if_nameindex");
    if (!real_if_nameindex || !(real = real_if_nameindex()))
        return NULL;

    if (!(out = calloc(MT5_IFACE_COUNT + 1, sizeof(*out)))) {
        if_freenameindex(real);
        return NULL;
    }
    /* Keep only the interfaces that exist, in a fixed order. */
    for (i = 0; i < MT5_IFACE_COUNT; i++) {
        for (p = real; p->if_index; p++) {
            if (strcmp(p->if_name, mt5_ifaces[i].name))
                continue;
            if (!(out[n].if_name = strdup(p->if_name))) {
                if_freenameindex(out);
                if_freenameindex(real);
                return NULL;
            }
            out[n++].if_index = mt5_ifaces[i].index;
            break;
        }
    }
    if_freenameindex(real);
    return out;
}

/*
 * Wine lists each adapter's addresses with getifaddrs(), and Docker hands out
 * a new IP on every start. Give every interface but lo a fixed address,
 * netmask and MAC. Entries are rewritten in place: glibc's freeifaddrs()
 * frees the list as one block.
 */
int getifaddrs(struct ifaddrs **ifap)
{
    static int (*real_getifaddrs)(struct ifaddrs **);
    struct ifaddrs *ifa;
    int ret;

    if (!real_getifaddrs)
        real_getifaddrs = dlsym(RTLD_NEXT, "getifaddrs");
    if (!real_getifaddrs)
        return -1;
    if ((ret = real_getifaddrs(ifap)))
        return ret;

    for (ifa = *ifap; ifa; ifa = ifa->ifa_next) {
        if (!ifa->ifa_addr || !strcmp(ifa->ifa_name, "lo"))
            continue;
        switch (ifa->ifa_addr->sa_family) {
        case AF_INET:
            ((struct sockaddr_in *)ifa->ifa_addr)->sin_addr.s_addr = htonl(MT5_IPV4);
            if (ifa->ifa_netmask)
                ((struct sockaddr_in *)ifa->ifa_netmask)->sin_addr.s_addr = htonl(MT5_IPV4_MASK);
            if ((ifa->ifa_flags & IFF_BROADCAST) && ifa->ifa_broadaddr)
                ((struct sockaddr_in *)ifa->ifa_broadaddr)->sin_addr.s_addr =
                    htonl(MT5_IPV4 | ~MT5_IPV4_MASK);
            break;
        case AF_INET6:
            memcpy(&((struct sockaddr_in6 *)ifa->ifa_addr)->sin6_addr, mt5_ipv6, sizeof(mt5_ipv6));
            break;
        case AF_PACKET:
            if (((struct sockaddr_ll *)ifa->ifa_addr)->sll_halen == sizeof(mt5_mac))
                memcpy(((struct sockaddr_ll *)ifa->ifa_addr)->sll_addr, mt5_mac, sizeof(mt5_mac));
            break;
        }
    }
    return 0;
}

int ioctl(int fd, unsigned long request, ...)
{
    static int (*real_ioctl)(int, unsigned long, ...);
    struct ifreq *ifr;
    va_list ap;
    void *arg;
    int ret;

    va_start(ap, request);
    arg = va_arg(ap, void *);
    va_end(ap);

    if (!real_ioctl)
        real_ioctl = dlsym(RTLD_NEXT, "ioctl");
    ret = real_ioctl(fd, request, arg);

    if (ret == 0 && request == SIOCGIFHWADDR) {
        ifr = arg;
        if (strcmp(ifr->ifr_name, "lo")) {
            ifr->ifr_hwaddr.sa_family = ARPHRD_ETHER;
            memcpy(ifr->ifr_hwaddr.sa_data, mt5_mac, sizeof(mt5_mac));
        }
    }
    return ret;
}
