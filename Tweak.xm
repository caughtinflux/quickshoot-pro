/*
*
*       ____        _      __   _____ __                __  ____           
*      / __ \__  __(_)____/ /__/ ___// /_  ____  ____  / /_/ __ \_________ 
*     / / / / / / / / ___/ //_/\__ \/ __ \/ __ \/ __ \/ __/ /_/ / ___/ __ \
*    / /_/ / /_/ / / /__/ ,<  ___/ / / / / /_/ / /_/ / /_/ ____/ /  / /_/ /
*    \___\_\__,_/_/\___/_/|_|/____/_/ /_/\____/\____/\__/_/   /_/   \____/ 
*                                                                          
*   Tweak.xm                                                        
*   © 2013 Aditya KD
*/


#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreFoundation/CFUserNotification.h>
#import <CommonCrypto/CommonDigest.h>

#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SBIconView.h>
#import <SpringBoard/SBIconViewMap.h>
#import <SpringBoard/SBIconImageView.h>
#import <SpringBoard/SBIcon.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBAwayController.h>
#import <SpringBoard/SBScreenFlash.h>

#import "LibstatusBar.h"
#import "QSCameraController.h"
#import "QSIconOverlayView.h"
#import "QSActivatorListener.h"
#import "QSLink.h"
#import "QSConstants.h"

#import <objc/runtime.h>
#include <sys/stat.h>

#pragma mark - Static Stuff
static BOOL _enabled                 = NO;
static BOOL _shownWelcomeAlert       = NO;
static BOOL _shouldStartChecks       = NO;
static BOOL _abilitiesChecked        = NO; // aka _isPirated
static BOOL _isCapturingImage        = NO;
static BOOL _isCapturingVideo        = NO;
static BOOL _hasInitialized          = NO;

static NSMutableArray *_enabledAppIDs           = nil;
static NSString       *_currentlyOverlayedAppID = nil;

static char *doubleTapGRKey; 
static char *tripleTapGRKey;
// static char *overlayViewKey;

static void QSUpdatePrefs(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);
static BOOL QSAppIsEnabled(NSString *identifier);
static void QSAddGestureRecognizersToView(SBIconView *view);
static void QSUserNotificationCallBack(CFUserNotificationRef userNotification, CFOptionFlags responseFlags);

__attribute__((always_inline)) static inline NSString    * QSCreateReversedSHA1FromFileAtPath(CFStringRef path, CFDataRef data, NSDictionary *flags); // this returns the MD5. *not* SHA-1 Also, it doesn't reverse anything. lulz
__attribute__((always_inline)) static inline qs_retval_t   QSCheckCapabilites(void);


#pragma mark - Defines For Piracy Checks
#define kQSRetval_bool           true
#define kQSRetval_int            2309 << 2
#define kQSRetval_char           'k'
#define kQSPackageListFileExists 23 << 3
#define kQSMD5CheckedOut         23 << 2


#pragma mark - Application Icon Hook
%hook SBIconView
- (void)setIcon:(SBIcon *)icon
{
    // this is an awesome hook, makes it work in the switcher too.
    %orig;
    _hasInitialized = YES;
    if (!(QSAppIsEnabled([icon leafIdentifier]))) {
        // removing gesture recognizers here *will* conflict with other tweaks.
        // a way to fix this shit has to be found.
        // self.gestureRecognizers = nil; ... won't do!
        UITapGestureRecognizer *dtr = objc_getAssociatedObject(self, &doubleTapGRKey);
        UITapGestureRecognizer *ttr = objc_getAssociatedObject(self, &tripleTapGRKey);

        if (dtr) {
            [self removeGestureRecognizer:dtr];
            objc_setAssociatedObject(self, &doubleTapGRKey, nil, OBJC_ASSOCIATION_ASSIGN);
        }
        if (ttr) {
            [self removeGestureRecognizer:ttr];
            objc_setAssociatedObject(self, &tripleTapGRKey, nil, OBJC_ASSOCIATION_ASSIGN);
        }
        // remove the associated objects. Coz YOLO
        return;
    }
    DLog(@"Autoadding recognizer to icon: %@", [icon leafIdentifier]);
    QSAddGestureRecognizersToView(self);
}

