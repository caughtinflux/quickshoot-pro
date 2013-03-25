#import <UIKit/UIKit.h>

typedef void (^QSAnimationCompletionHandler)(void);

@interface QSIconOverlayView : UIView

@property (nonatomic, copy) QSAnimationCompletionHandler animationCompletionHandler;

- (void)captureBegan;
- (void)captureCompleted;

@end
