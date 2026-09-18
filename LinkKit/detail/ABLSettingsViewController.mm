// Copyright: 2018, Ableton AG, Berlin. All rights reserved.

#include <functional>
#include <tuple>
#include <string>
#include <array>
#include "ABLSettingsViewController.h"
#include "detail/ABLObjCUtils.h"
#include "detail/ABLLinkAggregate.h"
#include "detail/LocalizableString.h"

namespace
{

void initUserDefaultFlag(NSString* key, BOOL defaultVal)
{
  if (![[NSUserDefaults standardUserDefaults] objectForKey:key])
  {
    [[NSUserDefaults standardUserDefaults] setBool:defaultVal forKey:key];
  }
}

void initUserDefaultObject(NSString* key, NSObject*defaultVal)
{
  if (![[NSUserDefaults standardUserDefaults] objectForKey:key])
  {
    [[NSUserDefaults standardUserDefaults] setObject:defaultVal forKey:key];
  }
}

NSString* defaultPeerName() {
  NSBundle* mainBundle = [NSBundle mainBundle];
  return [mainBundle objectForInfoDictionaryKey:ABLLinkPeerName] ?: @"Link App";
}

void initPeerName() {
  initUserDefaultObject(ABLLinkPeerName, defaultPeerName());
}

BOOL isStartStopSyncSupported()
{
  NSBundle* mainBundle = [NSBundle mainBundle];
  return [[mainBundle objectForInfoDictionaryKey:ABLLinkStartStopSyncSupportedKey] boolValue];
}

BOOL isLinkAudioSupported()
{
  NSBundle* mainBundle = [NSBundle mainBundle];
  return [[mainBundle objectForInfoDictionaryKey:ABLLinkAudioSupportedKey] boolValue];
}

} // unnamed


// String constants
static NSString* const kTitleString = @"Ableton Link";
static NSString* const kDescriptionLongString =
[LocalizedString resourcesLocalizedString: @"DescriptionLong" comment: @""]
?: @"Link allows you to play in time with other Link-enabled peers that are on the same network.\n \nTo create or join a session, enable Link.";
static NSString* const kLinkHyperlinkString =
[LocalizedString resourcesLocalizedString: @"LinkHyperlink" comment: @""]
?: @"Learn more at ";
static NSString* const kLinkHyperlinkLink = @"www.ableton.com/link";

static NSString* const kBrowsingString =
[LocalizedString resourcesLocalizedString: @"Browsing" comment: @""]
?: @"Browsing for Link-enabled peers...";

static NSString* const kInAppNotificationTitleString =
[LocalizedString resourcesLocalizedString: @"InAppNotificationTitle" comment: @""]
?: @"In-app notifications";
static NSString* const kInAppNotificationSubtitleString =
[LocalizedString resourcesLocalizedString: @"InAppNotificationSubtitle" comment: @""]
?: @"Get notified when apps join or leave";

static NSString* const kSyncStartStopTitleString =
[LocalizedString resourcesLocalizedString: @"SyncStartStopTitle" comment: @""]
?: @"Sync Start/Stop";
static NSString* const kSyncStartStopSubtitleString =
[LocalizedString resourcesLocalizedString: @"SyncStartStopSubtitle" comment: @""]
?: @"Send and listen to Start/Stop commands";

static NSString* const kLinkAudioTitleString =
[LocalizedString resourcesLocalizedString: @"EnableLinkAudioTitle" comment: @""]
?: @"Enable Audio";
static NSString* const kLinkAudioSubtitleString =
[LocalizedString resourcesLocalizedString: @"EnableLinkAudioSubtitle" comment: @""]
?: @"Share audio with Link peers";

static NSString* const kPeerNameTitleString =
[LocalizedString resourcesLocalizedString: @"PeerNameTitle" comment: @""]
?: @"Peer Name";
static NSString* const kPeerNameSubtitleString =
[LocalizedString resourcesLocalizedString: @"PeerNameSubtitle" comment: @""]
?: @"Other Link peers see that name";

static NSString* const kConnectedPeersSectionTitleString =
[LocalizedString resourcesLocalizedString: @"ConnectedPeersSectionTitle" comment: @""]
?: @"CONNECTED PEERS";