- (void)dealloc
{
    objc_setAssociatedObject(self, &doubleTapGRKey, nil, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(self, &tripleTapGRKey, nil, OBJC_ASSOCIATION_ASSIGN);
    %orig;
}

%new
- (void)qs_gestureRecognizerFired:(UITapGestureRecognizer *)gr
{
    if (!_enabled || _isCapturingImage || [QSCameraController sharedInstance].isCapturingImage) {
        // this check is necessary, because the user might be using other quickshoot methods too.
        return;
    }

    _currentlyOverlayedAppID = [[self icon] leafIdentifier];

    // image capture
    if (gr.state == UIGestureRecognizerStateEnded && gr.numberOfTapsRequired == 2 && !_isCapturingVideo) {
        _isCapturingImage = YES;

        SBIconImageView *imageView = [self iconImageView];
        QSIconOverlayView *overlayView = [[[QSIconOverlayView alloc] initWithFrame:imageView.frame captureMode:QSCaptureModePhoto] autorelease];
        [self setUserInteractionEnabled:NO];

        EXECUTE_BLOCK_AFTER_DELAY(10, ^{
            // create a failsafe, which runs after 10 seconds
            [self setUserInteractionEnabled:YES];
        });

        overlayView.animationCompletionHandler = ^{
            [overlayView removeFromSuperview];
            [self setUserInteractionEnabled:YES];
        };
        [imageView addSubview:overlayView];
        [overlayView captureBegan];

        [[QSCameraController sharedInstance] takePhotoWithCompletionHandler:^(BOOL success){
            _isCapturingImage = NO;
            [overlayView captureCompletedWithResult:success];
            [self setUserInteractionEnabled:YES]; // let the user tap the icon now.
        }];
    }
    // video capture
    if (gr.state == UIGestureRecognizerStateEnded && gr.numberOfTapsRequired == 3) {
        static QSIconOverlayView *overlayView;
        static BOOL wasInterrupted;

        if (!_isCapturingVideo) {
            if ([QSCameraController sharedInstance].isCapturingVideo) {
                // this check is necessary, because the user might be recording a video some other way, too.
                return;
            }
            _isCapturingVideo = YES;

            SBIconImageView *imageView = [self iconImageView];
            overlayView = [[QSIconOverlayView alloc] initWithFrame:imageView.frame captureMode:QSCaptureModeVideo];

            overlayView.animationCompletionHandler = ^{
                [overlayView removeFromSuperview];
                if (!wasInterrupted) {
                    [overlayView release];
                }
                wasInterrupted = YES;
            };

            [imageView addSubview:overlayView];
            [overlayView captureBegan];

            [[QSCameraController sharedInstance] startVideoCaptureWithHandler:^(BOOL success) {
                if (!success) {
                    [overlayView captureCompletedWithResult:NO];
                    _isCapturingVideo = NO;
                }
            } interruptionHandler:^(BOOL success) {
                wasInterrupted = YES;
                _isCapturingVideo = NO;
                [overlayView captureCompletedWithResult:success];
            }];
        }
        else {
            [overlayView captureIsStopping];
            [[QSCameraController sharedInstance] stopVideoCaptureWithHandler:^(BOOL success) {                
                [overlayView captureCompletedWithResult:success];
                _isCapturingVideo = NO;
            }];
        }
    }
}
%end


#pragma mark - App Launch Hook
%hook SBApplicationIcon
- (void)launch
{
    if (_isCapturingVideo && ([[(SBApplicationIcon *)self leafIdentifier] isEqualToString:_currentlyOverlayedAppID])) {
        // the app should not launch if it has an overlay.
        // this won't be called when capturing an image, because user interaction is disabled! :P
        return;
    }
    %orig;
}
%end

%hook SBUIController
- (void)activateApplicationFromSwitcher:(SBApplication *)app
{
    if (_isCapturingVideo && ([[(SBApplicationIcon *)self leafIdentifier] isEqualToString:_currentlyOverlayedAppID])) {
        // same as above method
        return;
    }
    %orig;
}
%end


#pragma mark - Camera Grabber Hooks
%hook UITapGestureRecognizer 
- (UITapGestureRecognizer *)initWithTarget:(id)target action:(SEL)action
{
    self = %orig;
    if (self && (target == [%c(SBAwayController) sharedAwayController]) && (action == @selector(handleCameraTapGesture:))) {
        DLog(@"QS: Modifying camera grabber gesture recognizer.");
        [(UITapGestureRecognizer *)self setNumberOfTapsRequired:2];
    }
    return self;
}
%end

%hook SBAwayController
- (void)handleCameraTapGesture:(UITapGestureRecognizer *)recognizer
{
    if (!_enabled || _isCapturingImage) {
        return;
    }

    if (recognizer.numberOfTapsRequired == 2 && !_isCapturingVideo) {
        _isCapturingImage = YES;
        [[QSCameraController sharedInstance] takePhotoWithCompletionHandler:^(BOOL success) {
            if (success) {
                _isCapturingImage = NO;
                [[%c(SBScreenFlash) sharedInstance] flash];
            }
        }];
    }
    else {
        %orig;
    }
}
%end


#pragma mark - SpringBoard Hook
%hook SpringBoard
/*
*   Hook to ensure UIDevice begins generating rotation events  
*/
- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    %orig;
    [(SpringBoard *)[UIApplication sharedApplication] setWantsOrientationEvents:YES];
    [(SpringBoard *)[UIApplication sharedApplication] updateOrientationAndAccelerometerSettings];
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [QSCameraController sharedInstance]; // make sure the object is created, hence setting it up to receive orientation notifs.
}


