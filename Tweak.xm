#import "QSCameraController.h"

#import <UIKit/UIKit.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SBIconViewMap.h>
#import <SpringBoard/SBIconView.h>
#import <SpringBoard/SBApplicationIcon.h>


%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)app
{
	%orig;
	SBIconModel *iconModel = (SBIconModel *)[[%c(SBIconController) sharedInstance] model];
	SBApplicationIcon *cameraAppIcon = [iconModel leafIconForIdentifier:@"com.apple.camera"];
	SBIconView *cameraIconView = [[%c(SBIconViewMap) homescreenMap] iconViewForIcon:cameraAppIcon];

	UITapGestureRecognizer *doubleTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(qs_doubleTapRecognizerFired:)];
	doubleTapGR.numberOfTapsRequired = 2;
	[cameraIconView addGestureRecognizer:doubleTapGR];
	[doubleTapGR release];
	[cameraIconView setUserInteractionEnabled:YES];
}

%new
- (void)qs_doubleTapRecognizerFired:(UITapGestureRecognizer *)dtr
{
	[[QSCameraController sharedInstance] takePhotoWithCompletionHandler:^(BOOL success){
		// empty, for nothing has to be done here.
		// leaving it in, for maybe I will need it in the future!
		return;
	}];
}

%end
