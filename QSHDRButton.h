#import <PhotoLibrary/CAMHDRButton.h>

@interface QSHDRButton : CAMHDRButton
@property (nonatomic, assign, getter=isOn) BOOL on;
- (void)setTapTarget:(id)target selector:(SEL)selector;
@end
