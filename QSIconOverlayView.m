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
    DLog(@"Start");
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
    DLog(@"End");
}

- (void)captureBegan
{
    DLog(@"");
    _irisImageView = [[UIImageView alloc] initWithImage:[self _bundleImageNamed:kIrisImageName]];
    CGPoint center = self.center;
    center.y += 2;
    _irisImageView.center = center;

    _irisImageView.alpha = 0;
    
    [self addSubview:_irisImageView];
    [self _animateIrisViewIn];
}

- (void)captureIsStopping
{
    DLog(@"");
    _shouldBlinkRecordLight = NO;
}

- (void)captureCompletedWithResult:(BOOL)result
{
    DLog(@"");
    NSString *completedImageName = ((result == YES) ? kDoneImageName : kCaptureFailedImageName);
    UIImageView *doneImageView = [[[UIImageView alloc] initWithImage:[self _bundleImageNamed:completedImageName]] autorelease];
    
    CGRect frame = doneImageView.frame;
    frame.origin.x = _irisImageView.bounds.size.width * 0.20;
    frame.origin.y = _irisImageView.bounds.origin.y - 1;
    doneImageView.frame = frame;

    [self _stopBlinkingFocus]; // removes the focus rect from _irisImageView. Won't crash if not in photo mode.
    [self _stopBlinkingRecordLight]; // same, albeit for video

    [_irisImageView addSubview:doneImageView];
    
    QSIconOverlayView __block *wSelf = self;
    // keep the done image on the icon for 1.5 seconds
    double delayInSeconds = 1.5;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [doneImageView removeFromSuperview];
        [wSelf _animateIrisViewOut];
    });

}


- (UIImage *)_bundleImageNamed:(NSString *)imageName
{
    NSString *imagePath = [_bundle pathForResource:imageName ofType:@"png"];
    return [UIImage imageWithContentsOfFile:imagePath];
}

- (void)_animateIrisViewIn
{
    DLog(@"");
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
    DLog(@"");
    CGFloat imageHeight = _irisImageView.image.size.height;
    CGFloat imageWidth = _irisImageView.image.size.width;

    QSIconOverlayView __block *wSelf = self;
    [UIView animateWithDuration:0.4 animations:^{
        CGRect zeroFrame = wSelf->_irisImageView.frame;
        zeroFrame.origin.x += (imageWidth * 0.5);
        zeroFrame.origin.y += (imageHeight * 0.5);
        zeroFrame.size.height = 0;
        zeroFrame.size.width  = 0;

        wSelf->_irisImageView.frame = zeroFrame;
    } completion:^(BOOL finished){
        if (finished && self.animationCompletionHandler) {
            self.animationCompletionHandler();
        }
    }];
}

- (void)_showBlinkingFocus
{
    DLog(@"");
    if (!_focusRectImageView) {
        _focusRectImageView = [[UIImageView alloc] initWithImage:[self _bundleImageNamed:kFocusRectImageName]];
    }
    _focusRectImageView.center = (CGPoint){(_irisImageView.bounds.size.width * 0.5), (_irisImageView.bounds.size.height * 0.5)};
    [_irisImageView addSubview:_focusRectImageView];
    [self _animateFocusRect];
}

- (void)_stopBlinkingFocus
{
    DLog(@"");
    [_focusRectImageView setAlpha:0.0f];
    [_focusRectImageView removeFromSuperview];
}

- (void)_animateFocusRect
{
    DLog(@"");
    // this method is somewhat wonky
    QSIconOverlayView __block *wSelf = self;
    [UIView animateWithDuration:0.07 delay:0.0 options:(UIViewAnimationOptionCurveEaseInOut) animations:^{
        [wSelf->_focusRectImageView setAlpha:1.0f]; 
    } completion:^(BOOL finished) {
        if (finished) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // dispatch_after 0.4 seconds, so that the focus rect remains on screen until then.
                // gives it a nice animation, like the focus rect in the camera app
                [UIView animateWithDuration:0.07 animations:^{
                    [wSelf->_focusRectImageView setAlpha:0.0f];
                } completion:^(BOOL finished){
                    if (finished) {
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            [wSelf _animateFocusRect];
                        });
                    }
                }];
            });
        }
    }];
}

- (void)_showBlinkingRecordLight
{
    DLog(@"");
    _recordingLightImageView = [[UIImageView alloc] initWithImage:[self _bundleImageNamed:kRecordOnImageName]];
    _currentRecordingImageName = kRecordOffImageName; // setting this to off, even though it is on, so that _blinkRecordLight doesn't immediately switch it to the off image.
    
    _recordingLightImageView.frame = CGRectMake(((_irisImageView.bounds.size.width * 0.5) - (_recordingLightImageView.image.size.width * 0.5f) + 0.5),
                                                ((_irisImageView.bounds.size.height * 0.5) - (_recordingLightImageView.image.size.height * 0.5f) + 0.5),
                                                _recordingLightImageView.frame.size.width,
                                                _recordingLightImageView.frame.size.height);

    [_irisImageView addSubview:_recordingLightImageView];
    _shouldBlinkRecordLight = YES;
    [self _blinkRecordLight];
}

- (void)_stopBlinkingRecordLight
{
    DLog(@"");
    [_recordingLightImageView removeFromSuperview];
}

- (void)_blinkRecordLight
{
    DLog(@"");
    if (!_shouldBlinkRecordLight) {
        _recordingLightImageView.image = [self _bundleImageNamed:kRecordOffImageName];
        return;
    }
    QSIconOverlayView __block *wSelf = self;
    _currentRecordingImageName = (([wSelf->_currentRecordingImageName isEqualToString:kRecordOnImageName]) ? kRecordOffImageName : kRecordOnImageName);
    wSelf->_recordingLightImageView.image = [wSelf _bundleImageNamed:wSelf->_currentRecordingImageName];
    EXECUTE_BLOCK_AFTER_DELAY(0.5, ^{
        [wSelf _blinkRecordLight];
    });
}

@end
