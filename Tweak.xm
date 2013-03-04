#import "QSCameraController.h"

#import <UIKit/UIKit.h>

#import <SpringBoard/SBIconView.h>
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
*	Static Functions
*
*/
static void QSUpdatePrefs(void);

// Helper functions
static QSFlashMode    QSFlashModeFromString(NSString *string);
static QSCameraDevice QSCameraDeviceFromString(NSString *string);
static void           QSSetCameraControllerPreferences(void);
static NSString     * QSGetMachineName(void);


/*
*
*	Preference Key Constants
*
*/
NSString * const QSFlashModeKey    = @"kQSFlashMode";
NSString * const QSCameraDeviceKey = @"kQSCameraDevice";
NSString * const QSHDRModeKey      = @"kQSHDREnabled";

/*
*
*	Preference Variables
*
*/
static QSCameraDevice _preferredCameraDevice;
static QSFlashMode    _preferredFlashMode;
static BOOL           _preferredHDRMode;


/*
*
*	Application Icon Hook
*
*/
%hook SBIconView
- (void)setIcon:(SBIcon *)icon
{
	// this is an awesome hook, makes it work in the switcher too.
	// so much for modesty
	// I don't know why I'm commenting like this.
	// Especially since no one else is going to read this
	// I might make you laugh a few months later.
	// lulz.
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
	[(SBIcon *)[self icon] setBadge:@"•••"];
	[(SBIcon *)[self icon] noteBadgeDidChange];

	QSSetCameraControllerPreferences();

	[[QSCameraController sharedInstance] takePhotoWithCompletionHandler:^(BOOL success){
		[(SBIcon *)[self icon] setBadge:nil];
		[(SBIcon *)[self icon] noteBadgeDidChange];
		return;
	}];
}
%end


/*
*
*	Camera Grabber Hooks
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
* Preference Functions' Implementations
*
*/
static void QSUpdatePrefs(void)
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
										CFSTR("com.caughtinflux.quickshoot.prefschanged"),
										NULL,
										CFNotificationSuspensionBehaviorHold);
		QSUpdatePrefs();
	}
}
