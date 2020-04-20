// Copyright: 2018, Ableton AG, Berlin. All rights reserved.

#include <Foundation/Foundation.h>
#include <UIKit/UIKit.h>
#include <string>
#include "ABLNotificationView.h"
#include "../detail/ABLSettingsViewController.h"
#include "../detail/LocalizableString.h"

// UIViewController subclass which forwards status bar appearance
// methods and the shouldAutorotate call to the forwardedVC view controller.
@interface _ABLForwardingVC: UIViewController
-(instancetype)initWithForwardedVC:(UIViewController*)viewController;
@end

@implementation _ABLForwardingVC
{
  __weak UIViewController* _forwardedVC;
}

-(instancetype)initWithForwardedVC:(UIViewController*)viewController
{
  if (self = [super init])
  {
    _forwardedVC = viewController;
  }
  return self;
}

-(BOOL)shouldAutorotate
{
  UIViewController* topVC = _forwardedVC;
  while (topVC.presentedViewController)
  {
    topVC = topVC.presentedViewController;
  }
  return [topVC shouldAutorotate];
}

- (BOOL)prefersStatusBarHidden
{
  return [_forwardedVC prefersStatusBarHidden];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
  return [_forwardedVC preferredStatusBarStyle];
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
  return [_forwardedVC preferredStatusBarUpdateAnimation];
}

@end

// UIWindow subclass which exposes forwardedRootVC as its own root VC. It's useful
// when we want to have the status bar appearance driven by root VC of other
// window (typically the key window).
@interface _ABLNotificationWindow: UIWindow
@property (nonatomic, weak) UIViewController* forwardedRootVC;
@end

@implementation _ABLNotificationWindow

-(void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)setForwardedRootVC:(UIViewController *)forwardedRootVC
{
  _forwardedRootVC = forwardedRootVC;
  self.rootViewController = [[_ABLForwardingVC alloc]
                             initWithForwardedVC:forwardedRootVC];
}

@end

// Appearance constants
static NSTimeInterval const kNotificationDuration = 2.0;
static NSTimeInterval const kSlideInAnimationDuration = 0.33;
static NSTimeInterval const kSlideOutAnimationDuration = 0.23;
static UIColor* const kBackgroundColor = [UIColor colorWithRed:64./255. green:211./255. blue:178./255. alpha:1.];
static UIColor* const kTextColor = [UIColor whiteColor];
static CGFloat const kHeaderFontSize = 16.0;
static CGFloat const kNotificationHeight = 34;


// String constants
static NSString* const kLinkZeroString =
[LocalizedString resourcesLocalizedString: @"LinkZero" comment: @""] ?: @"No Links";
static NSString* const kLinkOneString =
[LocalizedString resourcesLocalizedString: @"LinkOne" comment: @""] ?: @"1 Link";
static NSString* const kLinkOtherString =
[LocalizedString resourcesLocalizedString: @"LinkOther" comment: @""] ?: @"%u Links";


// The window for showing notification views. We need this to be able
// to show the notification view above the status bar.
static _ABLNotificationWindow* _notificationOverlayWindow;

// An instance of the currently visible notification. If nil, no
// notification is visible.
ABLNotificationView* _currentlyVisibleNotification;

// The top constraint of the currently visible notification. Usefull
// for animating slide in/out.
NSLayoutConstraint* _currentlyVisibleNotificationTopConstraint;

// The timer for the currently visible notification. If nil, no
// notification is visible.
NSTimer* _notificationDurationTimer;



@interface ABLNotificationView()
@property (strong, nonatomic) UILabel *messageLabel;
@end


@implementation ABLNotificationView

// ========================= Static methods ========================= //

+(void)showNotificationMessage:(size_t)numberOfPeers
{
  if([[NSUserDefaults standardUserDefaults] boolForKey:ABLNotificationEnabledKey] &&
     [UIApplication sharedApplication].applicationState == UIApplicationStateActive)
  {
    [self flashNotificationInIfNeeded];
    NSString* text = [self createNotificationTextForNumberOfPeers:numberOfPeers];
    [self updateNotificationText:text];
  }
}

+(void)flashNotificationInIfNeeded
{
  if (_currentlyVisibleNotification != nil)
  {
    // There is a visible notification on the screen already,
    // we need to just reset the visibility timer, that's all.
    [self resetNotificationDurationTimer];
    return;
  }

  [self createAndAnimateNotificationIn];
}

+(NSString*)createNotificationTextForNumberOfPeers:(size_t)numberOfPeers
{
  NSString* rawString;

  if (numberOfPeers == 0)
  {
    rawString = kLinkZeroString;
  }
  else if (numberOfPeers == 1)
  {
    rawString = kLinkOneString;
  }
  else
  {
    rawString = kLinkOtherString;
  }
  return  [NSString stringWithFormat:rawString, numberOfPeers];
}

+(void)updateNotificationText:(NSString*)text
{
  _currentlyVisibleNotification.messageLabel.text = text;
}

+(UIWindow *)notificationWindow
{
    if (@available(iOS 13.0, *))
    {
      for (UIScene *scene in UIApplication.sharedApplication.connectedScenes)
      {
        if (scene != nil && scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]])
        {
          for (UIWindow* window in ((UIWindowScene *)scene).windows)
          {
            if (window.isKeyWindow)
            {
              return window;
            }
          }
        }
      }
      return nil;
    }
    else
    {
      #pragma clang diagnostic ignored "-Wdeprecated-declarations"
      return UIApplication.sharedApplication.keyWindow;
      #pragma clang diagnostic pop
    }
}

