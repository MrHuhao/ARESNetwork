// UIButton+ARESNetworking.m
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

#import "UIButton+ARESNetworking.h"

#import <objc/runtime.h>

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)

#import "ARESURLResponseSerialization.h"
#import "ARESHTTPRequestOperation.h"

#import "UIImageView+ARESNetworking.h"

@interface UIButton (_ARESNetworking)
@end

@implementation UIButton (_ARESNetworking)

+ (NSOperationQueue *)ARES_sharedImageRequestOperationQueue {
    static NSOperationQueue *_ARES_sharedImageRequestOperationQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _ARES_sharedImageRequestOperationQueue = [[NSOperationQueue alloc] init];
        _ARES_sharedImageRequestOperationQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;
    });

    return _ARES_sharedImageRequestOperationQueue;
}

#pragma mark -

static const char * ARES_imageRequestOperationKeyForState(UIControlState state) {
    return [[NSString stringWithFormat:@"ARES_imageRequestOperationKeyForState_%lu", (unsigned long)state] cStringUsingEncoding:NSASCIIStringEncoding];
}

- (ARESHTTPRequestOperation *)ARES_imageRequestOperationForState:(UIControlState)state {
    return (ARESHTTPRequestOperation *)objc_getAssociatedObject(self, ARES_imageRequestOperationKeyForState(state));
}

- (void)ARES_setImageRequestOperation:(ARESHTTPRequestOperation *)imageRequestOperation
                           forState:(UIControlState)state
{
    objc_setAssociatedObject(self, ARES_imageRequestOperationKeyForState(state), imageRequestOperation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark -

static const char * ARES_backgroundImageRequestOperationKeyForState(UIControlState state) {
    return [[NSString stringWithFormat:@"ARES_backgroundImageRequestOperationKeyForState_%lu", (unsigned long)state] cStringUsingEncoding:NSASCIIStringEncoding];
}

- (ARESHTTPRequestOperation *)ARES_backgroundImageRequestOperationForState:(UIControlState)state {
    return (ARESHTTPRequestOperation *)objc_getAssociatedObject(self, ARES_backgroundImageRequestOperationKeyForState(state));
}

- (void)ARES_setBackgroundImageRequestOperation:(ARESHTTPRequestOperation *)imageRequestOperation
                                     forState:(UIControlState)state
{
    objc_setAssociatedObject(self, ARES_backgroundImageRequestOperationKeyForState(state), imageRequestOperation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#pragma mark -

@implementation UIButton (ARESNetworking)

+ (id <ARESImageCache>)sharedImageCache {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
    return objc_getAssociatedObject(self, @selector(sharedImageCache)) ?: [UIImageView sharedImageCache];
#pragma clang diagnostic pop
}

+ (void)setSharedImageCache:(id <ARESImageCache>)imageCache {
    objc_setAssociatedObject(self, @selector(sharedImageCache), imageCache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark -

- (id <ARESURLResponseSerialization>)imageResponseSerializer {
    static id <ARESURLResponseSerialization> _ARES_defaultImageResponseSerializer = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _ARES_defaultImageResponseSerializer = [ARESImageResponseSerializer serializer];
    });

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
    return objc_getAssociatedObject(self, @selector(imageResponseSerializer)) ?: _ARES_defaultImageResponseSerializer;
#pragma clang diagnostic pop
}

- (void)setImageResponseSerializer:(id <ARESURLResponseSerialization>)serializer {
    objc_setAssociatedObject(self, @selector(imageResponseSerializer), serializer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark -

- (void)setImageForState:(UIControlState)state
                 withURL:(NSURL *)url
{
    [self setImageForState:state withURL:url placeholderImage:nil];
}

- (void)setImageForState:(UIControlState)state
                 withURL:(NSURL *)url
        placeholderImage:(UIImage *)placeholderImage
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];

    [self setImageForState:state withURLRequest:request placeholderImage:placeholderImage success:nil failure:nil];
}

- (void)setImageForState:(UIControlState)state
          withURLRequest:(NSURLRequest *)urlRequest
        placeholderImage:(UIImage *)placeholderImage
                 success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image))success
                 failure:(void (^)(NSError *error))failure
{
    [self cancelImageRequestOperationForState:state];

    UIImage *cachedImage = [[[self class] sharedImageCache] cachedImageForRequest:urlRequest];
    if (cachedImage) {
        if (success) {
            success(nil, nil, cachedImage);
        } else {
            [self setImage:cachedImage forState:state];
        }

        [self ARES_setImageRequestOperation:nil forState:state];
    } else {
        if (placeholderImage) {
            [self setImage:placeholderImage forState:state];
        }

        __weak __typeof(self)weakSelf = self;
        ARESHTTPRequestOperation *imageRequestOperation = [[ARESHTTPRequestOperation alloc] initWithRequest:urlRequest];
        imageRequestOperation.responseSerializer = self.imageResponseSerializer;
        [imageRequestOperation setCompletionBlockWithSuccess:^(ARESHTTPRequestOperation *operation, id responseObject) {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            if ([[urlRequest URL] isEqual:[operation.request URL]]) {
                if (success) {
                    success(operation.request, operation.response, responseObject);
                } else if (responseObject) {
                    [strongSelf setImage:responseObject forState:state];
                }
            }
            [[[strongSelf class] sharedImageCache] cacheImage:responseObject forRequest:urlRequest];
        } failure:^(ARESHTTPRequestOperation *operation, NSError *error) {
            if ([[urlRequest URL] isEqual:[operation.response URL]]) {
                if (failure) {
                    failure(error);
                }
            }
        }];

        [self ARES_setImageRequestOperation:imageRequestOperation forState:state];
        [[[self class] ARES_sharedImageRequestOperationQueue] addOperation:imageRequestOperation];
    }
}

#pragma mark -

- (void)setBackgroundImageForState:(UIControlState)state
                           withURL:(NSURL *)url
{
    [self setBackgroundImageForState:state withURL:url placeholderImage:nil];
}

- (void)setBackgroundImageForState:(UIControlState)state
                           withURL:(NSURL *)url
                  placeholderImage:(UIImage *)placeholderImage
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];

    [self setBackgroundImageForState:state withURLRequest:request placeholderImage:placeholderImage success:nil failure:nil];
}

