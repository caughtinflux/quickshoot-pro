#import <UIKit/UIKit.h>

typedef void (^QSAnimationCompletionHandler)(void);

typedef enum {
	QSCaptureModePhoto,
	QSCaptureModeVideo
} QSCaptureMode;

@interface QSIconOverlayView : UIView

@property (nonatomic, copy) QSAnimationCompletionHandler animationCompletionHandler;

// Default capture mode is photo.
- (instancetype)initWithFrame:(CGRect)frame captureMode:(QSCaptureMode)captureMode;
- (void)captureBegan;
- (void)captureCompleted;
- (void)captureIsStopping;

@end
