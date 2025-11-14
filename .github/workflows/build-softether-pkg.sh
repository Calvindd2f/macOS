#!/bin/bash
set -e

### ============================================================
### SoftEther VPN Client – macOS ARM64 Automated PKG Builder
### Author: ChatGPT (for Clitoria)
### ============================================================

PKG_VERSION="1.0.0"
PKG_ID="com.softether.vpnclient"
WORKDIR="$HOME/softether-build"
PKGROOT="$WORKDIR/pkgroot"
SCRIPTDIR="$WORKDIR/scripts"
DIST="$WORKDIR/dist"
REPO="https://github.com/SoftEtherVPN/SoftEtherVPN_Stable.git"

echo "### SoftEther macOS ARM64 PKG Builder"
echo "### Workdir: $WORKDIR"
mkdir -p "$WORKDIR" "$PKGROOT" "$SCRIPTDIR" "$DIST"


### ------------------------------------------------------------
### 1. Install prerequisites
### ------------------------------------------------------------
echo "[1/7] Installing build dependencies..."
brew install git cmake gmake openssl@3 || true
OPENSSL_DIR=$(brew --prefix openssl@3)
export OPENSSL_ROOT_DIR="$OPENSSL_DIR"
export CFLAGS="-I$OPENSSL_DIR/include"
export LDFLAGS="-L$OPENSSL_DIR/lib"


### ------------------------------------------------------------
### 2. Clone repo
### ------------------------------------------------------------
echo "[2/7] Cloning SoftEther Stable..."
cd "$WORKDIR"
rm -rf SoftEtherVPN_Stable || true
git clone "$REPO"
cd SoftEtherVPN_Stable/vpnclient


### ------------------------------------------------------------
### 3. Build ARM64 binary
### ------------------------------------------------------------
echo "[3/7] Building ARM64 SoftEther client..."
gmake clean || true
gmake -j"$(sysctl -n hw.ncpu)"


### ------------------------------------------------------------
### 4. Assemble pkgroot (file payload)
### ------------------------------------------------------------
echo "[4/7] Preparing pkgroot tree..."

mkdir -p "$PKGROOT/usr/local/vpnclient"

cp vpnclient "$PKGROOT/usr/local/vpnclient/"
cp vpncmd "$PKGROOT/usr/local/vpnclient/"
# Copy hamcore if present
if [ -d "../../src/bin/hamcore" ]; then
  cp -R ../../src/bin/hamcore "$PKGROOT/usr/local/vpnclient/"
fi

chmod -R 755 "$PKGROOT/usr/local/vpnclient"


### ------------------------------------------------------------
### 5. Create postinstall script
### ------------------------------------------------------------
echo "[5/7] Generating postinstall script..."

cat << 'EOF' > "$SCRIPTDIR/postinstall"
#!/bin/bash
set -e

VPNDIR="/usr/local/vpnclient"

/usr/bin/killall vpnclient 2>/dev/null || true

"$VPNDIR/vpnclient" stop >/dev/null 2>&1 || true
"$VPNDIR/vpnclient" start

# Create NIC if required
"$VPNDIR/vpncmd" /CLIENT localhost /CMD NicCreate vpn || true

chmod -R 755 "$VPNDIR"

echo "SoftEther VPN Client installed successfully."
exit 0
EOF

chmod +x "$SCRIPTDIR/postinstall"


### ------------------------------------------------------------
### 6. Build the .pkg
### ------------------------------------------------------------
PKG_FILE="$DIST/SoftEtherVPNClient-ARM64-${PKG_VERSION}.pkg"
echo "[6/7] Building PKG → $PKG_FILE"

pkgbuild \
  --root "$PKGROOT" \
  --identifier "$PKG_ID" \
  --version "$PKG_VERSION" \
  --scripts "$SCRIPTDIR" \
  --install-location "/" \
  "$PKG_FILE"


### ------------------------------------------------------------
### 7. Optional signing + notarization
### ------------------------------------------------------------
if [ -n "$SIGN_ID" ]; then
  echo "[7/7] Signing PKG using: $SIGN_ID"

  SIGNED="$DIST/SoftEtherVPNClient-ARM64-${PKG_VERSION}-signed.pkg"

  productsign \
    --sign "$SIGN_ID" \
    "$PKG_FILE" \
    "$SIGNED"

  echo "Signed PKG created: $SIGNED"

  if [ -n "$NOTARIZE" ]; then
    echo "Submitting to Apple Notary Service…"

    xcrun notarytool submit "$SIGNED" \
      --keychain-profile "$NOTARIZE" \
      --wait

    echo "Stapling notarization ticket…"
    xcrun stapler staple "$SIGNED"
  fi
fi


echo "### Build complete!"
echo "Artifacts in: $DIST"
ls -lh "$DIST"
