#import <Foundation/Foundation.h>
#import <LocalAuthentication/LocalAuthentication.h>

// Prefix for finding our lines in idevicesyslog
static NSString * const kLogPrefix = @"[LAVPNFix]";

%hook LAContext

// nehelper calls this to decide whether user consent can be evaluated.
// On the downgrade it fails with LAError code -1000 (ACMContextCreate failed)
// because the SEP is from a newer iOS. We answer "yes" locally.
- (BOOL)canEvaluatePolicy:(LAPolicy)policy error:(NSError **)error {
    NSLog(@"%@ canEvaluatePolicy(%ld) -> YES", kLogPrefix, (long)policy);
    if (error) { *error = nil; }
    return YES;
}

// The actual consent evaluation. On stock devices this would show Face ID /
// passcode UI; here we just grant it immediately.
- (void)evaluatePolicy:(LAPolicy)policy localizedReason:(NSString *)localizedReason
                 reply:(void (^)(BOOL success, NSError *error))reply {
    NSLog(@"%@ evaluatePolicy(%ld) -> YES (granted)", kLogPrefix, (long)policy);
    reply(YES, nil);
}

%end

%ctor {
    NSString *proc = [[NSProcessInfo processInfo] processName];
    NSLog(@"%@ loaded into pid %d (%@)", kLogPrefix, getpid(), proc);
    %init;
}
