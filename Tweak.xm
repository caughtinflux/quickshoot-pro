#import <UIKit/UIKit.h>

#import "QSCameraController.h"
#import "QSIconOverlayView.h"
#import "QSActivatorListener.h"
#import "QSConstants.h"

#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBIconView.h>
#import <SpringBoard/SBIconImageView.h>
#import <SpringBoard/SBIcon.h>


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
    }
}

%new
- (void)qs_doubleTapRecognizerFired:(UITapGestureRecognizer *)dtr
{
    if (!_enabled || _isCapturingImage || (![[(SBIcon *)[self icon] leafIdentifier] isEqualToString:@"com.apple.camera"])) {
        NSLog(@"QuickShoot: Cowardly returning because icon identifier was not recognized");
        return;
    }

    _isCapturingImage = YES;

    SBIconImageView *imageView = [self iconImageView];
    QSIconOverlayView *overlayView = [[[QSIconOverlayView alloc] initWithFrame:imageView.frame] autorelease];
    [self setUserInteractionEnabled:NO];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
        // create a failsafe, which runs after 10 seconds
        [self setUserInteractionEnabled:YES];
    });

    overlayView.animationCompletionHandler = ^{
        [overlayView removeFromSuperview];
        [self setUserInteractionEnabled:YES];
    };
    [imageView addSubview:overlayView];
    [overlayView imageCaptureBegan];

    [[QSCameraController sharedInstance] takePhotoWithCompletionHandler:^(BOOL success){
        _isCapturingImage = NO;
        [overlayView imageCaptureCompleted];
    }];
}
%end


#pragma mark - Camera Grabber Hooks
%hook UITapGestureRecognizer 
- (UITapGestureRecognizer *)initWithTarget:(id)target action:(SEL)action
{
    self = %orig;
    if (self && (target == [%c(SBAwayController) sharedAwayController]) && (action == @selector(handleCameraTapGesture:))) {
        [(UITapGestureRecognizer *)self setNumberOfTapsRequired:2];
    }
    return self;
}
%end

%hook SBAwayController
- (void)handleCameraTapGesture:(UITapGestureRecognizer *)recognizer
{
    if (!_enabled) {
        return;
    }
    if (recognizer.numberOfTapsRequired == 2) {
        [[QSCameraController sharedInstance] takePhotoWithCompletionHandler:^(BOOL success){
            ;
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

static void QSUpdatePrefs(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    NSDictionary *prefs = [[NSDictionary alloc] initWithContentsOfFile:kPrefPath];

    _enabled = [prefs[QSEnabledKey] boolValue];
    [QSCameraController sharedInstance].cameraDevice = QSCameraDeviceFromString(prefs[QSCameraDeviceKey]);
    [QSCameraController sharedInstance].flashMode = QSFlashModeFromString(prefs[QSFlashModeKey]);
    [QSCameraController sharedInstance].enableHDR = [prefs[QSHDRModeKey] boolValue];
    [QSCameraController sharedInstance].waitForFocusCompletion = [prefs[QSWaitForFocusKey] boolValue];
    [QSCameraController sharedInstance].videoCaptureQuality = prefs[QSVideoQualityKey];
    [QSCameraController sharedInstance].videoFlashMode = QSFlashModeFromString(prefs[QSTorchModeKey]);

    [[NSNotificationCenter defaultCenter] postNotificationName:QSPrefsChangedNotificationName object:nil];

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
}