#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Preferences/Preferences.h>

@interface QSAboutListController : PSListController
@end

@implementation QSAboutListController

- (id)specifiers
{
    if (_specifiers == nil) {
        _specifiers = [[self loadSpecifiersFromPlistName:@"QSAboutListSpecifiers" target:self] retain];
    }
    return _specifiers;
}

@end
