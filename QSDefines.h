#ifndef QS_DEFINES_H
#define QS_DEFINES_H

#undef DEBUG

#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif

#define ALog(fmt, ...) NSLog((@"%s" fmt), __PRETTY_FUNCTION__, ##__VA_ARGS__);


// These values are accepted by PLCameraController as-is
typedef enum {
	QSCameraDeviceRear  = 0,
	QSCameraDeviceFront = 1,
} QSCameraDevice; // it's the same as UIImagePickerControllerCameraDevice

typedef enum {
	QSFlashModeAuto =  0,
	QSFlashModeOn   =  1,
	QSFlashModeOff  = -1,
} QSFlashMode;

typedef void (^QSCompletionHandler)(BOOL); // the BOOL argument is most probably pointless.

#define kPLCameraModePhoto 0 // yes, PL. PhotoLibrary, yeah? :D
#define kPLCameraModeVideo 1

#define kPrefPath [NSHomeDirectory() stringByAppendingString:@"/Library/Preferences/com.caughtinflux.qsproprefs.plist"]

#endif // QS_DEFINES_H