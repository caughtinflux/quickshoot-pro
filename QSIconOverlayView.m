/*
*       ____        _      __   _____ __                __  ____           
*      / __ \__  __(_)____/ /__/ ___// /_  ____  ____  / /_/ __ \_________ 
*     / / / / / / / / ___/ //_/\__ \/ __ \/ __ \/ __ \/ __/ /_/ / ___/ __ \
*    / /_/ / /_/ / / /__/ ,<  ___/ / / / / /_/ / /_/ / /_/ ____/ /  / /_/ /
*    \___\_\__,_/_/\___/_/|_|/____/_/ /_/\____/\____/\__/_/   /_/   \____/ 
*                                                                          
*   QSIconOverlayView.m
*   © 2013 Aditya KD
*/

#import "QSIconOverlayView.h"
#import "QSConstants.h"

#define kDoneImageName           @"Done"
#define kIrisImageName           @"Iris"
#define kFocusRectImageName      @"Loading"
#define kCaptureFailedImageName  @"LoadngFailed"
#define kRecordOffImageName      @"LoadingRecordOff"
#define kRecordOnImageName       @"LoadingRecordOn"

@interface QSIconOverlayView ()
{
    NSBundle      *_bundle;
    UIImageView   *_irisImageView;
    UIImageView   *_focusRectImageView;
    
    UIImageView   *_recordingLightImageView;
    NSString      *_currentRecordingImageName;
    QSCaptureMode  _currentCaptureMode;

    BOOL           _shouldBlinkRecordLight;
}

- (UIImage *)_bundleImageNamed:(NSString *)imageName;

- (void)_animateIrisViewIn;
- (void)_animateIrisViewOut;
- (void)_showBlinkingFocus;
- (void)_stopBlinkingFocus;
- (void)_animateFocusRect;

- (void)_showBlinkingRecordLight;
- (void)_stopBlinkingRecordLight;
- (void)_blinkRecordLight;

@end

@implementation QSIconOverlayView
- (instancetype)initWithFrame:(CGRect)frame captureMode:(QSCaptureMode)captureMode
{
    if ((self = [super initWithFrame:frame])) {
        _bundle = [[NSBundle alloc] initWithPath:@"/Library/Application Support/QuickShootPro"];
        _currentCaptureMode = captureMode;
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame captureMode:QSCaptureModePhoto];
}

- (void)dealloc
{
    [_animationCompletionHandler release];
    _animationCompletionHandler = nil;
    
    [_bundle release];
    _bundle = nil;

    [_irisImageView release];
    _irisImageView = nil;

    [_focusRectImageView release];
    _focusRectImageView = nil;

    [_recordingLightImageView release];
    _recordingLightImageView = nil;

    [super dealloc];
}

- (void)captureBegan
{
    _irisImageView = [[UIImageView alloc] initWithImage:[self _bundleImageNamed:kIrisImageName]];
    // CGPoint center = self.center;
    // center.y += 2;
    _irisImageView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                       UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
    _irisImageView.center = (CGPoint){(self.bounds.size.width * 0.5)+1, (self.bounds.size.height * 0.5)};
    _irisImageView.alpha = 0;
    
    [self addSubview:_irisImageView];
    [self _animateIrisViewIn];
}

- (void)captureIsStopping
{
    _shouldBlinkRecordLight = NO;
}

- (void)captureCompletedWithResult:(BOOL)result
{
    NSString *completedImageName = ((result == YES) ? kDoneImageName : kCaptureFailedImageName);
    UIImageView *doneImageView = [[[UIImageView alloc] initWithImage:[self _bundleImageNamed:completedImageName]] autorelease];
    
    CGRect frame = doneImageView.frame;
    frame.origin.x = _irisImageView.bounds.size.width * 0.20;
    frame.origin.y = _irisImageView.bounds.origin.y - 1;
    doneImageView.frame = frame;

    [self _stopBlinkingFocus]; // removes the focus rect from _irisImageView. Won't crash if not in photo mode.
    [self _stopBlinkingRecordLight]; // same, albeit for video

    [_irisImageView addSubview:doneImageView];
    
    // keep the done image on the icon for 1.5 seconds
    EXECUTE_BLOCK_AFTER_DELAY(1.5, ^{
        [doneImageView removeFromSuperview];
        [self _animateIrisViewOut];
    });

}


- (UIImage *)_bundleImageNamed:(NSString *)imageName
{
    NSString *imagePath = [_bundle pathForResource:imageName ofType:@"png"];
    return [UIImage imageWithContentsOfFile:imagePath];
}

