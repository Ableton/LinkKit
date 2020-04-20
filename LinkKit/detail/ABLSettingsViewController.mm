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

BOOL isStartStopSyncSupported()
{
  NSBundle* mainBundle = [NSBundle mainBundle];
  return [[mainBundle objectForInfoDictionaryKey:ABLLinkStartStopSyncSupportedKey] boolValue];
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


@implementation ABLSettingsViewController
{
  ABLLink* _ablLink;

  UITableViewCell* _enableDisableCell;
  UITextView* _enableDisableCellFooter;
  UITextView* _moreInfoLinkTextView;

  UITableViewCell* _notificationsCell;
  UITableViewCell* _syncStartStopCell;

  UITableViewCell* _statusCell;

  UIView* _connectedAppsFooterView;

  BOOL _originalToolbarHidden;
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

    // Listen for layoutMargins changes to update cell layouts accordingly
    [self.tableView addObserver:self
                     forKeyPath:@"layoutMargins"
                        options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld
                        context:nil];
  }
  return self;
}

-(void)deinit
{
  [self.tableView removeObserver:self forKeyPath:@"layoutMargins" ];
  _ablLink = nil;
}

-(void)setNumberOfPeers:(size_t)numberOfPeers
{
  _numberOfPeers = numberOfPeers;
  [self updateConnectedPeersCount:numberOfPeers];
}

-(void)observeValueForKeyPath:(NSString *)keyPath
                     ofObject:(id)object
                       change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                      context:(void *)context
{
  if ([object isEqual:self.tableView] && [keyPath isEqualToString:@"layoutMargins"])
  {
    UIEdgeInsets oldMargin = ((NSValue*)change[NSKeyValueChangeOldKey]).UIEdgeInsetsValue;
    UIEdgeInsets newMargin = ((NSValue*)change[NSKeyValueChangeNewKey]).UIEdgeInsetsValue;
    if (!UIEdgeInsetsEqualToEdgeInsets(oldMargin, newMargin))
    {
      [self recreateAllCells];
    }
  }
}

-(void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];

  _originalToolbarHidden = self.navigationController.toolbarHidden;
  [self.navigationController setToolbarHidden:NO];

  [self updateToolbar];
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
  [self recreateAllCells];
}

-(void)recreateAllCells
{
  _enableDisableCell = nil;
  _enableDisableCellFooter = nil;
  _notificationsCell = nil;
  _syncStartStopCell = nil;
  _statusCell = nil;
  _connectedAppsFooterView = nil;

  [self.tableView reloadData];
}

-(void)updateEnableDisableCellFooterVisibility
{
  [self enableDisableCellFooter].hidden = [self isEnabled];
}

-(void)updateToolbar
{
  UITextView* moreInfoLinkTextView = [self moreInfoLinkTextView];
  [moreInfoLinkTextView sizeToFit];

  UIToolbar* toolbar = self.navigationController.toolbar;

  [toolbar setBackgroundImage:[UIImage new]
           forToolbarPosition:UIBarPositionAny
                   barMetrics:UIBarMetricsDefault];

  [toolbar setShadowImage:[UIImage new]
       forToolbarPosition:UIToolbarPositionAny];

  if (@available(iOS 13.0, *))
  {
    [toolbar setBackgroundColor:[UIColor systemGroupedBackgroundColor]];
  }
  else
  {
    [toolbar setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
  }
  [toolbar addSubview:moreInfoLinkTextView];

  UIBarButtonItem* item = [[UIBarButtonItem alloc] initWithCustomView:moreInfoLinkTextView];

  [self setToolbarItems:@[item]];
}

// ========================= Headers & Footers ========================= //
#pragma mark - Headers & Footers

-(UITextView*)moreInfoLinkTextView
{
  if (_moreInfoLinkTextView == nil)
  {
    UITextView* textView = [UITextView new];
    textView.editable = NO;
    textView.scrollEnabled = NO;
    textView.selectable = YES;
    textView.font = [UIFont systemFontOfSize:13];
    textView.textColor = [UIColor lightGrayColor];
    textView.backgroundColor = [UIColor clearColor];
    textView.textContainer.lineFragmentPadding = 0;

    // Setting textView.dataDetectorTypes = UIDataDetectorTypeLink blocks the audio thread,
    // when a debugger is attached. This leads to audio dropouts when initializing the view
    // controller. As a workaround the URL is set manually.
    // This can lead to audio dropouts when tapping the link while running with a debugger
    // attached - which is less prominent during debugging.
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@%@", kLinkHyperlinkString, kLinkHyperlinkLink]];
    [text addAttribute:NSForegroundColorAttributeName value:[UIColor lightGrayColor] range:NSMakeRange(0, [kLinkHyperlinkString length])];
    [text addAttribute:NSForegroundColorAttributeName value:[UIColor blueColor] range:NSMakeRange([kLinkHyperlinkString length], [kLinkHyperlinkLink length])];
    NSURL *url = [NSURL URLWithString:@"http://www.ableton.com/link"];
    [text addAttribute: NSLinkAttributeName value:url range: NSMakeRange([kLinkHyperlinkString length], [kLinkHyperlinkLink length])];
    textView.attributedText = text;
    
    _moreInfoLinkTextView = textView;
  }

  return _moreInfoLinkTextView;
}

-(UITextView*)enableDisableCellFooter
{
  if (_enableDisableCellFooter == nil)
  {
    UITextView* textView = [UITextView new];
    textView.editable = NO;
    textView.scrollEnabled = NO;
    textView.selectable = NO;
    textView.font = [UIFont systemFontOfSize:13];
    textView.textColor = [UIColor lightGrayColor];
    textView.backgroundColor = [UIColor clearColor];
    textView.textContainer.lineFragmentPadding = 0;

    UIEdgeInsets insets = textView.contentInset;
    insets.left = self.tableView.layoutMargins.left;
    textView.contentInset = insets;

    UIEdgeInsets textContainerInsets = textView.textContainerInset;
    textContainerInsets.right = self.tableView.layoutMargins.right;
    textView.textContainerInset = textContainerInsets;

    textView.hidden = [self isEnabled];
    textView.text = kDescriptionLongString;

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

    CGFloat leftInset = self.tableView.layoutMargins.left;

    NSDictionary* views = NSDictionaryOfVariableBindings(label, activityIndicator);
    [_connectedAppsFooterView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"|-leftInset-[label]-[activityIndicator]"
                                             options:0
                                             metrics:@{@"leftInset": @(leftInset)}
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
  return [self isEnabled] ? 3 : 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  switch (section) {
    case kLinkEnableDisableSection:
      return 1;

    case kDetailSettingsSection:
      return isStartStopSyncSupported() ? 2 : 1;

    case kConnectedPeersSection:
      return 1;

    default:
      NSAssert(NO, @"Invalid section number");
      return -1;
  }
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  switch (indexPath.section) {
    case kLinkEnableDisableSection:
      return [self enableDisableCell];

    case kDetailSettingsSection:
      if (indexPath.row == 0)
      {
        return [self notificationsCell];
      }
      else if (indexPath.row == 1)
      {
        return [self syncStartStopCell];
      }

    case kConnectedPeersSection:
      return [self statusCell];

    default:
      NSAssert(NO, @"Invalid indexPath");
      return nil;

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
  if (section == kLinkEnableDisableSection && ![self isEnabled])
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
      if ([self isEnabled])
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

    [self animatedEnabledChange:enabled];
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

@end
