#import "WWNotificationHelper.h"
#import "../Shared/Constants.h"
#import "../Shared/NSDistributedNotificationCenter.h"

#import <BulletinBoard/BBAction.h>
#import <BulletinBoard/BBBulletin.h>
#import <BulletinBoard/BBServer.h>

@interface BBServer (WritingWatcher)
    - (void) publishBulletin:(BBBulletin*)bulletin destinations:(unsigned long long)destinations;
    
    - (void) publishBulletin:(BBBulletin*)bulletin destinations:(unsigned long long)destinations alwaysToLockScreen:(bool)alwaysToLockScreen;
    
    - (id) _sectionInfoForSectionID:(NSString*)sectionID effective:(BOOL)effective;
@end

@interface BBBulletin (WritingWatcher)
    // Not sure if we need to set this for everything to behave normally but why not
    @property (nonatomic) bool clearable;
@end

// This gets set from the BBServer init hook and allows us to send notifications
static BBServer* notificationServer = nil;

// Notifications must be dispatched from this queue or the process will crash
static NSObject<OS_dispatch_queue>* notificationServerQueue = nil;

%hook BBServer
    - (instancetype) initWithQueue:(id)queue {
        notificationServer = %orig;
        notificationServerQueue = queue;
        
        return notificationServer;
    }
    
    - (id) initWithQueue:(id)queue dataProviderManager:(id)dataProviderManager syncService:(id)syncService dismissalSyncCache:(id)dismissalSyncCache observerListener:(id)observerListener utilitiesListener:(id)utilitiesListener conduitListener:(id)conduitListener systemStateListener:(id)systemStateListener settingsListener:(id)settingsListener {
        notificationServer = %orig;
        notificationServerQueue = queue;
        
        return notificationServer;
    }
    
    - (void) dealloc {
        if (notificationServer == self) {
            notificationServer = nil;
        }
        
        %orig;
    }
%end

@implementation WWNotificationHelper
    + (void) sendNotificationWithMessage:(NSString*)message date:(NSDate*)date {
        if (!notificationServer) {
            return;
        }
        
        bool shouldUseOtherPublishMethod = false;
        
        if (![notificationServer respondsToSelector: @selector(publishBulletin:destinations:)]) {
            if ([notificationServer respondsToSelector: @selector(publishBulletin:destinations:alwaysToLockScreen:)]) {
                shouldUseOtherPublishMethod = true;
            } else {
                return;
            }
        }
        
        BBBulletin* bulletin = [[%c(BBBulletin) alloc] init];
        
        bulletin.bulletinID = [[NSProcessInfo processInfo] globallyUniqueString];
        bulletin.recordID = [[NSProcessInfo processInfo] globallyUniqueString];
        bulletin.publisherBulletinID = [[NSProcessInfo processInfo] globallyUniqueString];
        bulletin.lastInterruptDate = [NSDate date];
        bulletin.turnsOnDisplay = false;
        
        bulletin.message = message;
        bulletin.sectionID = @"com.apple.MobileSMS";
        
        if (date) {
            bulletin.date = date;
        } else {
            bulletin.date = [NSDate date];
        }
        
        // Open the Messages app when the notification is tapped
        bulletin.defaultAction = [%c(BBAction) actionWithLaunchBundleID: @"com.apple.MobileSMS" callblock: nil];
        
        if ([bulletin respondsToSelector: @selector(setClearable:)]) {
            [bulletin setClearable: true];
        }
        
        dispatch_sync(notificationServerQueue, ^{
            if (shouldUseOtherPublishMethod) {
                [notificationServer publishBulletin: bulletin destinations: 14 alwaysToLockScreen: false];
            } else {
                [notificationServer publishBulletin: bulletin destinations: 14];
            }
        });
    }
@end

%hook SpringBoard
    - (void) applicationDidFinishLaunching:(id)arg1 {
        %orig;
        
        // Wait a bit to make sure SpringBoard has fully initialized
        [NSTimer
            scheduledTimerWithTimeInterval: 5
            repeats: false
            block: ^(NSTimer* timer) {
                // Wait for command to send a notification bulletin
                [NSDistributedNotificationCenter.defaultCenter
                    addObserverForName: kNotificationSendNotificationBulletin
                    object: nil
                    queue: NSOperationQueue.mainQueue
                    usingBlock: ^(NSNotification* notification)
                {
                    NSDictionary* userInfo = notification.userInfo;
                    NSString* messageText = userInfo[kMessageText];
                    NSDate* messageDate = userInfo[kMessageDate];
                    
                    [WWNotificationHelper sendNotificationWithMessage: messageText date: messageDate];
                }];
            }
        ];
    }
%end