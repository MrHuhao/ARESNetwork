// UIActivityIndicatorView+ARESNetworking.m
//
// Copyright (c) 2013-2014 ARESNetworking (http://ARESnetworking.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "UIActivityIndicatorView+ARESNetworking.h"

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)

#import "ARESHTTPRequestOperation.h"

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 70000
#import "ARESURLSessionManager.h"
#endif

@implementation UIActivityIndicatorView (ARESNetworking)

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 70000
- (void)setAnimatingWithStateOfTask:(NSURLSessionTask *)task {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter removeObserver:self name:ARESNetworkingTaskDidResumeNotification object:nil];
    [notificationCenter removeObserver:self name:ARESNetworkingTaskDidSuspendNotification object:nil];
    [notificationCenter removeObserver:self name:ARESNetworkingTaskDidCompleteNotification object:nil];

    if (task) {
        if (task.state != NSURLSessionTaskStateCompleted) {
            if (task.state == NSURLSessionTaskStateRunning) {
                [self startAnimating];
            } else {
                [self stopAnimating];
            }

            [notificationCenter addObserver:self selector:@selector(ARES_startAnimating) name:ARESNetworkingTaskDidResumeNotification object:task];
            [notificationCenter addObserver:self selector:@selector(ARES_stopAnimating) name:ARESNetworkingTaskDidCompleteNotification object:task];
            [notificationCenter addObserver:self selector:@selector(ARES_stopAnimating) name:ARESNetworkingTaskDidSuspendNotification object:task];
        }
    }
}
#endif

#pragma mark -

- (void)setAnimatingWithStateOfOperation:(ARESURLConnectionOperation *)operation {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter removeObserver:self name:ARESNetworkingOperationDidStartNotification object:nil];
    [notificationCenter removeObserver:self name:ARESNetworkingOperationDidFinishNotification object:nil];

    if (operation) {
        if (![operation isFinished]) {
            if ([operation isExecuting]) {
                [self startAnimating];
            } else {
                [self stopAnimating];
            }

            [notificationCenter addObserver:self selector:@selector(ARES_startAnimating) name:ARESNetworkingOperationDidStartNotification object:operation];
            [notificationCenter addObserver:self selector:@selector(ARES_stopAnimating) name:ARESNetworkingOperationDidFinishNotification object:operation];
        }
    }
}

#pragma mark -

- (void)ARES_startAnimating {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self startAnimating];
    });
}

- (void)ARES_stopAnimating {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self stopAnimating];
    });
}

@end

#endif
