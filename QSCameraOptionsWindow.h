#import <UIKit/UIKit.h>
#import <PhotoLibrary/PLCameraFlashButtonDelegate-Protocol.h>
#import <PhotoLibrary/PLCameraSettingsViewDelegate-Protocol.h>
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

@interface QSCameraOptionsWindow : UIWindow <PLCameraFlashButtonDelegate, PLCameraSettingsViewDelegate>

@property(nonatomic, assign) id<QSCameraOptionsWindowDelegate> delegate;
@property(nonatomic, assign) NSTimeInterval automaticHideDelay; // in seconds

// If YES is passed in to a argument that isn't supported, it is shown on screen, but the buttons/switches are disabled
- (instancetype)initWithFrame:(CGRect)frame showFlash:(BOOL)shouldShowFlash showHDR:(BOOL)shouldShowHDR showCameraToggle:(BOOL)shouldShowCameraToggle;

- (void)setHDRMode:(BOOL)hdrMode;
- (void)setFlashMode:(QSFlashMode)flashMode;
- (void)hideWindowAnimated;

@end
