// Copyright: 2015, Ableton AG, Berlin. All rights reserved.

#import "ViewController.h"
#import "AudioEngine.h"
#include "ABLLink.h"
#include "ABLLinkSettingsViewController.h"

@interface ViewController ()

- (void)updateSessionTempo:(Float64)bpm;

@end

static void onSessionTempoChanged(Float64 bpm, void* context) {
    ViewController* vc = (__bridge ViewController *)context;
    [vc updateSessionTempo:bpm];
}

@implementation ViewController {
    AudioEngine *_audioEngine;
    BOOL _isPlaying;
    Float64 _bpm;
}

@synthesize transportButton, bpmLabel, bpmStepper;

- (void)viewDidLoad {
    [super viewDidLoad];

    _isPlaying = false;
    _bpm = 120;
    _audioEngine = [[AudioEngine alloc] initWithTempo:_bpm];
    ABLLinkSetSessionTempoCallback(_audioEngine.linkRef, onSessionTempoChanged, (__bridge void *)self);
    [_audioEngine start];
}

- (BOOL)prefersStatusBarHidden {
  return YES;
}

- (void)updateUi {
    self.transportButton.selected = _isPlaying;
    self.bpmLabel.text = [NSString stringWithFormat:@"%.1f bpm", _bpm];
}

#pragma mark - UI Actions
- (IBAction)transportButtonAction:(UIButton *)sender {
    _isPlaying = !sender.selected;
    _audioEngine.isPlaying = _isPlaying;
    [self updateUi];
}

- (IBAction)bpmStepperAction:(UIStepper *)sender {
    _bpm = _bpm + sender.value;
    self.bpmStepper.value = 0;
    [_audioEngine setBpm:_bpm];
    [self updateUi];
}

- (void)updateSessionTempo:(Float64)bpm {
    _bpm = bpm;
    [self updateUi];
}

-(IBAction)showLinkSettings:(id)sender
{
  UIViewController *linkSettings = [ABLLinkSettingsViewController instance:_audioEngine.linkRef];

  UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:linkSettings];
  // this will present a view controller as a popover in iPad and a modal VC on iPhone
  linkSettings.navigationItem.rightBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                  target:self
                                                  action:@selector(hideLinkSettings:)];

  navController.modalPresentationStyle = UIModalPresentationPopover;

  UIPopoverPresentationController *popC = navController.popoverPresentationController;
  popC.permittedArrowDirections = UIPopoverArrowDirectionAny;
  popC.sourceRect = [sender frame];

  // we recommend using a size of 320x400 for the display in a popover
  linkSettings.preferredContentSize = CGSizeMake(320.f, 400.f);

  UIButton *button = (UIButton *)sender;
  popC.sourceView = button.superview;

  [self presentViewController:navController animated:YES completion:nil];
}

- (void)hideLinkSettings:(id)sender
{
  #pragma unused(sender)
  [self dismissViewControllerAnimated:YES completion:nil];
}

@end
