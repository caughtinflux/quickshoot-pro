#import "QSActivatorListener.h"
#import "QSCameraController.h"
#import "QSCameraOptionsWindow.h"
#import "QSConstants.h"

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString * const QSCaptureListenerName = @"com.caughtinflux.quickshootpro.capturelistener";
static NSString * const QSOptionsListenerName = @"com.caughtinflux.quickshootpro.optionslistener";

#pragma mark - Lockscreen Class Interfaces
@class SBAwayView;
@interface SBAwayController : NSObject
+ (instancetype)sharedAwayController;
- (BOOL)isLocked;
- (void)attemptUnlock;
@end

@interface QSActivatorListener () {}
- (void)_preferencesChanged:(NSNotification *)notification;
@end

@implementation QSActivatorListener
{
    QSCameraOptionsWindow *_optionsWindow;
}

- (instancetype)init
{
    if ((self = [super init])) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_preferencesChanged:) name:QSPrefsChangedNotificationName object:nil];
    }
    return self;
}

#pragma mark - Activator Listener Protocol Implementation
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
    if ([[[LAActivator sharedInstance] assignedListenerNameForEvent:event] isEqualToString:QSCaptureListenerName]) {
        [[QSCameraController sharedInstance] takePhotoWithCompletionHandler:^(BOOL success) {
            ;// do nothing
        }];
        [event setHandled:YES];
    }
    else if ([[[LAActivator sharedInstance] assignedListenerNameForEvent:event] isEqualToString:QSOptionsListenerName]) {
        if (!_optionsWindow) {
            _optionsWindow = [[QSCameraOptionsWindow alloc] initWithFrame:(CGRect){{0, 20}, {200, 190}} showFlash:YES showHDR:YES showCameraToggle:YES]; 
            _optionsWindow.windowLevel = 1200;
            _optionsWindow.delegate = self;
            [self _preferencesChanged:nil]; // make sure the delay times 'n' shit are set.
        }
        if (_optionsWindow.hidden) {
            Class SBAwayController = objc_getClass("SBAwayController");
            if ([[SBAwayController sharedAwayController] isLocked]) {
                [[SBAwayController sharedAwayController] attemptUnlock]; // turn screen on.
            }
            _optionsWindow.hidden = NO; 
        }
        else {
            [_optionsWindow hideWindowAnimated];
        }
        [event setHandled:YES];
    }
}

#pragma mark - Options Window Delegate
- (void)optionsWindowCameraButtonToggled:(QSCameraOptionsWindow *)optionsWindow
{
    QSCameraDevice currentDevice = [[QSCameraController sharedInstance] cameraDevice];
    [[QSCameraController sharedInstance] setCameraDevice:((currentDevice == QSCameraDeviceRear) ? QSCameraDeviceFront : QSCameraDeviceRear)];

    NSMutableDictionary *prefsDict = [NSMutableDictionary dictionaryWithContentsOfFile:kPrefPath];
    prefsDict[QSCameraDeviceKey] = QSStringFromCameraDevice([QSCameraController sharedInstance].cameraDevice);
    [prefsDict writeToFile:kPrefPath atomically:YES];
}

- (void)optionsWindow:(QSCameraOptionsWindow *)optionsWindow hdrModeChanged:(BOOL)newMode
{
    [[QSCameraController sharedInstance] setEnableHDR:newMode];
    
    NSMutableDictionary *prefsDict = [NSMutableDictionary dictionaryWithContentsOfFile:kPrefPath];
    prefsDict[QSHDRModeKey] = [NSNumber numberWithBool:newMode];
    [prefsDict writeToFile:kPrefPath atomically:YES];
}

- (void)optionsWindow:(QSCameraOptionsWindow *)optionsWindow flashModeChanged:(QSFlashMode)newMode
{
    [[QSCameraController sharedInstance] setFlashMode:newMode];

    NSMutableDictionary *prefsDict = [NSMutableDictionary dictionaryWithContentsOfFile:kPrefPath];
    prefsDict[QSFlashModeKey] = QSStringFromFlashMode(newMode);
    [prefsDict writeToFile:kPrefPath atomically:YES];
}

- (QSCameraDevice)currentCameraDeviceForOptionsWindow:(QSCameraOptionsWindow *)optionsWindow
{
    return [QSCameraController sharedInstance].cameraDevice;
}

- (QSFlashMode)currentFlashModeForOptionsWindow:(QSCameraOptionsWindow *)optionsWindow
{
    return [QSCameraController sharedInstance].flashMode;
}

- (BOOL)currentHDRModeForOptionsWindow:(QSCameraOptionsWindow *)optionsWindow
{
    return [QSCameraController sharedInstance].enableHDR;
}

- (void)_preferencesChanged:(NSNotification *)notification
{
    @autoreleasepool {
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
        _optionsWindow.automaticHideDelay = [prefs[QSOptionsWindowHideDelayKey] doubleValue];

        [_optionsWindow setHDRMode:[prefs[QSHDRModeKey] boolValue]];
        [_optionsWindow setFlashMode:QSFlashModeFromString(prefs[QSFlashModeKey])];
    }
}

- (void)dealloc
{
    [_optionsWindow setHidden:YES];
    [_optionsWindow release];
    _optionsWindow = nil;

    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [super dealloc];
}
@end
