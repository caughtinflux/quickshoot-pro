#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "QSConstants.h"

@protocol QSVideoInterfaceDelegate;

@interface QSVideoInterface : NSObject <AVCaptureFileOutputRecordingDelegate>

/*
	The value of this property is an NSString (one of AVCaptureSessionPreset*).
	If the given preset cannot be set, AVCaptureSessionPresetMedium will be set
 */
@property(nonatomic, copy) NSString *videoQuality;

@property(nonatomic, assign) AVCaptureDevicePosition devicePosition;
@property(nonatomic, assign) AVCaptureTorchMode torchMode;
@property(nonatomic, assign) id<QSVideoInterfaceDelegate> delegate;

- (void)startVideoCapture;
- (void)stopVideoCapture;
- (void)setTorchModeFromFlashMode:(QSFlashMode)flashMode;

@end

@protocol QSVideoInterfaceDelegate <NSObject>
/*
*	These callbacks aren't guaranteed to be on the main queue
*	It is up to the object that implements these to make sure the current queue/thread is used.
*	If UI shit is done, make sure it is on the main thread.
*/
@optional
- (void)videoInterfaceStartedVideoCapture:(QSVideoInterface *)interface;
- (void)videoInterface:(QSVideoInterface *)videoInterface didFinishRecordingToURL:(NSURL *)filePathURL withError:(NSError *)error;
- (void)videoInterfaceCaptureDeviceErrorOccurred:(QSVideoInterface *)interface;
- (void)videoInterfaceCaptureInputErrorOccurred:(QSVideoInterface *)interface;
- (void)videoInterfaceFileOutputErrorOccurred:(QSVideoInterface *)interface;

// session callbacks
- (void)videoInterfaceSessionRuntimeErrorOccurred:(QSVideoInterface *)videoInterface;
- (void)videoInterfaceSessionDidStop:(QSVideoInterface *)videoInterface;
- (void)videoInterfaceSessionWasInterrupted:(QSVideoInterface *)videoInterface;
- (void)videoInterfaceSessionInterruptionEnded:(QSVideoInterface *)videoInterface;

@end