- (void)_performDeferredLaunchWork
{
    %orig;
#ifndef DEBUG
     if (_shouldStartChecks) {
        qs_retval_t returnedShit = QSCheckCapabilites();
        if (!returnedShit) {
            _abilitiesChecked = YES;
            QSUpdatePrefs(NULL, NULL, CFSTR("com.caughtinflux.quickshootpro.prefschanged"), NULL, NULL);
            return;
        }
        else if ((returnedShit->b != kQSRetval_bool) || (returnedShit->b != kQSRetval_int)) {
            // check the returned values to see if the function has been patched.
            _abilitiesChecked = YES;
            QSUpdatePrefs(NULL, NULL, CFSTR("com.caughtinflux.quickshootpro.prefschanged"), NULL, NULL);
        }
     }
#endif // DEBUG
}

- (void)_reportAppLaunchFinished
{
    %orig;
    // called on unlock.
#ifndef DEBUG    
    if (!_shownWelcomeAlert) {
#endif // DEBUG     
        NSDictionary *fields = @{(id)kCFUserNotificationAlertHeaderKey          : @"Welcome to QuickShoot",
                                 (id)kCFUserNotificationAlertMessageKey         : @"Thank you for your purchase. Open settings for more options and help, or get started right away. Try double tapping the camera icon.\n",
                                 (id)kCFUserNotificationDefaultButtonTitleKey   : @"Dismiss",
                                 (id)kCFUserNotificationAlternateButtonTitleKey : @"Settings"};

        SInt32 error;
        CFUserNotificationRef notificationRef = CFUserNotificationCreate(kCFAllocatorDefault, 0, kCFUserNotificationNoteAlertLevel, &error, (CFDictionaryRef)fields);
        // Get and add a run loop source to the current run loop to get notified when the alert is dismissed
        CFRunLoopSourceRef runLoopSource = CFUserNotificationCreateRunLoopSource(kCFAllocatorDefault, notificationRef, QSUserNotificationCallBack, 0);
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
        if (error == 0) {
            NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
            if (!prefs) {
                prefs = [[NSMutableDictionary alloc] init];
            }
            prefs[QSUserHasSeenAlertKey] = @(YES);
            [prefs writeToFile:kPrefPath atomically:YES];
            [prefs release];
        }
#ifndef DEBUG        
    }
#endif // DEBUG
}

