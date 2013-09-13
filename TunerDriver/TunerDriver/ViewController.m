//
//  ViewController.m
//  TunerDriver
//
//  Created by Ken Ferry on 4/29/13.
//  Copyright (c) 2013 Ken Ferry.
//  See LICENSE for details.
//

#import "ViewController.h"
#import "TunableSpec.h"

@interface ViewController ()
@property (strong, nonatomic) IBOutlet UILabel *label;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *topSpaceConstraint;

@end

@implementation ViewController

- (void)viewDidLoad
{
    TunableSpec *spec = [TunableSpec specNamed:@"MainSpec"];
    [spec withBoolForKey:@"RightAlignLabel" owner:self maintain:^(id owner, BOOL flag) {
        [[owner label] setTextAlignment:flag ? NSTextAlignmentRight : NSTextAlignmentLeft];
    }];
    
    [spec withDoubleForKey:@"TopSpacing" owner:self maintain:^(ViewController *owner, double doubleValue) {
        [[owner topSpaceConstraint] setConstant:doubleValue];
    }];
    
    [[self view] addGestureRecognizer:[spec twoFingerTripleTapGestureRecognizer]];

    [super viewDidLoad];
}



@end
