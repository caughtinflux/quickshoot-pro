#import "QSConstants.h"
#import "QSCameraController.h"
#import <Foundation/Foundation.h>
#import <sys/utsname.h>


NSString * const QSEnabledKey                   = @"kQSEnabled";
NSString * const QSFlashModeKey                 = @"kQSFlashMode";
NSString * const QSCameraDeviceKey              = @"kQSCameraDevice";
NSString * const QSHDRModeKey                   = @"kQSHDREnabled";
NSString * const QSWaitForFocusKey              = @"kQSWaitForFocus";
NSString * const QSOptionsWindowHideDelayKey    = @"kQSOptionsWindowHideAfter";
NSString * const QSPrefsChangedNotificationName = @"kQSPrefsChangedNotif";

static NSString * const QSCameraDeviceFrontValue = @"kQSCameraDeviceFront";
static NSString * const QSCameraDeviceRearValue  = @"kQSCameraDeviceRear";
static NSString * const QSFlashModeAutoValue     = @"kQSFlashModeAuto";
static NSString * const QSFlashModeOnValue       = @"kQSFlashModeOn";
static NSString * const QSFlashModeOffValue      = @"kQSFlashModeOff";


QSFlashMode QSFlashModeFromString(NSString *string)
{
    if ([string isEqualToString:@"kQSFlashModeOn"])
        return QSFlashModeOn;
    else if ([string isEqualToString:@"kQSFlashModeAuto"])
        return QSFlashModeOn;
    else if ([string isEqualToString:@"kQSFlashModeOff"])
        return QSFlashModeOff;
    else
        return QSFlashModeAuto; // default value, in case string is nil.
}

QSCameraDevice QSCameraDeviceFromString(NSString *string)
{
    if ([string isEqualToString:@"kQSCameraDeviceRear"])
        return QSCameraDeviceRear;
    else if ([string isEqualToString:@"kQSCameraDeviceFront"])
        return QSCameraDeviceFront;
    else
        return QSCameraDeviceRear;
}

inline id QSObjectFromPrefsForKey(NSString *key)
{
    return [[NSDictionary dictionaryWithContentsOfFile:kPrefPath] objectForKey:key];
}

inline NSString * QSStringFromCameraDevice(QSCameraDevice device)
{
    return ((device == QSCameraDeviceRear) ? @"kQSCameraDeviceRear" : @"kQSCameraDeviceFront");
}

inline NSString * QSStringFromFlashMode(QSFlashMode flashMode)
{
    return ((flashMode == QSFlashModeAuto) ? @"kQSFlashModeAuto" : ((flashMode == QSFlashModeOn) ? @"kQSFlashModeOn" : @"kQSFlashModeOff"));
}

inline NSString * QSGetMachineName(void)
{
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

