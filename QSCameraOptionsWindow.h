/*
*       ____        _      __   _____ __                __  ____           
*      / __ \__  __(_)____/ /__/ ___// /_  ____  ____  / /_/ __ \_________ 
*     / / / / / / / / ___/ //_/\__ \/ __ \/ __ \/ __ \/ __/ /_/ / ___/ __ \
*    / /_/ / /_/ / / /__/ ,<  ___/ / / / / /_/ / /_/ / /_/ ____/ /  / /_/ /
*    \___\_\__,_/_/\___/_/|_|/____/_/ /_/\____/\____/\__/_/   /_/   \____/ 
*                                                                          
*   QSCameraOptionsWindow.h
*   © 2013 Aditya KD
*/

#import <UIKit/UIKit.h>
#import <PhotoLibrary/CAMFlashButtonDelegate-Protocol.h>
#import <PhotoLibrary/PLCameraSettingsView.h>
#import "QSConstants.h"

@class QSCameraOptionsWindow;

@protocol QSCameraOptionsWindowDelegate <NSObject>
@required
- (void)optionsWindow:(QSCameraOptionsWindow *)optionsWindow hdrModeChanged:(BOOL)newMode;
- (void)optionsWindow:(QSCameraOptionsWindow *)optionsWindow flashModeChanged:(QSFlashMode)newMode;
- (void)optionsWindowCameraButtonToggled:(QSCameraOptionsWindow *)optionsWindow;
- (QSCameraDevice)currentCameraDeviceForOptionsWindow:(QSCameraOptionsWindow *)optionsWindow;
- (QSFlashMode)currentFlashModeForOptionsWindow:(QSCameraOptionsWindow *)optionsWindow;
- (BOOL)currentHDRModeForOptionsWindow:(QSCameraOptionsWindow *)optionsWindow;
@end

@interface QSCameraOptionsWindow : UIWindow <CAMFlashButtonDelegate, PLCameraSettingsViewDelegate>

@property(nonatomic, assign) id<QSCameraOptionsWindowDelegate> delegate;
@property(nonatomic, assign) NSTimeInterval automaticHideDelay; // in seconds

// If YES is passed in to a argument that isn't supported, it is shown on screen, but the buttons/switches are disabled
- (instancetype)initWithFrame:(CGRect)frame showFlash:(BOOL)shouldShowFlash showHDR:(BOOL)shouldShowHDR showCameraToggle:(BOOL)shouldShowCameraToggle;

- (void)setHDRMode:(BOOL)hdrMode;
- (void)setFlashMode:(QSFlashMode)flashMode;
- (void)hideWindowAnimated;

@end
