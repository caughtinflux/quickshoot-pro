#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <PhotoLibrary/PLCameraControllerDelegate-Protocol.h>

@interface QSCameraController : NSObject <PLCameraControllerDelegate, UIAlertViewDelegate>

- (void)takePhoto;

@end
