#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <PhotoLibrary/PLCameraControllerDelegate-Protocol.h>


typedef void (^QSCompletionHandler)(BOOL);

@interface QSCameraController : NSObject <PLCameraControllerDelegate, UIAlertViewDelegate>

+ (instancetype)sharedInstance;

// THe completion handler is retained(copied) by the following method.
- (void)takePhotoWithCompletionHandler:(QSCompletionHandler)completionHandler;

@end
