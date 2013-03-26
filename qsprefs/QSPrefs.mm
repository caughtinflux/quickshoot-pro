#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Preferences/Preferences.h>
#import <MessageUI/MessageUI.h>
#import <sys/utsname.h>
#import <AVFoundation/AVFoundation.h>

#import "QSAboutTableViewController.h"
#import "../QSConstants.h"

#import "NSTask.h"

NSString * QSCopyDPKGPackages(void);

@interface QSPrefsListController : PSListController <MFMailComposeViewControllerDelegate>
{
}

- (NSArray *)videoQualityTitles;
- (NSArray *)videoQualityValues;
- (NSArray *)torchModeTitles;
- (NSArray *)torchModeValues;

- (void)launchTwitter:(PSSpecifier *)spec;
- (void)showEmailComposer:(PSSpecifier *)spec;
- (void)showAboutController:(PSSpecifier *)spec;

@end

@implementation QSPrefsListController

- (id)specifiers
{
    if (_specifiers == nil) {
        _specifiers = [[self loadSpecifiersFromPlistName:@"QSPrefs" target:self] retain];
    }
    return _specifiers;
}

- (NSArray *)videoQualityTitles
{
    AVCaptureDevice *videoCaptureDevice = nil;
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in videoDevices) {
        if (device.position == AVCaptureDevicePositionBack) {
            videoCaptureDevice = device;
        }
    }

    NSMutableArray *titles = [@[@"High Quality", @"Medium Quality", @"Low Quality"] mutableCopy];
    if ([videoCaptureDevice supportsAVCaptureSessionPreset:AVCaptureSessionPreset352x288])
        [titles addObject:@"CIF Quality (352 x 288)"];
    if ([videoCaptureDevice supportsAVCaptureSessionPreset:AVCaptureSessionPreset640x480])
        [titles addObject:@"VGA Quality (640 x 480)"];
    if ([videoCaptureDevice supportsAVCaptureSessionPreset:AVCaptureSessionPreset1280x720])
        [titles addObject:@"720p (1280 x 720)"];
    if ([videoCaptureDevice supportsAVCaptureSessionPreset:AVCaptureSessionPreset1920x1080])
        [titles addObject:@"Full HD 1080p (1920 x 1080)"];
    if ([videoCaptureDevice supportsAVCaptureSessionPreset:AVCaptureSessionPresetiFrame960x540])
        [titles addObject:@"H.264 30 Mbits/sec (960 x 540)"];
    if ([videoCaptureDevice supportsAVCaptureSessionPreset:AVCaptureSessionPresetiFrame1280x720])
        [titles addObject:@"H.264 40 Mbits/sec (1280 x 720)"];

    return [titles autorelease];
}

- (NSArray *)videoQualityValues
{
    AVCaptureDevice *videoCaptureDevice = nil;
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in videoDevices) {
        if (device.position == AVCaptureDevicePositionBack) {
            videoCaptureDevice = device;
        }
    }

    NSMutableArray *values = [@[AVCaptureSessionPresetHigh, AVCaptureSessionPresetMedium, AVCaptureSessionPresetLow] mutableCopy];
    if ([videoCaptureDevice supportsAVCaptureSessionPreset:AVCaptureSessionPreset352x288])
        [values addObject:AVCaptureSessionPreset352x288];
    if ([videoCaptureDevice supportsAVCaptureSessionPreset:AVCaptureSessionPreset640x480])
        [values addObject:AVCaptureSessionPreset640x480];
    if ([videoCaptureDevice supportsAVCaptureSessionPreset:AVCaptureSessionPreset1280x720])
        [values addObject:AVCaptureSessionPreset1280x720];
    if ([videoCaptureDevice supportsAVCaptureSessionPreset:AVCaptureSessionPreset1920x1080])
        [values addObject:AVCaptureSessionPreset1920x1080];
    if ([videoCaptureDevice supportsAVCaptureSessionPreset:AVCaptureSessionPresetiFrame960x540])
        [values addObject:AVCaptureSessionPresetiFrame960x540];
    if ([videoCaptureDevice supportsAVCaptureSessionPreset:AVCaptureSessionPresetiFrame1280x720])
        [values addObject:AVCaptureSessionPresetiFrame1280x720];

    return [values autorelease];
}

// these will be shown only if the device has flash.
- (NSArray *)torchModeTitles
{
    return @[@"Automatic", @"Always On", @"Off"];
}

- (NSArray *)torchModeValues
{
    return @[@"kQSFlashModeAuto", @"kQSFlashModeOn", @"kQSFlashModeOff"];
}


- (void)launchTwitter:(PSSpecifier *)spec
{
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tweetbot:"]]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"tweetbot:///user_profile/caughtinflux"]];
    }
    else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tweetings:"]]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"tweetings:///user?screen_name=caughtinflux"]];
    }
    else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter:"]]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"twitter://user?screen_name=caughtinflux"]];
    }
    else {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://twitter.com/caughtinflux"]];
    }
}

- (void)showEmailComposer:(PSSpecifier *)spec
{
    MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
    mailController.mailComposeDelegate = self;

    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *machine = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    NSString *messageBody = [NSString stringWithFormat:@"%@, iOS %@", machine, [UIDevice currentDevice].systemVersion];

    [mailController setSubject:[NSString stringWithFormat:@"QuickShoot Pro Version %@", kQSVersion]];
    [mailController setMessageBody:messageBody isHTML:NO]; 
    [mailController setToRecipients:@[@"caughtinflux@me.com"]];

    NSString *packages = QSCopyDPKGPackages();
    [mailController addAttachmentData:[packages dataUsingEncoding:NSUTF8StringEncoding] mimeType:@"text/plain" fileName:@"user_package_list"];
    [packages release];
  
    // Present the mail composition interface.
    [(UIViewController *)self presentViewController:mailController animated:YES completion:^{[mailController release];}];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [(UIViewController *)self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)showAboutController:(PSSpecifier *)spec
{
    @try {
        QSAboutTableViewController *controller = [[QSAboutTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
        [((UIViewController *)self).navigationController pushViewController:controller animated:YES];
        [controller autorelease];
    }
    @catch (NSException *e) {
        NSLog(@"QuickShoot: Exception caught when trying to present about VC");
    }

}

NSString * QSCopyDPKGPackages(void)
{
    NSTask *task = [[NSTask alloc] init]; // Make a new task

    [task setLaunchPath:@"/usr/bin/dpkg"]; // Tell which command we are running
    [task setArguments:[NSArray arrayWithObjects:@"--get-selections", nil]];
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    [task launch];
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [task release]; //Release the task into the world, thus destroying it.

    return string;
}

@end

