#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdlib.h>
#import <string.h>
#import <dlfcn.h>
#import <netdb.h>
#import <arpa/inet.h>

#import <MobileGestalt/MobileGestalt.h>

#define caesar(x) rot(13, x, 0)
#define decaesar(x) rot(13, x, 1)
#define decrypt_rot(x, y) rot((26-x), y)
void rot(int c, char *str, int invert)
{
    int l = strlen(str);
    const char *alpha[2] = { "abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ"};
 
    int i;
    for (i = 0; i < l; i++) {
        if (invert == 0) {
            if (str[i] == ':') {
                str[i] = '@';
            }
            else if (str[i] == '/') {
                str[i] = '[';
            }
        }
        else {
            if (str[i] == '@') {
                str[i] = ':';
            }
            else if (str[i] == '[') {
                str[i] = '/';
            }
        }
        if (!isalpha(str[i])) {
            continue;
        }
        str[i] = alpha[isupper(str[i])][((int)(tolower(str[i])-'a')+c)%26];
    }
}

static struct { BOOL checked; BOOL ok; } __piracyCheck;
static char linkStr[] = "uggc@[[purpx.pnhtugvasyhk.pbz[oevfvate[";

#define GET_OUT() do { \
    __piracyCheck.checked = NO; \
    if (callback) callback(); \
    return; \
} while(0)

static void (^p_checker)(void(^callback)(void)) = ^(void(^callback)(void)) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        CFPropertyListRef (*MGCopyAnswer)(CFStringRef);
        MGCopyAnswer = (CFPropertyListRef (*)(CFStringRef))dlsym(RTLD_DEFAULT, "MGCopyAnswer");

        decaesar(linkStr);

        NSString *linkString = [NSString stringWithCString:linkStr encoding:NSASCIIStringEncoding];
        linkString = [linkString stringByAppendingString:[(NSString *)MGCopyAnswer(kMGUniqueDeviceID) autorelease]];
        
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
            __piracyCheck.checked = YES;
            __piracyCheck.ok = NO;
            if (callback) {
                callback();
            }
            return;
        }
        
        NSData *data = [NSData dataWithContentsOfURL:URL options:NSDataReadingUncached error:&error];
        if (error) {
            GET_OUT();
        }
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error || !dict) {
           GET_OUT();
        }
        NSString *val = dict[@"state"];
        __piracyCheck.checked = YES;
        __piracyCheck.ok = [val isEqual:@"Yes"];
        if (callback) {
            callback();
        }
        return;
    });
};