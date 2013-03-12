#import "QSCameraOptionsWindow.h"
#import <PhotoLibrary/PLCameraSettingsView.h>
#import <PhotoLibrary/PLCameraToggleButton.h>
#import <PhotoLibrary/PLCameraFlashButton.h>

#define kLeftSidePadding      5
#define kSettingsViewHeight   100
#define kCameraToggleWidth    60
#define kSmallButtonYDistance kSettingsViewHeight + 3


/*
*	Design Outline.
*	Oh the lulz.
*	
*	*****************
*   * HDR |UISwitch|*
*   *****************
*	
*	*******   *******     
*   | F/R |   |Flash|
*   *******	  *******
*/

@implementation QSCameraOptionsWindow

#pragma mark - Custom Initializer(s)
- (instancetype)initWithFrame:(CGRect)frame showFlash:(BOOL)shouldShowFlash showHDR:(BOOL)shouldShowHDR showCameraToggle:(BOOL)shouldShowCameraToggle
{
	if ((self = [super initWithFrame:frame])) {
		if (shouldShowHDR) {
			PLCameraSettingsView *settingsView = [[[PLCameraSettingsView alloc] initWithFrame:(CGRect){{kLeftSidePadding, 5}, {frame.size.width, kSettingsViewHeight}} showGrid:NO showHDR:YES showPano:NO] autorelease];
			settingsView.delegate = self;
			[self addSubview:settingsView];
		}
		if (shouldShowCameraToggle) {
			PLCameraToggleButton *toggleButton = [[[PLCameraToggleButton alloc] initWithFrame:(CGRect){{kLeftSidePadding, kSmallButtonYDistance}, {20, 20}} isInButtonBar:NO] autorelease];
			[self addSubview:toggleButton];
		}
		if (shouldShowFlash) {
			PLCameraFlashButton *flashButton =  [[[PLCameraFlashButton alloc] initWithFrame:(CGRect){{kCameraToggleWidth + 5,  kSmallButtonYDistance}, {20, 20}} isInButtonBar:NO] autorelease];
			flashButton.delegate = self;
			[self addSubview:flashButton];
		}
	}
	return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	return [self initWithFrame:frame showFlash:YES showHDR:YES showCameraToggle:YES];
}

@end
