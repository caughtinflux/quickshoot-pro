#import "QSIconOverlayView.h"

@interface QSIconOverlayView (Private)

- (UIImage *)_bundleImageNamed:(NSString *)imageName;
- (void)_animateIrisViewIn;
- (void)_animateIrisViewOut;
- (void)_showBlinkingFocus;
- (void)_stopBlinkingFocus;
- (void)_animateFocusRect;

@end

@implementation QSIconOverlayView
{
	NSBundle    *_bundle;
	UIImageView *_irisImageView;
	UIImageView *_focusRectImageView;

	BOOL 		 _isLoading;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		_bundle = [[NSBundle alloc] initWithPath:@"/Library/Application Support/QuickShootPro"];
	}
	return self;
}

- (void)imageCaptureBegan
{
	_irisImageView = [[UIImageView alloc] initWithImage:[self _bundleImageNamed:@"Iris"]];
	CGPoint center = self.center;
	center.y += 2;
	_irisImageView.center = center;

	_irisImageView.alpha = 0;
	
	[self addSubview:_irisImageView];
	[self _animateIrisViewIn];
}

- (void)imageCaptureCompleted
{
	UIImageView *doneImageView = [[[UIImageView alloc] initWithImage:[self _bundleImageNamed:@"Done"]] autorelease];
	CGRect frame = doneImageView.frame;
	frame.origin.x = _irisImageView.bounds.size.width * 0.20;
	frame.origin.y = _irisImageView.bounds.origin.y;
	doneImageView.frame = frame;

	[self _stopBlinkingFocus]; // removes the focus rect from _irisImageView
	[_irisImageView addSubview:doneImageView];

	QSIconOverlayView __block *wSelf = self;
	// keep the done image on the icon for 1.5 seconds
	double delayInSeconds = 1.5;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^{
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
	CGFloat imageHeight = _irisImageView.image.size.height;
	CGFloat imageWidth = _irisImageView.image.size.width;
	
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
			[wSelf _showBlinkingFocus];
		}
	}];
}

- (void)_animateIrisViewOut
{
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
		if (finished && wSelf.animationCompletionHandler) {
			wSelf.animationCompletionHandler();
		}
	}];
}

- (void)_showBlinkingFocus
{
	if (!_focusRectImageView) {
		_focusRectImageView = [[UIImageView alloc] initWithImage:[self _bundleImageNamed:@"Loading"]];
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
	QSIconOverlayView __block *wSelf = self;
	[UIView animateWithDuration:0.3f delay:0.0f options:(UIViewAnimationOptionCurveEaseInOut) animations:^{
		[wSelf->_focusRectImageView setAlpha:1.0f]; 
	} completion:^(BOOL finished) {
		if (finished) {
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				// dispatch_after 0.4 seconds, so that the focus rect remains on screen until then.
				// gives it a nice animation, like the focus rect in the camera app
				[UIView animateWithDuration:0.3f animations:^{
					[wSelf->_focusRectImageView setAlpha:0.0f];
				} completion:^(BOOL finished){
					if (finished)
						[wSelf _animateFocusRect];
				}];
			});
		}
	}];
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

	[super dealloc];
}

@end
