/*
*       ____        _      __   _____ __                __  ____           
*      / __ \__  __(_)____/ /__/ ___// /_  ____  ____  / /_/ __ \_________ 
*     / / / / / / / / ___/ //_/\__ \/ __ \/ __ \/ __ \/ __/ /_/ / ___/ __ \
*    / /_/ / /_/ / / /__/ ,<  ___/ / / / / /_/ / /_/ / /_/ ____/ /  / /_/ /
*    \___\_\__,_/_/\___/_/|_|/____/_/ /_/\____/\____/\__/_/   /_/   \____/ 
*                                                                          
*   QSActivatorListener.h
*   © 2013 Aditya KD
*/

#import <Foundation/NSObject.h>
#import <libactivator/libactivator.h>
#import "QSCameraOptionsWindow.h"

@interface QSActivatorListener : NSObject <LAListener, QSCameraOptionsWindowDelegate>

+ (instancetype)sharedInstance;

@property(nonatomic, assign) BOOL shouldFlashScreen;
@property(nonatomic, assign) BOOL shouldShowRecordingIcon;

@end
