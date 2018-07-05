// Copyright: 2018, Ableton AG, Berlin. All rights reserved.

@interface ABLNotificationView: UIView

// Shows a notification with the given number of peers.
+(void)showNotificationMessage:(size_t)numberOfPeers;

@end
