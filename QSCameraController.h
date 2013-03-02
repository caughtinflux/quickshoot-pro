#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <PhotoLibrary/PLCameraControllerDelegate-Protocol.h>

// These values are the same that are accepted by PLCameraController
typedef enum {
	QSCameraModeRear  = 0,
	QSCameraModeFront = 1,
} QSCameraMode;

typedef enum {
	QSFlashModeAuto =  0,
	QSFlashModeOn   =  1,
	QSFlashModeOff  = -1,
} QSFlashMode;

typedef void (^QSCompletionHandler)(BOOL); // the BOOL argument is most probably pointless.

@interface QSCameraController : NSObject <PLCameraControllerDelegate, UIAlertViewDelegate>

// these properties have to be set every time a photo is to be taken, they are zeroed out after every captur.
@property(nonatomic, assign) QSCameraMode cameraMode;
@property(nonatomic, assign) QSFlashMode flashMode;
@property(nonatomic, assign) BOOL enableHDR;
 
+ (instancetype)sharedInstance;
// THe completion handler is retained(copied) by the following method.
- (void)takePhotoWithCompletionHandler:(QSCompletionHandler)completionHandler;

@end
