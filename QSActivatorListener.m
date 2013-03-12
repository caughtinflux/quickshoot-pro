#import "QSActivatorListener.h"
#import "QSCameraController.h"

/*
*	This is a separate class, for I do not want to clutter QSCameraController with activator's shit
*/
@implementation QSActivatorListener

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	[[QSCameraController sharedInstance] takePhotoWithCompletionHandler:^(BOOL success) {
		;// do nothing
	}];
	[event setHandled:YES];
}

@end