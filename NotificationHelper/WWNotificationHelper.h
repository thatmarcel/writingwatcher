#import <Foundation/Foundation.h>

@interface WWNotificationHelper: NSObject
    // Sends a notification (bulletin) that's shown to the user
    + (void) sendNotificationWithMessage:(NSString*)message date:(NSDate*)date;
@end