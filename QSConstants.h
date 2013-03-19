#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>

#ifndef QS_CONSTANTS_H
#define QS_CONSTANTS_H

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

#define EXECUTE_BLOCK_AFTER_DELAY(delayInSeconds, block) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), block)


#pragma mark - String Constants
FOUNDATION_EXPORT NSString * const QSEnabledKey;
FOUNDATION_EXPORT NSString * const QSFlashModeKey;
FOUNDATION_EXPORT NSString * const QSCameraDeviceKey;
FOUNDATION_EXPORT NSString * const QSHDRModeKey;
FOUNDATION_EXPORT NSString * const QSWaitForFocusKey;
FOUNDATION_EXPORT NSString * const QSOptionsWindowHideDelayKey;
FOUNDATION_EXPORT NSString * const QSVideoQualityKey;
FOUNDATION_EXPORT NSString * const QSTorchModeKey;

FOUNDATION_EXPORT NSString * const QSPrefsChangedNotificationName;

#pragma mark - Function Declarations
FOUNDATION_EXPORT QSFlashMode    QSFlashModeFromString(NSString *string);
FOUNDATION_EXPORT QSCameraDevice QSCameraDeviceFromString(NSString *string);
FOUNDATION_EXPORT NSString *     QSVideoQualityFromString(NSString *string);

FOUNDATION_EXPORT inline id 	    QSObjectFromPrefsForKey(NSString *key);
FOUNDATION_EXPORT inline NSString * QSStringFromCameraDevice(QSCameraDevice device);
FOUNDATION_EXPORT inline NSString * QSStringFromFlashMode(QSFlashMode flashMode);

FOUNDATION_EXPORT inline NSString * QSGetMachineName(void);

#endif // QS_CONSTANTS_H
