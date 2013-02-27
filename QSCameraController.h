#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <PhotoLibrary/PLCameraControllerDelegate-Protocol.h>


typedef void (^QSCompletionHandler)(void);

@interface QSCameraController : NSObject <PLCameraControllerDelegate, UIAlertViewDelegate>

- (void)takePhotoWithCompletionHandler:(QSCompletionHandler)completionHandler;

@end
