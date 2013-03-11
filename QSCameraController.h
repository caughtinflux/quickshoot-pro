#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <PhotoLibrary/PLCameraControllerDelegate-Protocol.h>

// These values are accepted by PLCameraController as-is
typedef enum {
	QSCameraDeviceRear  = 0,
	QSCameraDeviceFront = 1,
} QSCameraDevice; // it's the same as UIImagePickerControllerCameraDevice

typedef enum {
	QSFlashModeAuto =  0,
	QSFlashModeOn   =  1,
	QSFlashModeOff  = -1,
} QSFlashMode;

typedef void (^QSCompletionHandler)(BOOL); // the BOOL argument is most probably pointless.

@interface QSCameraController : NSObject <PLCameraControllerDelegate, UIAlertViewDelegate>

// These properties are held on throughout the lifetime of the shared instance
@property(nonatomic, assign) QSCameraDevice cameraDevice;
@property(nonatomic, assign) QSFlashMode flashMode;
@property(nonatomic, assign) BOOL enableHDR;
@property(nonatomic, assign) BOOL waitForFocusCompletion;
 
+ (instancetype)sharedInstance;
// The completion handlers are copied
- (void)takePhotoWithCompletionHandler:(QSCompletionHandler)completionHandler;
- (void)startVideoCaptureWithCompletionHandler:(QSCompletionHandler)videoStartCompletionHandler;
- (void)stopVideoCaptureWithCompletionHandler:(QSCompletionHandler)videoStopCompletionHandler;

@end