- (void)_animateIrisViewIn
{
    CGFloat imageHeight = _irisImageView.image.size.height;
    CGFloat imageWidth  = _irisImageView.image.size.width;
    
    CGRect zeroFrame = _irisImageView.frame;
    zeroFrame.origin.x += (imageWidth / 2.0);
    zeroFrame.origin.y += (imageHeight / 2.0);
    zeroFrame.size.height = 0;
    zeroFrame.size.width  = 0;

    _irisImageView.frame = zeroFrame;
    _irisImageView.alpha = 1.0f;
    // make the view a small point, after adjusting the origin, and make it opaque.

    QSIconOverlayView __block *wSelf = self;
    [UIView animateWithDuration:0.3 animations:^{
        CGRect newFrame = wSelf->_irisImageView.frame;
        
        newFrame.size.height = imageHeight;
        newFrame.size.width = imageWidth;
        newFrame.origin.x -= (imageWidth * 0.5);
        newFrame.origin.y -= (imageHeight * 0.5);
        // circularly animate the iris view to its original rect.
        _irisImageView.frame = newFrame;
    } completion:^(BOOL finished){
        if (finished) {
            if (_currentCaptureMode == QSCaptureModePhoto) {
                [wSelf _showBlinkingFocus];
            }
            else {
                [wSelf _showBlinkingRecordLight];
            }
        }
    }];
}

- (void)_animateIrisViewOut
{
    CGFloat imageHeight = _irisImageView.image.size.height;
    CGFloat imageWidth = _irisImageView.image.size.width;

    [UIView animateWithDuration:0.4 animations:^{
        CGRect zeroFrame = _irisImageView.frame;
        zeroFrame.origin.x += (imageWidth * 0.5);
        zeroFrame.origin.y += (imageHeight * 0.5);
        zeroFrame.size.height = 0;
        zeroFrame.size.width  = 0;

        _irisImageView.frame = zeroFrame;
    } completion:^(BOOL finished){
        if (finished && self.animationCompletionHandler) {
            self.animationCompletionHandler();
        }
    }];
}

- (void)_showBlinkingFocus
{
    if (!_focusRectImageView) {
        _focusRectImageView = [[UIImageView alloc] initWithImage:[self _bundleImageNamed:kFocusRectImageName]];
    }
    _focusRectImageView.center = (CGPoint){(_irisImageView.bounds.size.width * 0.5), (_irisImageView.bounds.size.height * 0.5)};
    [_irisImageView addSubview:_focusRectImageView];
    [self _animateFocusRect];
}

- (void)_stopBlinkingFocus
{
    [_focusRectImageView setAlpha:0.0f];
    [_focusRectImageView removeFromSuperview];
}

- (void)_animateFocusRect
{
    // this method is somewhat wonky
    [UIView animateWithDuration:0.07 delay:0.0 options:(UIViewAnimationOptionCurveEaseInOut) animations:^{
        [_focusRectImageView setAlpha:1.0f]; 
    } completion:^(BOOL finished) {
        if (finished) {
            EXECUTE_BLOCK_AFTER_DELAY(0.4, ^{
                // dispatch_after 0.4 seconds, so that the focus rect remains on screen until then.
                // gives it a nice animation, like the focus rect in the camera app
                // Using UIView animation options to auto reverse makes it look like shit.
                // So...dispatch_after FTW!
                [UIView animateWithDuration:0.07 animations:^{
                    [_focusRectImageView setAlpha:0.0f];
                } completion:^(BOOL finished){
                    if (finished) {
                        EXECUTE_BLOCK_AFTER_DELAY(0.2, ^{
                            [self _animateFocusRect];
                        });
                    }
                }];
            });
        }
    }];
}

- (void)_showBlinkingRecordLight
{
    _recordingLightImageView = [[UIImageView alloc] initWithImage:[self _bundleImageNamed:kRecordOnImageName]];
    _currentRecordingImageName = kRecordOffImageName; // setting this to off, even though it is on, so that -[QSIconOverlayView _blinkRecordLight] doesn't immediately switch it to the off image.
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        _recordingLightImageView.frame = CGRectMake(((_irisImageView.bounds.size.width * 0.5) - (_recordingLightImageView.image.size.width * 0.5f) + 0.5),
                                                    ((_irisImageView.bounds.size.height * 0.5) - (_recordingLightImageView.image.size.height * 0.5f) + 0.9),
                                                    _recordingLightImageView.frame.size.width,
                                                    _recordingLightImageView.frame.size.height);
    }
    else {
       _recordingLightImageView.center = (CGPoint){_irisImageView.bounds.size.width * 0.5, _irisImageView.bounds.size.height * 0.5};
    }
    _recordingLightImageView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                                 UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);

    [_irisImageView addSubview:_recordingLightImageView];
    _shouldBlinkRecordLight = YES;
    [self _blinkRecordLight];
}

- (void)_stopBlinkingRecordLight
{
    [_recordingLightImageView removeFromSuperview];
}

- (void)_blinkRecordLight
{
    if (!_shouldBlinkRecordLight) {
        _recordingLightImageView.image = [self _bundleImageNamed:kRecordOffImageName];
        return;
    }
    _currentRecordingImageName = (([_currentRecordingImageName isEqualToString:kRecordOnImageName]) ? kRecordOffImageName : kRecordOnImageName);
    _recordingLightImageView.image = [self _bundleImageNamed:_currentRecordingImageName];
    EXECUTE_BLOCK_AFTER_DELAY(0.5, ^{
        [self _blinkRecordLight];
    });
}

@end
