/*
*       ____        _      __   _____ __                __  ____           
*      / __ \__  __(_)____/ /__/ ___// /_  ____  ____  / /_/ __ \_________ 
*     / / / / / / / / ___/ //_/\__ \/ __ \/ __ \/ __ \/ __/ /_/ / ___/ __ \
*    / /_/ / /_/ / / /__/ ,<  ___/ / / / / /_/ / /_/ / /_/ ____/ /  / /_/ /
*    \___\_\__,_/_/\___/_/|_|/____/_/ /_/\____/\____/\__/_/   /_/   \____/ 
*                                                                          
*   QSActivatorListener.m
*   © 2013 Aditya KD
*/

#import "QSActivatorListener.h"
#import "QSCameraController.h"
#import "QSCameraOptionsWindow.h"
#import "QSConstants.h"
#import "QSAntiPiracy.h"

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CFUserNotification.h>

#import <SpringBoard/SBBacklightController.h>
#import <SpringBoard/SBScreenFlash.h>

#define objc_getClass(_cls) NSClassFromString(@_cls)

#import "LibstatusBar.h"

#define STRING_FROM_BOOL(b) (b == YES ? @"YES" : @"NO")

@interface QSActivatorListener ()
{
    QSCameraOptionsWindow *_optionsWindow;
    BOOL _isCapturingVideo;
    BOOL _shouldBlinkVideoIcon;
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
        [[NSNotificationCenter defaultCenter] addObserver:sharedInstance selector:@selector(_preferencesChanged:) name:QSPrefsChangedNotificationName object:nil];
    });
    return sharedInstance;
}

#pragma mark - Activator Listener Protocol Implementation
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
    if (IS_PIRATED) return;

    // image capture
    if ([[[LAActivator sharedInstance] assignedListenerNameForEvent:event] isEqualToString:QSImageCaptureListenerName]) {
        if ([QSCameraController sharedInstance].isCapturingImage) {
            return;
        }
        [[QSCameraController sharedInstance] takePhotoWithCompletionHandler:^(BOOL success) {
            if (self.shouldFlashScreen) {
                [[objc_getClass("SBScreenFlash") mainScreenFlasher] flashWhiteWithCompletion:nil];
            }
        }];
    }
    // video capture
    else if ([[[LAActivator sharedInstance] assignedListenerNameForEvent:event] isEqualToString:QSVideoCaptureListenerName]) {
        static BOOL isStartingRecording;

        QSCompletionHandler videoStopHandler = ^(BOOL success) {
            _shouldBlinkVideoIcon = NO;
            _isCapturingVideo = NO;
            [(SpringBoard *)[UIApplication sharedApplication] removeStatusBarImageNamed:QSStatusBarImageName];
            if (!success) {
                SHOW_USER_NOTIFICATION(@"QuickShoot", @"The video recording did not complete successfully. Please try again.", @"Dismiss");
            }
        };

        if (_isCapturingVideo == NO && !isStartingRecording) {
            if ([QSCameraController sharedInstance].isCapturingVideo) {
                // this check is necessary, because the user might be recording a video some other way, too.
                [(SpringBoard *)[UIApplication sharedApplication] removeStatusBarImageNamed:QSStatusBarImageName];
                return;
            }
            _isCapturingVideo = YES;
            isStartingRecording = YES;

            [[QSCameraController sharedInstance] startVideoCaptureWithHandler:^(BOOL success) {
                if (!success) {
                    _isCapturingVideo = NO;
                    isStartingRecording = NO;
                }
                else {
                    if (self.shouldShowRecordingIcon) {
                        [(SpringBoard *)[UIApplication sharedApplication] addStatusBarImageNamed:QSStatusBarImageName];
                    }
                    isStartingRecording = NO;
                }
            } interruptionHandler:videoStopHandler];
        }
        else if (_isCapturingVideo == YES && !isStartingRecording) {
            if (self.shouldShowRecordingIcon) {
                _shouldBlinkVideoIcon = YES;
                [self _startBlinkingVideoIcon];
            } 
            [[QSCameraController sharedInstance] stopVideoCaptureWithHandler:videoStopHandler];
        }
    }
    // options window
    else if ([[[LAActivator sharedInstance] assignedListenerNameForEvent:event] isEqualToString:QSOptionsWindowListenerName]) {
        if (!_optionsWindow) {
            _optionsWindow = [[QSCameraOptionsWindow alloc] initWithFrame:(CGRect){{0, 20}, {200, 102}} showFlash:YES showHDR:YES showCameraToggle:YES]; 
            _optionsWindow.windowLevel = 2000;
            _optionsWindow.delegate = self;
            [self _preferencesChanged:nil]; // make sure the delay times 'n' shit are set.
        }
        if (_optionsWindow.hidden) {
            [[NSClassFromString(@"SBBacklightController") sharedInstance] turnOnScreenFullyWithBacklightSource:1];
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

@end
