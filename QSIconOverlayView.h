/*
*       ____        _      __   _____ __                __  ____           
*      / __ \__  __(_)____/ /__/ ___// /_  ____  ____  / /_/ __ \_________ 
*     / / / / / / / / ___/ //_/\__ \/ __ \/ __ \/ __ \/ __/ /_/ / ___/ __ \
*    / /_/ / /_/ / / /__/ ,<  ___/ / / / / /_/ / /_/ / /_/ ____/ /  / /_/ /
*    \___\_\__,_/_/\___/_/|_|/____/_/ /_/\____/\____/\__/_/   /_/   \____/ 
*                                                                          
*   QSIconOverlayView.h
*   © 2013 Aditya KD
*/

#import <UIKit/UIKit.h>

typedef void (^QSAnimationCompletionHandler)(void);

typedef enum {
	QSCaptureModePhoto,
	QSCaptureModeVideo
} QSCaptureMode;

@interface QSIconOverlayView : UIView

// The completion handler is destroyed when this view is deallocated. It is called _after_ all the animations are done, and the iris is animated out.
// Use only weak references to the view, or nil out the block when you're done using it
@property (nonatomic, copy) QSAnimationCompletionHandler animationCompletionHandler;

// Default capture mode is photo.
- (instancetype)initWithFrame:(CGRect)frame captureMode:(QSCaptureMode)captureMode;
- (void)captureBegan;

// result is used to display the corresponding image on the overlay view (done/error)
- (void)captureCompletedWithResult:(BOOL)result;

// Call capture is stopping for video recording to stop the recording light from blinking.
- (void)captureIsStopping;

@end
