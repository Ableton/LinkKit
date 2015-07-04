// Copyright: 2015, Ableton AG, Berlin. All rights reserved.

#import "ViewController.h"
#import "AudioEngine.h"

@interface ViewController ()

- (void)setIsPlaying:(BOOL)isPlaying atTempo:(Float64)bpm;

@end


@implementation ViewController {
  AudioEngine *_audioEngine;
  NSTimer *_updateUiTimer;
}

@synthesize transportButton, bpmLabel, bpmStepper;

- (void)viewDidLoad {
    [super viewDidLoad];

    _audioEngine = [AudioEngine new];
    [_audioEngine start];

    _updateUiTimer =
        [NSTimer scheduledTimerWithTimeInterval:0.016
                                         target:self
                                       selector:@selector(updateUi)
                                       userInfo:nil
                                        repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_updateUiTimer forMode:NSRunLoopCommonModes];
}

- (void)dealloc {
    [_updateUiTimer invalidate];
}

- (void)setIsPlaying:(BOOL)isPlaying atTempo:(Float64)bpm {
    self.transportButton.selected = isPlaying;
    self.bpmLabel.text = [NSString stringWithFormat:@"%.1f bpm", bpm];
    // The stepper is interpretted as a delta from the last set bpm value, so we
    // reset it whenever the value is updated.
    self.bpmStepper.value = 0;
}

- (void)updateUi {
    [self setIsPlaying:[_audioEngine isPlaying] atTempo:[_audioEngine bpm]];
}

#pragma mark - UI Actions
- (IBAction)transportButtonAction:(UIButton *)sender {
    if (sender.selected) {
        [_audioEngine stopPlaying];
    }
    else
    {
        [_audioEngine startPlaying];
    }
}

- (IBAction)bpmStepperAction:(UIStepper *)sender {
    Float64 currentBpm = [_audioEngine bpm];
    [_audioEngine setBpm:currentBpm + sender.value];
}

- (IBAction)connectivitySwitchAction:(UISwitch *)sender {
    _audioEngine.isSyncEnabled = sender.on;
}

@end
