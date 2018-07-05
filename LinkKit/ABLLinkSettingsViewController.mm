// Copyright: 2018, Ableton AG, Berlin. All rights reserved.

#include "ABLLinkSettingsViewController.h"
#include "detail/ABLLinkAggregate.h"

@implementation ABLLinkSettingsViewController

+ (instancetype)instance:(ABLLinkRef)ablLink {
  if (ablLink)
  {
    return (ABLLinkSettingsViewController*)ablLink->mpSettingsViewController;
  }
  else
  {
    return nil;
  }
}

- (instancetype)init {
  return nil;
}

@end
