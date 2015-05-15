// Copyright: 2015, Ableton AG, Berlin. All rights reserved.


#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIButton *transportButton;
@property (weak, nonatomic) IBOutlet UILabel *bpmLabel;
@property (weak, nonatomic) IBOutlet UIStepper *bpmStepper;

- (IBAction)transportButtonAction:(UIButton *)sender;
- (IBAction)bpmStepperAction:(UIStepper *)sender;
- (IBAction)connectivitySwitchAction:(UISwitch *)sender;

@end