#ifdef DEBUG
%new
- (void)qs_alertTest
{
    NSDictionary *fields = @{(id)kCFUserNotificationAlertHeaderKey          : @"Welcome to QuickShoot",
                             (id)kCFUserNotificationAlertMessageKey         : @"Thank you for your purchase. Open settings for more options and help, or get started right away. Try double tapping the camera icon.\n",
                             (id)kCFUserNotificationDefaultButtonTitleKey   : @"Dismiss",
                             (id)kCFUserNotificationAlternateButtonTitleKey : @"Settings"};

    SInt32 error;
    CFUserNotificationRef notificationRef = CFUserNotificationCreate(kCFAllocatorDefault, 0, kCFUserNotificationNoteAlertLevel, &error, (CFDictionaryRef)fields);
    
    // Get and add a run loop source to the main run loop to get notified when the alert is dismissed
    CFRunLoopSourceRef runLoopSource = CFUserNotificationCreateRunLoopSource(kCFAllocatorDefault, notificationRef, QSUserNotificationCallBack, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopCommonModes);
    CFRelease(runLoopSource);
}

%new 
- (void)qs_photoTest
{
    [[QSCameraController sharedInstance] takePhotoWithCompletionHandler:nil];
}

%new
- (void)qs_videoTest
{
    [[QSCameraController sharedInstance] startVideoCaptureWithHandler:nil interruptionHandler:nil];
    EXECUTE_BLOCK_AFTER_DELAY(10, ^{[[QSCameraController sharedInstance] stopVideoCaptureWithHandler:nil];});
}
%end
#endif // DEBUG

static void QSUserNotificationCallBack(CFUserNotificationRef userNotification, CFOptionFlags responseFlags)
{
    DLog(@"Called this");
    if ((responseFlags & 0x3) == kCFUserNotificationAlternateResponse) {
        // Open settings to custom bundle
        [(SpringBoard *)[UIApplication sharedApplication] applicationOpenURL:[NSURL URLWithString:@"prefs:root=QuickShoot%20Pro"] publicURLsOnly:NO];
    }
    CFRelease(userNotification);
}

static BOOL QSAppIsEnabled(NSString *identifier)
{
    if ([identifier isEqualToString:@"com.apple.camera"]) {
        return YES;
    }
    for (NSString *appID in _enabledAppIDs) {
        if ([appID isEqualToString:identifier]) {
            return YES;
        }
    }

    return NO;
}

