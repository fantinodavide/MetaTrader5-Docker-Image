#!/bin/bash

# Configuration variables
mt5file='/config/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe'
WINEPREFIX='/config/.wine'
WINEDEBUG='-all'
wine_executable="wine"
metatrader_version="5.0.36"
mt5server_port="8001"
MT5_CMD_OPTIONS="${MT5_CMD_OPTIONS:-}"
mono_url="https://dl.winehq.org/wine/wine-mono/10.3.0/wine-mono-10.3.0-x86.msi"
python_url="https://www.python.org/ftp/python/3.9.13/python-3.9.13.exe"
mt5setup_url="https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
webview2_url="https://go.microsoft.com/fwlink/p/?LinkId=2124703"

# Export environment variables for Wine
export WINEPREFIX
export WINEDEBUG

# Disable Wine debugging DLLs to prevent MT5 debugger detection
# dbghelp and dbgeng are Windows debugging libraries that MT5 checks for
export WINEDLLOVERRIDES="dbghelp=d;dbgeng=d;winedbg.exe=d"

# Function to display a graphical message
show_message() {
    echo $1
}

# Function to check if a dependency is installed
check_dependency() {
    if ! command -v $1 &> /dev/null; then
        echo "$1 is not installed. Please install it to continue."
        exit 1
    fi
}

# Function to check if a Python package is installed
is_python_package_installed() {
    python3 -c "import pkg_resources; exit(not pkg_resources.require('$1'))" 2>/dev/null
    return $?
}

# Function to check if a Python package is installed in Wine
is_wine_python_package_installed() {
    $wine_executable python -c "import pkg_resources; exit(not pkg_resources.require('$1'))" 2>/dev/null
    return $?
}

# Check for necessary dependencies
check_dependency "curl"
check_dependency "$wine_executable"

# Install Mono if not present
if [ ! -e "/config/.wine/drive_c/windows/mono" ]; then
    show_message "[1/9] Downloading and installing Mono..."
    curl -o /config/.wine/drive_c/mono.msi $mono_url
    WINEDLLOVERRIDES=mscoree=d $wine_executable msiexec /i /config/.wine/drive_c/mono.msi /qn
    rm /config/.wine/drive_c/mono.msi
    show_message "[1/9] Mono installed."
else
    show_message "[1/9] Mono is already installed."
fi

# Install Microsoft Core Fonts for proper text rendering
fonts_marker="/config/.wine/.fonts_installed"
if [ ! -e "$fonts_marker" ]; then
    show_message "[2/9] Installing Microsoft Core Fonts for text rendering..."
    # Use winetricks to install corefonts (Arial, Times New Roman, etc.)
    winetricks -q corefonts
    # Install additional fonts that MetaTrader may need
    winetricks -q tahoma
    touch "$fonts_marker"
    show_message "[2/9] Core fonts installed."
else
    show_message "[2/9] Core fonts are already installed."
fi

# Configure Wine registry for font smoothing (ClearType) and anti-debug bypass
fontsmooth_marker="/config/.wine/.fontsmooth_configured"
if [ ! -e "$fontsmooth_marker" ]; then
    show_message "[3/9] Configuring Wine registry (font smoothing, anti-debug)..."
    # Enable font smoothing
    $wine_executable reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v FontSmoothing /t REG_SZ /d "2" /f
    $wine_executable reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v FontSmoothingType /t REG_DWORD /d 2 /f
    $wine_executable reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v FontSmoothingGamma /t REG_DWORD /d 1400 /f
    $wine_executable reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v FontSmoothingOrientation /t REG_DWORD /d 1 /f

    # Disable debugging DLLs in Wine to prevent MT5 debugger detection
    $wine_executable reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v "dbghelp" /t REG_SZ /d "" /f
    $wine_executable reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v "dbgeng" /t REG_SZ /d "" /f

    touch "$fontsmooth_marker"
    show_message "[3/9] Wine registry configured."
else
    show_message "[3/9] Wine registry is already configured."
fi

