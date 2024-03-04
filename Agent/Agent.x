#import <Foundation/Foundation.h>

#import "WWNotificationSender.h"

@interface IMHandle: NSObject
	- (NSString*) _displayNameWithAbbreviation;
@end

@interface IMItem: NSObject
	- (NSString*) sender;
	- (NSDictionary*) senderInfo;
	- (NSString*) handle;
	
	- (NSDate*) clientSendTime;
	- (NSDate*) time;
	
	- (IMHandle*) _senderHandle;
@end

@interface IMMessageItem: IMItem
	- (BOOL) isTypingMessage;
	- (BOOL) isFinished;
@end

@interface FZMessage: IMMessageItem
@end

@interface IMDServiceSession: NSObject
	- (void) writingWatcherHandleMessage:(IMMessageItem*)message;
@end

@interface IMDaemonController: NSObject
	+ (instancetype) sharedController;
	- (BOOL) connectToDaemon;
@end

%hook IMDServiceSession

%new
- (void) writingWatcherHandleMessage:(IMMessageItem*)message {
	if (![message respondsToSelector: @selector(isTypingMessage)]) {
		NSLog(@"[WritingWatcher] Agent: Message does not respond to isTypingMessage");
		return;
	}
	
	if (![message respondsToSelector: @selector(isFinished)]) {
		NSLog(@"[WritingWatcher] Agent: Message does not respond to isFinished");
		return;
	}
	
	if (![message isTypingMessage]) {
		return;
	}
	
	NSLog(@"[WritingWatcher] Agent: Handling a typing message");
	
	NSDate* messageDate = [message clientSendTime];
	
	if (!messageDate) {
		messageDate = [message time];
	}
	
	NSString* senderDisplayName = nil;
	
	// I don't know what the best way to retrieve the contact name is.
	// This is scuffed (connecting to the IMDaemon from imagent makes no sense?)
	// but I tried quite a few ways and I don't know if my device is cursed
	// or if I'm stupid but nothing is working.
	// Maybe connecting to IMDaemon from SpringBoard could work when
	// hooking the daemon capabilities getter but not sure.
	// Many things that should work don't work (on my device), maybe this weird
	// thing works on some devices, maybe it doesn't
	
	NSBundle* imCoreBundle = [[NSBundle alloc] initWithPath: @"/System/Library/PrivateFrameworks/IMCore.framework"];
	[imCoreBundle load];
	
	if ([message respondsToSelector: @selector(_senderHandle)]) {
		IMDaemonController* controller = [%c(IMDaemonController) sharedController];
		[controller connectToDaemon];
		
		IMHandle* senderHandle = [message _senderHandle];
		
		if (senderHandle && [senderHandle respondsToSelector: @selector(_displayNameWithAbbreviation)]) {
			senderDisplayName = [senderHandle _displayNameWithAbbreviation];
		}
	}
	
	NSString *completeSenderName;
	
	if (senderDisplayName) {
		completeSenderName = [NSString
			stringWithFormat: @"%@ (%@)", [message sender], senderDisplayName
		];
	} else {
		completeSenderName = [message sender];
	}
	
	if ([message isFinished]) {
		NSLog(
			@"[WritingWatcher] Agent: Received cancel typing message from sender: %@ (handle: %@ info: %@)",
			[message sender],
			[message handle],
			[message senderInfo]
		);
		
		[WWNotificationSender
			sendNotificationWithMessage: [NSString
				stringWithFormat: @"%@ stopped typing", completeSenderName
			]
			date: messageDate
		];
	} else {
		NSLog(
			@"[WritingWatcher] Agent: Received start typing message from sender: %@ (handle: %@ info: %@)",
			[message sender],
			[message handle],
			[message senderInfo]
		);
		
		[WWNotificationSender
			sendNotificationWithMessage: [NSString
				stringWithFormat: @"%@ started typing", completeSenderName
			]
			date: messageDate
		];
	}
}

- (void) didReceiveMessage:(FZMessage*)message forChat:(id)chat style:(unsigned char)style account:(id)account fromIDSID:(id)senderIDSID {
	%orig;
	
	[self writingWatcherHandleMessage: message];
}

- (void) didReceiveMessage:(FZMessage*)message forChat:(id)chat style:(unsigned char)style fromIDSID:(id)senderIDSID {
	%orig;
		
	[self writingWatcherHandleMessage: message];
}

- (BOOL) didReceiveMessages:(NSArray<FZMessage*>*)messages forChat:(id)chat style:(unsigned char)style account:(id)account fromIDSID:(id)senderIDSID {
	BOOL result = %orig;
	
	for (FZMessage* message in messages) {
		[self writingWatcherHandleMessage: message];
	}
	
	return result;
}

- (void) didReceiveMessage:(FZMessage*)message forChat:(id)chat style:(unsigned char)style {
	%orig;
		
	[self writingWatcherHandleMessage: message];
}

- (void) didReceiveMessage:(FZMessage*)message forChat:(id)chat style:(unsigned char)style account:(id)account {
	%orig;
		
	[self writingWatcherHandleMessage: message];
}

- (void) didReceiveMessages:(NSArray<FZMessage*>*)messages forChat:(id)chat style:(unsigned char)style account:(id)account {
	%orig;
	
	for (FZMessage* message in messages) {
		[self writingWatcherHandleMessage: message];
	}
}

%end

%ctor {
	NSLog(@"[WritingWatcher] Agent: Started");
}