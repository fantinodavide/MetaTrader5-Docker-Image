/*
 * Fixed network adapter identity for Wine, loaded with LD_PRELOAD.
 *
 * MetaTrader 5 deletes its saved accounts "due security reason" when the
 * machine's network adapters look different. Wine builds each adapter from
 * if_nameindex() (name, and the index its GUID and LUID are made of) and
 * ioctl(SIOCGIFHWADDR) (MAC address). Docker changes the MACs, the indexes
 * and even the names (eth0/eth1/eth2) on every container start.
 *
 * Inside the processes that load this library, the adapter list is always
 * lo (index 1) and eth0 (index 2), and every adapter except lo reports the
 * same MAC. The container's real networking is untouched: Docker always
 * creates eth0, and Wine's other lookups (flags, MTU, statistics) go to the
 * real interface by name.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <net/if.h>
#include <net/if_arp.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>

static const unsigned char mt5_mac[6] = { 0x02, 0x00, 0x00, 0x4d, 0x54, 0x35 };

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
