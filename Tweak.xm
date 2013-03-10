#import <UIKit/UIKit.h>

#import "QSCameraController.h"
#import "QSIconOverlayView.h"

#import <SpringBoard/SBIconView.h>
#import <SpringBoard/SBIconImageView.h>
#import <SpringBoard/SBIcon.h>

#import <sys/utsname.h>

#define kPrefPath [NSHomeDirectory() stringByAppendingString:@"/Library/Preferences/com.caughtinflux.qsproprefs.plist"]

@interface SBAwayView : UIView
- (id)lockBar;
@end

@interface SBAwayController : NSObject
+ (SBAwayController *)sharedAwayController;
- (SBAwayView *)awayView;
@end


/*
*
*   Function Declarations
*
*/
static void QSUpdatePrefs(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);

static QSFlashMode QSFlashModeFromString(NSString *string);
static QSCameraDevice QSCameraDeviceFromString(NSString *string);

// these are inlines, so no errors are thrown if I don't use them. also, they're tiny
static inline NSString * QSGetMachineName(void);


/*
*
*   Preference Key Constants
*
*/
static NSString * const QSFlashModeKey    = @"kQSFlashMode";
static NSString * const QSCameraDeviceKey = @"kQSCameraDevice";
static NSString * const QSHDRModeKey      = @"kQSHDREnabled";
static NSString * const QSWaitForFocusKey = @"kQSWaitForFocus";


/*
*
*   Variables
*
*/
static BOOL            _isCapturingImage;


/*
*
*   Application Icon Hook
*
*/
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

    _isCapturingImage = YES;

    SBIconImageView *imageView = [self iconImageView];
    QSIconOverlayView *overlayView = [[[QSIconOverlayView alloc] initWithFrame:imageView.frame] autorelease];
    [self setUserInteractionEnabled:NO];

    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
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


/*
*
*   Camera Grabber Hooks
*
*/
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

/*
*
*   Function Definitions
*
*/
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
    @autoreleasepool {
        %init;
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        (CFNotificationCallback)&QSUpdatePrefs,
                                        CFSTR("com.caughtinflux.quickshootpro.prefschanged"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorHold);
        QSUpdatePrefs(NULL, NULL, NULL, NULL, NULL);
    }
}