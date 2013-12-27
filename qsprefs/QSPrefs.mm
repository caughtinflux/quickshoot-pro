#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Preferences/Preferences.h>
#import <MessageUI/MessageUI.h>
#import <sys/utsname.h>
#import <AVFoundation/AVFoundation.h>
#import <CommonCrypto/CommonDigest.h>

#import "../QSVersion.h"
#import "QSAboutTableViewController.h"
#import "NSTask.h"

NSString * QSCopyDPKGPackages(void);

@interface QSPrefsListController : PSListController <MFMailComposeViewControllerDelegate>
{
}
@end

@implementation QSPrefsListController
+ (void)load
{
    [[NSBundle bundleWithPath:@"/System/Library/Frameworks/AVFoundation.framework"] load];
}

- (id)specifiers
{
    if (_specifiers == nil) {
        _specifiers = [[self loadSpecifiersFromPlistName:@"QSPrefs" target:self] retain];
    }
    return _specifiers;
}

- (NSArray *)videoQualityTitles
{
    AVCaptureDevice *videoCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    NSMutableArray *titles = [[NSMutableArray alloc] initWithObjects:@"High Quality", @"Medium Quality", @"Low Quality", nil];
    
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
    AVCaptureDevice *videoCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    NSMutableArray *values = [[NSMutableArray alloc] initWithObjects:AVCaptureSessionPresetHigh, AVCaptureSessionPresetMedium, AVCaptureSessionPresetLow, nil];
    
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

- (void)launchTwitter
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

- (void)showEmailComposer
{
    MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
    mailController.mailComposeDelegate = self;

    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *machine = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    NSString *separator = @"Please do not delete the above data and attachments, and type below this line.\n------------------------------------------------\n";
    NSString *messageBody = [NSString stringWithFormat:@"Information:\nDevice Type: %@\nDevice Version: iOS %@\nQuickShoot Version: %@\n\n%@", machine, [UIDevice currentDevice].systemVersion, kPackageVersion, separator];

    [mailController setSubject:@"QuickShoot Pro Support"];
    [mailController setMessageBody:messageBody isHTML:NO]; 
    [mailController setToRecipients:[NSArray arrayWithObjects:@"caughtinflux@me.com", nil]];

    NSString *packages = QSCopyDPKGPackages();
    NSString *attachmentsString = [NSString stringWithFormat:@"%@", packages];
    [packages release];

    [mailController addAttachmentData:[attachmentsString dataUsingEncoding:NSUTF8StringEncoding] mimeType:@"text/plain" fileName:@"user_package_list"];
  
    // Present the mail composition interface.
    [(UIViewController *)self presentViewController:mailController animated:YES completion:^{[mailController release];}];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [(UIViewController *)self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)showAboutController
{
    QSAboutTableViewController *controller = [[QSAboutTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
    [((UIViewController *)self).navigationController pushViewController:controller animated:YES];
    [controller autorelease];
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

