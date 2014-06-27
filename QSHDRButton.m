#import "QSHDRButton.h"
#import "QSConstants.h"

@protocol CAMHDRButtonDelegate <NSObject>
- (void)HDRButtonDidCollapse:(CAMHDRButton *)button;
- (void)HDRButtonWillExpand:(CAMHDRButton *)button;
- (void)HDRButtonWasPressed:(CAMHDRButton *)button;
- (void)HDRButtonModeDidChange:(CAMHDRButton *)button;
@end

@interface CAMHDRButton (SevenPointOne)
@property (nonatomic, assign) id <CAMHDRButtonDelegate> delegate;
@property (nonatomic, assign) NSInteger HDRMode;
@property (nonatomic, getter=isAutoDisallowed) NSInteger autoDisallowed;
- (void)setHDRMode:(NSInteger)mode notifyDelegate:(BOOL)notify;
@end

@interface QSHDRButton () <CAMHDRButtonDelegate>
{
    id _target;
    SEL _sel;
}
@end

@implementation QSHDRButton
- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        if ([self respondsToSelector:@selector(setDelegate:)]) {
            self.delegate = self;
            self.autoDisallowed = 1;
        } 
    }
    return self;
}

- (BOOL)isOn
{
    return (self.HDRMode > 0);
}

- (void)setOn:(BOOL)on
{
    if ([self respondsToSelector:@selector(setHDRMode:)]) {
        self.HDRMode = (on ? 1 : 0);
        [self setHDRMode:(on ? 1 : 0) notifyDelegate:YES];
    }
    else {
        [super setOn:on];
    }
}

- (void)setTapTarget:(id)target selector:(SEL)selector
{
    [self removeTarget:_target action:_sel forControlEvents:UIControlEventTouchUpInside];
    [self addTarget:target action:selector forControlEvents:UIControlEventTouchUpInside];
    _target = target;
    _sel = selector;
}

- (void)HDRButtonDidCollapse:(CAMHDRButton *)button {}
- (void)HDRButtonWillExpand:(CAMHDRButton *)button {}

- (void)HDRButtonWasPressed:(CAMHDRButton *)button {}

- (void)HDRButtonModeDidChange:(CAMHDRButton *)button
{
    [_target performSelector:_sel withObject:self];
}
@end