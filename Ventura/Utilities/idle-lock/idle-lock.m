#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#include <dlfcn.h>
#include <signal.h>

static IOPMAssertionID g_displayAssertion = kIOPMNullAssertionID;
static IOPMAssertionID g_systemAssertion = kIOPMNullAssertionID;

static void (*SACLockScreenImmediate)(void) = NULL;

static void setup_power_assertions(void) {
    if (g_displayAssertion == kIOPMNullAssertionID) {
        IOReturn ret = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep,
            kIOPMAssertionLevelOn,
            CFSTR("Prevent Display Sleep to maintain Tiger Lake eDP link"),
            &g_displayAssertion
        );
        if (ret == kIOReturnSuccess) {
            NSLog(@"[idle-lock] PreventUserIdleDisplaySleep assertion active (id: %u)", g_displayAssertion);
        } else {
            NSLog(@"[idle-lock] Warning: Failed to create display sleep assertion: %d", ret);
        }
    }

    if (g_systemAssertion == kIOPMNullAssertionID) {
        IOReturn ret = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep,
            kIOPMAssertionLevelOn,
            CFSTR("Prevent System Sleep on Tiger Lake Hackintosh"),
            &g_systemAssertion
        );
        if (ret == kIOReturnSuccess) {
            NSLog(@"[idle-lock] PreventUserIdleSystemSleep assertion active (id: %u)", g_systemAssertion);
        }
    }
}

static void release_power_assertions(void) {
    if (g_displayAssertion != kIOPMNullAssertionID) {
        IOPMAssertionRelease(g_displayAssertion);
        g_displayAssertion = kIOPMNullAssertionID;
    }
    if (g_systemAssertion != kIOPMNullAssertionID) {
        IOPMAssertionRelease(g_systemAssertion);
        g_systemAssertion = kIOPMNullAssertionID;
    }
}

static void sig_handler(int sig) {
    NSLog(@"[idle-lock] Received signal %d, exiting...", sig);
    release_power_assertions();
    exit(0);
}

static BOOL is_screen_locked(void) {
    CFDictionaryRef dict = CGSessionCopyCurrentDictionary();
    if (!dict) return NO;
    NSDictionary *d = (__bridge NSDictionary *)dict;
    BOOL locked = [d[@"CGSSessionScreenIsLocked"] boolValue];
    CFRelease(dict);
    return locked;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        signal(SIGINT, sig_handler);
        signal(SIGTERM, sig_handler);
        
        NSLog(@"[idle-lock] Starting Tiger Lake Native Idle Lock daemon...");
        
        // Resolve SACLockScreenImmediate
        void *hLogin = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY);
        if (hLogin) {
            SACLockScreenImmediate = (void(*)(void))dlsym(hLogin, "SACLockScreenImmediate");
        }
        if (!SACLockScreenImmediate) {
            NSLog(@"[idle-lock] Warning: SACLockScreenImmediate not found, will use fallback");
        }
        
        // Ensure display sleep assertions are held
        setup_power_assertions();
        
        // Timer every 5 seconds to check idle time
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:5.0 repeats:YES block:^(NSTimer * _Nonnull t) {
            // Read timeout preference from user defaults (defaults read com.user.idlelock timeout)
            NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
            [defs synchronize];
            double timeout = [defs doubleForKey:@"timeout"];
            if (timeout <= 0) {
                timeout = 300.0; // Default: 300 seconds (5 minutes)
            }
            
            // Re-verify assertions
            setup_power_assertions();
            
            // Check if already locked
            if (is_screen_locked()) {
                return;
            }
            
            // Query seconds since last user input event
            CFTimeInterval idle = CGEventSourceSecondsSinceLastEventType(
                kCGEventSourceStateCombinedSessionState,
                kCGAnyInputEventType
            );
            
            if (idle >= timeout) {
                NSLog(@"[idle-lock] User idle for %.1fs (timeout=%.1fs). Locking screen...", idle, timeout);
                if (SACLockScreenImmediate) {
                    SACLockScreenImmediate();
                } else {
                    // Fallback to CGSession
                    system("/System/Library/CoreServices/Menu\\ Extras/User.menu/Contents/Resources/CGSession -suspend 2>/dev/null");
                }
            }
        }];
        
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        [[NSRunLoop currentRunLoop] run];
    }
    return 0;
}
