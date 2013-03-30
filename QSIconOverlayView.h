#import <UIKit/UIKit.h>

typedef void (^QSAnimationCompletionHandler)(void);

typedef enum {
	QSCaptureModePhoto,
	QSCaptureModeVideo
} QSCaptureMode;

@interface QSIconOverlayView : UIView

// The completion handler is destroyed when this view is dealloc'd. It is called _after_ all the animations are done, and the iris is animated out.
@property (nonatomic, copy) QSAnimationCompletionHandler animationCompletionHandler;

// Default capture mode is photo.
- (instancetype)initWithFrame:(CGRect)frame captureMode:(QSCaptureMode)captureMode;
- (void)captureBegan;

// result is used to display the corresponding image on the overlay view (done/error)
- (void)captureCompletedWithResult:(BOOL)result;

// Call capture is stopping for video recording to stop the recording light from blinking.
- (void)captureIsStopping;

@end
