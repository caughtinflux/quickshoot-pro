#import "QSActivatorListener.h"
#import "QSCameraController.h"
#import "QSCameraOptionsWindow.h"
#import "QSConstants.h"

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import <SpringBoard/SBScreenFlash.h>
#import <objc/runtime.h>

#import "LibstatusBar.h"


#pragma mark - Lockscreen Class Interfaces
@class SBAwayView;
@interface SBAwayController : NSObject
+ (instancetype)sharedAwayController;
- (BOOL)isLocked;
- (void)attemptUnlock;
@end

@interface QSActivatorListener ()
{
    QSCameraOptionsWindow *_optionsWindow;
    BOOL                   _isCapturingVideo;
}
- (void)_preferencesChanged:(NSNotification *)notification;
@end

@implementation QSActivatorListener

+ (instancetype)sharedInstance
{
    static dispatch_once_t predicate;
    static QSActivatorListener *sharedInstance;
    dispatch_once(&predicate, ^{
        sharedInstance = [[self alloc] init];
        [sharedInstance setAbilitiesChecked:YES];
        [[NSNotificationCenter defaultCenter] addObserver:sharedInstance selector:@selector(_preferencesChanged:) name:QSPrefsChangedNotificationName object:nil];
    });
    return sharedInstance;
}

#pragma mark - Activator Listener Protocol Implementation
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
    if (!self.abilitiesChecked) {
        return;
    }

    // image capture
    if ([[[LAActivator sharedInstance] assignedListenerNameForEvent:event] isEqualToString:QSImageCaptureListenerName]) {
        [[QSCameraController sharedInstance] takePhotoWithCompletionHandler:^(BOOL success) {
            [(SBScreenFlash *)[objc_getClass("SBScreenFlash") sharedInstance] flash];
        }];
    }

    // video capture
    else if ([[[LAActivator sharedInstance] assignedListenerNameForEvent:event] isEqualToString:QSVideoCaptureListenerName]) {
        if (_isCapturingVideo == NO) {
            _isCapturingVideo = YES;
            [[QSCameraController sharedInstance] startVideoCaptureWithHandler:^(BOOL success) {
                [(SpringBoard *)[UIApplication sharedApplication] addStatusBarImageNamed:QSStatusBarImageName];
            }];
        }
        else if (_isCapturingVideo) {
            [[QSCameraController sharedInstance] stopVideoCaptureWithHandler:^(BOOL success) {
                [(SpringBoard *)[UIApplication sharedApplication] removeStatusBarImageNamed:QSStatusBarImageName];
                _isCapturingVideo = NO;
            }];
        }
    }

    // options window
    else if ([[[LAActivator sharedInstance] assignedListenerNameForEvent:event] isEqualToString:QSOptionsWindowListenerName]) {
        if (!_optionsWindow) {
            _optionsWindow = [[QSCameraOptionsWindow alloc] initWithFrame:(CGRect){{0, 20}, {200, 102}} showFlash:YES showHDR:YES showCameraToggle:YES]; 
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
    }

    [event setHandled:YES];
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
