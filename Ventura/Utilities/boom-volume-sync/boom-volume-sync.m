#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import <AudioToolbox/AudioToolbox.h>

static AudioObjectID gTargetDevice = kAudioObjectUnknown;
static AudioObjectID gVirtualDevice = kAudioObjectUnknown;
static AudioObjectPropertyListenerBlock gVirtualListenerBlock = nil;

static BOOL isVirtualDevice(AudioObjectID dev) {
    if (dev == kAudioObjectUnknown) return NO;
    AudioObjectPropertyAddress trAddr = {
        .mSelector = kAudioDevicePropertyTransportType,
        .mScope = kAudioObjectPropertyScopeGlobal,
        .mElement = kAudioObjectPropertyElementMain
    };
    UInt32 transport = 0;
    UInt32 trSize = sizeof(transport);
    if (AudioObjectGetPropertyData(dev, &trAddr, 0, NULL, &trSize, &transport) != noErr)
        return NO;
    return (transport == kAudioDeviceTransportTypeVirtual);
}

static AudioObjectID findDeviceByUID(NSString *targetUID) {
    AudioObjectPropertyAddress addr = {
        .mSelector = kAudioHardwarePropertyDevices,
        .mScope = kAudioObjectPropertyScopeGlobal,
        .mElement = kAudioObjectPropertyElementMain
    };
    UInt32 size = 0;
    if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &addr, 0, NULL, &size) != noErr)
        return kAudioObjectUnknown;

    UInt32 count = size / sizeof(AudioObjectID);
    AudioObjectID *devices = (AudioObjectID *)malloc(size);
    if (!devices) return kAudioObjectUnknown;
    AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, devices);

    AudioObjectID matched = kAudioObjectUnknown;
    for (UInt32 i = 0; i < count; i++) {
        AudioObjectID dev = devices[i];
        AudioObjectPropertyAddress uidAddr = {
            .mSelector = kAudioDevicePropertyDeviceUID,
            .mScope = kAudioObjectPropertyScopeGlobal,
            .mElement = kAudioObjectPropertyElementMain
        };
        CFStringRef uidRef = NULL;
        UInt32 uidSize = sizeof(uidRef);
        if (AudioObjectGetPropertyData(dev, &uidAddr, 0, NULL, &uidSize, &uidRef) == noErr && uidRef) {
            NSString *uid = (__bridge NSString *)uidRef;
            if ([uid isEqualToString:targetUID]) {
                matched = dev;
                CFRelease(uidRef);
                break;
            }
            CFRelease(uidRef);
        }
    }
    free(devices);
    return matched;
}

static AudioObjectID findBuiltInOutputDevice(void) {
    AudioObjectPropertyAddress addr = {
        .mSelector = kAudioHardwarePropertyDevices,
        .mScope = kAudioObjectPropertyScopeGlobal,
        .mElement = kAudioObjectPropertyElementMain
    };
    UInt32 size = 0;
    if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &addr, 0, NULL, &size) != noErr)
        return kAudioObjectUnknown;

    UInt32 count = size / sizeof(AudioObjectID);
    AudioObjectID *devices = (AudioObjectID *)malloc(size);
    if (!devices) return kAudioObjectUnknown;
    AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, devices);

    AudioObjectID physicalDevice = kAudioObjectUnknown;
    for (UInt32 i = 0; i < count; i++) {
        AudioObjectID dev = devices[i];
        AudioObjectPropertyAddress streamAddr = {
            .mSelector = kAudioDevicePropertyStreams,
            .mScope = kAudioDevicePropertyScopeOutput,
            .mElement = kAudioObjectPropertyElementMain
        };
        UInt32 streamSize = 0;
        AudioObjectGetPropertyDataSize(dev, &streamAddr, 0, NULL, &streamSize);
        if (streamSize == 0) continue;

        AudioObjectPropertyAddress trAddr = {
            .mSelector = kAudioDevicePropertyTransportType,
            .mScope = kAudioObjectPropertyScopeGlobal,
            .mElement = kAudioObjectPropertyElementMain
        };
        UInt32 transport = 0;
        UInt32 trSize = sizeof(transport);
        AudioObjectGetPropertyData(dev, &trAddr, 0, NULL, &trSize, &transport);

        if (transport == kAudioDeviceTransportTypeBuiltIn) {
            physicalDevice = dev;
            break;
        }
    }
    free(devices);
    return physicalDevice;
}

