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


// Hooks for the lockscreen bit.
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

%hook SBAwayController
- (void)handleCameraTapGesture:(UITapGestureRecognizer *)tapGesture
{
	[[QSCameraController sharedInstance] takePhotoWithCompletionHandler:^(BOOL success){
		return;
	}];
}
%end