+(void)createAndAnimateNotificationIn
{
  [self prepareNotificationWindowIfNeeded];

  _ABLNotificationWindow* window = _notificationOverlayWindow;
  UIWindow* keyWindow = [self notificationWindow];
  if (keyWindow == nil)
  {
      return;
  }
    
  window.frame = keyWindow.frame;

  // Assign forwarded root VC to properly handle status bar updates
  window.forwardedRootVC = keyWindow.rootViewController;

  ABLNotificationView* notification = [ABLNotificationView new];
  notification.userInteractionEnabled = NO;

  [_notificationOverlayWindow addSubview:notification];
  [notification setTranslatesAutoresizingMaskIntoConstraints:NO];

  NSDictionary* views = NSDictionaryOfVariableBindings(notification);
  CGFloat notificationHeight = self.preferredNotificationHeight;

  [window addConstraints:
   [NSLayoutConstraint constraintsWithVisualFormat:@"|[notification]|"
                                           options:0
                                           metrics:nil
                                             views:views]];

  NSLayoutConstraint* heightConstraint =
    [NSLayoutConstraint constraintWithItem:notification
                                 attribute:NSLayoutAttributeHeight
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:nil
                                 attribute:NSLayoutAttributeNotAnAttribute
                                multiplier:1
                                  constant:notificationHeight];

  NSLayoutConstraint* topConstraint =
    [NSLayoutConstraint constraintWithItem:notification
                                 attribute:NSLayoutAttributeTop
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:window
                                 attribute:NSLayoutAttributeTop
                                multiplier:1
                                  constant:-notificationHeight];

  [window addConstraints:@[heightConstraint, topConstraint]];
  _currentlyVisibleNotification = notification;
  _currentlyVisibleNotificationTopConstraint = topConstraint;

  // Layout everything to prepare the start position for the slide-in animation
  [window layoutIfNeeded];

  // Make the window visible
  window.hidden = NO;

  [UIView animateWithDuration:kSlideInAnimationDuration animations:^{
    // Animate the slide-in
    topConstraint.constant = 0;
    [window layoutIfNeeded];

  } completion:^(BOOL finished) {
    [self resetNotificationDurationTimer];
  }];
}

+(void)prepareNotificationWindowIfNeeded
{
  // Create the window if needed
  if (_notificationOverlayWindow == nil)
  {
    _notificationOverlayWindow = [_ABLNotificationWindow new];
    _notificationOverlayWindow.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _notificationOverlayWindow.backgroundColor = [UIColor clearColor];
    _notificationOverlayWindow.userInteractionEnabled = NO;
  }

  [_notificationOverlayWindow setWindowLevel:UIWindowLevelStatusBar + 1];
}

+(void)resetNotificationDurationTimer
{
  [_notificationDurationTimer invalidate];

  _notificationDurationTimer = [NSTimer scheduledTimerWithTimeInterval:kNotificationDuration
                                                                target:self
                                                              selector:@selector(dismissNotificationIfNeeded)
                                                              userInfo:nil
                                                               repeats:NO];
}

+(void)dismissNotificationIfNeeded
{
  if (_currentlyVisibleNotification == nil) { return; }

  // We create a local copy and reset the shared value. If there is another
  // notification coming in while we animate the slide-out of the old
  // notification, it will be handled as a completely new notification.
  UIView* notification = _currentlyVisibleNotification;
  _currentlyVisibleNotification = nil;

  NSLayoutConstraint* topConstraint = _currentlyVisibleNotificationTopConstraint;
  _currentlyVisibleNotificationTopConstraint = nil;

  CGFloat notificationHeight = self.preferredNotificationHeight;

  [UIView animateWithDuration:kSlideOutAnimationDuration
                   animations:^{
                     topConstraint.constant = -notificationHeight;
                     [notification.superview layoutIfNeeded];
                   } completion:^(BOOL finished) {
                     [notification removeFromSuperview];

                     // Hide the window if there is no other notification
                     if (_currentlyVisibleNotification == nil)
                     {
                       _notificationOverlayWindow.hidden = YES;
                     }
                   }];
}

+(CGFloat)preferredNotificationHeight
{
  CGFloat notificationHeight = kNotificationHeight;
  if (@available(iOS 11.0, *))
  {
    UIWindow* keyWindow = [self notificationWindow];
    if (keyWindow != nil)
    {
      // Add the top area inset to the notification height
      notificationHeight += keyWindow.safeAreaInsets.top;
    }
  }

  return notificationHeight;
}

// ========================= Instance methods ========================= //

-(instancetype)init
{
  if ((self = [super init]))
  {
    self.backgroundColor = kBackgroundColor;
  }
  return self;
}

-(UILabel*)messageLabel {
  if (_messageLabel == nil)
  {
    _messageLabel = [UILabel new];
    _messageLabel.textColor = kTextColor;
    _messageLabel.font = [UIFont systemFontOfSize:kHeaderFontSize];
    _messageLabel.textAlignment = NSTextAlignmentCenter;
    _messageLabel.adjustsFontSizeToFitWidth = YES;

    _messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_messageLabel];

    NSDictionary* views = @{@"label": _messageLabel};
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"|-[label]-|" options:0 metrics:nil views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:[label]-|" options:0 metrics:nil views:views]];
  }

  return _messageLabel;
}

@end
