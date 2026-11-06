#import <Foundation/Foundation.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <signal.h>

static IOPMAssertionID g_assertion = 0;

void sig_handler(int signo) {
    if (g_assertion) {
        IOPMAssertionRelease(g_assertion);
        g_assertion = 0;
    }
    exit(0);
}

int main() {
    @autoreleasepool {
        signal(SIGINT, sig_handler);
        signal(SIGTERM, sig_handler);

        IOReturn ret = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventSystemSleep,
            kIOPMAssertionLevelOn,
            CFSTR("Prevent Clamshell S3 Crash"),
            &g_assertion
        );

        if (ret != kIOReturnSuccess) {
            NSLog(@"Failed to create assertion: %d", ret);
            return 1;
        }

        NSLog(@"Clamshell-fix active. PreventSystemSleep asserted.");
        CFRunLoopRun();
    }
    return 0;
}
