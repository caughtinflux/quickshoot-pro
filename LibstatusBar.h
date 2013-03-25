#import <SpringBoard/SpringBoard.h>

@class NSString;

@interface SpringBoard(LibstatusBar)

- (void)addStatusBarImageNamed:(NSString *)name;
- (void)removeStatusBarImageNamed:(NSString *)name;

@end
