/*
*       ____        _      __   _____ __                __  ____           
*      / __ \__  __(_)____/ /__/ ___// /_  ____  ____  / /_/ __ \_________ 
*     / / / / / / / / ___/ //_/\__ \/ __ \/ __ \/ __ \/ __/ /_/ / ___/ __ \
*    / /_/ / /_/ / / /__/ ,<  ___/ / / / / /_/ / /_/ / /_/ ____/ /  / /_/ /
*    \___\_\__,_/_/\___/_/|_|/____/_/ /_/\____/\____/\__/_/   /_/   \____/ 
*                                                                          
*   QSVideoInterface.h
*   © 2013 Aditya KD
*/

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
@optional
/*
*	These callbacks aren't guaranteed to be on the main queue
*	It is up to the object that implements these to make sure the current queue/thread is used.
*	If UI shit is done, make sure it is on the main thread.
*/
- (void)videoInterfaceStartedVideoCapture:(QSVideoInterface *)interface;
- (void)videoInterface:(QSVideoInterface *)videoInterface didFinishRecordingToURL:(NSURL *)filePathURL withError:(NSError *)error;
- (void)videoInterfaceCaptureDeviceErrorOccurred:(QSVideoInterface *)interface;
- (void)videoInterfaceCaptureInputErrorOccurred:(QSVideoInterface *)interface;
- (void)videoInterfaceFileOutputErrorOccurred:(QSVideoInterface *)interface;
@end
