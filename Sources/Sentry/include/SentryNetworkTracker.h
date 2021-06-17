#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const SENTRY_NETWORK_REQUEST_OPERATION = @"network.request";

@interface SentryNetworkTracker : NSObject

@property (class, readonly, nonatomic) SentryNetworkTracker *sharedInstance;

- (void)urlSessionTaskResume:(NSURLSessionTask *)sessionTask;

@end

NS_ASSUME_NONNULL_END