static AudioObjectID findActivePhysicalOutputDevice(void) {
    // 1. Check Default System Output Device (e.g. soundcore Space Q45 or Built-in Output)
    AudioObjectPropertyAddress sysAddr = {
        .mSelector = kAudioHardwarePropertyDefaultSystemOutputDevice,
        .mScope = kAudioObjectPropertyScopeGlobal,
        .mElement = kAudioObjectPropertyElementMain
    };
    AudioObjectID sysDev = kAudioObjectUnknown;
    UInt32 size = sizeof(sysDev);
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &sysAddr, 0, NULL, &size, &sysDev) == noErr) {
        if (sysDev != kAudioObjectUnknown && !isVirtualDevice(sysDev)) {
            return sysDev;
        }
    }

    // 2. Check for any connected Bluetooth output device
    AudioObjectPropertyAddress addr = {
        .mSelector = kAudioHardwarePropertyDevices,
        .mScope = kAudioObjectPropertyScopeGlobal,
        .mElement = kAudioObjectPropertyElementMain
    };
    size = 0;
    if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &addr, 0, NULL, &size) == noErr) {
        UInt32 count = size / sizeof(AudioObjectID);
        AudioObjectID *devices = (AudioObjectID *)malloc(size);
        if (devices) {
            AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, devices);
            for (UInt32 i = 0; i < count; i++) {
                AudioObjectID dev = devices[i];
                AudioObjectPropertyAddress streamAddr = {
                    .mSelector = kAudioDevicePropertyStreams,
                    .mScope = kAudioDevicePropertyScopeOutput,
                    .mElement = kAudioObjectPropertyElementMain
                };
                UInt32 streamSize = 0;
                AudioObjectGetPropertyDataSize(dev, &streamAddr, 0, NULL, &streamSize);
                if (streamSize == 0) continue;

                AudioObjectPropertyAddress trAddr = {
                    .mSelector = kAudioDevicePropertyTransportType,
                    .mScope = kAudioObjectPropertyScopeGlobal,
                    .mElement = kAudioObjectPropertyElementMain
                };
                UInt32 transport = 0;
                UInt32 trSize = sizeof(transport);
                AudioObjectGetPropertyData(dev, &trAddr, 0, NULL, &trSize, &transport);

                if (transport == kAudioDeviceTransportTypeBluetooth ||
                    transport == kAudioDeviceTransportTypeBluetoothLE) {
                    free(devices);
                    return dev;
                }
            }
            free(devices);
        }
    }

    // 3. Fall back to Built-in Output
    return findBuiltInOutputDevice();
}

static AudioObjectID getDefaultOutputDevice(void) {
    AudioObjectPropertyAddress addr = {
        .mSelector = kAudioHardwarePropertyDefaultOutputDevice,
        .mScope = kAudioObjectPropertyScopeGlobal,
        .mElement = kAudioObjectPropertyElementMain
    };
    AudioObjectID dev = kAudioObjectUnknown;
    UInt32 size = sizeof(dev);
    AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, &dev);
    return dev;
}

static void ensureWorkingInputDevice(void) {
    AudioObjectID tglMic = findDeviceByUID(@"TGLDmic_InternalMic_UID");
    if (tglMic == kAudioObjectUnknown) return;

    AudioObjectPropertyAddress inAddr = {
        .mSelector = kAudioHardwarePropertyDefaultInputDevice,
        .mScope = kAudioObjectPropertyScopeGlobal,
        .mElement = kAudioObjectPropertyElementMain
    };
    AudioObjectID curIn = kAudioObjectUnknown;
    UInt32 size = sizeof(curIn);
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &inAddr, 0, NULL, &size, &curIn) == noErr) {
        if (curIn != tglMic) {
            NSLog(@"[boom-volume-sync] Guard: Default input was %u, keeping working microphone (TGLDmic: %u)", curIn, tglMic);
            AudioObjectSetPropertyData(kAudioObjectSystemObject, &inAddr, 0, NULL, size, &tglMic);
        }
    }
}

static void syncVolumeAndMute(AudioObjectID srcDev, AudioObjectID dstDev) {
    if (srcDev == kAudioObjectUnknown || dstDev == kAudioObjectUnknown || srcDev == dstDev)
        return;

    // Volume
    AudioObjectPropertyAddress volAddr = {
        .mSelector = kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        .mScope = kAudioDevicePropertyScopeOutput,
        .mElement = kAudioObjectPropertyElementMain
    };
    Float32 vol = 0.0f;
    UInt32 size = sizeof(vol);
    if (AudioObjectGetPropertyData(srcDev, &volAddr, 0, NULL, &size, &vol) == noErr) {
        AudioObjectSetPropertyData(dstDev, &volAddr, 0, NULL, size, &vol);
    }

    // Mute
    AudioObjectPropertyAddress muteAddr = {
        .mSelector = kAudioDevicePropertyMute,
        .mScope = kAudioDevicePropertyScopeOutput,
        .mElement = kAudioObjectPropertyElementMain
    };
    UInt32 mute = 0;
    size = sizeof(mute);
    if (AudioObjectGetPropertyData(srcDev, &muteAddr, 0, NULL, &size, &mute) == noErr) {
        AudioObjectSetPropertyData(dstDev, &muteAddr, 0, NULL, size, &mute);
    }
}

