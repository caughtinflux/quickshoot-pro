#import <UIKit/UIKit.h>

typedef void (^QSAnimationCompletionHandler)(void);

@interface QSIconOverlayView : UIView

@property (nonatomic, copy) QSAnimationCompletionHandler animationCompletionHandler;

- (void)imageCaptureBegan;
- (void)imageCaptureCompleted;

@end
