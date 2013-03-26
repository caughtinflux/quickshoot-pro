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
    // UIBarButtonItem *doneButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneButtonHit:)] autorelease];
    // self.navigationItem.rightBarButtonItem = doneButton;
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return ((section == 0) ? @"Usage" : @"Acknowledgements");
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return ((section == 0) ? 2 : 1);
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGSize size = [[self _stringForIndexPath:indexPath] sizeWithFont:[UIFont systemFontOfSize:15] constrainedToSize:CGSizeMake(300, CGFLOAT_MAX)];
    return size.height + 25;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"QSAboutCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
    	cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    cell.textLabel.font = [UIFont systemFontOfSize:15];
    cell.textLabel.text = [self _stringForIndexPath:indexPath];

    cell.textLabel.numberOfLines = 0;
    [cell.textLabel sizeToFit];

    return cell;
}

- (NSString *)_stringForIndexPath:(NSIndexPath *)indexPath
{
	NSString *string = @"";
	if (indexPath.section == 0 && indexPath.row == 0) {
		string = @"QuickShoot Pro builds on the concept of its predecessor, QuickShoot, and takes it much further. Never again do you have to miss out on that perfect photo opputunity just because you were waiting for the camera app to launch."
				 @"You can even record videos as fast as you can take photos.";

	}
	else if (indexPath.section == 1 && indexPath.row == 1) {
		string = @"To capture a photo, just double tap any of the icons you have switched on in QuickShoot Pro's preferences. Triple tapping them toggles video recording.\n"
				 @"You can also assign activator shortcuts (see settings) to capture a photo, or for video recording. The Options Window lets you change the camera settings like HDR, flash mode, and camera device without even having to enter the settings."
				 @"Thank you for your purchase, hope you enjoy the experience!";
	}
	else if (indexPath.section == 1) {
		string = @"Thanks to Sentry for his work on the icon overlay images, the pretty UI wouldn't be possible without you.\n"
		         @"I'd also like to thank all the great people on #theos IRC channel for all the help they've given me during the course of this project.\n"
		         @"The video camera icon for the status bar is by Anas Ramadan, from The Noun Project.";
	}

	return string;
}

@end
