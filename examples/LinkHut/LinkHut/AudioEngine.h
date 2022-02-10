// Copyright: 2018, Ableton AG, Berlin. All rights reserved.

#include <Foundation/Foundation.h>
#include "ABLLink.h"

@interface AudioEngine : NSObject

- (instancetype)initWithTempo:(Float64)bpm NS_DESIGNATED_INITIALIZER;
- (void)start;
- (void)stop;
- (void)proposeTempo:(Float64)bpm;
- (void)setQuantum:(Float64)quantum;
- (void)requestTransportStart;
- (void)requestTransportStop;
- (ABLLinkRef)linkRef;

@end
