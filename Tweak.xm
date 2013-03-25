#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CommonCrypto/CommonDigest.h>

#import "QSCameraController.h"
#import "QSIconOverlayView.h"
#import "QSActivatorListener.h"
#import "QSInformationKit.h"
#import "QSConstants.h"

#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBIconView.h>
#import <SpringBoard/SBIconViewMap.h>
#import <SpringBoard/SBIconImageView.h>
#import <SpringBoard/SBIcon.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBScreenFlash.h>

#import "LibstatusBar.h"

#import <objc/runtime.h>

#pragma mark - Lockscreen Class Interfaces
@class SBAwayView;
@interface SBAwayController : NSObject
+ (instancetype)sharedAwayController;
- (BOOL)isLocked;
- (SBAwayView *)awayView;
@end


#pragma mark - Static Stuff
static BOOL _enabled;
static BOOL _isCapturingImage;
static BOOL            _enabled                 = NO;
static BOOL            _abilitiesChecked        = NO; // aka _isPirated
static BOOL            _isCapturingImage        = NO;
static BOOL            _isCapturingVideo        = NO;
static BOOL            _hasInitialized          = NO;
static NSMutableArray *_enabledAppIDs           = nil;
static NSString       *_currentlyOverlayedAppID = nil;

static char doubleTapGRKey[] = "com.caughtinflux.quickshootpro.doubleTapGRKey";
static char tripleTapGRKey[] = "com.caughtinflux.quickshootpro.tripleTapGRKey";

static BOOL QSAppIsEnabled(NSString *identifier);
static void QSAddGestureRecognizersToView(SBIconView *view);


#pragma mark - Application Icon Hook
%hook SBIconView
- (void)setIcon:(SBIcon *)icon
{
    // this is an awesome hook, makes it work in the switcher too.
    // so much for modesty
    %orig;
    if ([[(SBIcon *)icon leafIdentifier] isEqualToString:@"com.apple.camera"]) {
        UITapGestureRecognizer *doubleTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(qs_doubleTapRecognizerFired:)];
        doubleTapGR.numberOfTapsRequired = 2;
        [(SBIconView *)self addGestureRecognizer:doubleTapGR];
        [doubleTapGR release];
        [(SBIconView *)self setUserInteractionEnabled:YES];
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
        QSIconOverlayView *overlayView = [[[QSIconOverlayView alloc] initWithFrame:imageView.frame] autorelease];
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
            overlayView = [[[QSIconOverlayView alloc] initWithFrame:imageView.frame] autorelease];

            overlayView.animationCompletionHandler = ^{
                [overlayView removeFromSuperview];
            };
            [imageView addSubview:overlayView];
            [overlayView captureBegan];

            [[QSCameraController sharedInstance] startVideoCaptureWithHandler:^(BOOL success) {
                ;
            }];
        }
        else {
            [[QSCameraController sharedInstance] stopVideoCaptureWithHandler:^(BOOL success) {
                [overlayView captureCompleted];
                _isCapturingVideo = NO;
            }];
        }
    }
}
%end

#pragma mark - Hook to Prevent Apps Launching when QuickShooting
%hook SBApplicationIcon
- (void)launch
{
    if (_isCapturingVideo && ([[(SBApplicationIcon *)self leafIdentifier] isEqualToString:_currentlyOverlayedAppID])) {
        // the app should not launch if it has an overlay.
        // this won't be called when capturing an image, but video is and
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
    if (!_enabled || _isCapturingImage)
        return;

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


#pragma mark - SpringBoard Hook (Rotation Events)
%hook SpringBoard
- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    %orig;
    [(SpringBoard *)[UIApplication sharedApplication] setWantsOrientationEvents:YES];
    [(SpringBoard *)[UIApplication sharedApplication] updateOrientationAndAccelerometerSettings];
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [QSCameraController sharedInstance]; // make sure the object is created, hence setting it up to receive orientation notifs.
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
        DLog(@"Updating app icons' stuffs")
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

%ctor
{
    NSAutoreleasePool *p = [NSAutoreleasePool new];
    %init;
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    (CFNotificationCallback)&QSUpdatePrefs,
                                    CFSTR("com.caughtinflux.quickshootpro.prefschanged"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorHold);
    QSUpdatePrefs(NULL, NULL, NULL, NULL, NULL);
    
    NSLog(@"QS: Registering listener");
    [[LAActivator sharedInstance] registerListener:[QSActivatorListener new] forName:@"com.caughtinflux.quickshootpro.optionslistener"];
    [[LAActivator sharedInstance] registerListener:[QSActivatorListener new] forName:@"com.caughtinflux.quickshootpro.capturelistener"];
    
    [p drain];
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
                                        CFSTR("com.caughtinflux.quickshootpro.prefschanged.appicons"),
                                        NULL,

        QSUpdatePrefs(NULL, NULL, CFSTR("com.caughtinflux.quickshootpro.prefschanged"), NULL, NULL);
        QSUpdatePrefs(NULL, NULL, CFSTR("com.caughtinflux.quickshootpro.prefschanged.appicons"), NULL, NULL);
        
        [[LAActivator sharedInstance] registerListener:[QSActivatorListener sharedInstance] forName:QSOptionsWindowListenerName];
        [[LAActivator sharedInstance] registerListener:[QSActivatorListener sharedInstance] forName:QSImageCaptureListenerName];
        [[LAActivator sharedInstance] registerListener:[QSActivatorListener sharedInstance] forName:QSVideoCaptureListenerName];
        
    }
}