#import <Preferences/Preferences.h>

@interface quickshootprefsListController: PSListController {
}
@end

@implementation quickshootprefsListController
- (id)specifiers {
	if(_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"quickshootprefs" target:self] retain];
	}
	return _specifiers;
}
@end

// vim:ft=objc
