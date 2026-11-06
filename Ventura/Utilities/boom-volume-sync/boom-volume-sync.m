#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import <AudioToolbox/AudioToolbox.h>

static AudioObjectID gHardwareDevice = kAudioObjectUnknown;
static AudioObjectID gVirtualDevice = kAudioObjectUnknown;
static AudioObjectPropertyListenerBlock gVirtualListenerBlock = nil;

static AudioObjectID findPhysicalOutputDevice(void) {
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

static void setupVirtualListeners(void) {
    removeVirtualListeners();

    gHardwareDevice = findPhysicalOutputDevice();
    AudioObjectID defDev = getDefaultOutputDevice();

    if (isVirtualDevice(defDev)) {
        gVirtualDevice = defDev;
        NSLog(@"[boom-volume-sync] Tracking virtual device ID %u -> syncing to hardware ID %u", gVirtualDevice, gHardwareDevice);

        gVirtualListenerBlock = ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress *inAddresses) {
            syncVolumeAndMute(gVirtualDevice, gHardwareDevice);
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

        // Initial sync
        syncVolumeAndMute(gVirtualDevice, gHardwareDevice);
    } else {
        NSLog(@"[boom-volume-sync] Default output device is physical ID %u (no virtual driver active)", defDev);
    }
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"[boom-volume-sync] Starting Boom 3D / WhatsApp hardware volume sync service...");

        setupVirtualListeners();

        // Listen for default output device changes (e.g. Boom 3D launched, quit, or device switched)
        AudioObjectPropertyAddress defAddr = {
            .mSelector = kAudioHardwarePropertyDefaultOutputDevice,
            .mScope = kAudioObjectPropertyScopeGlobal,
            .mElement = kAudioObjectPropertyElementMain
        };
        AudioObjectAddPropertyListenerBlock(kAudioObjectSystemObject, &defAddr, dispatch_get_main_queue(), ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress *inAddresses) {
            NSLog(@"[boom-volume-sync] Default output device changed, re-evaluating listeners...");
            setupVirtualListeners();
        });

        // Run main runloop indefinitely (consumes 0% CPU, pure event-driven)
        [[NSRunLoop mainRunLoop] run];
    }
    return 0;
}
