#!/bin/bash
set -e

echo "### SoftEther VPN Client – macOS ARM64 Build Script ###"

# --- Prereqs ----------------------------------------------------------
echo "[1/7] Installing build dependencies..."
brew install git cmake gmake openssl@3 || true

OPENSSL_DIR=$(brew --prefix openssl@3)

export OPENSSL_ROOT_DIR="$OPENSSL_DIR"
export CFLAGS="-I$OPENSSL_DIR/include"
export LDFLAGS="-L$OPENSSL_DIR/lib"

echo "Using OpenSSL from: $OPENSSL_DIR"

# --- Download Source ---------------------------------------------------
echo "[2/7] Downloading SoftEther source..."
rm -rf SoftEtherVPN_Stable || true
git clone https://github.com/SoftEtherVPN/SoftEtherVPN_Stable.git
cd SoftEtherVPN_Stable

# --- Build vpnclient ---------------------------------------------------
echo "[3/7] Building SoftEther VPN client for ARM64..."
cd vpnclient
gmake -j"$(sysctl -n hw.ncpu)"

# --- Install -----------------------------------------------------------
echo "[4/7] Installing to /usr/local/vpnclient ..."
sudo gmake install

cd /usr/local/vpnclient

# --- Start Service -----------------------------------------------------
echo "[5/7] Starting vpnclient service..."
sudo ./vpnclient start

# --- Create Virtual NIC ------------------------------------------------
echo "[6/7] Creating virtual NIC 'vpn'..."
sudo ./vpncmd /CLIENT localhost /CMD NicCreate vpn || true

echo "NOTE: If macOS blocks the network extension:"
echo "Go to: System Settings → Privacy & Security → Allow SoftEtherVPN"
echo "Then reboot once."

# --- Status ------------------------------------------------------------
echo "[7/7] Checking status..."
sudo ./vpncmd /CLIENT localhost /CMD NicList

echo
echo "### SoftEther VPN Client build complete!"
echo "Binaries installed at: /usr/local/vpnclient"
echo "Commands:"
echo "  sudo /usr/local/vpnclient/vpnclient start"
echo "  sudo /usr/local/vpnclient/vpncmd"
echo
