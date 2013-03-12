#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <PhotoLibrary/PLCameraControllerDelegate-Protocol.h>
#import "QSDefines.h"

@interface QSCameraController : NSObject <PLCameraControllerDelegate>

@property(nonatomic, assign) QSCameraDevice cameraDevice;
@property(nonatomic, assign) QSFlashMode flashMode;
@property(nonatomic, assign) BOOL enableHDR;
@property(nonatomic, assign) BOOL waitForFocusCompletion;
@property(nonatomic, assign) UIDeviceOrientation currentOrientation;
 
+ (instancetype)sharedInstance;
// The completion handlers are copied
- (void)takePhotoWithCompletionHandler:(QSCompletionHandler)completionHandler;
- (void)startVideoCaptureWithHandler:(QSCompletionHandler)handler;
- (void)stopVideoCaptureWithHandler;

@end
