// ARESSecurity.m
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

#import "ARESSecurityPolicy.h"

// Equivalent of macro in <AssertMacros.h>, without causing compiler warning:
// "'DebugAssert' is deprecated: first deprecated in OS X 10.8"
#ifndef ARES_Require
    #define ARES_Require(assertion, exceptionLabel)                \
        do {                                                     \
            if (__builtin_expect(!(assertion), 0)) {             \
                goto exceptionLabel;                             \
            }                                                    \
        } while (0)
#endif

#ifndef ARES_Require_noErr
    #define ARES_Require_noErr(errorCode, exceptionLabel)          \
        do {                                                     \
            if (__builtin_expect(0 != (errorCode), 0)) {         \
                goto exceptionLabel;                             \
            }                                                    \
        } while (0)
#endif

#if !defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
static NSData * ARESSecKeyGetData(SecKeyRef key) {
    CFDataRef data = NULL;

    ARES_Require_noErr(SecItemExport(key, kSecFormatUnknown, kSecItemPemArmour, NULL, &data), _out);

    return (__bridge_transfer NSData *)data;

_out:
    if (data) {
        CFRelease(data);
    }

    return nil;
}
#endif

static BOOL ARESSecKeyIsEqualToKey(SecKeyRef key1, SecKeyRef key2) {
#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
    return [(__bridge id)key1 isEqual:(__bridge id)key2];
#else
    return [ARESSecKeyGetData(key1) isEqual:ARESSecKeyGetData(key2)];
#endif
}

static id ARESPublicKeyForCertificate(NSData *certificate) {
    id allowedPublicKey = nil;
    SecCertificateRef allowedCertificate;
    SecCertificateRef allowedCertificates[1];
    CFArrayRef tempCertificates = nil;
    SecPolicyRef policy = nil;
    SecTrustRef allowedTrust = nil;
    SecTrustResultType result;

    allowedCertificate = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certificate);
    ARES_Require(allowedCertificate != NULL, _out);

    allowedCertificates[0] = allowedCertificate;
    tempCertificates = CFArrayCreate(NULL, (const void **)allowedCertificates, 1, NULL);

    policy = SecPolicyCreateBasicX509();
    ARES_Require_noErr(SecTrustCreateWithCertificates(tempCertificates, policy, &allowedTrust), _out);
    ARES_Require_noErr(SecTrustEvaluate(allowedTrust, &result), _out);

    allowedPublicKey = (__bridge_transfer id)SecTrustCopyPublicKey(allowedTrust);

_out:
    if (allowedTrust) {
        CFRelease(allowedTrust);
    }

    if (policy) {
        CFRelease(policy);
    }

    if (tempCertificates) {
        CFRelease(tempCertificates);
    }

    if (allowedCertificate) {
        CFRelease(allowedCertificate);
    }

    return allowedPublicKey;
}

static BOOL ARESServerTrustIsValid(SecTrustRef serverTrust) {
    BOOL isValid = NO;
    SecTrustResultType result;
    ARES_Require_noErr(SecTrustEvaluate(serverTrust, &result), _out);

    isValid = (result == kSecTrustResultUnspecified || result == kSecTrustResultProceed);

_out:
    return isValid;
}

static NSArray * ARESCertificateTrustChainForServerTrust(SecTrustRef serverTrust) {
    CFIndex certificateCount = SecTrustGetCertificateCount(serverTrust);
    NSMutableArray *trustChain = [NSMutableArray arrayWithCapacity:(NSUInteger)certificateCount];

    for (CFIndex i = 0; i < certificateCount; i++) {
        SecCertificateRef certificate = SecTrustGetCertificateAtIndex(serverTrust, i);
        [trustChain addObject:(__bridge_transfer NSData *)SecCertificateCopyData(certificate)];
    }

    return [NSArray arrayWithArray:trustChain];
}

static NSArray * ARESPublicKeyTrustChainForServerTrust(SecTrustRef serverTrust) {
    SecPolicyRef policy = SecPolicyCreateBasicX509();
    CFIndex certificateCount = SecTrustGetCertificateCount(serverTrust);
    NSMutableArray *trustChain = [NSMutableArray arrayWithCapacity:(NSUInteger)certificateCount];
    for (CFIndex i = 0; i < certificateCount; i++) {
        SecCertificateRef certificate = SecTrustGetCertificateAtIndex(serverTrust, i);

        SecCertificateRef someCertificates[] = {certificate};
        CFArrayRef certificates = CFArrayCreate(NULL, (const void **)someCertificates, 1, NULL);

        SecTrustRef trust;
        ARES_Require_noErr(SecTrustCreateWithCertificates(certificates, policy, &trust), _out);
        
        SecTrustResultType result;
        ARES_Require_noErr(SecTrustEvaluate(trust, &result), _out);

        [trustChain addObject:(__bridge_transfer id)SecTrustCopyPublicKey(trust)];

    _out:
        if (trust) {
            CFRelease(trust);
        }

        if (certificates) {
            CFRelease(certificates);
        }

        continue;
    }
    CFRelease(policy);

    return [NSArray arrayWithArray:trustChain];
}

#pragma mark -

