#import "QSIconOverlayView.h"

@interface QSIconOverlayView (Private)

- (UIImage *)_bundleImageNamed:(NSString *)imageName;
- (void)_animateIrisViewIn;
- (void)_animateIrisViewOut;
- (void)_showBlinkingFocus;
- (void)_stopBlinkingFocus;

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
	
	CGPoint center = self.center;
	center.y -= 10;
	doneImageView.center = center;

	[self _stopBlinkingFocus]; // removes the focus rect from _irisImageView
	[_irisImageView addSubview:doneImageView];

	QSIconOverlayView __block *wSelf = self;

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
		newFrame.origin.x -= (imageWidth / 2.0);
		newFrame.origin.y -= (imageHeight / 2.0);
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
		zeroFrame.origin.x += (imageWidth / 2.0);
		zeroFrame.origin.y += (imageHeight / 2.0);
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
	[_irisImageView addSubview:_focusRectImageView];
	CGPoint center = self.center;
	center.x -= 5;
	center.y -= 5;
	_focusRectImageView.center = center;

	QSIconOverlayView __block *wSelf = self;
	[UIView animateWithDuration:0.4f delay:0.0f options:(UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionRepeat |  UIViewAnimationOptionAutoreverse) animations:^{
		[wSelf->_focusRectImageView setAlpha:0.0f];
	} completion:^(BOOL finished) {
		;
	}];
}

- (void)_stopBlinkingFocus
{
	[_focusRectImageView setAlpha:0.0f];
	[_focusRectImageView removeFromSuperview];
}

- (void)dealloc
{
	[_bundle release];
	_bundle = nil;

	[_irisImageView release];
	_irisImageView = nil;

	[_focusRectImageView release];
	_focusRectImageView = nil;

	[super dealloc];
}

@end