static NSString* const kPeersConnectedZeroString =
[LocalizedString resourcesLocalizedString: @"PeersConnectedZero" comment: @""]
?: @"No peers connected";
static NSString* const kPeersConnectedOneString =
[LocalizedString resourcesLocalizedString: @"PeersConnectedOne" comment: @""]
?: @"Connected to 1 peer";
static NSString* const kPeersConnectedManyString =
[LocalizedString resourcesLocalizedString: @"PeersConnectedMany" comment: @""]
?: @"Connected to %zu peers";


// Section indices
static NSInteger const kLinkEnableDisableSection = 0;
static NSInteger const kDetailSettingsSection = 1;
static NSInteger const kConnectedPeersSection = 2;

typedef NS_ENUM(NSInteger, ABLDetailRow)
{
  ABLDetailRowNotifications,
  ABLDetailRowStartStopSync,
  ABLDetailRowLinkAudio,
  ABLDetailRowPeerName,
};


@implementation ABLSettingsViewController
{
  ABLLink* _ablLink;

  UITableViewCell* _enableDisableCell;
  UITextView* _enableDisableCellFooter;
  UITextView* _moreInfoLinkTextView;

  UITableViewCell* _notificationsCell;
  UITableViewCell* _syncStartStopCell;
  UITableViewCell* _audioCell;
  UITableViewCell* _peerNameCell;
  UITextField* _peerNameTextField;

  UITableViewCell* _statusCell;

  UIView* _connectedAppsFooterView;
  NSLayoutConstraint* _connectedAppsLabelLeadingConstraint;

  BOOL _originalToolbarHidden;

  BOOL _detailSectionsVisible;

  BOOL _footerMarginsUpdateScheduled;
}

ABL_NOT_IMPLEMENTED_INITIALIZER(initWithCoder:(NSCoder *)aDecoder)
ABL_NOT_IMPLEMENTED_INITIALIZER(initWithStyle:(UITableViewStyle)style)

// ==== <iOS8 FIX> - remove when we drop support for iOS8
// On iOS8, initWithStyle designed initializer doesn't work properly
// and doesn't call [super initWithNibName] but [super init] instead.
// This results in calling initWithNibName initialier on the subclass.
// More info: http://www.openradar.me/20549233

_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wobjc-designated-initializers\"") \
- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  return [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
}
_Pragma("clang diagnostic pop")

// ==== </iOS8 FIX>

-(instancetype)initWithLink:(ABLLink *)link
{
  if (self = [super initWithStyle:UITableViewStyleGrouped])
  {
    _ablLink = link;
    self.title = kTitleString;

    self.tableView.backgroundView = [UIView new];
    if (@available(iOS 13.0, *))
    {
      self.tableView.backgroundView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    }
    else
    {
      #pragma clang diagnostic ignored "-Wdeprecated-declarations"
      self.tableView.backgroundView.backgroundColor = [UIColor groupTableViewBackgroundColor];
      #pragma clang diagnostic pop
    }

    // Set up default values
    initUserDefaultFlag(ABLLinkEnabledKey, NO);
    initUserDefaultFlag(ABLNotificationEnabledKey, YES);
    initUserDefaultFlag(ABLLinkStartStopSyncEnabledKey, NO);
    initUserDefaultFlag(ABLLinkAudioEnabledKey, NO);
    initPeerName();

    _detailSectionsVisible =
      [[NSUserDefaults standardUserDefaults] boolForKey:ABLLinkEnabledKey];
  }
  return self;
}

-(void)deinit
{
  _ablLink = nil;
}

-(void)setNumberOfPeers:(size_t)numberOfPeers
{
  _numberOfPeers = numberOfPeers;
  [self updateConnectedPeersCount:numberOfPeers];
}

-(void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];

  if (_detailSectionsVisible != [self isEnabled])
  {
    _detailSectionsVisible = [self isEnabled];
    [self.tableView reloadData];
  }

  _originalToolbarHidden = self.navigationController.toolbarHidden;
  [self.navigationController setToolbarHidden:NO];
}

-(void)viewWillDisappear:(BOOL)animated
{
  [super viewWillDisappear:animated];
  [self setToolbarItems:nil];
  [self.navigationController setToolbarHidden:_originalToolbarHidden];
}

