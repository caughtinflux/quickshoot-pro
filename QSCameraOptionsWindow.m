/*
*       ____        _      __   _____ __                __  ____           
*      / __ \__  __(_)____/ /__/ ___// /_  ____  ____  / /_/ __ \_________ 
*     / / / / / / / / ___/ //_/\__ \/ __ \/ __ \/ __ \/ __/ /_/ / ___/ __ \
*    / /_/ / /_/ / / /__/ ,<  ___/ / / / / /_/ / /_/ / /_/ ____/ /  / /_/ /
*    \___\_\__,_/_/\___/_/|_|/____/_/ /_/\____/\____/\__/_/   /_/   \____/ 
*                                                                          
*   QSCameraOptionsWindow.m
*   © 2013 Aditya KD
*/

#import "QSCameraOptionsWindow.h"
#import <PhotoLibrary/CAMTopBar.h>
#import <PhotoLibrary/CAMFlashButton.h>
#import <PhotoLibrary/CAMFlipButton.h>
#import <PhotoLibrary/CAMHDRButton.h>
#import <PhotoLibrary/CAMButtonLabel.h>
#import <PhotoLibrary/PLCameraController.h>
#import <QuartzCore/QuartzCore.h>
#import <SpringBoard/SpringBoard.h>
#import <objc/runtime.h>

#pragma mark - View Placement Constants
#define kLeftSidePadding      5
#define kHDRButtonHeight      45
#define kHDRButtonWidth       190
#define kFlashButtonWidth     70
#define kCameraToggleWidth    kFlashButtonWidth
#define kSmallButtonYDistance kHDRButtonHeight + 15

@interface QSCameraOptionsWindow ()
{
    CAMTopBar *_topBar;
    CAMFlipButton *_toggleButton;
    CAMFlashButton *_flashButton;
    CAMHDRButton *_hdrButton;
    CAMButtonLabel *_cameraModeChangedLabel;
    NSTimer *_hideTimer;
    NSTimer *_labelHideTimer;
    CGRect _originalFrame;

    UIDynamicAnimator *_animator;
    UIDynamicItemBehavior *_dynamicItemBehavior;
    UICollisionBehavior *_collisionBehavior;
}

- (void)_flashCameraTypeLabelWithFadeIn:(BOOL)shouldFadeIn;
- (void)_restartHideTimer;
- (void)_hideTimerFired:(NSTimer *)timer;
- (void)_restartLabelHideTimer;
- (void)_labelHideTimerFired:(NSTimer *)timer;
@end

@implementation QSCameraOptionsWindow
@synthesize delegate = _optionsDelegate; // since UIWindow has _delegate already. Bah.

