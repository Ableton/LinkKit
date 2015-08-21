// Copyright: 2015, Ableton AG, Berlin. All rights reserved.

#include <Foundation/Foundation.h>
#include "ABLSync.h"

@interface AudioEngine : NSObject

@property (nonatomic) Float64 bpm;
@property (readonly, nonatomic) Float64 beatTime;
@property (nonatomic) Float64 quantum;
@property (nonatomic) BOOL isPlaying;
@property (readonly, nonatomic) BOOL isSyncEnabled;
@property (readonly, nonatomic) ABLSyncRef syncRef;

- (void)start;
- (void)stop;

@end