// ========================= Cells ========================= //
#pragma mark - Cells

-(UITableViewCell*)enableDisableCell
{
  if (_enableDisableCell == nil)
  {
    _enableDisableCell = [[UITableViewCell alloc]
                          initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];

    _enableDisableCell.textLabel.text = kTitleString;
    UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
    BOOL enabled = [self isEnabled];
    switchView.on = enabled;
    [switchView addTarget:self action:@selector(enableLink:) forControlEvents:UIControlEventValueChanged];
    _enableDisableCell.accessoryView = switchView;

  }
  return _enableDisableCell;
}

-(UITableViewCell*)notificationsCell
{
  if (_notificationsCell == nil)
  {
    _notificationsCell = [[UITableViewCell alloc]
                          initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];

    _notificationsCell.textLabel.text = kInAppNotificationTitleString;
    _notificationsCell.detailTextLabel.text = kInAppNotificationSubtitleString;
    _notificationsCell.detailTextLabel.textColor = [UIColor grayColor];

    UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
    switchView.on = [[NSUserDefaults standardUserDefaults] boolForKey:ABLNotificationEnabledKey];
    [switchView addTarget:self action:@selector(enableNotifications:) forControlEvents:UIControlEventValueChanged];

    _notificationsCell.accessoryView = switchView;

  }
  return _notificationsCell;
}

-(UITableViewCell*)syncStartStopCell
{
  if (_syncStartStopCell == nil)
  {
    _syncStartStopCell = [[UITableViewCell alloc]
                          initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];

    _syncStartStopCell.textLabel.text = kSyncStartStopTitleString;
    _syncStartStopCell.detailTextLabel.text = kSyncStartStopSubtitleString;
    _syncStartStopCell.detailTextLabel.textColor = [UIColor grayColor];

    UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
    switchView.on = [self isStartStopSyncEnabled];
    [switchView addTarget:self action:@selector(enableStartStopSync:) forControlEvents:UIControlEventValueChanged];

    _syncStartStopCell.accessoryView = switchView;

  }
  return _syncStartStopCell;
}

-(UITableViewCell*)audioCell
{
  if (_audioCell == nil)
  {
    _audioCell = [[UITableViewCell alloc]
                          initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];

    _audioCell.textLabel.text = kLinkAudioTitleString;
    _audioCell.detailTextLabel.text = kLinkAudioSubtitleString;
    _audioCell.detailTextLabel.textColor = [UIColor grayColor];

    UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
    switchView.on = [self isLinkAudioEnabled];
    [switchView addTarget:self action:@selector(enableLinkAudio:) forControlEvents:UIControlEventValueChanged];

    _audioCell.accessoryView = switchView;
  }
  return _audioCell;
}


-(void)updatePeerNameTextColor
{
  if ([_peerNameTextField.text isEqualToString:defaultPeerName()]) {
    _peerNameTextField.textColor = [UIColor grayColor];
  } else {
    _peerNameTextField.textColor = nil;
  }
}

-(UITableViewCell*)peerNameCell
{
  if (_peerNameCell == nil)
  {
    _peerNameCell = [[UITableViewCell alloc]
                          initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];

    _peerNameCell.textLabel.text = kPeerNameTitleString;
    _peerNameCell.detailTextLabel.text = kPeerNameSubtitleString;
    _peerNameCell.detailTextLabel.textColor = [UIColor grayColor];

    _peerNameTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 150, 30)];
    _peerNameTextField.text = [[NSUserDefaults standardUserDefaults] objectForKey:ABLLinkPeerName];
    [self updatePeerNameTextColor];
    _peerNameTextField.textAlignment = NSTextAlignmentRight;
    _peerNameTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    _peerNameTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    [_peerNameTextField addTarget:self action:@selector(onPeerName:) forControlEvents:UIControlEventEditingDidEnd];
    _peerNameCell.accessoryView = _peerNameTextField;
  }
  return _peerNameCell;
}

