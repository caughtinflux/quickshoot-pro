#import <UIKit/UIKit.h>

#import "QSCameraController.h"
#import "QSIconOverlayView.h"
#import "QSActivatorListener.h"
#import "QSDefines.h"

#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBIconView.h>
#import <SpringBoard/SBIconImageView.h>
#import <SpringBoard/SBIcon.h>

#import <sys/utsname.h>


#pragma mark - Lockscreen Class Interfaces
@class SBAwayView;
@interface SBAwayController : NSObject
+ (instancetype)sharedAwayController;
- (SBAwayView *)awayView;
@end


#pragma mark - Function Declarations
static void QSUpdatePrefs(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);
static QSFlashMode QSFlashModeFromString(NSString *string);
static QSCameraDevice QSCameraDeviceFromString(NSString *string);
// these are inlines, so no errors are thrown if I don't use them. Also, they're tiny
static inline NSString * QSGetMachineName(void);


#pragma mark - Preference Key Constants
static NSString * const QSFlashModeKey    = @"kQSFlashMode";
static NSString * const QSCameraDeviceKey = @"kQSCameraDevice";
static NSString * const QSHDRModeKey      = @"kQSHDREnabled";
static NSString * const QSWaitForFocusKey = @"kQSWaitForFocus";

#pragma mark - Static Variables
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
    if (_isCapturingImage) {
        return;
    }

    NSDate *startDate = [NSDate date];
    _isCapturingImage = YES;

    SBIconImageView *imageView = [self iconImageView];
    QSIconOverlayView *overlayView = [[[QSIconOverlayView alloc] initWithFrame:imageView.frame] autorelease];
    [self setUserInteractionEnabled:NO];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
        // create a failsafe, which runs after 10 seconds
        // just in case the s
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
        DLog(@"Capture time: %f", fabs([startDate timeIntervalSinceNow]));
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

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    (CFNotificationCallback)&QSUpdatePrefs,
                                    CFSTR("com.caughtinflux.quickshootpro.prefschanged"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorHold);
    QSUpdatePrefs(NULL, NULL, NULL, NULL, NULL);
}
%end

#pragma mark - Function Definitions
static void QSUpdatePrefs(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    NSDictionary *prefs = [[NSDictionary alloc] initWithContentsOfFile:kPrefPath];

    [QSCameraController sharedInstance].cameraDevice = QSCameraDeviceFromString(prefs[QSCameraDeviceKey]);
    [QSCameraController sharedInstance].flashMode = QSFlashModeFromString(prefs[QSFlashModeKey]);
    [QSCameraController sharedInstance].enableHDR = [prefs[QSHDRModeKey] boolValue];
    [QSCameraController sharedInstance].waitForFocusCompletion = [prefs[QSWaitForFocusKey] boolValue];

    [prefs release];
}

static QSFlashMode QSFlashModeFromString(NSString *string)
{
    if ([string isEqualToString:@"kQSFlashModeOn"])
        return QSFlashModeOn;
    else if ([string isEqualToString:@"kQSFlashModeAuto"])
        return QSFlashModeOn;
    else if ([string isEqualToString:@"kQSFlashModeOff"])
        return QSFlashModeOff;
    else
        return QSFlashModeAuto; // default value, in case string is nil.
}

static QSCameraDevice QSCameraDeviceFromString(NSString *string)
{
    if ([string isEqualToString:@"kQSCameraDeviceRear"])
        return QSCameraDeviceRear;
    else if ([string isEqualToString:@"kQSCameraDeviceFront"])
        return QSCameraDeviceFront;
    else
        return QSCameraDeviceRear;
}

static inline NSString * QSGetMachineName(void)
{
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
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
    
    DLog(@"QS: Registering listener");
    [[LAActivator sharedInstance] registerListener:[QSActivatorListener new] forName:@"com.caughtinflux.quickshootpro.optionslistener"];
    [[LAActivator sharedInstance] registerListener:[QSActivatorListener new] forName:@"com.caughtinflux.quickshootpro.capturelistener"];
    
    [p drain];
}