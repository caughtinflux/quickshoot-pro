#import <UIKit/UIKit.h>
#import <PhotoLibrary/PLCameraFlashButtonDelegate-Protocol.h>
#import <PhotoLibrary/PLCameraSettingsViewDelegate-Protocol.h>
#import "QSDefines.h"

@class QSCameraOptionsWindow;

@protocol QSCameraOptionsWindowDelegate <NSObject>
@required
- (void)optionsWindow:(QSCameraOptionsWindow *)optionsWindow hdrModeChanged:(BOOL)newMode;
- (void)optionsWindow:(QSCameraOptionsWindow *)optionsWindow flashModeChanged:(QSFlashMode)newMode;
- (void)optionsWindowCameraButtonToggled:(QSCameraOptionsWindow *)optionsWindow;
@end

@interface QSCameraOptionsWindow : UIWindow <PLCameraFlashButtonDelegate, PLCameraSettingsViewDelegate>

- (instancetype)initWithFrame:(CGRect)frame showFlash:(BOOL)shouldShowFlash showHDR:(BOOL)shouldShowHDR showCameraToggle:(BOOL)shouldShowCameraToggle;

@property(nonatomic, assign) id<QSCameraOptionsWindowDelegate> delegate;

@end
