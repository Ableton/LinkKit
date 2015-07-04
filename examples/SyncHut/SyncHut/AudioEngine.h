// Copyright: 2015, Ableton AG, Berlin. All rights reserved.

#include <Foundation/Foundation.h>

@interface AudioEngine : NSObject

- (void)startPlaying;
- (void)stopPlaying;
- (BOOL)isPlaying;
@property (nonatomic) Float64 bpm;
@property (readonly, nonatomic) Float64 beatTime;
@property (nonatomic) Float64 quantum;
@property (nonatomic) BOOL isSyncEnabled;

- (void)start;
- (void)stop;

@end

