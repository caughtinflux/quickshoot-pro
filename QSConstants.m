#import "QSConstants.h"
#import "QSCameraController.h"
#import <Foundation/Foundation.h>
#import <sys/utsname.h>


#pragma mark - Preference Key Constants
NSString * const QSFlashModeKey    = @"kQSFlashMode";
NSString * const QSCameraDeviceKey = @"kQSCameraDevice";
NSString * const QSHDRModeKey      = @"kQSHDREnabled";
NSString * const QSWaitForFocusKey = @"kQSWaitForFocus";


#pragma mark - Function Definitions
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

inline NSString * QSGetMachineName(void)
{
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

