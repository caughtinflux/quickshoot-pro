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

// #import <8_1/SpringBoard/SpringBoard.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SBIconView.h>
#import <SpringBoard/SBIconViewMap.h>
#import <SpringBoard/SBIconImageView.h>
#import <SpringBoard/SBIcon.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBScreenFlash.h>

#import <UIKit/UIGestureRecognizerTarget.h>

#import "LibstatusBar.h"
#import "QSCameraController.h"
#import "QSIconOverlayView.h"
#import "QSActivatorListener.h"
#import "QSConstants.h"
#import "QSAntiPiracy.h"

#import <objc/runtime.h>

#pragma mark - Variables
static BOOL _enabled = NO;
static BOOL _shownWelcomeAlert = NO;
static BOOL _isCapturingImage = NO;
static BOOL _isCapturingVideo = NO;
static BOOL _hasInitialized = NO;

static BOOL _flashScreen = NO;
static BOOL _showRecordingIcon = NO; // This one is not strictly necessary, as nothing in this file shows the status bar icon. Kept for the future!

static NSMutableArray *_enabledAppIDs = nil;
static NSString *_currentlyOverlayedAppID = nil;

static char *doubleTapGRKey; 
static char *tripleTapGRKey;

#pragma mark - Function Declarations
static void QSUpdatePrefs(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);
static BOOL QSAppIsEnabled(NSString *identifier);
static void QSAddGestureRecognizersToView(SBIconView *view);
static void QSUserNotificationCallBack(CFUserNotificationRef userNotification, CFOptionFlags responseFlags);

