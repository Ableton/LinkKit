// Copyright: 2020, Ableton AG, Berlin. All rights reserved.

#include "LocalizableString.h"

@implementation LocalizedString

+(NSString *)resourcesLocalizedString:(NSString*)key comment:(NSString*)comment {
  static NSBundle* bundle = nil;
  if (!bundle) {
    NSString* path = [[[NSBundle mainBundle] resourcePath]
                      stringByAppendingPathComponent:@"LinkKitResources.bundle"];
    bundle = [NSBundle bundleWithPath:path];
  }
  if (bundle == nil) {
    return nil;
  }
  return [bundle localizedStringForKey:key value:key table:nil];
}

@end
