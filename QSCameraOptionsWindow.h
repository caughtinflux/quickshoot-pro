#import <UIKit/UIKit.h>
#import <PhotoLibrary/PLCameraFlashButtonDelegate-Protocol.h>
#import <PhotoLibrary/PLCameraSettingsViewDelegate-Protocol.h>
#import "QSDefines.h"

@interface QSCameraOptionsWindow : UIWindow <PLCameraFlashButtonDelegate, PLCameraSettingsViewDelegate>

- (instancetype)initWithFrame:(CGRect)frame showFlash:(BOOL)shouldShowFlash showHDR:(BOOL)shouldShowHDR showCameraToggle:(BOOL)shouldShowCameraToggle;

@end