#pragma mark - Application Icon Hook
%hook SBIconView
- (void)setIcon:(SBIcon *)icon
{
    // this is an awesome hook, makes it work in the switcher too.
    %orig;
    _hasInitialized = YES;
    if (!(QSAppIsEnabled([icon leafIdentifier]))) {
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
    CLog(@"Adding recognizer to icon: %@", [icon leafIdentifier]);
    QSAddGestureRecognizersToView(self);
}

- (void)dealloc
{
    objc_setAssociatedObject(self, &doubleTapGRKey, nil, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(self, &tripleTapGRKey, nil, OBJC_ASSOCIATION_ASSIGN);
    %orig;
}

%new(v@:@)
- (void)qs_gestureRecognizerFired:(UITapGestureRecognizer *)gr
{
    if (!_enabled || _isCapturingImage || [QSCameraController sharedInstance].isCapturingImage || IS_PIRATED) {
        // this check is necessary, because the user might be using other quickshoot methods too.
        return;
    }

    _currentlyOverlayedAppID = [[self icon] leafIdentifier];

    // image capture
    if (gr.state == UIGestureRecognizerStateEnded && gr.numberOfTapsRequired == 2 && !_isCapturingVideo) {
        _isCapturingImage = YES;

        SBIconImageView *imageView = [self _iconImageView];
        QSIconOverlayView *overlayView = [[[QSIconOverlayView alloc] initWithFrame:imageView.frame captureMode:QSCaptureModePhoto] autorelease];
        [self setUserInteractionEnabled:NO];

        EXECUTE_BLOCK_AFTER_DELAY(10, ^{
            // create a failsafe, which runs after 10 seconds
            [self setUserInteractionEnabled:YES];
        });
        overlayView.animationCompletionHandler = ^{
            [overlayView removeFromSuperview];
            [self setUserInteractionEnabled:YES];
            overlayView.animationCompletionHandler = nil;
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

            SBIconImageView *imageView = [self _iconImageView];
            overlayView = [[QSIconOverlayView alloc] initWithFrame:imageView.frame captureMode:QSCaptureModeVideo];
            overlayView.animationCompletionHandler = ^{
                [overlayView removeFromSuperview];
                if (!wasInterrupted) {
                    [overlayView release];
                }
                wasInterrupted = YES;
                overlayView.animationCompletionHandler = nil;
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
%hook SBIcon
- (void)launchFromLocation:(SBIconLocation)location
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

%hook SBLockScreenView
- (void)setCameraGrabberHidden:(BOOL)hidden forRequester:(id)requester
{
    %orig(hidden, requester);
    if (hidden || IS_PIRATED) {
        return;
    }
    UIView *grabberView = MSHookIvar<UIView *>(self, "_cameraGrabberView");
    UITapGestureRecognizer *tapRecognizer = objc_getAssociatedObject(self, @selector(qsTapRecognizer));
    if (grabberView && !tapRecognizer) {
        tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(qs_handleDoubleTap:)];
        tapRecognizer.numberOfTapsRequired = 2;
        objc_setAssociatedObject(grabberView, @selector(qsTapRecognizer), tapRecognizer, OBJC_ASSOCIATION_ASSIGN);

        for (UIGestureRecognizer *recognizer in grabberView.gestureRecognizers) {
            // Ensure all other gesture recognisers wait for this one to fail
            [recognizer requireGestureRecognizerToFail:tapRecognizer];
        }
        [grabberView addGestureRecognizer:tapRecognizer];
    }
}

%new 
- (void)qs_handleDoubleTap:(UITapGestureRecognizer *)sender
{
    if (!_enabled || _isCapturingImage || _isCapturingVideo) {
        return;
    }
    _isCapturingImage = YES;
    [[QSCameraController sharedInstance] takePhotoWithCompletionHandler:^(BOOL success) {
        _isCapturingImage = NO;
        if (success) {
            if (_flashScreen) {
                [[%c(SBScreenFlash) sharedInstance] flash];
            }
        }
    }];
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
    [(SpringBoard *)[UIApplication sharedApplication] updateOrientationDetectionSettings];
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [QSCameraController sharedInstance]; // make sure the object is created, hence setting it up to receive orientation notifs.
    QSUpdatePrefs(NULL, NULL, CFSTR("com.caughtinflux.quickshootpro.prefschanged"), NULL, NULL);
    QSUpdatePrefs(NULL, NULL, CFSTR("com.caughtinflux.quickshootpro.prefschanged.appicons"), NULL, NULL);
}

- (void)_reportAppLaunchFinished
{
    %orig;
    // called on unlock.
    if (!_shownWelcomeAlert) { 
        NSDictionary *fields = @{(id)kCFUserNotificationAlertHeaderKey: @"Welcome to QuickShoot",
                                 (id)kCFUserNotificationAlertMessageKey: @"Thank you for your purchase. Open settings for more options and help, or get started right away. Try double tapping the camera icon.\n",
                                 (id)kCFUserNotificationDefaultButtonTitleKey: @"Dismiss",
                                 (id)kCFUserNotificationAlternateButtonTitleKey: @"Settings"};

        SInt32 error = 0;
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
    }
}

%end

#pragma mark - User Notification Callback
static void QSUserNotificationCallBack(CFUserNotificationRef userNotification, CFOptionFlags responseFlags)
{
    if ((responseFlags & 0x3) == kCFUserNotificationAlternateResponse) {
        // Open settings to custom bundle
        [(SpringBoard *)[UIApplication sharedApplication] applicationOpenURL:[NSURL URLWithString:@"prefs:root=QuickShoot%20Pro"] publicURLsOnly:NO];
    }
    CFRelease(userNotification);
}

#pragma mark - App Enabled Check
static BOOL QSAppIsEnabled(NSString *identifier)
{
    if (!identifier) {
        return NO;
    }
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
    // Remove the current recognizers
    UITapGestureRecognizer *doubleTapGR = objc_getAssociatedObject(view, &doubleTapGRKey);
    UITapGestureRecognizer *tripleTapGR = objc_getAssociatedObject(view, &tripleTapGRKey);

    [doubleTapGR.view removeGestureRecognizer:doubleTapGR];
    [tripleTapGR.view removeGestureRecognizer:tripleTapGR];
    objc_setAssociatedObject(view, &doubleTapGRKey, nil, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(view, &tripleTapGRKey, nil, OBJC_ASSOCIATION_ASSIGN);

    
    doubleTapGR = [[UITapGestureRecognizer alloc] initWithTarget:view action:@selector(qs_gestureRecognizerFired:)];
    doubleTapGR.numberOfTapsRequired = 2;

    tripleTapGR = [[UITapGestureRecognizer alloc] initWithTarget:view action:@selector(qs_gestureRecognizerFired:)];
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
#pragma mark - Gesture Recognizer Updates
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

            if (dtr || ttr) {
                [iconView removeGestureRecognizer:dtr];
                [iconView removeGestureRecognizer:ttr];

                objc_setAssociatedObject(iconView, &doubleTapGRKey, nil, OBJC_ASSOCIATION_ASSIGN);
                objc_setAssociatedObject(iconView, &tripleTapGRKey, nil, OBJC_ASSOCIATION_ASSIGN);
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
    NSDictionary *prefs = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.caughtinflux.qsproprefs"];
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

        QSCameraController *controller = [QSCameraController sharedInstance];
        controller.cameraDevice = QSCameraDeviceFromString(prefs[QSCameraDeviceKey]);
        controller.flashMode = QSFlashModeFromString(prefs[QSFlashModeKey]);
        controller.enableHDR = [prefs[QSHDRModeKey] boolValue];
        controller.waitForFocusCompletion = [prefs[QSWaitForFocusKey] boolValue];
        controller.videoCaptureQuality = prefs[QSVideoQualityKey];
        controller.videoFlashMode = QSFlashModeFromString(prefs[QSFlashModeKey]);
        
        _flashScreen = ((prefs[QSScreenFlashKey] != nil)  ? [prefs[QSScreenFlashKey] boolValue] : YES);
        _showRecordingIcon = ((prefs[QSRecordingIconKey] != nil) ? [prefs[QSRecordingIconKey] boolValue] : YES);
        
        [QSActivatorListener sharedInstance].shouldFlashScreen = _flashScreen;
        [QSActivatorListener sharedInstance].shouldShowRecordingIcon = _showRecordingIcon;

        [[NSNotificationCenter defaultCenter] postNotificationName:QSPrefsChangedNotificationName object:nil];
    }
    else if ([(NSString *)name isEqualToString:@"com.caughtinflux.quickshootpro.prefschanged.appicons"]) {
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
}

#pragma mark - Constructor
%ctor
{
    @autoreleasepool {
        NSLog(@"QS: Initialising, registering listeners and preference callbacks");
        %init;
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
        
//        [[LAActivator sharedInstance] registerListener:[QSActivatorListener sharedInstance] forName:QSOptionsWindowListenerName];
        [[LAActivator sharedInstance] registerListener:[QSActivatorListener sharedInstance] forName:QSImageCaptureListenerName];
        [[LAActivator sharedInstance] registerListener:[QSActivatorListener sharedInstance] forName:QSVideoCaptureListenerName];
    }
}
