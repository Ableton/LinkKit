// Copyright: 2018, Ableton AG, Berlin. All rights reserved.

#include <UIKit/UIKit.h>

@interface QuantumView : UIView

- (void)setBeatTime:(Float64)beatTime;
- (void)setQuantum:(Float64)quantum;
- (void)setIsPlaying:(BOOL)isPlaying;

@end
