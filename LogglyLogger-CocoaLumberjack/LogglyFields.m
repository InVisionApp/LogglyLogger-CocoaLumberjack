//
// Created by Mats Melke on 2014-02-20.
//

#import "LogglyFields.h"



#if TARGET_OS_IPHONE
@import UIKit;
#elif TARGET_OS_MAC
@import Cocoa;

#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/sysctl.h>

#endif

@implementation LogglyFields {
    dispatch_queue_t _queue;
    NSDictionary *_fieldsDictionary;
}

- (id)init {
    if((self = [super init])) {
        _queue = dispatch_queue_create("se.baresi.logglylogger.logglyfields.queue", NULL);
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:0];
        [dict setObject:[[NSLocale preferredLanguages] objectAtIndex:0] forKey:@"lang"];
        id bundleDisplayName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
        if (bundleDisplayName != nil) {
            [dict setObject:bundleDisplayName forKey:@"appname"];
        } else {
            NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
            if(bundleName != nil) {
                [dict setObject:bundleName forKey:@"appname"];
            }
        }
        NSString *bundleVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
        if(bundleVersion != nil) {
            [dict setObject:bundleVersion forKey:@"appversion"];
        }

#if TARGET_OS_IPHONE
        [dict setObject:[UIDevice currentDevice].name forKey:@"devicename"];
        [dict setObject:[UIDevice currentDevice].model forKey:@"devicemodel"];
        [dict setObject:[UIDevice currentDevice].systemVersion forKey:@"osversion"];
#elif TARGET_OS_MAC
        [dict setObject:[[NSHost currentHost] localizedName] forKey:@"devicename"];
        [dict setObject:[self machineModel] forKey:@"devicemodel"];
        [dict setObject:[self machineModel] forKey:@"osversion"];
#endif
        [dict setObject:[self generateRandomStringWithSize:10] forKey:@"sessionid"];
        _fieldsDictionary = [NSDictionary dictionaryWithDictionary:dict];
    }
    return self;
}

#if TARGET_OS_MAC
-(NSString *) machineModel {
    size_t len = 0;
    sysctlbyname("hw.model", NULL, &len, NULL, 0);

    if (len) {
        char *model = malloc(len*sizeof(char));
        sysctlbyname("hw.model", model, &len, NULL, 0);
        NSString *model_ns = [NSString stringWithUTF8String:model];
        free(model);
        return model_ns;
    }

    return @"(empty)";
}

-(NSString *) osVersion {
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    NSString* versionStr = [NSString stringWithFormat:@"%ld.%ld.%ld", (long)version.majorVersion, (long)version.majorVersion, (long)version.patchVersion];
    return versionStr;
}
#endif

#pragma mark implementation of LogglyFieldsDelegate protocol

- (NSDictionary *)logglyFieldsToIncludeInEveryLogStatement {
    // The dict may be altered by one of the setters, so lets use a queue for thread safety
    __block NSDictionary *dict;
    dispatch_sync(_queue, ^{
        dict = [_fieldsDictionary copy];
    });
    return dict;
}

#pragma mark Property setters

- (void)setAppversion:(NSString *)appversion {
    dispatch_barrier_async(_queue, ^{
        NSMutableDictionary *dict = [_fieldsDictionary mutableCopy];
        if (appversion != nil) {
            [dict setObject:appversion forKey:@"appversion"];
        } else {
            [dict removeObjectForKey:@"appversion"];
        }
        _fieldsDictionary = [NSDictionary dictionaryWithDictionary:dict];
    });
}

- (void)setSessionid:(NSString *)sessionid {
    dispatch_barrier_async(_queue, ^{
        NSMutableDictionary *dict = [_fieldsDictionary mutableCopy];
        if (sessionid != nil) {
            [dict setObject:sessionid forKey:@"sessionid"];
        } else {
            [dict removeObjectForKey:@"sessionid"];
        }
        _fieldsDictionary = [NSDictionary dictionaryWithDictionary:dict];
    });
}

- (void)setUserid:(NSString *)userid {
    dispatch_barrier_async(_queue, ^{
        NSMutableDictionary *dict = [_fieldsDictionary mutableCopy];
        if (userid != nil) {
             [dict setObject:userid forKey:@"userid"];
        } else {
            [dict removeObjectForKey:@"userid"];
        }
        _fieldsDictionary = [NSDictionary dictionaryWithDictionary:dict];
    });
}

- (void)setObject:(id)object forKey:(NSString *) key{
    dispatch_barrier_async(_queue, ^{
        NSMutableDictionary *dict = [_fieldsDictionary mutableCopy];
        if (object != nil) {
            [dict setObject:object forKey:key];
        } else {
            [dict removeObjectForKey:key];
        }
        _fieldsDictionary = [NSDictionary dictionaryWithDictionary:dict];
    });
}

#pragma mark Private methods

- (NSString*)generateRandomStringWithSize:(int)num {
    NSMutableString* string = [NSMutableString stringWithCapacity:num];
    for (int i = 0; i < num; i++) {
        [string appendFormat:@"%C", (unichar)('a' + arc4random_uniform(25))];
    }
    return string;
}

@end