#pragma mark - Custom Initializer(s)
- (instancetype)initWithFrame:(CGRect)frame showFlash:(BOOL)shouldShowFlash showHDR:(BOOL)shouldShowHDR showCameraToggle:(BOOL)shouldShowCameraToggle
{
    if ((self = [super initWithFrame:frame])) {
        if (shouldShowHDR) {
            _hdrButton = [[CAMHDRButton alloc] initWithFrame:(CGRect){CGPointZero, {20, 20}}];
            _hdrButton.center = (CGPoint){(self.frame.size.width * 0.5), 20};
            [_hdrButton addTarget:self action:@selector(_HDRSettingDidChange:) forControlEvents:UIControlEventTouchUpInside];
        }
        if (shouldShowFlash) {
            _flashButton = [[CAMFlashButton alloc] initWithFrame:(CGRect){CGPointZero, {20, 20}}];
            if ([[PLCameraController sharedInstance] hasFlash]) {
                _flashButton.flashMode = [self.delegate currentFlashModeForOptionsWindow:self];
            }
            else {
                _flashButton.showWarningIndicator = YES;
            }
            _flashButton.delegate = self;
        }
        if (shouldShowCameraToggle) {
            _toggleButton = [[CAMFlipButton alloc] initWithFrame:(CGRect){CGPointZero, {20, 20}}];
            [_toggleButton addTarget:self action:@selector(cameraToggleButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        }

        _topBar = [[CAMTopBar alloc] initWithFrame:(CGRect){{0, 0}, {[UIScreen mainScreen].bounds.size.width * 0.8, 40}}];
        _topBar.flipButton = _toggleButton;
        _topBar.flashButton = _flashButton;
        _flashButton.delegate = self;
        _topBar.HDRButton = _hdrButton;
        [self addSubview:_topBar];
        _topBar.style = 2;
        _topBar.backgroundStyle = 1;
        
        self.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.8f];
        self.layer.cornerRadius = 10.f;
        self.layer.masksToBounds = YES;
        self.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
        self.userInteractionEnabled = YES;
        self.frame = (CGRect){{frame.origin.x, frame.origin.y}, _topBar.frame.size};

        [self _setupRecognizerAndDynamics];
        _originalFrame = self.frame;
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame showFlash:YES showHDR:YES showCameraToggle:YES];
}

- (void)dealloc
{
    [_hdrButton release];
    [_toggleButton release];
    [_flashButton release];
    [_topBar removeFromSuperview];
    [_topBar release];

    [_animator release];
    [_dynamicItemBehavior release];
    [_collisionBehavior release];

    _optionsDelegate = nil;

    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)setFlashMode:(QSFlashMode)flashMode
{
    _flashButton.flashMode = flashMode;
}

- (void)setHDRMode:(BOOL)hdrMode
{
    _hdrButton.on = hdrMode;
}

- (void)setHidden:(BOOL)shouldHide
{
    [super setHidden:shouldHide];
    if (!shouldHide) {
        self.alpha = 1.0f;
        [self _restartHideTimer];
        if (self.delegate) {
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
    if (!_automaticHideDelay > 0) {
        _automaticHideDelay = 10.0; // set a default 10 second delay.
    }
    return _automaticHideDelay;
}

- (void)hideWindowAnimated
{
    [UIView animateWithDuration:0.25 animations:^{
        self.alpha = 0.0f;
    } completion:^(BOOL finished) {
        if (finished) {
            self.hidden = YES;
        }
    }];
}

#pragma mark - Camera Button Target
- (void)cameraToggleButtonTapped:(CAMFlipButton *)toggleButton
{
    [self _restartHideTimer];
    if ([self.delegate conformsToProtocol:@protocol(QSCameraOptionsWindowDelegate)]) {
        [self.delegate optionsWindowCameraButtonToggled:self];
        [self _flashCameraTypeLabelWithFadeIn:YES];
    }
}

#pragma mark - SettingsView Delegate
- (void)_HDRSettingDidChange:(CAMHDRButton *)button
{
    [self _restartHideTimer];
    button.on = !(button.on);
    if ([self.delegate conformsToProtocol:@protocol(QSCameraOptionsWindowDelegate)]) {
        [self.delegate optionsWindow:self hdrModeChanged:button.on];
    }
}

#pragma mark - Flash Button Delegate
- (void)flashButtonDidCollapse:(CAMFlashButton *)button
{
    [UIView animateWithDuration:0.3 animations:^{ _hdrButton.alpha = 1.f; }];
}

- (void)flashButtonWillExpand:(CAMFlashButton *)button
{
    [UIView animateWithDuration:0.3 animations:^{ _hdrButton.alpha = 0.f; }];
}

- (void)flashButtonWasPressed:(CAMFlashButton *)button
{
    [self _restartHideTimer];
}

- (void)flashButtonModeDidChange:(CAMFlashButton *)button
{
    if ([self.delegate conformsToProtocol:@protocol(QSCameraOptionsWindowDelegate)]) {
        [self.delegate optionsWindow:self flashModeChanged:(QSFlashMode)button.flashMode];
    }
}

#pragma mark - Private Methods
- (void)_flashCameraTypeLabelWithFadeIn:(BOOL)shouldFadeIn
{
    if (_cameraModeChangedLabel) {
        _cameraModeChangedLabel.text = (([self.delegate currentCameraDeviceForOptionsWindow:self] == QSCameraDeviceRear) ? @"Rear Camera" : @"Front Camera");
        [self _restartLabelHideTimer];
        // Returning here makes sure that the window doesn't expand glitchily.
        return;
    }

    CGRect topBarFrame = _topBar.frame;
    _cameraModeChangedLabel = [[[CAMButtonLabel alloc] initWithFrame:(CGRect){{0, topBarFrame.size.height}, {100, 20}}] autorelease];
    _cameraModeChangedLabel.text = (([self.delegate currentCameraDeviceForOptionsWindow:self] == QSCameraDeviceRear) ? @"Rear Camera" : @"Front Camera");
    _cameraModeChangedLabel.alpha = 0.0;
    _cameraModeChangedLabel.center = (CGPoint){_topBar.center.x, _cameraModeChangedLabel.center.y};

    [self addSubview:_cameraModeChangedLabel];

    NSTimeInterval fadeInDuration = shouldFadeIn ? 0.4 : 0.0;
    [UIView animateWithDuration:fadeInDuration animations:^{ 
        CGRect frame = self.frame;
        self.frame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, frame.size.height + _cameraModeChangedLabel.frame.size.height);
        _cameraModeChangedLabel.alpha = 1.0f;
    } completion:^(BOOL finished) {
        if (finished) {
            _labelHideTimer = [NSTimer scheduledTimerWithTimeInterval:0.75 target:self selector:@selector(_labelHideTimerFired:) userInfo:nil repeats:NO];
        }
    }];
}

- (void)_restartHideTimer
{
    // make sure the window doesn't hide for at least another self.automaticHideDelay seconds
    if ([_hideTimer isValid])
        [_hideTimer invalidate];

    _hideTimer = nil;
    _hideTimer = [NSTimer scheduledTimerWithTimeInterval:self.automaticHideDelay target:self selector:@selector(_hideTimerFired:) userInfo:nil repeats:NO];
}

- (void)_hideTimerFired:(NSTimer *)timer
{
    [self hideWindowAnimated];
    _hideTimer = nil;
}

- (void)_restartLabelHideTimer
{
    if ([_labelHideTimer isValid]) {
        [_labelHideTimer invalidate];
    }
    _labelHideTimer = nil;
    _labelHideTimer = [NSTimer scheduledTimerWithTimeInterval:0.85 target:self selector:@selector(_labelHideTimerFired:) userInfo:nil repeats:NO];
}

- (void)_labelHideTimerFired:(NSTimer *)timer
{
    QSCameraOptionsWindow __block *wSelf = self;
    [UIView animateWithDuration:0.4 animations:^{
        wSelf.frame = CGRectMake(wSelf.frame.origin.x, wSelf.frame.origin.y, wSelf->_originalFrame.size.width, wSelf->_originalFrame.size.height);
        wSelf->_cameraModeChangedLabel.alpha = 0.0f;
    } completion:^(BOOL finished) {
        if (finished) {
            [wSelf->_cameraModeChangedLabel removeFromSuperview];
            wSelf->_cameraModeChangedLabel = nil;
        }
    }];
}

- (void)_setupRecognizerAndDynamics
{
    UIPanGestureRecognizer *panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_pan:)];
    [self addGestureRecognizer:panGR];
    [panGR release];

    _animator = [[UIDynamicAnimator alloc] initWithReferenceView:self];
    
    _dynamicItemBehavior = [[UIDynamicItemBehavior alloc] initWithItems:@[self]];
    _dynamicItemBehavior.allowsRotation = NO;
    _dynamicItemBehavior.density = 5.0;
    _dynamicItemBehavior.resistance = 5.f;
    _dynamicItemBehavior.elasticity = 0.5f;

    _collisionBehavior = [[UICollisionBehavior alloc] initWithItems:@[self]];
    [_collisionBehavior addBoundaryWithIdentifier:@"ScreenBounds" forPath:[UIBezierPath bezierPathWithRect:[UIScreen mainScreen].bounds]];
    _collisionBehavior.collisionMode = UICollisionBehaviorModeBoundaries;
    
    [_animator addBehavior:_dynamicItemBehavior];
    [_animator addBehavior:_collisionBehavior];
}

- (void)_pan:(UIPanGestureRecognizer *)panGR
{
    [self _restartHideTimer];
    if (panGR.state == UIGestureRecognizerStateChanged) {
        CGPoint center = self.center;
        CGPoint translation = [panGR translationInView:[[UIApplication sharedApplication] keyWindow]];
        center.x += translation.x;
        center.y += translation.y;
        self.center = center;
        _dynamicItemBehavior.resistance = CGFLOAT_MAX;
        [panGR setTranslation:CGPointZero inView:[[UIApplication sharedApplication] keyWindow]];
    }
    else if (panGR.state == UIGestureRecognizerStateEnded) {
        CGPoint velocity = [panGR velocityInView:self];
        _dynamicItemBehavior.resistance = 5.f;
        [_animator updateItemUsingCurrentState:self];
        [_dynamicItemBehavior addLinearVelocity:velocity forItem:self];
    }
}

@end
