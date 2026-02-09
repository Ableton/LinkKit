// Copyright: 2018, Ableton AG, Berlin. All rights reserved.

#pragma once

#include <UIKit/UIKit.h>

#define ABLLinkEnabledKey @"ABLLinkEnabledKey"
#define ABLNotificationEnabledKey @"ABLNotificationEnabled"
#define ABLLinkStartStopSyncSupportedKey @"ABLLinkStartStopSyncSupported"
#define ABLLinkStartStopSyncEnabledKey @"ABLStartStopSyncEnabled"
#define ABLLinkAudioSupportedKey @"ABLLinkAudioSupported"
#define ABLLinkAudioEnabledKey @"ABLLinkAudioEnabled"
#define ABLLinkPeerName @"ABLLinkPeerName"
#define ABLLinkSuppressNotificationsKey @"ABLLinkSuppressNotifications"

struct ABLLink;

@interface ABLSettingsViewController: UITableViewController

@property (nonatomic) size_t numberOfPeers;

-(instancetype)initWithLink:(ABLLink*)link NS_DESIGNATED_INITIALIZER;
-(void)deinit;

@end
