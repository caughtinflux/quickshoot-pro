#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdlib.h>
#import <string.h>
#import <dlfcn.h>
#import <netdb.h>
#import <arpa/inet.h>
#import <MobileGestalt/MobileGestalt.h>

#import "QSConstants.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgcc-compat"

#define decaesar(x) rot(13, x, 1, 0, 0, NULL)

static inline void rot(int c, char *str, int __1, int unused, int unused_0, void *unused_1) __attribute__((always_inline))
{
    int l = strlen(str);
    const char *alpha[2] = { "abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ"};
 
    int i;
    for (i = 0; i < l; i++) {
        if (str[i] == '@') {
            str[i] = ':';
        }
        else if (str[i] == '[') {
            str[i] = '/';
        }
        
        if (!isalpha(str[i])) {
            continue;
        }
        str[i] = alpha[isupper(str[i])][((int)(tolower(str[i]) - 'a') + c) % 26];
    }
}
#pragma clang diagnostic push
#pragma clang diagnostic pop

static struct { BOOL checked; BOOL ok; } __piracyCheck = { NO, NO };
static char linkStr[] = "uggc@[[purpx.pnhtugvasyhk.pbz[cubravk[";

#define GET_OUT() do { \
    __piracyCheck.checked = NO; \
    if (callback) callback(); \
    return; \
} while(0)

static void (^p_checker)(void(^callback)(void)) = ^(void(^callback)(void)) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        CLog(@"Beginning check");
        CFPropertyListRef (*MGCopyAnswer)(CFStringRef);
        MGCopyAnswer = (CFPropertyListRef (*)(CFStringRef))dlsym(RTLD_DEFAULT, "MGCopyAnswer");

        // String is now normal, calling this block again will cause explosions
        decaesar(linkStr);

        NSString *linkString = [NSString stringWithCString:linkStr encoding:NSASCIIStringEncoding];
        linkString = [linkString stringByAppendingString:[(NSString *)MGCopyAnswer(kMGUniqueDeviceID) autorelease]];
        CLog(@"Link is %@", linkString);
        
        NSError *error = nil;
        NSURL *URL = [NSURL URLWithString:linkString];

        struct hostent *remoteHostEnt = gethostbyname([[URL host] UTF8String]);
        if (!remoteHostEnt) {
            GET_OUT();
        }
        // Get address info from host entry
        struct in_addr *remoteInAddr = (struct in_addr *)remoteHostEnt->h_addr_list[0];
        // Convert numeric addr to ASCII string
        char *sRemoteInAddr = inet_ntoa(*remoteInAddr);

        if (strcmp(sRemoteInAddr, "127.0.0.1") == 0 || strcmp(sRemoteInAddr, "::1") == 0) {
            // Something is blocking us on purpose
            CLog(@"Routed to localhost, exiting");
            __piracyCheck.checked = YES;
            __piracyCheck.ok = NO;
            if (callback) {
                callback();
            }
            return;
        }
        NSData *data = [NSData dataWithContentsOfURL:URL options:NSDataReadingUncached error:&error];
        if (error) {
            CLog(@"Could not retrieve data");
            GET_OUT();
        }
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error || !dict) {
            CLog(@"Could not read JSON data");
            GET_OUT();
        }
        NSString *val = dict[@"state"];
        __piracyCheck.checked = YES;
        __piracyCheck.ok = ([val isEqual:@"Yes"] || [val isEqual:@"unknown"]);
        CLog(@"state = %@", [@(__piracyCheck.ok) stringValue]);
        if (callback) {
            callback();
        }
        return;
    });
};