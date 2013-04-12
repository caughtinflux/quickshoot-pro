/*
*       ____        _      __   _____ __                __  ____           
*      / __ \__  __(_)____/ /__/ ___// /_  ____  ____  / /_/ __ \_________ 
*     / / / / / / / / ___/ //_/\__ \/ __ \/ __ \/ __ \/ __/ /_/ / ___/ __ \
*    / /_/ / /_/ / / /__/ ,<  ___/ / / / / /_/ / /_/ / /_/ ____/ /  / /_/ /
*    \___\_\__,_/_/\___/_/|_|/____/_/ /_/\____/\____/\__/_/   /_/   \____/ 
*                                                                          
*   QSCameraController.h
*   © 2013 Aditya KD
*/

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <PhotoLibrary/PLCameraControllerDelegate-Protocol.h>

#import "QSVideoInterface.h"
#import "QSConstants.h"

@interface QSCameraController : NSObject <PLCameraControllerDelegate, QSVideoInterfaceDelegate>

@property(nonatomic, assign) QSCameraDevice cameraDevice;
@property(nonatomic, assign) QSFlashMode flashMode;
@property(nonatomic, assign) BOOL enableHDR;

// Setting this property to yes causes the controller to wait for up to 5 seconds for focusing to complete before taking a photo
@property(nonatomic, assign) BOOL waitForFocusCompletion;
// Automatically set every time the orientation changes, but you can force a different orientation, provided it doesn't change after you've forced it.
@property(nonatomic, assign) UIDeviceOrientation currentOrientation;

@property(nonatomic, readonly, getter = isCapturingVideo) BOOL capturingVideo;
@property(nonatomic, readonly, getter = isCapturingImage) BOOL capturingImage;

@property(nonatomic, assign) BOOL playShutterSound;

// video properties
@property(nonatomic, copy) NSString *videoCaptureQuality;
@property(nonatomic, assign) QSFlashMode videoFlashMode;
 
+ (instancetype)sharedInstance;

// The completion handlers are copied. They are, however, destroyed after being called, so no need to worry about retain loops
- (void)takePhotoWithCompletionHandler:(QSCompletionHandler)completionHandler;

// Pass in an interruption handler. Seriously. You don't want to never get a callback of this.
// All these methods will work if you pass in nil as the handler. Do you if you don't care what happens
- (void)startVideoCaptureWithHandler:(QSCompletionHandler)handler interruptionHandler:(QSCompletionHandler)interruptionHandler;
- (void)stopVideoCaptureWithHandler:(QSCompletionHandler)handler;

@end
