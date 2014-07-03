//
//  KFTunableSpec.h
//  TunableSpec
//
//  Created by Ken Ferry on 4/29/13.
//  Copyright (c) 2013 Ken Ferry.
//  See LICENSE for details.
//

/* KFTunableSpec provides live tweaking of UI spec values in a running app. From the source code perspective, it's similar to NSUserDefaults, but the values are backed by a JSON file. It's able to display UI for tuning the values, and a share button exports a new JSON file to be checked back into source control.
 
 To use [KFTunableSpec specNamed:@"MainSpec"], the resources directory must contain a file MainSpec.json. That file has values and the information required to lay out a UI for tuning the values.
 
 A value can tuned with a slider or a switch.
 
Sample JSON:
 
[
 {
     "sliderMaxValue" : 300,
     "key" : "GridSpacing",
     "label" : "Grid Spacing",
     "sliderValue" : 175,
     "sliderMinValue" : 10
 },
 {
     "key" : "EnableClickySounds",
     "label" : "Clicky Sounds",
     "switchValue" : false
 }
]
 
 or minimally,
 
[
 {
     "key" : "GridSpacing",
     "sliderValue" : 175,
 },
 {
     "key" : "EnableClickySounds",
     "switchValue" : false
 }
]

 Besides simple getters, "maintain" versions are provided so you can live update your UI. The maintenance block will be called whenever the value changes due to being tuned. For example, with
 
 [spec withDoubleForKey:@"LabelText" owner:self maintain:^(id owner, double doubleValue) {
     [[owner label] setText:[NSString stringWithFormat:@"%g", doubleValue]];
 }];
 
 the label text would live-update as you dragged the tuning slider.

 The maintenance block is always invoked once right away so that the UI gets a correct initial value.
 
 The "owner" parameter is for avoiding leaks. If the owner is deallocated, the maintenance block will be as well. In the case below, self would leak, because the block keeps self alive and vice versa.
 
 [spec withDoubleForKey:@"LabelText" owner:self maintain:^(id owner, double doubleValue) {
     [[self label] setText:[NSString stringWithFormat:@"%g", doubleValue]]; // LEAKS, DO NOT DO THIS, USE OWNER OR CAPTURE LABEL ITSELF
 }];

*/

#import <UIKit/UIKit.h>


@interface KFTunableSpec : NSObject

+ (id)specNamed:(NSString *)name;

#pragma mark Getting Values

- (double)doubleForKey:(NSString *)key;
- (void)withDoubleForKey:(NSString *)key owner:(id)weaklyHeldOwner maintain:(void (^)(id owner, double doubleValue))maintenanceBlock;

- (BOOL)boolForKey:(NSString *)defaultName;
- (void)withBoolForKey:(NSString *)key owner:(id)weaklyHeldOwner maintain:(void (^)(id owner, BOOL flag))maintenanceBlock;


// useful as a metrics dictionary in -[NSLayoutConstraint constraintsWithVisualFormat:options:metrics:views:]
- (NSDictionary *)dictionaryRepresentation;


#pragma mark Showing Tuning UI

// convenience - a recognizer that sets controlsAreVisible on triple tap of two fingers
- (UIGestureRecognizer *)twoFingerTripleTapGestureRecognizer;
@property (nonatomic) BOOL controlsAreVisible;

@end
