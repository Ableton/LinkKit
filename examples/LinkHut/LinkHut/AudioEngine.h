// Copyright: 2015, Ableton AG, Berlin. All rights reserved.

#include <Foundation/Foundation.h>
#include "ABLLink.h"

@interface AudioEngine : NSObject

@property (nonatomic) Float64 bpm;
@property (readonly, nonatomic) Float64 beatTime;
@property (nonatomic) Float64 quantum;
@property (nonatomic) BOOL isPlaying;
@property (readonly, nonatomic) BOOL isLinkEnabled;
@property (readonly, nonatomic) ABLLinkRef linkRef;

- (instancetype)initWithTempo:(Float64)bpm;
- (void)start;
- (void)stop;

@end
