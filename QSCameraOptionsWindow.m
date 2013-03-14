#import "QSCameraOptionsWindow.h"
#import <PhotoLibrary/PLCameraSettingsView.h>
#import <PhotoLibrary/PLCameraToggleButton.h>
#import <PhotoLibrary/PLCameraFlashButton.h>
#import <PhotoLibrary/PLCameraController.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - View Placement Constants
#define kLeftSidePadding      5
#define kSettingsViewHeight   45
#define kSettingsViewWidth    190
#define kFlashButtonWidth     70
#define kCameraToggleWidth    kFlashButtonWidth
#define kSmallButtonYDistance kSettingsViewHeight + 15

@interface QSCameraOptionsWindow () {}
- (void)_flashCameraTypeLabelWithFadeIn:(BOOL)shouldFadeIn;
- (void)_restartHideTimer;
- (void)_hideTimerFired:(NSTimer *)timer;
@end

@implementation QSCameraOptionsWindow
{
    PLCameraToggleButton *_toggleButton;
    PLCameraFlashButton  *_flashButton;
    NSTimer              *_hideTimer;
}
@synthesize delegate = _optionsDelegate; // since UIWindow has _delegate already. Bah.

#pragma mark - Custom Initializer(s)
- (instancetype)initWithFrame:(CGRect)frame showFlash:(BOOL)shouldShowFlash showHDR:(BOOL)shouldShowHDR showCameraToggle:(BOOL)shouldShowCameraToggle
{
    DLog(@"");
    if ((self = [super initWithFrame:frame])) {
        if (shouldShowHDR) {
            PLCameraSettingsView *settingsView = [[[PLCameraSettingsView alloc] initWithFrame:(CGRect){{kLeftSidePadding, 5}, {kSettingsViewWidth, kSettingsViewHeight}} showGrid:NO showHDR:YES showPano:NO] autorelease];
            settingsView.delegate = self;
            [self addSubview:settingsView];
        }
        if (shouldShowFlash) {
            _flashButton = [[PLCameraFlashButton alloc] initWithFrame:(CGRect){{kLeftSidePadding,  kSmallButtonYDistance}, {kFlashButtonWidth, 20}} isInButtonBar:NO];
            
            if ([[PLCameraController sharedInstance] hasFlash]) {
                _flashButton.flashMode = QSFlashModeFromString(([NSDictionary dictionaryWithContentsOfFile:kPrefPath][QSFlashModeKey]));
            }
            else {
                _flashButton.showWarningIndicator = YES;
            }

            _flashButton.autorotationEnabled = YES;
            [_flashButton startWatchingDeviceOrientationChanges];
            
            _flashButton.delegate = self;
            [self addSubview:_flashButton];
        }
        if (shouldShowCameraToggle) {
            _toggleButton = [[PLCameraToggleButton alloc] initWithFrame:(CGRect){{kFlashButtonWidth + 25, kSmallButtonYDistance}, {kCameraToggleWidth, 20}} isInButtonBar:NO];
            _toggleButton.autorotationEnabled = YES;
            [_toggleButton startWatchingDeviceOrientationChanges];
            [_toggleButton addTarget:self action:@selector(cameraToggleButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:_toggleButton];
        }
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    DLog(@"");
    return [self initWithFrame:frame showFlash:YES showHDR:YES showCameraToggle:YES];
}

- (void)setFlashMode:(QSFlashMode)flashMode
{
    DLog(@"flashMode: %i", flashMode);
    _flashButton.flashMode = flashMode;
}

- (void)setHidden:(BOOL)shouldHide
{
    [super setHidden:shouldHide];
    if (!shouldHide) {
        self.alpha = 1.0f;
        [self _restartHideTimer];
        if ([self.delegate conformsToProtocol:@protocol(QSCameraOptionsWindowDelegate)]) {
            [self _flashCameraTypeLabelWithFadeIn:NO];
        }
    }
    else if ([_hideTimer isValid]) {
        [_hideTimer invalidate];
        _hideTimer = nil;
    }
}

- (NSTimeInterval)automaticHideDelay
{
    DLog(@"");
    if (!_automaticHideDelay > 0) {
        _automaticHideDelay = 8.0; //set a default 10 second delay.
    }
    return _automaticHideDelay;
}

- (void)hideWindowAnimated
{
    [UIView animateWithDuration:0.5 animations:^{
        self.alpha = 0.0f;
    } completion:^(BOOL finished) {
        if (finished)
            self.hidden = YES;
    }];
}

#pragma mark - Camera Button Target
- (void)cameraToggleButtonTapped:(PLCameraToggleButton *)toggleButton
{
    DLog(@"");
    [self _restartHideTimer];
    if ([self.delegate conformsToProtocol:@protocol(QSCameraOptionsWindowDelegate)]) {
        [self.delegate optionsWindowCameraButtonToggled:self];
        [self _flashCameraTypeLabelWithFadeIn:YES];
    }
}

#pragma mark - SettingsView Delegate
- (void)shouldEnterPanorama {} // stubs, don't want crashes because they aren't responded to.
- (void)gridSettingDidChange:(BOOL)newSetting {}

- (void)HDRSettingDidChange:(BOOL)newSetting
{
    DLog(@"");
    if ([self.delegate conformsToProtocol:@protocol(QSCameraOptionsWindowDelegate)]) {
        [self.delegate optionsWindow:self hdrModeChanged:newSetting];
    }
}

#pragma mark - Flash Button Delegate
- (void)flashButtonDidCollapse:(PLCameraFlashButton *)button
{
    DLog(@"");
    [_toggleButton setHidden:NO animationDuration:0.8];
}

- (void)flashButtonWillExpand:(PLCameraFlashButton *)button
{
    DLog(@"");
    [_toggleButton setHidden:YES animationDuration:0.5];
}

- (void)flashButtonWasPressed:(PLCameraFlashButton *)button
{
    DLog(@"");
    [self _restartHideTimer];
}

- (void)flashButtonModeDidChange:(PLCameraFlashButton *)button
{
    DLog(@"");
    if ([self.delegate conformsToProtocol:@protocol(QSCameraOptionsWindowDelegate)]) {
        [self.delegate optionsWindow:self flashModeChanged:(QSFlashMode)button.flashMode];
    }
}

#pragma mark - Private Methods
- (void)_flashCameraTypeLabelWithFadeIn:(BOOL)shouldFadeIn
{
    UILabel *cameraModeChangedLabel = [[[UILabel alloc] initWithFrame:(CGRect){{kLeftSidePadding, kSmallButtonYDistance + 40}, {kFlashButtonWidth * 2.2, kSettingsViewHeight - 10}}] autorelease];
    cameraModeChangedLabel.backgroundColor = [UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:0.70f];
    cameraModeChangedLabel.layer.cornerRadius = 7.f;
    cameraModeChangedLabel.layer.masksToBounds = YES;
    cameraModeChangedLabel.layer.borderColor = [UIColor blackColor].CGColor;
    cameraModeChangedLabel.layer.borderWidth = 1.0f;

    cameraModeChangedLabel.textColor = [UIColor blackColor];
    cameraModeChangedLabel.font = [UIFont boldSystemFontOfSize:15];
    cameraModeChangedLabel.textAlignment = NSTextAlignmentCenter;
    cameraModeChangedLabel.text = (([self.delegate currentCameraDeviceForOptionsWindow:self] == QSCameraDeviceRear) ? @"Rear Camera" : @"Front Camera");
    cameraModeChangedLabel.shadowColor = [UIColor whiteColor];
    cameraModeChangedLabel.shadowOffset = (CGSize){0, 1};

    cameraModeChangedLabel.alpha = 0.0;

    [self addSubview:cameraModeChangedLabel];

    NSTimeInterval fadeInDuration = shouldFadeIn ? 0.4 : 0.0;
    [UIView animateWithDuration:fadeInDuration animations:^{
        cameraModeChangedLabel.alpha = 1.0f;
    } completion:^(BOOL finished) {
        if (finished) {
            EXECUTE_BLOCK_AFTER_DELAY(0.75, ^{
                [UIView animateWithDuration:0.4 animations:^{
                    cameraModeChangedLabel.alpha = 0.0f;
                } completion:^(BOOL finished) {
                    if (finished)
                        [cameraModeChangedLabel removeFromSuperview];
                }];
            });
        }
    }];
}


- (void)_restartHideTimer
{
    DLog(@"");
    // make sure the window doesn't hide for at least another self.automaticHideDelay seconds
    if ([_hideTimer isValid])
        [_hideTimer invalidate];

    _hideTimer = nil;
    _hideTimer = [NSTimer scheduledTimerWithTimeInterval:self.automaticHideDelay target:self selector:@selector(_hideTimerFired:) userInfo:nil repeats:NO];
}

- (void)_hideTimerFired:(NSTimer *)timer
{
    DLog(@"");
    [self hideWindowAnimated];
    _hideTimer = nil;
}

- (void)dealloc
{
    [_toggleButton release];
    _toggleButton = nil;

    [_flashButton release];
    _flashButton = nil;

    _optionsDelegate = nil;

    [super dealloc];
}

@end
