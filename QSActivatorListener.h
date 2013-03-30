#import <Foundation/NSObject.h>
#import <libactivator/libactivator.h>
#import "QSCameraOptionsWindow.h"

@interface QSActivatorListener : NSObject <LAListener, QSCameraOptionsWindowDelegate>

+ (instancetype)sharedInstance;

@property(nonatomic, assign) BOOL abilitiesChecked; // aka _isLegitCopy. This is used as a confusion tactic, but mostly won't confuse anyone other than you.

@end
