// Copyright: 2018, Ableton AG, Berlin. All rights reserved.

#include "AppDelegate.h"
#include "ViewController.h"

@implementation AppDelegate

@synthesize window;

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    #pragma unused(application, launchOptions)
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    #pragma unused(application)

    ViewController *controller = (ViewController*)window.rootViewController;
    if (!controller.isPlaying) {
        // Deactivate Link if the app is not playing so that it won't
        // continue to browse for connections while in the background.
        ABLLinkSetActive(controller.linkRef, false);
        [controller enableAudioEngine:NO];
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    #pragma unused(application)

    ViewController *controller = (ViewController*)window.rootViewController;
    // Unconditionally activate link when becoming active. If the app is
    // active, Link should be active.
    ABLLinkSetActive(controller.linkRef, true);
    [controller enableAudioEngine:YES];
}

@end
