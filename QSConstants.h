/*
*
*       ____        _      __   _____ __                __  ____           
*      / __ \__  __(_)____/ /__/ ___// /_  ____  ____  / /_/ __ \_________ 
*     / / / / / / / / ___/ //_/\__ \/ __ \/ __ \/ __ \/ __/ /_/ / ___/ __ \
*    / /_/ / /_/ / / /__/ ,<  ___/ / / / / /_/ / /_/ / /_/ ____/ /  / /_/ /
*    \___\_\__,_/_/\___/_/|_|/____/_/ /_/\____/\____/\__/_/   /_/   \____/ 
*                                                                          
*   QSConstants.h
*   © 2013 Aditya KD
*/

#import <CoreFoundation/CoreFoundation.h>
#import <CoreFoundation/CFUserNotification.h>
#import <Foundation/Foundation.h>
#import <stdbool.h>

#ifndef QS_CONSTANTS_H
#define QS_CONSTANTS_H

#ifdef DEBUG
	#define DLog(fmt, ...) NSLog((@"QS: %s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
	#define CLog(fmt, ...) NSLog((@"QS: " fmt), ##__VA_ARGS__)
	#define ParamLog(_formatString, _param, ...) DLog(@"%s = "_formatString, #_param, _param, ##__VA_ARGS__)
	#define ParamLogC(_formatString, _param, ...) CLog(@"%s = "_formatString, #_param, _param, ##__VA_ARGS__)
#else
	#define DLog(...)
	#define CLog(...)
	#define ParamLog(...)
	#define ParamLogC(...)
#endif

#define ALog(fmt, ...) NSLog((@"QS: " fmt), ##__VA_ARGS__)	

#define kPiratedCopyNotification @"QSUpdatedCapabilities"
#define kPLCameraModePhoto 0 // yes, PL. PhotoLibrary, yeah? :D
#define kPLCameraModeVideo 1

#define kPrefPath [NSHomeDirectory() stringByAppendingString:@"/Library/Preferences/com.caughtinflux.qsproprefs.plist"]

#define EXECUTE_BLOCK_AFTER_DELAY(delayInSeconds, block) (dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), block))

#define SHOW_USER_NOTIFICATION(title, message, dismissButtonTitle) \
							   NSDictionary *fields = @{(id)kCFUserNotificationAlertHeaderKey        : title, \
                                 						(id)kCFUserNotificationAlertMessageKey       : message, \
                                                        (id)kCFUserNotificationDefaultButtonTitleKey : dismissButtonTitle}; \
        					   CFUserNotificationRef notificationRef = CFUserNotificationCreate(kCFAllocatorDefault, 0, kCFUserNotificationNoteAlertLevel, NULL, (CFDictionaryRef)fields); \
        					   CFRelease(notificationRef)

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

#pragma mark - String Constants
FOUNDATION_EXPORT NSString * const QSEnabledKey;
FOUNDATION_EXPORT NSString * const QSUserHasSeenAlertKey;
FOUNDATION_EXPORT NSString * const QSFlashModeKey;
FOUNDATION_EXPORT NSString * const QSCameraDeviceKey;
FOUNDATION_EXPORT NSString * const QSHDRModeKey;
FOUNDATION_EXPORT NSString * const QSWaitForFocusKey;
FOUNDATION_EXPORT NSString * const QSOptionsWindowHideDelayKey;
FOUNDATION_EXPORT NSString * const QSVideoQualityKey;
FOUNDATION_EXPORT NSString * const QSTorchModeKey;
FOUNDATION_EXPORT NSString * const QSReferenceTimeKey;
FOUNDATION_EXPORT NSString * const QSScreenFlashKey;
FOUNDATION_EXPORT NSString * const QSRecordingIconKey;
FOUNDATION_EXPORT NSString * const QSShutterSoundKey;


FOUNDATION_EXPORT NSString * const QSPrefsChangedNotificationName;
FOUNDATION_EXPORT NSString * const QSImageCaptureListenerName;
FOUNDATION_EXPORT NSString * const QSVideoCaptureListenerName;
FOUNDATION_EXPORT NSString * const QSOptionsWindowListenerName;

FOUNDATION_EXPORT NSString * const QSStatusBarImageName;

#pragma mark - Function Declarations
FOUNDATION_EXPORT QSFlashMode    QSFlashModeFromString(NSString *string);
FOUNDATION_EXPORT QSCameraDevice QSCameraDeviceFromString(NSString *string);
FOUNDATION_EXPORT NSString *     QSVideoQualityFromString(NSString *string);

FOUNDATION_EXPORT __attribute__((always_inline)) inline id 	       QSObjectFromPrefsForKey(NSString *key);
FOUNDATION_EXPORT __attribute__((always_inline)) inline NSString * QSStringFromCameraDevice(QSCameraDevice device);
FOUNDATION_EXPORT __attribute__((always_inline)) inline NSString * QSStringFromFlashMode(QSFlashMode flashMode);
FOUNDATION_EXPORT __attribute__((always_inline)) inline NSString * QSGetMachineName(void);

#endif // QS_CONSTANTS_H
