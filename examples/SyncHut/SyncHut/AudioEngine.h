// Copyright: 2015, Ableton AG, Berlin. All rights reserved.

#include <Foundation/Foundation.h>
#include "ABLSync.h"

@interface AudioEngine : NSObject

// The audio engine owns the sync instance but makes it available to the
// application layer via this property
@property (nonatomic, readonly) ABLSyncRef ablSync;

- (void)start;
- (void)stop;

@end