-(UITableViewCell*)statusCell
{
  if (_statusCell == nil)
  {
    _statusCell = [[UITableViewCell alloc]
                          initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    [self updateConnectedPeersCount:self.numberOfPeers];
  }
  return _statusCell;
}

-(void)animatedEnabledChange:(BOOL)enabled
{
  if (_detailSectionsVisible == enabled)
  {
    return;
  }
  _detailSectionsVisible = enabled;

  NSMutableIndexSet* indexSet = [NSMutableIndexSet indexSet];
  [indexSet addIndex:kDetailSettingsSection];
  [indexSet addIndex:kConnectedPeersSection];

  [self.tableView beginUpdates];

  if (enabled)
  {
    [self.tableView insertSections:indexSet withRowAnimation:UITableViewRowAnimationFade];
  }
  else
  {
    [self.tableView deleteSections:indexSet withRowAnimation:UITableViewRowAnimationFade];
  }

  [self updateEnableDisableCellFooterVisibility];

  [self.tableView endUpdates];
}

-(void)updateConnectedPeersCount:(size_t)count
{
  NSString* rawString;
  switch (count)
  {
    case 0:
      rawString = kPeersConnectedZeroString;
      break;

    case 1:
      rawString = kPeersConnectedOneString;
      break;

    default:
      rawString = kPeersConnectedManyString;
  }

  NSString* finalText = [NSString stringWithFormat:rawString, count];
  [self statusCell].textLabel.text = finalText;
}

- (void)viewLayoutMarginsDidChange
{
  [super viewLayoutMarginsDidChange];

  if (!_footerMarginsUpdateScheduled)
  {
    _footerMarginsUpdateScheduled = YES;
    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      __typeof(self) strongSelf = weakSelf;
      if (strongSelf != nil)
      {
        strongSelf->_footerMarginsUpdateScheduled = NO;
        [strongSelf updateFooterLayoutMargins];
      }
    });
  }
}

-(void)updateFooterLayoutMargins
{
  const UIEdgeInsets margins = self.tableView.layoutMargins;

  if (_enableDisableCellFooter != nil)
  {
    UIEdgeInsets contentInset = _enableDisableCellFooter.contentInset;
    contentInset.left = margins.left;
    _enableDisableCellFooter.contentInset = contentInset;

    UIEdgeInsets textContainerInset = _enableDisableCellFooter.textContainerInset;
    textContainerInset.right = margins.right;
    _enableDisableCellFooter.textContainerInset = textContainerInset;
  }

  _connectedAppsLabelLeadingConstraint.constant = margins.left;

  [self.tableView beginUpdates];
  [self.tableView endUpdates];
}

-(void)updateEnableDisableCellFooterVisibility
{
  [self enableDisableCellFooter].hidden = _detailSectionsVisible;
}

// ========================= Footer ==================================== //
#pragma mark - Footer

-(UITextView*)enableDisableCellFooter
{
  if (_enableDisableCellFooter == nil)
  {
    UITextView* textView = [UITextView new];
    textView.editable = NO;
    textView.scrollEnabled = NO;
    textView.selectable = YES;
    textView.font = [UIFont systemFontOfSize:13];
    textView.backgroundColor = [UIColor clearColor];
    textView.textContainer.lineFragmentPadding = 0;

    UIEdgeInsets insets = textView.contentInset;
    insets.left = self.tableView.layoutMargins.left;
    textView.contentInset = insets;

    UIEdgeInsets textContainerInsets = textView.textContainerInset;
    textContainerInsets.right = self.tableView.layoutMargins.right;
    textView.textContainerInset = textContainerInsets;

    textView.hidden = _detailSectionsVisible;
    
    // Setting textView.dataDetectorTypes = UIDataDetectorTypeLink blocks the audio thread,
    // when a debugger is attached. This leads to audio dropouts when initializing the view
    // controller. As a workaround the URL is set manually.
    // This can lead to audio dropouts when tapping the link while running with a debugger
    // attached - which is less prominent during debugging.
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n\n%@%@", kDescriptionLongString, kLinkHyperlinkString, kLinkHyperlinkLink]];
    CGFloat hyperlinkBegin = [kDescriptionLongString length] + 2 + [kLinkHyperlinkString length];
    [text addAttribute:NSForegroundColorAttributeName value:[UIColor grayColor] range:NSMakeRange(0, hyperlinkBegin)];
    [text addAttribute:NSForegroundColorAttributeName value:[UIColor blueColor] range:NSMakeRange(hyperlinkBegin, [kLinkHyperlinkLink length])];
    NSURL *url = [NSURL URLWithString:@"http://www.ableton.com/link"];
    [text addAttribute: NSLinkAttributeName value:url range: NSMakeRange(hyperlinkBegin, [kLinkHyperlinkLink length])];
    textView.attributedText = text;

    _enableDisableCellFooter = textView;
  }

  return _enableDisableCellFooter;
}

