#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <PhotoLibrary/PLCameraControllerDelegate-Protocol.h>

#import "QSVideoInterface.h"
#import "QSConstants.h"

@interface QSCameraController : NSObject <PLCameraControllerDelegate, QSVideoInterfaceDelegate>

@property(nonatomic, assign) QSCameraDevice cameraDevice;
@property(nonatomic, assign) QSFlashMode flashMode;
@property(nonatomic, assign) BOOL enableHDR;
@property(nonatomic, assign) BOOL waitForFocusCompletion;
@property(nonatomic, assign) UIDeviceOrientation currentOrientation;

// video properties
@property(nonatomic, copy) NSString *videoCaptureQuality;
@property(nonatomic, assign) QSFlashMode videoFlashMode;
 
+ (instancetype)sharedInstance;
// The completion handlers are copied
- (void)takePhotoWithCompletionHandler:(QSCompletionHandler)completionHandler;
- (void)startVideoCaptureWithHandler:(QSCompletionHandler)handler;
- (void)stopVideoCaptureWithHandler:(QSCompletionHandler)handler;

@end
