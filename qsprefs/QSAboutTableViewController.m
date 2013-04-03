#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "../QSConstants.h"

@interface QSAboutTableViewController : UITableViewController <UITableViewDelegate, UITableViewDataSource>

- (NSString *)_stringForIndexPath:(NSIndexPath *)indexPath;

@end

@implementation QSAboutTableViewController
                            
- (void)dealloc
{ 
   [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.title = @"About";
    self.tableView.allowsSelection = NO;
}

#pragma mark - Table View Data Source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return ((section == 0) ? @"Usage" : @"Acknowledgements");
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return ((section == 0) ? nil : @"Use this software responsibly, in compliance with all your local and federal laws.");
} 

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    DLog(@"Section: %i", section);
    return ((section == 0) ? 2 : 1);
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // I _HATE_ this code.
    CGSize size = [[self _stringForIndexPath:indexPath] sizeWithFont:[UIFont systemFontOfSize:15] constrainedToSize:CGSizeMake(300, CGFLOAT_MAX)];
    CGFloat retval = size.height;
    BOOL isiPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);

    if ((indexPath.section == 0) && (indexPath.row == 1)) {
        if (isiPad) {
            retval -= 35;
        }
        else {
            retval += 28;
        }
    }
    else if ((indexPath.section == 0) && (indexPath.row == 0)) {
        if (!isiPad) {
            retval += 35;
        }
    }
    else if (indexPath.section == 1) {
        if (isiPad) {
            retval += 10;
        }
        else {
            retval += 60;
        }
    }
    return retval;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"QSAboutCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    cell.textLabel.font = [UIFont systemFontOfSize:((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 15 : 15)];
    cell.textLabel.text = [self _stringForIndexPath:indexPath];

    cell.textLabel.numberOfLines = 0;

    return cell;
}

- (NSString *)_stringForIndexPath:(NSIndexPath *)indexPath
{
    NSString *string = @"";
    if (indexPath.section == 0 && indexPath.row == 0) {
        string = @"QuickShoot Pro builds on the concept of its predecessor, QuickShoot, and takes it much further. Never again do you have to miss out on that perfect photo opportunity just because you were waiting for the camera app to launch."
                 @"You can even record videos as fast as you can take photos.";

    }
    else if (indexPath.section == 0 && indexPath.row == 1) {
        string = @"To capture a photo, just double tap any of the icons you have switched on in QuickShoot Pro's preferences. Triple tapping them toggles video recording.\n"
                 @"You can also assign activator shortcuts (see settings) to capture a photo, or to record video. The Options Window lets you change the camera settings like HDR, flash mode, and camera device without even having to enter the settings."
                 @"Thank you for your purchase, hope you enjoy the experience!";
    }
    else if (indexPath.section == 1) {
        string = @"Thanks, Sentry for your work on the UI. It wouldn't look as good without your help.\n"
                 @"I'd also like to thank all the great people on the #theos IRC channel for the help they've given me during the course of this project.\n"
                 @"The video camera icon for the status bar is by Anas Ramadan, from The Noun Project.";
    }

    return string;
}

@end