-(UIView*)connectedAppsFooterView
{
  if (_connectedAppsFooterView == nil)
  {
    _connectedAppsFooterView = [UIView new];

    UILabel *label = [UILabel new];
    label.font = [UIFont systemFontOfSize:13];
    label.textColor = [UIColor lightGrayColor];
    label.text = kBrowsingString;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [_connectedAppsFooterView addSubview:label];

    UIActivityIndicatorView *activityIndicator;
    if (@available(iOS 13.0, *))
    {
      activityIndicator = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    }
    else
    {
      activityIndicator = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    }
    [activityIndicator startAnimating];

    // Resizing through CoreGraphics because the size is fixed
    CGAffineTransform resizeFactor = CGAffineTransformMakeScale(0.8f, 0.8f);
    activityIndicator.transform = resizeFactor;

    activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [_connectedAppsFooterView addSubview: activityIndicator];

    _connectedAppsLabelLeadingConstraint =
      [NSLayoutConstraint constraintWithItem:label
                                   attribute:NSLayoutAttributeLeading
                                   relatedBy:NSLayoutRelationEqual
                                      toItem:_connectedAppsFooterView
                                   attribute:NSLayoutAttributeLeading
                                  multiplier:1
                                    constant:self.tableView.layoutMargins.left];
    [_connectedAppsFooterView addConstraint:_connectedAppsLabelLeadingConstraint];

    NSDictionary* views = NSDictionaryOfVariableBindings(label, activityIndicator);
    [_connectedAppsFooterView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"[label]-[activityIndicator]"
                                             options:0
                                             metrics:nil
                                               views:views]];

    [_connectedAppsFooterView addConstraint:[NSLayoutConstraint constraintWithItem:label
                                                                         attribute:NSLayoutAttributeCenterY
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:_connectedAppsFooterView
                                                                         attribute:NSLayoutAttributeCenterY
                                                                        multiplier:1
                                                                          constant:0]];

    [_connectedAppsFooterView addConstraint:[NSLayoutConstraint constraintWithItem:activityIndicator
                                                                         attribute:NSLayoutAttributeCenterY
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:_connectedAppsFooterView
                                                                         attribute:NSLayoutAttributeCenterY
                                                                        multiplier:1
                                                                          constant:0]];
  }
  return _connectedAppsFooterView;
}

// ========================= Data Source ========================= //
#pragma mark - Data Source

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return _detailSectionsVisible ? 3 : 1;
}

-(NSArray<NSNumber*>*)detailRows
{
  NSMutableArray<NSNumber*>* rows = [NSMutableArray array];
  [rows addObject:@(ABLDetailRowNotifications)];
  if (isStartStopSyncSupported())
  {
    [rows addObject:@(ABLDetailRowStartStopSync)];
  }
  if (isLinkAudioSupported())
  {
    [rows addObject:@(ABLDetailRowLinkAudio)];
    [rows addObject:@(ABLDetailRowPeerName)];
  }
  return rows;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  switch (section) {
    case kLinkEnableDisableSection:
      return 1;

    case kDetailSettingsSection:
      return (NSInteger)[self detailRows].count;

    case kConnectedPeersSection:
      return 1;

    default:
      NSAssert(NO, @"Invalid section number");
      return -1;
  }
}

-(UITableViewCell*)detailSettingsCellForRow:(NSInteger)row
{
  NSArray<NSNumber*>* rows = [self detailRows];
  if (row < 0 || row >= (NSInteger)rows.count)
  {
    NSAssert(NO, @"Invalid row in the detail settings section");
    return [UITableViewCell new];
  }

  switch ((ABLDetailRow)rows[(NSUInteger)row].integerValue)
  {
    case ABLDetailRowNotifications:
      return [self notificationsCell];

    case ABLDetailRowStartStopSync:
      return [self syncStartStopCell];

    case ABLDetailRowLinkAudio:
      return [self audioCell];

    case ABLDetailRowPeerName:
      return [self peerNameCell];
  }
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  switch (indexPath.section) {
    case kLinkEnableDisableSection:
      return [self enableDisableCell];

    case kDetailSettingsSection:
      return [self detailSettingsCellForRow:indexPath.row];

    case kConnectedPeersSection:
      return [self statusCell];

    default:
      NSAssert(NO, @"Invalid indexPath");
      return [UITableViewCell new];
  }
}

