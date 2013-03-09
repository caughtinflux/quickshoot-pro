#import <UIKit/UIKit.h>

#import "QSCameraController.h"
#import "QSIconOverlayView.h"

#import <SpringBoard/SBIconView.h>
#import <SpringBoard/SBIconImageView.h>
#import <SpringBoard/SBIcon.h>

#import <sys/utsname.h>

#define kPrefPath [NSHomeDirectory() stringByAppendingString:@"/Library/Preferences/com.caughtinflux.qsprefs.plist"]

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
static inline void QSSetCameraControllerPreferences(void);
static inline NSString * QSGetMachineName(void);


/*
*
*   Preference Key Constants
*
*/
NSString * const QSFlashModeKey    = @"kQSFlashMode";
NSString * const QSCameraDeviceKey = @"kQSCameraDevice";
NSString * const QSHDRModeKey      = @"kQSHDREnabled";

/*
*
*   Variables
*
*/
static QSCameraDevice  _preferredCameraDevice;
static QSFlashMode     _preferredFlashMode;
static BOOL            _preferredHDRMode;
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

    QSSetCameraControllerPreferences();

    SBIconImageView *imageView = [self iconImageView];
    QSIconOverlayView *overlayView = [[[QSIconOverlayView alloc] initWithFrame:imageView.frame] autorelease];
    [self setUserInteractionEnabled:NO];
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
        QSSetCameraControllerPreferences();
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
    _preferredCameraDevice = QSCameraDeviceFromString(prefs[QSCameraDeviceKey]);
    _preferredFlashMode = QSFlashModeFromString(prefs[QSFlashModeKey]);
    _preferredHDRMode = [prefs[QSHDRModeKey] boolValue];

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

static inline void QSSetCameraControllerPreferences(void)
{
    [[QSCameraController sharedInstance] setCameraDevice:_preferredCameraDevice];
    [[QSCameraController sharedInstance] setFlashMode:_preferredFlashMode];
    [[QSCameraController sharedInstance] setEnableHDR:_preferredHDRMode];
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