#import "QSCameraController.h"

#import <UIKit/UIKit.h>

#import <SpringBoard/SBIconView.h>
#import <SpringBoard/SBIcon.h>

@interface SBAwayController : NSObject
+ (SBAwayController *)sharedAwayController;
@end


%hook SBIconView
- (void)setIcon:(SBIcon *)icon
{
	%orig;
	if ([[(SBIcon *)icon leafIdentifier] isEqualToString:@"com.apple.camera"]) {
		UITapGestureRecognizer *doubleTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(qs_doubleTapRecognizerFired:)];
		doubleTapGR.numberOfTapsRequired = 2;
		[(SBIconView *)self addGestureRecognizer:doubleTapGR];
		[doubleTapGR release];
		[(SBIconView *)self setUserInteractionEnabled:YES];
	}
}

%new
- (void)qs_doubleTapRecognizerFired:(UITapGestureRecognizer *)dtr
{
	[(SBIcon *)[self icon] setBadge:@"•••"];
	[(SBIcon *)[self icon] noteBadgeDidChange];
	[[QSCameraController sharedInstance] takePhotoWithCompletionHandler:^(BOOL success){
		[(SBIcon *)[self icon] setBadge:nil];
		[(SBIcon *)[self icon] noteBadgeDidChange];
		return;
	}];
}
%end


// Camera Grabber Hooks
%hook UITapGestureRecognizer
- (UITapGestureRecognizer *)initWithTarget:(id)target action:(SEL)action
{
	self = %orig;
	if (self && (target == [%c(SBAwayController) sharedAwayController]) && (action == @selector(handleCameraTapGesture:))) {
		[(UITapGestureRecognizer *)self setNumberOfTapsRequired:2];
	}
	return self;
}
%end

%hook SBAwayLockBar
- (void)setShowsSlideShowButton:(BOOL)shouldShow
{
	%orig;
	if (shouldShow) {
		UIButton *slideshowButton = MSHookIvar<UIButton *>(self, "_slideshowButton");

		UITapGestureRecognizer *doubleTapGR = [[UITapGestureRecognizer alloc] initWithTarget:[%c(SBAwayController) sharedAwayController] action:@selector(handleCameraTapGesture:)];
		doubleTapGR.numberOfTapsRequired = 2;
		[slideshowButton addGestureRecognizer:doubleTapGR];
		[doubleTapGR release];
	}
}
%end

%hook SBAwayController
- (void)handleCameraTapGesture:(UITapGestureRecognizer *)recognizer
{
	if (recognizer.numberOfTouchesRequired == 2) {
		[[QSCameraController sharedInstance] takePhotoWithCompletionHandler:^(BOOL success){
			;
		}];
	}
}
%end