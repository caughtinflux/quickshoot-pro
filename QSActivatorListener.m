#import "QSActivatorListener.h"
#import "QSCameraController.h"
#import "QSCameraOptionsWindow.h"
#import "QSConstants.h"

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import <SpringBoard/SBScreenFlash.h>
#import <SpringBoard/SBAwayController.h>
#import <objc/runtime.h>

#import "LibstatusBar.h"

@interface QSActivatorListener ()
{
    QSCameraOptionsWindow *_optionsWindow;
    BOOL                   _isCapturingVideo;
    BOOL                   _shouldBlinkVideoIcon;
}

- (void)_startBlinkingVideoIcon;
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
        DLog(@"Image capture");
        [[QSCameraController sharedInstance] takePhotoWithCompletionHandler:^(BOOL success) {
            [(SBScreenFlash *)[objc_getClass("SBScreenFlash") sharedInstance] flash];
        }];
    }
    // video capture
    else if ([[[LAActivator sharedInstance] assignedListenerNameForEvent:event] isEqualToString:QSVideoCaptureListenerName]) {
        DLog(@"Video handling");
        if (_isCapturingVideo == NO) {
            _isCapturingVideo = YES;
            [[QSCameraController sharedInstance] startVideoCaptureWithHandler:^(BOOL success) {
                [(SpringBoard *)[UIApplication sharedApplication] addStatusBarImageNamed:QSStatusBarImageName];
            }];
        }
        else {
            _shouldBlinkVideoIcon = YES;
            [self _startBlinkingVideoIcon];
            [[QSCameraController sharedInstance] stopVideoCaptureWithHandler:^(BOOL success) {
                _shouldBlinkVideoIcon = NO;
                _isCapturingVideo = NO;
                [(SpringBoard *)[UIApplication sharedApplication] removeStatusBarImageNamed:QSStatusBarImageName];
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
    DLog(@"");
    QSCameraDevice currentDevice = [[QSCameraController sharedInstance] cameraDevice];
    [[QSCameraController sharedInstance] setCameraDevice:((currentDevice == QSCameraDeviceRear) ? QSCameraDeviceFront : QSCameraDeviceRear)];

    NSMutableDictionary *prefsDict = [NSMutableDictionary dictionaryWithContentsOfFile:kPrefPath];
    prefsDict[QSCameraDeviceKey] = QSStringFromCameraDevice([QSCameraController sharedInstance].cameraDevice); 
    [prefsDict writeToFile:kPrefPath atomically:YES];
}

- (void)optionsWindow:(QSCameraOptionsWindow *)optionsWindow hdrModeChanged:(BOOL)newMode
{
    DLog(@"");
    [[QSCameraController sharedInstance] setEnableHDR:newMode];
    
    NSMutableDictionary *prefsDict = [NSMutableDictionary dictionaryWithContentsOfFile:kPrefPath];
    prefsDict[QSHDRModeKey] = [NSNumber numberWithBool:newMode];
    [prefsDict writeToFile:kPrefPath atomically:YES];
}

- (void)optionsWindow:(QSCameraOptionsWindow *)optionsWindow flashModeChanged:(QSFlashMode)newMode
{
    DLog(@"Flash mode now: %i", newMode);
    [[QSCameraController sharedInstance] setFlashMode:newMode];
    [[QSCameraController sharedInstance] setVideoFlashMode:newMode];

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

#pragma mark - Private Stuffs!
- (void)_startBlinkingVideoIcon
{
    if (!_shouldBlinkVideoIcon) {
        return;
    }
    [(SpringBoard *)[UIApplication sharedApplication] addStatusBarImageNamed:QSStatusBarImageName];
    EXECUTE_BLOCK_AFTER_DELAY(0.3, ^{
        [(SpringBoard *)[UIApplication sharedApplication] removeStatusBarImageNamed:QSStatusBarImageName];
        EXECUTE_BLOCK_AFTER_DELAY(0.3, ^{
            [self _startBlinkingVideoIcon];
        });
    });
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
