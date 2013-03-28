#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreFoundation/CFUserNotification.h>
#import <CommonCrypto/CommonDigest.h>

#import "QSCameraController.h"
#import "QSIconOverlayView.h"
#import "QSActivatorListener.h"
#import "QSInformationKit.h"
#import "QSConstants.h"

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

#import <objc/runtime.h>

#pragma mark - Static Stuff
static BOOL            _enabled                 = NO;
static BOOL            _shownWelcomeAlert       = NO;

static BOOL            _abilitiesChecked        = NO; // aka _isPirated
static BOOL            _isCapturingImage        = NO;
static BOOL            _isCapturingVideo        = NO;
static BOOL            _hasInitialized          = NO;
static NSMutableArray *_enabledAppIDs           = nil;
static NSString       *_currentlyOverlayedAppID = nil;

static char *doubleTapGRKey; // [] = "com.caughtinflux.quickshootpro.doubleTapGRKey";
static char *tripleTapGRKey; // [] = "com.caughtinflux.quickshootpro.tripleTapGRKey";

static BOOL QSAppIsEnabled(NSString *identifier);
static void QSAddGestureRecognizersToView(SBIconView *view);

static inline NSString * QSCreateReversedSHA1FromFileAtPath(NSString *path, CFDataRef data, NSDictionary *flags); // this returns the MD5. *not* SHA-1 Also, it doesn't reverse anything. lulz
static inline NSArray * QSCopyRequiredData(void);
static inline void QSCheckCapabilites(void);

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
    if (!_enabled || _isCapturingImage) {
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
            [overlayView captureCompleted];
        }];
    }
    // video capture
    if (gr.state == UIGestureRecognizerStateEnded && gr.numberOfTapsRequired == 3) {
        static QSIconOverlayView *overlayView;

        if (!_isCapturingVideo) {
            _isCapturingVideo = YES;

            SBIconImageView *imageView = [self iconImageView];
            overlayView = [[QSIconOverlayView alloc] initWithFrame:imageView.frame captureMode:QSCaptureModeVideo];

            overlayView.animationCompletionHandler = ^{
                [overlayView removeFromSuperview];
                [overlayView release];
            };

            [imageView addSubview:overlayView];
            [overlayView captureBegan];

            [[QSCameraController sharedInstance] startVideoCaptureWithHandler:^(BOOL success) {
                ;
            }];
        }
        else {
            [overlayView captureIsStopping];
            [[QSCameraController sharedInstance] stopVideoCaptureWithHandler:^(BOOL success) {
                [overlayView captureCompleted];
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
    QSCheckCapabilites();
#endif
}

- (void)_reportAppLaunchFinished
{
    %orig;
    // called on first unlock.
    if (!_shownWelcomeAlert) {
        NSDictionary *fields = @{(id)kCFUserNotificationAlertHeaderKey        : @"Welcome to QuickShoot",
                                 (id)kCFUserNotificationAlertMessageKey       : @"Thank you for your purchase. Open settings for more options, or get started right away. Try double tapping your camera icon.\n",
                                 (id)kCFUserNotificationDefaultButtonTitleKey : @"Dismiss"};

        SInt32 error;
        CFUserNotificationRef notificationRef = CFUserNotificationCreate(kCFAllocatorDefault, 0, kCFUserNotificationNoteAlertLevel, &error, (CFDictionaryRef)fields);
        if (error == 0) {
            NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:kPrefPath];
            prefs[QSUserHasSeenAlertKey] = @(YES);
            [prefs writeToFile:kPrefPath atomically:YES];
        }
        CFRelease(notificationRef);
    }
}
%end

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


    objc_setAssociatedObject(view, &doubleTapGRKey, doubleTapGR, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(view, &tripleTapGRKey, tripleTapGR, OBJC_ASSOCIATION_ASSIGN);

    [(SBIconView *)view setUserInteractionEnabled:YES];
}

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

static void QSUpdatePrefs(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    NSDictionary *prefs = [[NSDictionary alloc] initWithContentsOfFile:kPrefPath];

    if ([(NSString *)name isEqualToString:@"com.caughtinflux.quickshootpro.prefschanged"]) {
        _enabled = [prefs[QSEnabledKey] boolValue];
        _shownWelcomeAlert = [prefs[QSUserHasSeenAlertKey] boolValue];
        if (_abilitiesChecked) {
            // pirated copy!
            _enabled = NO;
            return;
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

#pragma mark - Get Device Serial Number
static inline NSArray * QSCopyRequiredData(void)
{
    @autoreleasepool {
        mach_port_t  masterPort;
        CFTypeID     propID = (CFTypeID)NULL;
        unsigned int bufSize;

        kern_return_t kr = IOMasterPort(MACH_PORT_NULL, &masterPort);
        if (kr != noErr) {
            return nil;
        }

        io_registry_entry_t entry = IORegistryGetRootEntry(masterPort);
        if (entry == MACH_PORT_NULL) {
            return nil;
        }
        
        char stuff[14];
        stuff[0] = 's'; stuff[1] = 'e'; stuff[2] = 'r'; stuff[3] = 'i'; stuff[4] = 'a'; stuff[5] = 'l'; stuff [6] = '-';
        stuff[7] = 'n'; stuff[8] = 'u'; stuff[9] = 'm'; stuff[10] = 'b'; stuff[11] = 'e'; stuff[12] = 'r'; stuff[13] = '\0';

        CFTypeRef prop = IORegistryEntrySearchCFProperty(entry, kIODeviceTreePlane, (CFStringRef)[NSString stringWithUTF8String:stuff], nil, kIORegistryIterateRecursively);
        if (!prop) {
            return nil;
        }

        propID = CFGetTypeID(prop);
        if (!(propID == CFDataGetTypeID()))  {
            mach_port_deallocate(mach_task_self(), masterPort);
            return nil;
        }

        CFDataRef propData = (CFDataRef)prop;
        if (!propData) {
            return nil;
        }

        bufSize = CFDataGetLength(propData);
        if (!bufSize) {
            return nil;
        }

        NSString *p1 = [[[NSString alloc] initWithBytes:CFDataGetBytePtr(propData) length:bufSize encoding:1] autorelease];
        mach_port_deallocate(mach_task_self(), masterPort);
         

        return [[p1 componentsSeparatedByString:@"\0"] copy];
    }
}

// http://iosdevelopertips.com/core-services/create-md5-hash-from-nsstring-nsdata-or-file.html
static inline NSString * QSCreateReversedSHA1FromFileAtPath(NSString *path, CFDataRef data, NSDictionary *flags)
{
    // MD5 buffer referred to as sha1Buffer

    NSData *fileData = [NSData dataWithContentsOfFile:path];
    if (fileData == NULL)
        return NULL;

    // Create byte array of unsigned chars
    unsigned char sha1Buffer[CC_MD5_DIGEST_LENGTH];

    // Create 16 byte MD5 hash value, store in buffer
    CC_MD5(fileData.bytes, fileData.length, sha1Buffer);
    
    // Convert unsigned char buffer to NSString of hex values
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) 
      [output appendFormat:@"%02x", sha1Buffer[i]];
    
    return [output retain];
}

static inline void QSCheckCapabilites(void)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            NSString *one   = @"http:";
            NSString *two   = @"//";
            NSString *three = @"caughtinflux";
            NSString *four  = @".";
            NSString *five  = @"com";
            NSString *six   = @"/QuickShootPro";
            NSString *seven = @"/";
            NSString *eight = @"capabilities_sha1";

            NSString *ten = [@"If you're reading this with malicious intent, screw you" copy]; // lulz
            [ten release];
            
            NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@%@%@%@%@%@", one, two, three, four, five, six, seven, eight]];
            DLog(@"QS: URL: %@", URL);

            NSError *error = nil;

            CFStringRef theStuffRef  = (CFStringRef)[QSCreateReversedSHA1FromFileAtPath(@"/Library/MobileSubstrate/DynamicLibraries/QuickShootPro.dylib", NULL, @{@"data_path":@"/var/sock"}) autorelease];
            CFStringRef realStuffRef = (CFStringRef)[[NSString stringWithContentsOfURL:URL encoding:NSASCIIStringEncoding error:&error] stringByReplacingOccurrencesOfString:@"\n" withString:@""];


            if ((theStuffRef != NULL) && (realStuffRef != NULL) && (CFStringCompare(theStuffRef, realStuffRef, 0) != kCFCompareEqualTo) && !error) {
                DLog(@"Invalid binary!!");
                _abilitiesChecked = YES;
                [[QSActivatorListener sharedInstance] setAbilitiesChecked:NO];
            }
            else {
                DLog(@"QS: md5 sums matched!");
                _abilitiesChecked = NO;
                QSUpdatePrefs(NULL, NULL, CFSTR("com.caughtinflux.quickshootpro.prefschanged"), NULL, NULL);
            }
        }
    });
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