#pragma mark - Gesture Recognizer Handling
static void QSAddGestureRecognizersToView(SBIconView *view)
{
    UITapGestureRecognizer *doubleTapGR = [[UITapGestureRecognizer alloc] initWithTarget:view action:@selector(qs_gestureRecognizerFired:)];
    doubleTapGR.numberOfTapsRequired = 2;
    UITapGestureRecognizer *tripleTapGR = [[UITapGestureRecognizer alloc] initWithTarget:view action:@selector(qs_gestureRecognizerFired:)];
    tripleTapGR.numberOfTapsRequired = 3;

    [doubleTapGR requireGestureRecognizerToFail:tripleTapGR];

    [(SBIconView *)view addGestureRecognizer:doubleTapGR];
    [(SBIconView *)view addGestureRecognizer:tripleTapGR];
    [doubleTapGR release];
    [tripleTapGR release];

    // ASSIGN association is used, because the gesture recognizers are autoreleased gesture recognizers of that object, so no issues there.
    objc_setAssociatedObject(view, &doubleTapGRKey, doubleTapGR, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(view, &tripleTapGRKey, tripleTapGR, OBJC_ASSOCIATION_ASSIGN);

    [(SBIconView *)view setUserInteractionEnabled:YES];
}
/*
*   This method is most probably useless, because the icon views don't exist when the user is an another application
*   But it makes up for when and if SpringBoard feels like keeping the icon views around.
*   It adds and remove the gesture recognizer based on the new/removed apps using associated object magic
*/
static void QSUpdateAppIconRecognizersRemovingApps(NSArray *disabledApps)
{
    [disabledApps retain];
    for (NSString *appID in disabledApps) {
        @autoreleasepool {
            if ([appID isEqualToString:@"com.apple.camera"]) {
                continue;
            }

            SBIconModel *iconModel = (SBIconModel *)[(SBIconController *)[%c(SBIconController) sharedInstance] model];
            SBIcon *icon = (SBIcon *)[(SBIconModel *)iconModel leafIconForIdentifier:appID];
            SBIconView *iconView = [[%c(SBIconViewMap) homescreenMap] iconViewForIcon:icon];
            UITapGestureRecognizer *dtr = objc_getAssociatedObject(iconView, &doubleTapGRKey);
            UITapGestureRecognizer *ttr = objc_getAssociatedObject(iconView, &tripleTapGRKey);

            if (dtr && ttr) {
                DLog(@"Removing recognizers from view");
                [iconView removeGestureRecognizer:dtr];
                [iconView removeGestureRecognizer:ttr];
                objc_setAssociatedObject(iconView, &doubleTapGRKey, nil, OBJC_ASSOCIATION_ASSIGN);
                objc_setAssociatedObject(iconView, &doubleTapGRKey, nil, OBJC_ASSOCIATION_ASSIGN);
            }
        }
    }
    for (NSString *appID in _enabledAppIDs) {
        @autoreleasepool {
            SBIconModel *iconModel = (SBIconModel *)[(SBIconController *)[%c(SBIconController) sharedInstance] model];
            SBIcon *icon = (SBIcon *)[(SBIconModel *)iconModel leafIconForIdentifier:appID];
            SBIconView *iconView = [[%c(SBIconViewMap) homescreenMap] iconViewForIcon:icon];

            QSAddGestureRecognizersToView(iconView);
        }
    }
    [disabledApps release];
}

static inline NSInteger QSDaysBetweenDates(NSDate *fromDateTime, NSDate *toDateTime)
{
    NSDate *fromDate;
    NSDate *toDate;

    NSCalendar *calendar = [NSCalendar currentCalendar];

    [calendar rangeOfUnit:NSDayCalendarUnit startDate:&fromDate interval:NULL forDate:fromDateTime];
    [calendar rangeOfUnit:NSDayCalendarUnit startDate:&toDate interval:NULL forDate:toDateTime];

    NSDateComponents *difference = [calendar components:NSDayCalendarUnit fromDate:fromDate toDate:toDate options:0];

    return [difference day];
}

#pragma mark - Prefs Callback
static void QSUpdatePrefs(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    // This function is surely called _at least_ once before the piracy check is called. Makes sense to have the date check be in here.

    if (_abilitiesChecked) {
        // pirated copy!
        _enabled = NO;
        return;
    }

    NSDictionary *prefs = [[NSDictionary alloc] initWithContentsOfFile:kPrefPath];
    if ([(NSString *)name isEqualToString:@"com.caughtinflux.quickshootpro.prefschanged"]) {
        if (!prefs) {
            _enabled = YES;
            return;
        }
        if (!(prefs[QSEnabledKey])) {
            _enabled = YES;
        }
        else {
            _enabled = [prefs[QSEnabledKey] boolValue];
        }
        
        _shownWelcomeAlert = [prefs[QSUserHasSeenAlertKey] boolValue];
        
        // Do piracy checks after a day of usage. Let the try before you buy crowd experience it.
        NSDate *refDate = prefs[QSReferenceTimeKey];
        if (!refDate) {
            NSMutableDictionary *mutablePrefs = [prefs mutableCopy];
            mutablePrefs[QSReferenceTimeKey] = [NSDate date];
            [mutablePrefs writeToFile:kPrefPath atomically:YES];
            [mutablePrefs release];
        }
        else if (QSDaysBetweenDates(refDate, [NSDate date]) >= 1) { 
            _shouldStartChecks = YES;
        }

        [QSCameraController sharedInstance].cameraDevice = QSCameraDeviceFromString(prefs[QSCameraDeviceKey]);
        [QSCameraController sharedInstance].flashMode = QSFlashModeFromString(prefs[QSFlashModeKey]);
        [QSCameraController sharedInstance].enableHDR = [prefs[QSHDRModeKey] boolValue];
        [QSCameraController sharedInstance].waitForFocusCompletion = [prefs[QSWaitForFocusKey] boolValue];
        [QSCameraController sharedInstance].videoCaptureQuality = prefs[QSVideoQualityKey];
        [QSCameraController sharedInstance].videoFlashMode = QSFlashModeFromString(prefs[QSFlashModeKey]);

        [[NSNotificationCenter defaultCenter] postNotificationName:QSPrefsChangedNotificationName object:nil];
    }

    else if ([(NSString *)name isEqualToString:@"com.caughtinflux.quickshootpro.prefschanged.appicons"]) {
        DLog(@"Updating app icons' stuffs");
        NSMutableArray *disabledApps = [[NSMutableArray new] autorelease];
        
        [_enabledAppIDs release];
        _enabledAppIDs = nil;
        _enabledAppIDs = [NSMutableArray new];

        for (NSString *key in [prefs allKeys]) {
            if ([key hasPrefix:@"QSApp-"]) {
                if (([prefs[key] boolValue] == YES)) {
                    [_enabledAppIDs addObject:[key stringByReplacingOccurrencesOfString:@"QSApp-" withString:@""]];
                }
                else {
                    [disabledApps addObject:[key stringByReplacingOccurrencesOfString:@"QSApp-" withString:@""]];
                }
            }
        }
        if (_hasInitialized) {
            // running this before SpringBoard has loaded completely == BAD IDEA.
            QSUpdateAppIconRecognizersRemovingApps(disabledApps);
        }
    }

    [prefs release];
}

#pragma mark - MD5 Function
/*
*   Returns the MD5 of the the file at path "path".
*   data and flags are unused, and are in there for the confusion of the cracker.
*/
__attribute__((always_inline)) static inline NSString * QSCreateReversedSHA1FromFileAtPath(CFStringRef path, CFDataRef data, NSDictionary *flags)
{
    // MD5 buffer referred to as sha1Buffer
    CFRetain(path);
    NSData *fileData = [NSData dataWithContentsOfFile:(NSString *)path];
    CFRelease(path);
    if (!fileData) {
        return nil;
    }
    // Create byte array of unsigned chars
    unsigned char sha1Buffer[CC_MD5_DIGEST_LENGTH]; // md5buffer
    unsigned char md5Buffer[CC_SHA1_DIGEST_LENGTH]; // sha1buffer

    // Create 16 byte MD5 hash value, store in buffer
    CC_MD5(fileData.bytes, fileData.length, sha1Buffer);
    CC_SHA1(fileData.bytes, fileData.length, md5Buffer); // for moar confusion. Lulz.
    
    // Convert unsigned char buffer to NSString of hex values
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) 
      [output appendFormat:@"%02x", sha1Buffer[i]];
    
    return [output copy];
}

