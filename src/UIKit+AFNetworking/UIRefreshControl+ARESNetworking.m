// UIRefreshControl+ARESNetworking.m
//
// Copyright (c) 2014 ARESNetworking (http://ARESnetworking.com)
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

#import "UIRefreshControl+ARESNetworking.h"

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)

#import "ARESHTTPRequestOperation.h"

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 70000
#import "ARESURLSessionManager.h"
#endif

@implementation UIRefreshControl (ARESNetworking)

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 70000
- (void)setRefreshingWithStateOfTask:(NSURLSessionTask *)task {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter removeObserver:self name:ARESNetworkingTaskDidResumeNotification object:nil];
    [notificationCenter removeObserver:self name:ARESNetworkingTaskDidSuspendNotification object:nil];
    [notificationCenter removeObserver:self name:ARESNetworkingTaskDidCompleteNotification object:nil];

    if (task) {
        if (task.state != NSURLSessionTaskStateCompleted) {
            if (task.state == NSURLSessionTaskStateRunning) {
                [self beginRefreshing];
            } else {
                [self endRefreshing];
            }

            [notificationCenter addObserver:self selector:@selector(ARES_beginRefreshing) name:ARESNetworkingTaskDidResumeNotification object:task];
            [notificationCenter addObserver:self selector:@selector(ARES_endRefreshing) name:ARESNetworkingTaskDidCompleteNotification object:task];
            [notificationCenter addObserver:self selector:@selector(ARES_endRefreshing) name:ARESNetworkingTaskDidSuspendNotification object:task];
        }
    }
}
#endif

- (void)setRefreshingWithStateOfOperation:(ARESURLConnectionOperation *)operation {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter removeObserver:self name:ARESNetworkingOperationDidStartNotification object:nil];
    [notificationCenter removeObserver:self name:ARESNetworkingOperationDidFinishNotification object:nil];

    if (operation) {
        if (![operation isFinished]) {
            if ([operation isExecuting]) {
                [self beginRefreshing];
            } else {
                [self endRefreshing];
            }

            [notificationCenter addObserver:self selector:@selector(ARES_beginRefreshing) name:ARESNetworkingOperationDidStartNotification object:operation];
            [notificationCenter addObserver:self selector:@selector(ARES_endRefreshing) name:ARESNetworkingOperationDidFinishNotification object:operation];
        }
    }
}

#pragma mark -

- (void)ARES_beginRefreshing {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self beginRefreshing];
    });
}

- (void)ARES_endRefreshing {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self endRefreshing];
    });
}

@end

#endif
