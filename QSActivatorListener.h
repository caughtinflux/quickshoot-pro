#import <Foundation/NSObject.h>
#import <libactivator/libactivator.h>
#import "QSCameraOptionsWindow.h"

@interface QSActivatorListener : NSObject <LAListener, QSCameraOptionsWindowDelegate>
@end