static void removeVirtualListeners(void) {
    if (gVirtualDevice == kAudioObjectUnknown || !gVirtualListenerBlock) return;

    AudioObjectPropertyAddress volAddr = {
        .mSelector = kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        .mScope = kAudioDevicePropertyScopeOutput,
        .mElement = kAudioObjectPropertyElementMain
    };
    AudioObjectRemovePropertyListenerBlock(gVirtualDevice, &volAddr, dispatch_get_main_queue(), gVirtualListenerBlock);

    AudioObjectPropertyAddress muteAddr = {
        .mSelector = kAudioDevicePropertyMute,
        .mScope = kAudioDevicePropertyScopeOutput,
        .mElement = kAudioObjectPropertyElementMain
    };
    AudioObjectRemovePropertyListenerBlock(gVirtualDevice, &muteAddr, dispatch_get_main_queue(), gVirtualListenerBlock);

    gVirtualDevice = kAudioObjectUnknown;
}

static void updateActiveRouting(void) {
    ensureWorkingInputDevice();

    AudioObjectID targetOut = findActivePhysicalOutputDevice();
    AudioObjectID defDev = getDefaultOutputDevice();

    if (gTargetDevice != targetOut) {
        gTargetDevice = targetOut;
        NSLog(@"[boom-volume-sync] Active physical target changed to ID %u", gTargetDevice);
    }

    if (isVirtualDevice(defDev)) {
        if (gVirtualDevice != defDev) {
            removeVirtualListeners();
            gVirtualDevice = defDev;
            NSLog(@"[boom-volume-sync] Tracking virtual device ID %u -> target physical ID %u", gVirtualDevice, gTargetDevice);

            gVirtualListenerBlock = ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress *inAddresses) {
                syncVolumeAndMute(gVirtualDevice, gTargetDevice);
            };

            AudioObjectPropertyAddress volAddr = {
                .mSelector = kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                .mScope = kAudioDevicePropertyScopeOutput,
                .mElement = kAudioObjectPropertyElementMain
            };
            AudioObjectAddPropertyListenerBlock(gVirtualDevice, &volAddr, dispatch_get_main_queue(), gVirtualListenerBlock);

            AudioObjectPropertyAddress muteAddr = {
                .mSelector = kAudioDevicePropertyMute,
                .mScope = kAudioDevicePropertyScopeOutput,
                .mElement = kAudioObjectPropertyElementMain
            };
            AudioObjectAddPropertyListenerBlock(gVirtualDevice, &muteAddr, dispatch_get_main_queue(), gVirtualListenerBlock);
        }
        syncVolumeAndMute(gVirtualDevice, gTargetDevice);
    } else {
        removeVirtualListeners();
        NSLog(@"[boom-volume-sync] Default output is physical ID %u (no virtual routing needed)", defDev);
    }
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"[boom-volume-sync] Starting Boom 3D / WhatsApp / Bluetooth volume & mic guard service...");

        updateActiveRouting();

        // 1. Listen for default output device changes (Boom 3D starting/stopping)
        AudioObjectPropertyAddress defAddr = {
            .mSelector = kAudioHardwarePropertyDefaultOutputDevice,
            .mScope = kAudioObjectPropertyScopeGlobal,
            .mElement = kAudioObjectPropertyElementMain
        };
        AudioObjectAddPropertyListenerBlock(kAudioObjectSystemObject, &defAddr, dispatch_get_main_queue(), ^(UInt32 n, const AudioObjectPropertyAddress *a) {
            updateActiveRouting();
        });

        // 2. Listen for default system output changes (Bluetooth connecting/disconnecting)
        AudioObjectPropertyAddress sysDefAddr = {
            .mSelector = kAudioHardwarePropertyDefaultSystemOutputDevice,
            .mScope = kAudioObjectPropertyScopeGlobal,
            .mElement = kAudioObjectPropertyElementMain
        };
        AudioObjectAddPropertyListenerBlock(kAudioObjectSystemObject, &sysDefAddr, dispatch_get_main_queue(), ^(UInt32 n, const AudioObjectPropertyAddress *a) {
            NSLog(@"[boom-volume-sync] Default system output changed (Bluetooth connect/disconnect)");
            updateActiveRouting();
        });

        // 3. Listen for hardware device list changes
        AudioObjectPropertyAddress devListAddr = {
            .mSelector = kAudioHardwarePropertyDevices,
            .mScope = kAudioObjectPropertyScopeGlobal,
            .mElement = kAudioObjectPropertyElementMain
        };
        AudioObjectAddPropertyListenerBlock(kAudioObjectSystemObject, &devListAddr, dispatch_get_main_queue(), ^(UInt32 n, const AudioObjectPropertyAddress *a) {
            updateActiveRouting();
        });

        // 4. Listen for default input changes (prevent accidental switch to broken BT SCO mic)
        AudioObjectPropertyAddress inAddr = {
            .mSelector = kAudioHardwarePropertyDefaultInputDevice,
            .mScope = kAudioObjectPropertyScopeGlobal,
            .mElement = kAudioObjectPropertyElementMain
        };
        AudioObjectAddPropertyListenerBlock(kAudioObjectSystemObject, &inAddr, dispatch_get_main_queue(), ^(UInt32 n, const AudioObjectPropertyAddress *a) {
            ensureWorkingInputDevice();
        });

        [[NSRunLoop mainRunLoop] run];
    }
    return 0;
}
