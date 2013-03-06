#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <PhotoLibrary/PLCameraControllerDelegate-Protocol.h>

// These values are the same that are accepted by PLCameraController
typedef enum {
	QSCameraDeviceRear  = 0,
	QSCameraDeviceFront = 1,
} QSCameraDevice; // UIImagePickerControllerCameraDevice

typedef enum {
	QSFlashModeAuto =  0,
	QSFlashModeOn   =  1,
	QSFlashModeOff  = -1,
} QSFlashMode;

typedef void (^QSCompletionHandler)(BOOL); // the BOOL argument is most probably pointless.

@interface QSCameraController : NSObject <PLCameraControllerDelegate, UIAlertViewDelegate>

// these properties have to be set every time a photo is to be taken, they are zeroed out after every capture.
@property(nonatomic, assign) QSCameraDevice cameraDevice;
@property(nonatomic, assign) QSFlashMode flashMode;
@property(nonatomic, assign) BOOL enableHDR;
 
+ (instancetype)sharedInstance;
// The completion handler is copied
- (void)takePhotoWithCompletionHandler:(QSCompletionHandler)completionHandler;
- (void)startVideoCaptureWithCompletionHandler:(QSCompletionHandler)videoStartCompletionHandler;
- (void)stopVideoCaptureWithCompletionHandler:(QSCompletionHandler)videoStopCompletionHandler;

@end
