#import "QSCameraController.h"
#import <PhotoLibrary/PLCameraController.h>
#import <UIKit/UIKit.h>

/*
For Reference:
Feb 25 07:15:56 flux-iPhone SpringBoard[3386] <Warning>: QS: Captured Photo: {
	    kPLCameraPhotoImageKey = "<UIImage: 0x20b376b0>";
	    kPLCameraPhotoIsFinalCaptureKey = 1;
	    kPLCameraPhotoPreviewImageKey = "<UIImage: 0x20a06260>";
	    kPLCameraPhotoPreviewSurfaceKey = "<IOSurface 0x20c22944 [0x1fdf9070]>";
	    kPLCameraPhotoPreviewSurfaceSizeKey = 786440;
	    kPLCameraPhotoPropertiesKey =     {
	        Orientation = 6;
	        "{Exif}" =         {
	            ApertureValue = "2.970853654340484";
	            BrightnessValue = "-1.662620276692737";
	            ExposureMode = 0;
	            ExposureProgram = 2;
	            ExposureTime = "0.06666666666666667";
	            FNumber = "2.8";
	            Flash = 24;
	            FocalLenIn35mmFilm = 35;
	            FocalLength = "3.85";
	            ISOSpeedRatings =             (
	                1000
	            );
	            MeteringMode = 5;
	            PixelXDimension = 2592;
	            PixelYDimension = 1936;
	            SceneType = 1;
	            SensingMethod = 2;
	            ShutterSpeedValue = "3.911199862602335";
	            SubjectArea =             (
	                1295,
	                967,
	                699,
	                696
	            );
	            WhiteBalance = 0;
	        };
	    };
	    kPLCameraPhotoSurfaceKey = "<IOSurface 0x20c22934 [0x1fdf9070]>";
	    kPLCameraPhotoSurfaceSizeKey = 2342123;
	} Error: (null)
*/

@implementation QSCameraController
{
}

+ (instancetype)sharedController
{
	static QSCameraController *sharedController;
	if (!sharedController) {
		sharedController = [[self alloc] init];
	}
	return sharedController;
}

- (id)init
{
	self = [super init];
	if (self) {
	}
	return self;
}

- (void)takePhoto
{
	[[PLCameraController sharedInstance] setDelegate:self];
	[[PLCameraController sharedInstance] startPreview];

	while (![[PLCameraController sharedInstance] canCapturePhoto]) {
		;
	}
	[[PLCameraController sharedInstance] capturePhoto];

}

- (void)cameraControllerDidTakePhoto:(id)arg1
{
	NSLog(@"QS: didtakephoto %@", arg1);;
}

- (void)cameraController:(PLCameraController *)camController capturedPhoto:(NSDictionary *)photoDict error:(NSError *)error
{
	@autoreleasepool {
		NSLog(@"QS: %@", photoDict);
		self.photoDict = photoDict;
		UIImage *photo = self.photoDict[@"kPLCameraPhotoImageKey"];
		UIImageWriteToSavedPhotosAlbum(photo, nil, nil, nil);
	}
}

- (void)dealloc
{
	[_photoDict release];
	_photoDict = nil;
	[super dealloc];

}
@end