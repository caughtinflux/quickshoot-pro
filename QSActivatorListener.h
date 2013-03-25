#import <Foundation/NSObject.h>
#import <libactivator/libactivator.h>
#import "QSCameraOptionsWindow.h"

@interface QSActivatorListener : NSObject <LAListener, QSCameraOptionsWindowDelegate>

+ (instancetype)sharedInstance;

// if this is NO, it means it is not a legit copy
@property(nonatomic, assign) BOOL abilitiesChecked;

@end
