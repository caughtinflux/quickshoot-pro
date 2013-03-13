#import "QSActivatorListener.h"
#import "QSCameraController.h"
#import "QSCameraOptionsWindow.h"
#import "QSConstants.h"

#import <UIKit/UIKit.h>

static NSString * const QSCaptureListenerName = @"com.caughtinflux.quickshootpro.capturelistener";
static NSString * const QSOptionsListenerName = @"com.caughtinflux.quickshootpro.optionslistener";


@implementation QSActivatorListener
{
    QSCameraOptionsWindow *_optionsWindow;
}

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
            _optionsWindow.windowLevel = UIWindowLevelStatusBar + 10;
            _optionsWindow.delegate = self;
        }

        _optionsWindow.hidden = (_optionsWindow.hidden) ? NO : YES;
        [event setHandled:YES];
    }
}

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

@end