- (void)setBackgroundImageForState:(UIControlState)state
                    withURLRequest:(NSURLRequest *)urlRequest
                  placeholderImage:(UIImage *)placeholderImage
                           success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image))success
                           failure:(void (^)(NSError *error))failure
{
    [self cancelBackgroundImageRequestOperationForState:state];

    UIImage *cachedImage = [[[self class] sharedImageCache] cachedImageForRequest:urlRequest];
    if (cachedImage) {
        if (success) {
            success(nil, nil, cachedImage);
        } else {
            [self setBackgroundImage:cachedImage forState:state];
        }

        [self ARES_setBackgroundImageRequestOperation:nil forState:state];
    } else {
        if (placeholderImage) {
            [self setBackgroundImage:placeholderImage forState:state];
        }

        __weak __typeof(self)weakSelf = self;
        ARESHTTPRequestOperation *backgroundImageRequestOperation = [[ARESHTTPRequestOperation alloc] initWithRequest:urlRequest];
        backgroundImageRequestOperation.responseSerializer = self.imageResponseSerializer;
        [backgroundImageRequestOperation setCompletionBlockWithSuccess:^(ARESHTTPRequestOperation *operation, id responseObject) {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            if ([[urlRequest URL] isEqual:[operation.request URL]]) {
                if (success) {
                    success(operation.request, operation.response, responseObject);
                } else if (responseObject) {
                    [strongSelf setBackgroundImage:responseObject forState:state];
                }
            }
        } failure:^(ARESHTTPRequestOperation *operation, NSError *error) {
            if ([[urlRequest URL] isEqual:[operation.response URL]]) {
                if (failure) {
                    failure(error);
                }
            }
        }];

        [self ARES_setBackgroundImageRequestOperation:backgroundImageRequestOperation forState:state];
        [[[self class] ARES_sharedImageRequestOperationQueue] addOperation:backgroundImageRequestOperation];
    }
}

#pragma mark -

- (void)cancelImageRequestOperationForState:(UIControlState)state {
    [[self ARES_imageRequestOperationForState:state] cancel];
    [self ARES_setImageRequestOperation:nil forState:state];
}

- (void)cancelBackgroundImageRequestOperationForState:(UIControlState)state {
    [[self ARES_backgroundImageRequestOperationForState:state] cancel];
    [self ARES_setBackgroundImageRequestOperation:nil forState:state];
}

@end

#endif