@interface ARESSecurityPolicy()
@property (readwrite, nonatomic, strong) NSArray *pinnedPublicKeys;
@end

@implementation ARESSecurityPolicy

+ (NSArray *)defaultPinnedCertificates {
    static NSArray *_defaultPinnedCertificates = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSArray *paths = [bundle pathsForResourcesOfType:@"cer" inDirectory:@"."];

        NSMutableArray *certificates = [NSMutableArray arrayWithCapacity:[paths count]];
        for (NSString *path in paths) {
            NSData *certificateData = [NSData dataWithContentsOfFile:path];
            [certificates addObject:certificateData];
        }

        _defaultPinnedCertificates = [[NSArray alloc] initWithArray:certificates];
    });

    return _defaultPinnedCertificates;
}

+ (instancetype)defaultPolicy {
    ARESSecurityPolicy *securityPolicy = [[self alloc] init];
    securityPolicy.SSLPinningMode = ARESSSLPinningModeNone;

    return securityPolicy;
}

+ (instancetype)policyWithPinningMode:(ARESSSLPinningMode)pinningMode {
    ARESSecurityPolicy *securityPolicy = [[self alloc] init];
    securityPolicy.SSLPinningMode = pinningMode;
    securityPolicy.validatesDomainName = YES;
    [securityPolicy setPinnedCertificates:[self defaultPinnedCertificates]];

    return securityPolicy;
}

- (id)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    self.validatesCertificateChain = YES;

    return self;
}

#pragma mark -

- (void)setPinnedCertificates:(NSArray *)pinnedCertificates {
    _pinnedCertificates = pinnedCertificates;

    if (self.pinnedCertificates) {
        NSMutableArray *mutablePinnedPublicKeys = [NSMutableArray arrayWithCapacity:[self.pinnedCertificates count]];
        for (NSData *certificate in self.pinnedCertificates) {
            id publicKey = ARESPublicKeyForCertificate(certificate);
            if (!publicKey) {
                continue;
            }
            [mutablePinnedPublicKeys addObject:publicKey];
        }
        self.pinnedPublicKeys = [NSArray arrayWithArray:mutablePinnedPublicKeys];
    } else {
        self.pinnedPublicKeys = nil;
    }
}

#pragma mark -

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust {
    return [self evaluateServerTrust:serverTrust forDomain:nil];
}

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust
                  forDomain:(NSString *)domain
{
    NSMutableArray *policies = [NSMutableArray array];
    if (self.validatesDomainName) {
        [policies addObject:(__bridge_transfer id)SecPolicyCreateSSL(true, (__bridge CFStringRef)domain)];
    } else {
        [policies addObject:(__bridge_transfer id)SecPolicyCreateBasicX509()];
    }

    SecTrustSetPolicies(serverTrust, (__bridge CFArrayRef)policies);

    if (!ARESServerTrustIsValid(serverTrust) && !self.allowInvalidCertificates) {
        return NO;
    }

    NSArray *serverCertificates = ARESCertificateTrustChainForServerTrust(serverTrust);
    switch (self.SSLPinningMode) {
        case ARESSSLPinningModeNone:
            return YES;
        case ARESSSLPinningModeCertificate: {
            NSMutableArray *pinnedCertificates = [NSMutableArray array];
            for (NSData *certificateData in self.pinnedCertificates) {
                [pinnedCertificates addObject:(__bridge_transfer id)SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certificateData)];
            }
            SecTrustSetAnchorCertificates(serverTrust, (__bridge CFArrayRef)pinnedCertificates);

            if (!ARESServerTrustIsValid(serverTrust)) {
                return NO;
            }

            if (!self.validatesCertificateChain) {
                return YES;
            }

            NSUInteger trustedCertificateCount = 0;
            for (NSData *trustChainCertificate in serverCertificates) {
                if ([self.pinnedCertificates containsObject:trustChainCertificate]) {
                    trustedCertificateCount++;
                }
            }

            return trustedCertificateCount == [serverCertificates count];
        }
        case ARESSSLPinningModePublicKey: {
            NSUInteger trustedPublicKeyCount = 0;
            NSArray *publicKeys = ARESPublicKeyTrustChainForServerTrust(serverTrust);
            if (!self.validatesCertificateChain && [publicKeys count] > 0) {
                publicKeys = @[[publicKeys firstObject]];
            }

            for (id trustChainPublicKey in publicKeys) {
                for (id pinnedPublicKey in self.pinnedPublicKeys) {
                    if (ARESSecKeyIsEqualToKey((__bridge SecKeyRef)trustChainPublicKey, (__bridge SecKeyRef)pinnedPublicKey)) {
                        trustedPublicKeyCount += 1;
                    }
                }
            }

            return trustedPublicKeyCount > 0 && ((self.validatesCertificateChain && trustedPublicKeyCount == [serverCertificates count]) || (!self.validatesCertificateChain && trustedPublicKeyCount >= 1));
        }
    }
    
    return NO;
}

#pragma mark - NSKeyValueObserving

+ (NSSet *)keyPathsForValuesARESfectingPinnedPublicKeys {
    return [NSSet setWithObject:@"pinnedCertificates"];
}

@end
