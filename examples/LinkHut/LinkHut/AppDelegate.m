// Copyright: 2015, Ableton AG, Berlin. All rights reserved.

#import "AppDelegate.h"
#import "ViewController.h"

@implementation AppDelegate

@synthesize window;

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  #pragma unused(application, launchOptions)
  // Override point for customization after application launch.
  return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
  #pragma unused(application)
  /*
  Sent when the application is about to move from active to inactive state.
  This can occur for certain types of temporary interruptions (such as an
  incoming phone call or SMS message) or when the user quits the application
  and it begins the transition to the background state. Use this method to pause
  ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games
  should use this method to pause the game.
  */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
  #pragma unused(application)

  ViewController *controller = (ViewController*)window.rootViewController;
  if (!controller.isPlaying) {
    // Deactivate Link if the app is not playing so that it won't
    // continue to browse for connections while in the background.
    ABLLinkSetActive(controller.linkRef, false);
    [controller enableAudioEngine:NO];
  }
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  #pragma unused(application)
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
  #pragma unused(application)

  ViewController *controller = (ViewController*)window.rootViewController;
  // Unconditionally activate link when becoming active. If the app is
  // active, Link should be active.
  ABLLinkSetActive(controller.linkRef, true);
  [controller enableAudioEngine:YES];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
  #pragma unused(application)
  //Called when the application is about to terminate. Save data if appropriate.
}

@end