#pragma mark - Piracy Check. Lolcat
/*
*   This function has two parts: local and remote. First, it checks if /var/lib/dpkg/info/com.caughtinflux.quickshootpro.list exists. Most pirate repos use custom identifiers to prevent conflicts with the original package.
*   IF the identifier checks out, do a secondary check. Download a list of all known MD5 hashes of the dylibs (for different versions).
*   Check that against a locally generated MD5, and decide whether pirated or not.
*   The remote download is carried out asynchronously, but the method returns a pointer to a struct with predefined values, so the caller can check them to be sure that the function hasn't been patched
*/
__attribute__((always_inline)) static inline qs_retval_t QSCheckCapabilites(void)
{
    char fp0[55];
    fp0[0] = '/'; fp0[1] = 'v'; fp0[2] = 'a'; fp0[3] = 'r'; fp0[4] = '/'; fp0[5] = 'l'; fp0[6] = 'i'; fp0[7] = 'b'; fp0[8] = '/'; fp0[9] = 'd'; fp0[10] = 'p'; fp0[11] = 'k'; fp0[12] = 'g'; fp0[13] = '/'; fp0[14] = 'i'; fp0[15] = 'n'; fp0[16] = 'f'; fp0[17] = 'o'; fp0[18] = '/'; fp0[19] = 'c'; fp0[20] = 'o'; fp0[21] = 'm'; fp0[22] = '.'; fp0[23] = 'c'; fp0[24] = 'a'; fp0[25] = 'u'; fp0[26] = 'g'; fp0[27] = 'h'; fp0[28] = 't'; fp0[29] = 'i'; fp0[30] = 'n'; fp0[31] = 'f'; fp0[32] = 'l'; fp0[33] = 'u'; fp0[34] = 'x'; fp0[35] = '.'; fp0[36] = 'q'; fp0[37] = 'u'; fp0[38] = 'i'; fp0[39] = 'c'; fp0[40] = 'k'; fp0[41] = 's'; fp0[42] = 'h'; fp0[43] = 'o'; fp0[44] = 'o'; fp0[45] = 't'; fp0[46] = 'p'; fp0[47] = 'r'; fp0[48] = 'o'; fp0[49] = '.'; fp0[50] = 'l'; fp0[51] = 'i'; fp0[52] = 's'; fp0[53] = 't'; fp0[54] = '\0';
    // /var/lib/dpkg/info/com.caughtinflux.quickshootpro.plist

    CFStringRef fp0Ref = CFStringCreateWithCString(kCFAllocatorDefault, (const char *)fp0, CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
    if (![[NSFileManager defaultManager] fileExistsAtPath:(NSString *)fp0Ref]) {
        ;// This is a diversion
    }
    CFRelease(fp0Ref);
    struct stat st;
    if (stat(fp0, &st) != 0) {
        // check if /var/lib/dpkg/info/com.caughtinflux.quickshootpro.plist exists
        // abilities checked = NO means it isn't pirated.
        _abilitiesChecked = YES;
        QSUpdatePrefs(NULL, NULL, CFSTR("com.caughtinflux.quickshootpro.prefschanged"), NULL, NULL);
    }
    else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            @autoreleasepool {
                // Get the URL from the dynamically generated inline function, in the form of a CFString
                CFStringRef urlStringRef = CFStringCreateWithCString(kCFAllocatorDefault, (const char *)QSGetLink(), CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
                CFURLRef URL = CFURLCreateWithString(kCFAllocatorDefault, urlStringRef, NULL);
                CFRelease(urlStringRef);
                urlStringRef = NULL;

                NSError *error = nil;
                // path to dylib
                char fp[62];
                fp[0] = '/'; fp[1] = 'L'; fp[2] = 'i'; fp[3] = 'b'; fp[4] = 'r'; fp[5] = 'a'; fp[6] = 'r'; fp[7] = 'y'; fp[8] = '/'; fp[9] = 'M'; fp[10] = 'o'; fp[11] = 'b'; fp[12] = 'i'; fp[13] = 'l'; fp[14] = 'e'; fp[15] = 'S'; fp[16] = 'u'; fp[17] = 'b'; fp[18] = 's'; fp[19] = 't'; fp[20] = 'r'; fp[21] = 'a'; fp[22] = 't'; fp[23] = 'e'; fp[24] = '/'; fp[25] = 'D'; fp[26] = 'y'; fp[27] = 'n'; fp[28] = 'a'; fp[29] = 'm'; fp[30] = 'i'; fp[31] = 'c'; fp[32] = 'L'; fp[33] = 'i'; fp[34] = 'b'; fp[35] = 'r'; fp[36] = 'a'; fp[37] = 'r'; fp[38] = 'i'; fp[39] = 'e'; fp[40] = 's'; fp[41] = '/'; fp[42] = 'Q'; fp[43] = 'u'; fp[44] = 'i'; fp[45] = 'c'; fp[46] = 'k'; fp[47] = 'S'; fp[48] = 'h'; fp[49] = 'o'; fp[50] = 'o'; fp[51] = 't'; fp[52] = 'P'; fp[53] = 'r'; fp[54] = 'o'; fp[55] = '.'; fp[56] = 'd'; fp[57] = 'y'; fp[58] = 'l'; fp[59] = 'i'; fp[60] = 'b'; fp[61] = '\0';

                CFStringRef fpStrRef = CFStringCreateWithCString(kCFAllocatorDefault, (const char *)fp, CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
                
                // Get the MD5 of the dylib
                CFStringRef theStuffRef  = (CFStringRef)[QSCreateReversedSHA1FromFileAtPath(fpStrRef, NULL, @{@"data_path":@"/var/sock"}) autorelease];
                CFRelease(fpStrRef);
                fpStrRef = NULL;

                // Download the MD5s of all the known versions into an array.
                CFArrayRef allTheShitRef = (CFArrayRef)[[NSString stringWithContentsOfURL:(NSURL *)URL encoding:NSUTF8StringEncoding error:&error] componentsSeparatedByString:@"\n"];
                
                NSInteger done = 0;
                if (allTheShitRef) {
                    for (NSString *realStuffRef in (NSArray *)allTheShitRef) {
                        if ((CFStringCompare(theStuffRef, (CFStringRef)realStuffRef, 0) == kCFCompareEqualTo)) {
                            // everything checked out
                            done = kQSMD5CheckedOut;
                            break;
                        }
                    }
                    if (done != kQSMD5CheckedOut) {
                        done = 23 << 5; // just a diversionary tactic.
                    }
                }  
            
                CFRelease(URL);
                URL = NULL;

                if ((!error) && (theStuffRef != NULL) && (allTheShitRef != NULL) && (done != kQSMD5CheckedOut)) {
                    // most probably pirated.
                    // don't do anything if there was an error, don't want users getting angry. Hence the !error check.
                    _abilitiesChecked = YES;
                    [[QSActivatorListener sharedInstance] setAbilitiesChecked:NO]; // this uses the opposite. i.e [QSActivatorListener abilitiesChecked] == isLegitCopy
                    QSUpdatePrefs(NULL, NULL, CFSTR("com.caughtinflux.quickshootpro.prefschanged"), NULL, NULL);
                }
                else {
                    // the checksums matched. For now.
                    _abilitiesChecked = NO;
                    [[QSActivatorListener sharedInstance] setAbilitiesChecked:YES];
                    QSUpdatePrefs(NULL, NULL, CFSTR("com.caughtinflux.quickshootpro.prefschanged"), NULL, NULL);
                }
            }
        });
    }
    
    qs_retval_t ret = (qs_retval_t)malloc(sizeof(qs_retval_t));
    ret->a = kQSRetval_bool;
    ret->b = kQSRetval_int;
    ret->c = kQSRetval_char; 
    return ret;
}

%ctor
{
    @autoreleasepool {
        %init;
        NSLog(@"QS: Registering listeners and preference callbacks");
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        (CFNotificationCallback)&QSUpdatePrefs,
                                        CFSTR("com.caughtinflux.quickshootpro.prefschanged"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorHold);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        (CFNotificationCallback)&QSUpdatePrefs,
                                        CFSTR("com.caughtinflux.quickshootpro.prefschanged.appicons"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorHold);

        QSUpdatePrefs(NULL, NULL, CFSTR("com.caughtinflux.quickshootpro.prefschanged"), NULL, NULL);
        QSUpdatePrefs(NULL, NULL, CFSTR("com.caughtinflux.quickshootpro.prefschanged.appicons"), NULL, NULL);
        
        [[LAActivator sharedInstance] registerListener:[QSActivatorListener sharedInstance] forName:QSOptionsWindowListenerName];
        [[LAActivator sharedInstance] registerListener:[QSActivatorListener sharedInstance] forName:QSImageCaptureListenerName];
        [[LAActivator sharedInstance] registerListener:[QSActivatorListener sharedInstance] forName:QSVideoCaptureListenerName];
        
    }
}