-(NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  if (section == kConnectedPeersSection)
  {
    return kConnectedPeersSectionTitleString;
  }
  return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
  if (section == kLinkEnableDisableSection && !_detailSectionsVisible)
  {
    return kDescriptionLongString;
  }
  return nil;
}

-(UIView*)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
  switch (section)
  {
    case kLinkEnableDisableSection:
      return [self enableDisableCellFooter];

    case kConnectedPeersSection:
      return [self connectedAppsFooterView];

    default:
      return nil;
  }
}

-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
  switch (section) {
    case kLinkEnableDisableSection:
    {
      if (_detailSectionsVisible)
      {
        return 0;
      }
      else
      {
        UIView* footer = [self tableView:tableView viewForFooterInSection:section];
        CGSize preferredSize = [footer systemLayoutSizeFittingSize:CGSizeMake(tableView.bounds.size.width, CGFLOAT_MAX)];

        [footer setNeedsLayout];
        [footer setNeedsDisplay];

        return preferredSize.height;
      }
    }

    case kConnectedPeersSection:
      return 44.; // Similar to the cell default height

    default:
      return 0;
  }
}

// ========================= Delegate ========================= //
#pragma mark - Delegate

-(BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
  return NO;
}

// ========================= Link ========================= //
#pragma mark - Link

-(BOOL)isEnabled
{
  return _ablLink->mEnabled;
}

-(void)enableLink:(UISwitch*)sender
{
  BOOL enabled = sender.on;

  [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:ABLLinkEnabledKey];
  [[NSUserDefaults standardUserDefaults] synchronize];

  if (!enabled)
  {
    // We need to reset the number of peers manually
    [self setNumberOfPeers:0];
  }

  if (enabled != _ablLink->mEnabled)
  {
    _ablLink->mEnabled = enabled;
    _ablLink->mpCallbacks->mIsEnabledCallback(enabled);
    _ablLink->updateEnabled();

    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf animatedEnabledChange:enabled];
    });
  }
}

-(void)enableNotifications:(UISwitch*)sender
{
  [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:ABLNotificationEnabledKey];
}

-(BOOL)isStartStopSyncEnabled
{
  return _ablLink->isStartStopSyncEnabled();
}

-(BOOL)isLinkAudioEnabled
{
  return _ablLink->isLinkAudioEnabled();
}

-(void)enableStartStopSync:(UISwitch*)sender
{
  BOOL enabled = sender.on;

  [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:ABLLinkStartStopSyncEnabledKey];
  [[NSUserDefaults standardUserDefaults] synchronize];

  if (enabled != _ablLink->isStartStopSyncEnabled())
  {
    _ablLink->enableStartStopSync(enabled);
    _ablLink->mpCallbacks->mIsStartStopSyncEnabledCallback(enabled);
  }
}

-(void)enableLinkAudio:(UISwitch*)sender
{
  BOOL enabled = sender.on;

  [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:ABLLinkAudioEnabledKey];
  [[NSUserDefaults standardUserDefaults] synchronize];

  if (enabled != _ablLink->isLinkAudioEnabled())
  {
    _ablLink->enableLinkAudio(enabled);
    _ablLink->mpCallbacks->mIsAudioEnabledCallback(enabled);
  }
}

-(void)onPeerName:(UITextField*)textField
{
  NSLog(@"Peer Name: %@", textField.text);

  if (textField.text.length == 0) {
    textField.text = defaultPeerName();
  }

  NSString* name = textField.text;

  [[NSUserDefaults standardUserDefaults] setObject:name forKey:ABLLinkPeerName];
  [[NSUserDefaults standardUserDefaults] synchronize];

  [self updatePeerNameTextColor];

  _ablLink->setPeerName([name UTF8String]);
}

@end
