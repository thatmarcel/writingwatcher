#import "WWNotificationSender.h"
#import "../Shared/Constants.h"
#import "../Shared/NSDistributedNotificationCenter.h"

@implementation WWNotificationSender
    + (void) sendNotificationWithMessage:(NSString*)message date:(NSDate*)date {
        // Tell the NotificationHelper to send a notification bulletin
        [NSDistributedNotificationCenter.defaultCenter
            postNotificationName: kNotificationSendNotificationBulletin
            object: nil
            userInfo: @{ kMessageText: message, kMessageDate: date }
        ];
    }
@end