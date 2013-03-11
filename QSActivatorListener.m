#import "QSActivatorListener.h"
#import "QSCameraController.h"

/*
*	This is a separate class, for I do not want to clutter QSCameraController with activator's shit
*
*
*/
@implementation QSActivatorListener

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	[[QSCameraController sharedInstance] takePhotoWithCompletionHandler:^(BOOL success) {
		;// do nothing
	}];
	[event setHandled:YES];
}

+ (void)load
{
	@autoreleasepool {
    	[[LAActivator sharedInstance] registerListener:[self new] forName:@"com.caughtinflux.quickshootpro.listener"];
    }
}

@end