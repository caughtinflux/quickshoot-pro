#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Preferences/Preferences.h>
#import <MessageUI/MessageUI.h>
#import <sys/utsname.h>
#import <AVFoundation/AVFoundation.h>

#define kQSVersion @"1337 h4x0r sekrit"

@interface QSPrefsListController : PSListController <MFMailComposeViewControllerDelegate>
{
}
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
  
    // Present the mail composition interface.
    [(UIViewController *)self presentViewController:mailController animated:YES completion:^{[mailController release];}];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [(UIViewController *)self dismissViewControllerAnimated:YES completion:NULL];
}

@end

