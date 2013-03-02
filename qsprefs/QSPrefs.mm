#import <Preferences/Preferences.h>

@interface QSPrefsListController: PSListController {
}
@end

@implementation QSPrefsListController
- (id)specifiers {
	if(_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"QSPrefs" target:self] retain];
	}
	return _specifiers;
}
@end

// vim:ft=objc