# Install WebView2 Runtime for HTML rendering (reports, help, etc.)
webview2_marker="/config/.wine/.webview2_installed"
if [ ! -e "$webview2_marker" ]; then
    show_message "[4/9] Installing WebView2 Runtime for report rendering..."
    curl -L -o /tmp/MicrosoftEdgeWebview2Setup.exe "$webview2_url"
    # Install WebView2 silently
    $wine_executable /tmp/MicrosoftEdgeWebview2Setup.exe /silent /install
    rm -f /tmp/MicrosoftEdgeWebview2Setup.exe
    touch "$webview2_marker"
    show_message "[4/9] WebView2 Runtime installed."
else
    show_message "[4/9] WebView2 Runtime is already installed."
fi

# Check if MetaTrader 5 is already installed
if [ -e "$mt5file" ]; then
    show_message "[5/9] File $mt5file already exists."
else
    show_message "[5/9] File $mt5file is not installed. Installing..."

    # Set Windows 10 mode in Wine and download and install MT5
    $wine_executable reg add "HKEY_CURRENT_USER\\Software\\Wine" /v Version /t REG_SZ /d "win10" /f
    show_message "[5/9] Downloading MT5 installer..."
    curl -o /config/.wine/drive_c/mt5setup.exe $mt5setup_url
    show_message "[5/9] Installing MetaTrader 5..."
    $wine_executable "/config/.wine/drive_c/mt5setup.exe" "/auto" &
    wait
    rm -f /config/.wine/drive_c/mt5setup.exe
fi

# Recheck if MetaTrader 5 is installed
if [ -e "$mt5file" ]; then
    show_message "[6/9] File $mt5file is installed. Running MT5..."
    $wine_executable "$mt5file" $MT5_CMD_OPTIONS &
else
    show_message "[6/9] File $mt5file is not installed. MT5 cannot be run."
fi


# Install Python in Wine if not present
if ! $wine_executable python --version 2>/dev/null; then
    show_message "[7/9] Installing Python in Wine..."
    curl -L $python_url -o /tmp/python-installer.exe
    $wine_executable /tmp/python-installer.exe /quiet InstallAllUsers=1 PrependPath=1
    rm /tmp/python-installer.exe
    show_message "[7/9] Python installed in Wine."
else
    show_message "[7/9] Python is already installed in Wine."
fi

# Upgrade pip and install required packages
show_message "[8/9] Installing Python libraries"
$wine_executable python -m pip install --upgrade --no-cache-dir pip
# Install MetaTrader5 library in Windows if not installed
show_message "[8/9] Installing MetaTrader5 library in Windows"
if ! is_wine_python_package_installed "MetaTrader5==$metatrader_version"; then
    $wine_executable python -m pip install --no-cache-dir MetaTrader5==$metatrader_version
fi
# Install mt5linux library in Windows if not installed
show_message "[8/9] Checking and installing mt5linux library in Windows if necessary"
if ! is_wine_python_package_installed "mt5linux"; then
    $wine_executable python -m pip install --no-cache-dir "mt5linux>=0.1.9"
fi

# Install python-dateutil if needed (datetime is built-in, but dateutil adds features)
if ! is_wine_python_package_installed "python-dateutil"; then
    show_message "[8/9] Installing python-dateutil library in Windows"
    $wine_executable python -m pip install --no-cache-dir python-dateutil
fi

# Install mt5linux library in Linux if not installed
show_message "[8/9] Checking and installing mt5linux library in Linux if necessary"
if ! is_python_package_installed "mt5linux"; then
    pip install --break-system-packages --no-cache-dir --no-deps mt5linux && \
    pip install --break-system-packages --no-cache-dir rpyc plumbum numpy
fi

# Install pyxdg library in Linux if not installed
show_message "[8/9] Checking and installing pyxdg library in Linux if necessary"
if ! is_python_package_installed "pyxdg"; then
    pip install --break-system-packages --no-cache-dir pyxdg
fi

# Start the MT5 server on Linux
show_message "[9/9] Starting the mt5linux server..."
python3 -m mt5linux --host 0.0.0.0 -p $mt5server_port -w $wine_executable python.exe &

# Give the server some time to start
sleep 5

# Check if the server is running
if ss -tuln | grep ":$mt5server_port" > /dev/null; then
    show_message "[9/9] The mt5linux server is running on port $mt5server_port."
else
    show_message "[9/9] Failed to start the mt5linux server on port $mt5server_port."
fi
