// UIImageView+ARESNetworking.m
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

#import "UIImageView+ARESNetworking.h"

#import <objc/runtime.h>

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)

#import "ARESHTTPRequestOperation.h"

@interface ARESImageCache : NSCache <ARESImageCache>
@end

#pragma mark -

@interface UIImageView (_ARESNetworking)
@property (readwrite, nonatomic, strong, setter = ARES_setImageRequestOperation:) ARESHTTPRequestOperation *ARES_imageRequestOperation;
@end

@implementation UIImageView (_ARESNetworking)

+ (NSOperationQueue *)ARES_sharedImageRequestOperationQueue {
    static NSOperationQueue *_ARES_sharedImageRequestOperationQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _ARES_sharedImageRequestOperationQueue = [[NSOperationQueue alloc] init];
        _ARES_sharedImageRequestOperationQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;
    });

    return _ARES_sharedImageRequestOperationQueue;
}

- (ARESHTTPRequestOperation *)ARES_imageRequestOperation {
    return (ARESHTTPRequestOperation *)objc_getAssociatedObject(self, @selector(ARES_imageRequestOperation));
}

- (void)ARES_setImageRequestOperation:(ARESHTTPRequestOperation *)imageRequestOperation {
    objc_setAssociatedObject(self, @selector(ARES_imageRequestOperation), imageRequestOperation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#pragma mark -

@implementation UIImageView (ARESNetworking)
@dynamic imageResponseSerializer;

+ (id <ARESImageCache>)sharedImageCache {
    static ARESImageCache *_ARES_defaultImageCache = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _ARES_defaultImageCache = [[ARESImageCache alloc] init];

        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * __unused notification) {
            [_ARES_defaultImageCache removeAllObjects];
        }];
    });

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
    return objc_getAssociatedObject(self, @selector(sharedImageCache)) ?: _ARES_defaultImageCache;
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

- (void)setImageWithURL:(NSURL *)url {
    [self setImageWithURL:url placeholderImage:nil];
}

- (void)setImageWithURL:(NSURL *)url
       placeholderImage:(UIImage *)placeholderImage
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];

    [self setImageWithURLRequest:request placeholderImage:placeholderImage success:nil failure:nil];
}

- (void)setImageWithURLRequest:(NSURLRequest *)urlRequest
              placeholderImage:(UIImage *)placeholderImage
                       success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image))success
                       failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure
{
    [self cancelImageRequestOperation];

    UIImage *cachedImage = [[[self class] sharedImageCache] cachedImageForRequest:urlRequest];
    if (cachedImage) {
        if (success) {
            success(nil, nil, cachedImage);
        } else {
            self.image = cachedImage;
        }

        self.ARES_imageRequestOperation = nil;
    } else {
        if (placeholderImage) {
            self.image = placeholderImage;
        }
        
        __weak __typeof(self)weakSelf = self;
        self.ARES_imageRequestOperation = [[ARESHTTPRequestOperation alloc] initWithRequest:urlRequest];
        self.ARES_imageRequestOperation.responseSerializer = self.imageResponseSerializer;
        [self.ARES_imageRequestOperation setCompletionBlockWithSuccess:^(ARESHTTPRequestOperation *operation, id responseObject) {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            if ([[urlRequest URL] isEqual:[strongSelf.ARES_imageRequestOperation.request URL]]) {
                if (success) {
                    success(urlRequest, operation.response, responseObject);
                } else if (responseObject) {
                    strongSelf.image = responseObject;
                }

                if (operation == strongSelf.ARES_imageRequestOperation){
                        strongSelf.ARES_imageRequestOperation = nil;
                }
            }

            [[[strongSelf class] sharedImageCache] cacheImage:responseObject forRequest:urlRequest];
        } failure:^(ARESHTTPRequestOperation *operation, NSError *error) {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            if ([[urlRequest URL] isEqual:[strongSelf.ARES_imageRequestOperation.request URL]]) {
                if (failure) {
                    failure(urlRequest, operation.response, error);
                }

                if (operation == strongSelf.ARES_imageRequestOperation){
                        strongSelf.ARES_imageRequestOperation = nil;
                }
            }
        }];

        [[[self class] ARES_sharedImageRequestOperationQueue] addOperation:self.ARES_imageRequestOperation];
    }
}

- (void)cancelImageRequestOperation {
    [self.ARES_imageRequestOperation cancel];
    self.ARES_imageRequestOperation = nil;
}

@end

#pragma mark -

static inline NSString * ARESImageCacheKeyFromURLRequest(NSURLRequest *request) {
    return [[request URL] absoluteString];
}

@implementation ARESImageCache

- (UIImage *)cachedImageForRequest:(NSURLRequest *)request {
    switch ([request cachePolicy]) {
        case NSURLRequestReloadIgnoringCacheData:
        case NSURLRequestReloadIgnoringLocalAndRemoteCacheData:
            return nil;
        default:
            break;
    }

	return [self objectForKey:ARESImageCacheKeyFromURLRequest(request)];
}

- (void)cacheImage:(UIImage *)image
        forRequest:(NSURLRequest *)request
{
    if (image && request) {
        [self setObject:image forKey:ARESImageCacheKeyFromURLRequest(request)];
    }
}

@end

#endif