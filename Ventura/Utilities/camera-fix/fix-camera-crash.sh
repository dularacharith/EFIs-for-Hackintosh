#!/bin/bash
# ==============================================================================
# Tiger Lake (Iris Xe) Camera & Video Calling Crash Fix for macOS Ventura
# ==============================================================================
# On Intel Tiger Lake Hackintoshes, WhatsApp and other WebRTC apps crash when
# starting video calls due to an uninitialized pointer bug in Apple's
# AppleIntelTGLGraphicsVADriver.bundle during hardware pixel conversion.
#
# This script disables the buggy hardware video acceleration bundle, forcing
# macOS to use CPU software pixel conversion (which is 100% stable).
# Metal 3D acceleration (AppleIntelTGLGraphicsMTLDriver.bundle) and FaceTime
# remain completely unaffected and fully accelerated.
# ==============================================================================

set -e

echo "==> Checking for AppleIntelTGLGraphicsVADriver.bundle..."

TARGET="/Library/GPUBundles/AppleIntelTGLGraphicsVADriver.bundle"

if [ -d "$TARGET" ]; then
    echo "==> Disabling buggy Tiger Lake Video Acceleration bundle..."
    sudo mv "$TARGET" "${TARGET}.disabled"
    echo "==> Successfully disabled: ${TARGET}.disabled"
elif [ -d "${TARGET}.disabled" ]; then
    echo "==> Driver bundle is already disabled (${TARGET}.disabled)."
else
    echo "==> Driver bundle not found at $TARGET. No action needed."
fi

echo "==> Restarting camera and video decoding services..."
sudo killall -9 VTDecoderXPCService VDCAssistant UVCAssistant 2>/dev/null || true

echo "==> Camera & Video Calling fix applied successfully! You can now use WhatsApp video calls."
