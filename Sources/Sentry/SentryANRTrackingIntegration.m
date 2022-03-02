#import "SentryANRTrackingIntegration.h"
#import "SentryANRTracker.h"
#import "SentryCrashAdapter.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryLog.h"
#import "SentryThreadWrapper.h"
#import <Foundation/Foundation.h>
#import <SentryOptions+Private.h>
#import <SentryEvent.h>
#import <SentryException.h>
#import <SentrySDK.h>
#import <SentryMechanism.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryANRTrackingIntegration ()

@property (nonatomic, strong) SentryANRTracker *tracker;
@property (nullable, nonatomic, copy) NSString *testConfigurationFilePath;

@end

@implementation SentryANRTrackingIntegration

- (instancetype)init
{
    if (self = [super init]) {
        self.testConfigurationFilePath
            = NSProcessInfo.processInfo.environment[@"XCTestConfigurationFilePath"];
    }
    return self;
}

- (void)installWithOptions:(SentryOptions *)options
{
    if ([self shouldBeDisabled:options]) {
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    self.tracker =
        [[SentryANRTracker alloc] initWithDelegate:self
                             timeoutIntervalMillis:options.anrTimeoutIntervalMillis
                               currentDateProvider:[SentryDefaultCurrentDateProvider sharedInstance]
                                      crashAdapter:[SentryCrashAdapter sharedInstance]
                              dispatchQueueWrapper:[[SentryDispatchQueueWrapper alloc] init]
                                     threadWrapper:[[SentryThreadWrapper alloc] init]];
    [self.tracker start];
}

- (BOOL)shouldBeDisabled:(SentryOptions *)options
{
    if (!options.enableANRTracking) {
        return YES;
    }

    SentryCrashAdapter *crashAdapter = [SentryCrashAdapter sharedInstance];
    if ([crashAdapter isBeingTraced] && !options.enableANRTrackingInDebug) {
        return YES;
    }

    // The testConfigurationFilePath is not nil when running unit tests. This doesn't work for UI
    // tests though.
    if (self.testConfigurationFilePath) {
        [SentryLog logWithMessage:@"Won't track ANRs, because detected that unit tests are running."
                         andLevel:kSentryLevelDebug];
        return YES;
    }

    return NO;
}

- (void)uninstall
{
    if (nil != self.tracker) {
        [self.tracker stop];
    }
}

- (void)anrDetected
{
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelError];

    SentryException *exception =
        [[SentryException alloc] initWithValue:@"ANR happened"
                                          type:@"ANR"];
    SentryMechanism *mechanism = [[SentryMechanism alloc] initWithType:@"ANR"];
    mechanism.handled = @(YES);
    exception.mechanism = mechanism;
    event.exceptions = @[ exception ];
    
    [SentrySDK captureEvent:event];
    [SentryLog logWithMessage:@"ANR detected" andLevel:kSentryLevelDebug];
}

@end

NS_ASSUME_NONNULL_END
