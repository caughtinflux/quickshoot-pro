#import "QSCameraOptionsWindow.h"
#import <PhotoLibrary/PLCameraSettingsView.h>
#import <PhotoLibrary/PLCameraToggleButton.h>
#import <PhotoLibrary/PLCameraFlashButton.h>

#define kLeftSidePadding      5
#define kSettingsViewHeight   50
#define kSettingsViewWidth    190
#define kFlashButtonWidth     70
#define kCameraToggleWidth    kFlashButtonWidth
#define kSmallButtonYDistance kSettingsViewHeight + 15


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
{
	PLCameraToggleButton *_toggleButton;
}
@synthesize delegate = _optionsDelegate;

#pragma mark - Custom Initializer(s)
- (instancetype)initWithFrame:(CGRect)frame showFlash:(BOOL)shouldShowFlash showHDR:(BOOL)shouldShowHDR showCameraToggle:(BOOL)shouldShowCameraToggle
{
	if ((self = [super initWithFrame:frame])) {
		if (shouldShowHDR) {
			PLCameraSettingsView *settingsView = [[[PLCameraSettingsView alloc] initWithFrame:(CGRect){{kLeftSidePadding, 5}, {kSettingsViewWidth, kSettingsViewHeight}} showGrid:NO showHDR:YES showPano:NO] autorelease];
			settingsView.delegate = self;
			[self addSubview:settingsView];
		}
		if (shouldShowFlash) {
			PLCameraFlashButton *flashButton =  [[[PLCameraFlashButton alloc] initWithFrame:(CGRect){{kLeftSidePadding,  kSmallButtonYDistance}, {kFlashButtonWidth, 20}} isInButtonBar:NO] autorelease];
			flashButton.autorotationEnabled = YES;
			flashButton.delegate = self;
			[self addSubview:flashButton];
		}
		if (shouldShowCameraToggle) {
			_toggleButton = [[PLCameraToggleButton alloc] initWithFrame:(CGRect){{kFlashButtonWidth + 18, kSmallButtonYDistance}, {kCameraToggleWidth, 20}} isInButtonBar:NO];
			_toggleButton.autorotationEnabled = YES;
			[_toggleButton addTarget:self action:@selector(cameraToggleButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
			[self addSubview:_toggleButton];
		}
	}
	return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	return [self initWithFrame:frame showFlash:YES showHDR:YES showCameraToggle:YES];
}


#pragma mark - Camera Button Target
- (void)cameraToggleButtonTapped:(PLCameraToggleButton *)toggleButton
{
	if ([self.delegate conformsToProtocol:@protocol(QSCameraOptionsWindowDelegate)]) {
		[self.delegate optionsWindowCameraButtonToggled:self];
	}
}


#pragma mark - SettingsView Delegate
- (void)shouldEnterPanorama
{

}

- (void)gridSettingDidChange:(BOOL)newSetting
{

}

- (void)HDRSettingDidChange:(BOOL)newSetting
{
	if ([self.delegate conformsToProtocol:@protocol(QSCameraOptionsWindowDelegate)]) {
		[self.delegate optionsWindow:self hdrModeChanged:newSetting];
	}
}


#pragma mark - Flash Button Delegate
- (void)flashButtonDidCollapse:(PLCameraFlashButton *)button
{
	[_toggleButton setHidden:NO animationDuration:0.5];
}

- (void)flashButtonWillExpand:(PLCameraFlashButton *)button
{
	[_toggleButton setHidden:YES animationDuration:0.5];
}

- (void)flashButtonWasPressed:(PLCameraFlashButton *)button
{

}

- (void)flashButtonModeDidChange:(PLCameraFlashButton *)button
{
	if ([self.delegate conformsToProtocol:@protocol(QSCameraOptionsWindowDelegate)]) {
		[self.delegate optionsWindow:self flashModeChanged:(QSFlashMode)button.flashMode];
	}
}

- (void)dealloc
{
	[_toggleButton release];
	_toggleButton = nil;

	[super dealloc];
}
@end
