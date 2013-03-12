#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Preferences/Preferences.h>
#import <MessageUI/MessageUI.h>
#import <sys/utsname.h>

#define kQSVersion @"1.3"

@interface QSPrefsListController: PSListController <MFMailComposeViewControllerDelegate>
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
 
    [mailController setSubject:[NSString stringWithFormat:@"QuickShoot Version %@", kQSVersion]];
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

