#import <Foundation/Foundation.h>
#import <PhotoLibrary/PLCameraControllerDelegate-Protocol.h>

@interface QSCameraController : NSObject <PLCameraControllerDelegate>

@property (nonatomic, retain) NSDictionary *photoDict;

+ (instancetype)sharedController;
- (void)takePhoto;

@end
