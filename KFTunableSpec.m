//
//  KFTunableSpec.m
//  TunableSpec
//
//  Created by Ken Ferry on 4/29/13.
//  Copyright (c) 2013 Ken Ferry.
//  See LICENSE for details.
//

#import "KFTunableSpec.h"

@class _KFCalloutView;

#import "TargetConditionals.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import <QuartzCore/QuartzCore.h>
#include <stdlib.h>
#include <xlocale.h>

#if TARGET_OS_IPHONE
static UIImage *CloseImage();
static UIImage *CalloutBezelImage();
static UIImage *CalloutArrowImage();
#endif

@interface _KFSpecItem : NSObject {
    NSMapTable *_maintenanceBlocksByOwner;
    id _objectValue;
}
@property (nonatomic) NSString *key;
@property (nonatomic) NSString *label;

@property (nonatomic) id objectValue;
@property (nonatomic) id defaultValue;

- (void)withOwner:(id)weaklyHeldOwner maintain:(void (^)(id owner, id objValue))maintenanceBlock;

// override this
- (id)tuningView;

@end

@implementation _KFSpecItem

+ (NSArray *)propertiesForJSONRepresentation {
    return @[@"key", @"label"];
}

- (id)initWithJSONRepresentation:(NSDictionary *)json {
    if (json[@"key"] == nil) return nil;
    
    self = [super init];
    if (self) {
        for (NSString *prop in [[self class] propertiesForJSONRepresentation]) {
            [self setValue:json[prop] forKey:prop];
        }
        
        [self setDefaultValue:[self objectValue]];
        _maintenanceBlocksByOwner = [NSMapTable weakToStrongObjectsMapTable];
    }
    return self;
}

- (id)init
{
    NSAssert(0, @"must use initWithJSONRepresentation");
    return self;
}

- (void)withOwner:(id)weaklyHeldOwner maintain:(void (^)(id owner, id objValue))maintenanceBlock {
    NSMutableArray *maintenanceBlocksForOwner = [_maintenanceBlocksByOwner objectForKey:weaklyHeldOwner];
    if (!maintenanceBlocksForOwner) {
        maintenanceBlocksForOwner = [NSMutableArray array];
        [_maintenanceBlocksByOwner setObject:maintenanceBlocksForOwner forKey:weaklyHeldOwner];
    }
    [maintenanceBlocksForOwner addObject:maintenanceBlock];
    maintenanceBlock(weaklyHeldOwner, [self objectValue]);
}

-(id)objectValue {
    return _objectValue;
}

- (void)setObjectValue:(id)objectValue {
    if (![_objectValue isEqual:objectValue]) {
        _objectValue = objectValue;
        objectValue = [self objectValue];
        for (id owner in _maintenanceBlocksByOwner) {
            for (void (^maintenanceBlock)(id owner, id objValue) in [_maintenanceBlocksByOwner objectForKey:owner]) {
                maintenanceBlock(owner, objectValue);
            }
        }
    }
}

static NSString *CamelCaseToSpaces(NSString *camelCaseString) {
    return [camelCaseString stringByReplacingOccurrencesOfString:@"([a-z])([A-Z])" withString:@"$1 $2" options:NSRegularExpressionSearch range:NSMakeRange(0, [camelCaseString length])];

}

- (NSString *)label {
    return _label ?: CamelCaseToSpaces([self key]);
}

- (id)tuningView {
    NSAssert(0, @"%@ must implement %@ and not call super", [self class], NSStringFromSelector(_cmd));
    return nil;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:%@", [self key], [self objectValue]];
}

- (NSDictionary *)jsonRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (NSString *prop in [[self class] propertiesForJSONRepresentation]) {
        [dict setObject:[self valueForKey:prop] forKey:prop];
    }
    
    return dict;
}

@end

@interface _KFSilderSpecItem : _KFSpecItem
@property (nonatomic) NSNumber *sliderMinValue;
@property (nonatomic) NSNumber *sliderMaxValue;
#if TARGET_OS_IPHONE
@property UIView *container;
@property UISlider *slider;
@property _KFCalloutView *calloutView;
@property NSLayoutConstraint *calloutXCenter;
#else
@property NSSlider *slider;
#endif
@end

@implementation _KFSilderSpecItem

+ (NSArray *)propertiesForJSONRepresentation {
    static NSArray *sProps;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sProps = [[super propertiesForJSONRepresentation] arrayByAddingObjectsFromArray:@[@"sliderValue", @"sliderMinValue", @"sliderMaxValue"]];
    });
    return sProps;
}

- (id)initWithJSONRepresentation:(NSDictionary *)json {
    if (json[@"sliderValue"] == nil) {
        return nil;
    } else {
        return [super initWithJSONRepresentation:json];
    }
}

- (id)sliderValue {
    return [self objectValue];
}

- (void)setSliderValue:(id)sliderValue {
    [self setObjectValue:sliderValue];
}

- (NSNumber *)sliderMinValue {
    return _sliderMinValue ?: @0;
}

- (NSNumber *)sliderMaxValue {
    return _sliderMaxValue ?: @([[self defaultValue] doubleValue]*2);
}

@end

#if TARGET_OS_IPHONE

@interface _KFCalloutView : UIView
@property (readonly) UILabel *label;
@end

@implementation _KFCalloutView
- (id)init {
    self = [super init];
    if (self) {
        UIImageView *bezelView = [[UIImageView alloc] init];
        UIImageView *arrowView = [[UIImageView alloc] init];
        UILabel *label = [[UILabel alloc] init];
        [label setTextColor:[UIColor whiteColor]];
        [label setTextAlignment:NSTextAlignmentCenter];
        NSDictionary *views = NSDictionaryOfVariableBindings(bezelView, arrowView, label);
        [views enumerateKeysAndObjectsUsingBlock:^(id key, UIView *view, BOOL *stop) {
            [view setTranslatesAutoresizingMaskIntoConstraints:NO];
        }];
        
        [bezelView addSubview:label];
        [bezelView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-16-[label]-16-|" options:0 metrics:nil views:views]];
        [bezelView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-7-[label]-7-|" options:0 metrics:nil views:views]];

        [self addSubview:bezelView];
        [self addSubview:arrowView];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[bezelView]|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(>=5)-[arrowView]-(>=5)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[bezelView]-(-1)-[arrowView]|" options:NSLayoutFormatAlignAllCenterX metrics:nil views:views]];
        
        [bezelView setImage:CalloutBezelImage()];
        [arrowView setImage:CalloutArrowImage()];
        _label = label;
    }
    return self;
}
@end

@implementation _KFSilderSpecItem (KFUI)

- (UIView *)tuningView {
    if (![self container]) {
        UIView *container = [[UIView alloc] init];
        UISlider *slider = [[UISlider alloc] init];
        _KFCalloutView *callout = [[_KFCalloutView alloc] init];
        NSDictionary *views = NSDictionaryOfVariableBindings(slider, callout);
        
        [self setSlider:slider];
        [slider setTranslatesAutoresizingMaskIntoConstraints:NO];
        [container addSubview:slider];
        [container addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[slider]-0-|" options:0 metrics:nil views:views]];
        [container addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[slider]-0-|" options:0 metrics:nil views:views]];
        [slider addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[slider(>=300@720)]" options:0 metrics:nil views:views]];
        [slider addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[slider(>=25@750)]" options:0 metrics:nil views:views]];
        
        [slider setMinimumValue:[[self sliderMinValue] doubleValue]];
        [slider setMaximumValue:[[self sliderMaxValue] doubleValue]];
        [self withOwner:self maintain:^(id owner, id objValue) { [slider setValue:[objValue doubleValue]]; }];
        [slider addTarget:self action:@selector(takeSliderValue:) forControlEvents:UIControlEventValueChanged];
        
        [callout setTranslatesAutoresizingMaskIntoConstraints:NO];
        [container addSubview:callout];
        [container addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[callout]-3-[slider]" options:0 metrics:nil views:views]];
        [self setCalloutXCenter:[NSLayoutConstraint constraintWithItem:callout attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:container attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
        [container addConstraint:[self calloutXCenter]];
        [callout setAlpha:0];
        
        [self withOwner:self maintain:^(id owner, id objValue) { [[callout label] setText:[NSString stringWithFormat:@"%.2f", [objValue doubleValue]]]; }];
        [slider addTarget:self action:@selector(showCallout:) forControlEvents:UIControlEventTouchDown];
        [slider addTarget:self action:@selector(updateCalloutXCenter:) forControlEvents:UIControlEventValueChanged];
        [slider addTarget:self action:@selector(hideCallout:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
        
        [self setCalloutView:callout];
        [self setContainer:container];
    }
    return [self container];
}

- (void)takeSliderValue:(UISlider *)slider {
    [self setSliderValue:@([slider value])];
}

- (void)showCallout:(id)sender {
    [UIView animateWithDuration:0.15 animations:^{
        [[self calloutView] setAlpha:1.0];
    }];
}

- (void)hideCallout:(id)sender {
    [UIView animateWithDuration:0.15 animations:^{
        [[self calloutView] setAlpha:0.0];
    }];
}

- (void)updateCalloutXCenter:(id)sender {
    UISlider *slider = [self slider];
    CGRect bounds = [slider bounds];
    CGRect thumbRectSliderSpace = [slider thumbRectForBounds:bounds trackRect:[slider trackRectForBounds:bounds] value:[slider value]];
    CGRect thumbRect = [[self container] convertRect:thumbRectSliderSpace fromView:slider];
    [[self calloutXCenter] setConstant:thumbRect.origin.x + thumbRect.size.width/2];
}

@end
#else // OS X

@implementation _KFSilderSpecItem (KFUI)

- (NSView *)tuningView {
    if (![self slider]) {
        NSSlider *slider = [[NSSlider alloc] init];
        [slider setIdentifier:[[self key] stringByAppendingString:@"Slider"]];
        [self setSlider:slider];
        id views = NSDictionaryOfVariableBindings(slider);
        [slider addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[slider(>=300@720)]" options:0 metrics:nil views:views]];
        
        [slider setMinValue:[[self sliderMinValue] doubleValue]];
        [slider setMaxValue:[[self sliderMaxValue] doubleValue]];
        [self withOwner:self maintain:^(id owner, id objValue) { [slider setDoubleValue:[objValue doubleValue]]; }];
        [slider setTarget:self];
        [slider setAction:@selector(takeSliderValue:)];
    }
    return [self slider];
}

- (void)takeSliderValue:(NSSlider *)slider {
    [self setSliderValue:@([slider doubleValue])];
}
@end

#endif



@interface _KFSwitchSpecItem : _KFSpecItem
#if TARGET_OS_IPHONE
@property UISwitch *uiSwitch;
#else
@property NSButton *checkboxButton;
#endif
@end

@implementation _KFSwitchSpecItem

+ (NSArray *)propertiesForJSONRepresentation {
    static NSArray *sProps;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sProps = [[super propertiesForJSONRepresentation] arrayByAddingObjectsFromArray:@[@"switchValue"]];
    });
    return sProps;
}

- (id)initWithJSONRepresentation:(NSDictionary *)json {
    if (json[@"switchValue"] == nil) {
        return nil;
    } else {
        return [super initWithJSONRepresentation:json];
    }
}
#if TARGET_OS_IPHONE
- (UIView *)tuningView {
    if (![self uiSwitch]) {
        UISwitch *uiSwitch = [[UISwitch alloc] init];
        [uiSwitch addTarget:self action:@selector(takeSwitchValue:) forControlEvents:UIControlEventValueChanged];
        [self withOwner:self maintain:^(id owner, id objValue) { [uiSwitch setOn:[objValue boolValue]]; }];
        [self setUiSwitch:uiSwitch];
    }
    return [self uiSwitch];
}

- (void)takeSwitchValue:(UISwitch *)uiSwitch {
    [self setSwitchValue:@([uiSwitch isOn])];
}
#else
- (NSView *)tuningView {
    if (![self checkboxButton]) {
        NSButton *checkboxButton = [[NSButton alloc] init];
        [checkboxButton setButtonType:NSSwitchButton];
        [checkboxButton setTarget:self];
        [checkboxButton setAction:@selector(takeSwitchValue:)];
        [self withOwner:self maintain:^(id owner, id objValue) { [checkboxButton setState:[objValue boolValue]]; }];
        [self setCheckboxButton:checkboxButton];
    }
    return [self checkboxButton];
}

- (void)takeSwitchValue:(NSButton *)checkboxButton {
    [self setSwitchValue:@([checkboxButton state])];
}
#endif

- (id)switchValue {
    return [self objectValue];
}

- (void)setSwitchValue:(id)switchValue {
    [self setObjectValue:switchValue];
}

@end

#if !TARGET_OS_IPHONE
@interface _KFColorSpecItem : _KFSpecItem
@property NSColorWell *colorWell;
@end

@implementation _KFColorSpecItem

+ (NSArray *)propertiesForJSONRepresentation {
    static NSArray *sProps;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sProps = [[super propertiesForJSONRepresentation] arrayByAddingObjectsFromArray:@[@"sRGBAColor"]];
    });
    return sProps;
}

- (id)initWithJSONRepresentation:(NSDictionary *)json {
    if (json[@"sRGBAColor"] == nil) {
        return nil;
    } else {
        return [super initWithJSONRepresentation:json];
    }
}

- (void)setSRGBAColor:(NSString *)rgbaColorString {
    static NSRegularExpression *parsingRegex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error;
        parsingRegex = [[NSRegularExpression alloc] initWithPattern:@"^rgba\\("
                        @"\\s*([0-9]{1,3})\\s*,"
                        @"\\s*([0-9]{1,3})\\s*,"
                        @"\\s*([0-9]{1,3})\\s*,"
                        @"\\s*((?:1(?:\\.0+)?)|(?:0\\.[0-9]*))\\s*"
                        @"\\)$" options:0 error:&error];
        NSAssert(parsingRegex, @"%@", [error localizedDescription]);
    });
    
    [[NSScanner alloc] init];
    NSTextCheckingResult *res = [parsingRegex firstMatchInString:rgbaColorString options:0 range:NSMakeRange(0, [rgbaColorString length])];
    if (!res) goto bail;
    CGFloat components[4];
    for (int i = 0; i < 3; i++) {
        components[i] = [[rgbaColorString substringWithRange:[res rangeAtIndex:i+1]] integerValue] / 255.0;
        if (components[i] > 1.0) goto bail;
    }
    components[3] = strtod_l([[rgbaColorString substringWithRange:[res rangeAtIndex:4]] UTF8String], NULL, NULL);

    [self setObjectValue:[NSColor colorWithColorSpace:[NSColorSpace sRGBColorSpace] components:components count:4]];
    return;
    
    bail:
     NSAssert(0, @"String %@ did not parse. Example: \"rgba(0,0,255,0.3)\".", rgbaColorString);

}

- (NSString *)sRGBAColor {
    NSColor *sRGBColor = [[self objectValue] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    CGFloat components[4];
    [sRGBColor getComponents:components];
    return [NSString stringWithFormat:@"rgba(%g,%g,%g,%g)", round(components[0]*255), round(components[1]*255), round(components[2]*255), components[3]];
}

- (NSView *)tuningView {
    if (![self colorWell]) {
        NSColorWell *colorWell = [[NSColorWell alloc] init];
        id views = NSDictionaryOfVariableBindings(colorWell);
        [colorWell addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[colorWell(20)]" options:0 metrics:nil views:views]];
        [colorWell addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[colorWell(>=300@720)]" options:0 metrics:nil views:views]];
        [colorWell setTarget:self];
        [colorWell setAction:@selector(takeColorValue:)];
        [self withOwner:self maintain:^(id owner, id objValue) { [colorWell setColor:objValue]; }];
        [self setColorWell:colorWell];
    }
    return [self colorWell];
}

- (void)takeColorValue:(NSColorWell *)colorWell {
    [self setObjectValue:[colorWell color]];
}

@end
#endif

@interface KFTunableSpec () {
    NSMutableArray *_KFSpecItems;
    NSMutableArray *_savedDictionaryRepresentations;
    NSUInteger _currentSaveIndex;
}
@property NSString *name;

@end

#if TARGET_OS_IPHONE
@interface KFTunableSpec () <UIDocumentInteractionControllerDelegate>
@property UIWindow *window;
@property UIButton *previousButton;
@property UIButton *saveButton;
@property UIButton *defaultsButton;
@property UIButton *revertButton;
@property UIButton *shareButton;
@property UIButton *closeButton;

@property UIDocumentInteractionController *interactionController; // interaction controller doesn't keep itself alive during presentation. lame.
@end
#else
@interface KFTunableSpec () <NSWindowDelegate>
@property NSWindow *window;
@property NSButton *revertButton;
@property NSButton *saveButton;
@end
#endif

@implementation KFTunableSpec

static NSMutableDictionary *sSpecsByName;
+(void)initialize {
    if (!sSpecsByName) sSpecsByName = [NSMutableDictionary dictionary];
}

+ (id)specNamed:(NSString *)name {
    KFTunableSpec *spec = sSpecsByName[name];
    if (!spec) {
        spec = [[self alloc] initWithName:name];
        sSpecsByName[name] = spec;
    }
    return spec;
}

- (id)initWithName:(NSString *)name {
    self = [super init];
    if (self) {
        [self setName:name];
        _KFSpecItems = [[NSMutableArray alloc] init];
        _savedDictionaryRepresentations = [NSMutableArray array];
        
        NSParameterAssert(name != nil);
        NSURL *jsonURL = [[NSBundle mainBundle] URLForResource:name withExtension:@"json"];
        NSAssert(jsonURL != nil, @"Missing %@.json in resources directory.", name);
        
        NSData *jsonData = [NSData dataWithContentsOfURL:jsonURL];
        NSError *error = nil;
        NSArray *specItemReps = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        NSAssert(specItemReps != nil, @"error decoding %@.json: %@", name, error);

        for (NSDictionary *rep in specItemReps) {
            _KFSpecItem *specItem = nil;
            specItem = specItem ?: [[_KFSilderSpecItem alloc] initWithJSONRepresentation:rep];
            specItem = specItem ?: [[_KFSwitchSpecItem alloc] initWithJSONRepresentation:rep];
//            specItem = specItem ?: [[_KFColorSpecItem alloc] initWithJSONRepresentation:rep];
            
            if (specItem) {
                [_KFSpecItems addObject:specItem];
            } else {
                NSLog(@"%s: Couldn't read entry %@ in %@. Probably you're missing a key? Check KFTunableSpec.h.", __func__, rep, name);
            }
        }
    }
    return self;
}

- (id)init
{
    return [self initWithName:nil];
}

- (_KFSpecItem *)_KFSpecItemForKey:(NSString *)key {
    for (_KFSpecItem *specItem in _KFSpecItems) {
        if ([[specItem key] isEqual:key]) {
            return specItem;
        }
    }
    NSLog(@"%@:Warning – you're trying to use key \"%@\" that doesn't have a valid entry in %@.json. That's unsupported.", [self class], key, [self name]);
    return nil;
}

- (double)doubleForKey:(NSString *)key {
    return [[[self _KFSpecItemForKey:key] objectValue] doubleValue];
}

- (void)withDoubleForKey:(NSString *)key owner:(id)weaklyHeldOwner maintain:(void (^)(id owner, double doubleValue))maintenanceBlock {
    [[self _KFSpecItemForKey:key] withOwner:weaklyHeldOwner maintain:^(id owner, id objectValue){
        maintenanceBlock(owner, [objectValue doubleValue]);
    }];
}

- (BOOL)boolForKey:(NSString *)key {
    return [[[self _KFSpecItemForKey:key] objectValue] boolValue];
}

- (void)withBoolForKey:(NSString *)key owner:(id)weaklyHeldOwner maintain:(void (^)(id owner, BOOL flag))maintenanceBlock {
    [[self _KFSpecItemForKey:key] withOwner:weaklyHeldOwner maintain:^(id owner, id objectValue){
        maintenanceBlock(owner, [objectValue boolValue]);
    }];
}

#if !TARGET_OS_IPHONE
- (NSColor *)colorForKey:(NSString *)key {
    return [[self _KFSpecItemForKey:key] objectValue];
}
- (void)withColorForKey:(NSString *)key owner:(id)weaklyHeldOwner maintain:(void (^)(id owner, NSColor *colorValue))maintenanceBlock {
    [[self _KFSpecItemForKey:key] withOwner:weaklyHeldOwner maintain:maintenanceBlock];
}
#endif


#if TARGET_OS_IPHONE
- (UIViewController *)makeViewController {
    UIView *mainView = [[UIView alloc] init];
    [mainView setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:0.6]];
    [[mainView layer] setBorderColor:[[UIColor whiteColor] CGColor]];
    [[mainView layer] setCornerRadius:5];
    
    UIView *lastControl = nil;
    for (_KFSpecItem *def in _KFSpecItems) {
        UILabel *label = [[UILabel alloc] init];
        [label setTextColor:[UIColor whiteColor]];
        [label setBackgroundColor:[UIColor clearColor]];
        UIView *control = [def tuningView];
        [label setTranslatesAutoresizingMaskIntoConstraints:NO];
        [label setText:[[def label] stringByAppendingString:@":"]];
        [label setTextAlignment:NSTextAlignmentRight];
        id views = lastControl ? NSDictionaryOfVariableBindings(label, control, lastControl) : NSDictionaryOfVariableBindings(label, control);
        [views enumerateKeysAndObjectsUsingBlock:^(id key, id view, BOOL *stop) {
            [view setTranslatesAutoresizingMaskIntoConstraints:NO];
            [mainView addSubview:view];
        }];
        [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[label]-[control]-(==20@700,>=20)-|" options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
        
        if (lastControl) {
            [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[lastControl]-[control]" options:0 metrics:nil views:views]];
            [mainView addConstraint:[NSLayoutConstraint constraintWithItem:lastControl attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:control attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
        } else {
            [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[control]" options:0 metrics:nil views:views]];
        }
        lastControl = control;
    }
    
    NSMutableDictionary *views = [NSMutableDictionary dictionary];
    for (NSString *op in @[@"revert", @"share"]) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [button setTintColor:[UIColor whiteColor]];
        [button setTitle:[op capitalizedString] forState:UIControlStateNormal];
        [button addTarget:self action:NSSelectorFromString(op) forControlEvents:UIControlEventTouchUpInside];
        [button setTranslatesAutoresizingMaskIntoConstraints:NO];
        [views setObject:button forKey:op];
        [self setValue:button forKey:[op stringByAppendingString:@"Button"]];
        [mainView addSubview:button];
    }
    
    [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(>=20)-[revert(==share)]-[share]-(>=20)-|" options:NSLayoutFormatAlignAllTop metrics:nil views:views]];
    [mainView addConstraint:[NSLayoutConstraint constraintWithItem:views[@"revert"] attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:mainView attribute:NSLayoutAttributeCenterX multiplier:1 constant:-10]];
    
    if (lastControl) {
        [views setObject:lastControl forKey:@"lastControl"];
        [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[lastControl]-[share]-|" options:0 metrics:nil views:views]];
    } else {
        [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[share]-|" options:0 metrics:nil views:views]];
    }
    
    
    // We would like to add a close button on the top left corner of the mainView
    // It sticks out a bit from the mainView. In order to have the part that sticks out stay tappable, we make a contentView that completely contains the closeButton and the mainView.

    UIButton *closeButton = [[UIButton alloc] init];
    [closeButton addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [closeButton setImage:CloseImage() forState:UIControlStateNormal];
    [closeButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [closeButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    
    UIView *contentView = [[UIView alloc] init];
    [mainView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [closeButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [contentView addSubview:mainView];
    [contentView addSubview:closeButton];
    
    // perch close button center on contentView corner, slightly inset
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:closeButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:mainView attribute:NSLayoutAttributeLeading multiplier:1 constant:5]];
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:closeButton attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:mainView attribute:NSLayoutAttributeTop multiplier:1 constant:5]];
    
    // center mainView in contentView
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:mainView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:mainView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];

    // align edge of close button with contentView
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:closeButton attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:closeButton attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];

    UIViewController *viewController = [[UIViewController alloc] init];
    [viewController setView:contentView];
    return viewController;
}

- (BOOL)controlsAreVisible {
    return [self window] != nil;
}

CGPoint RectCenter(CGRect rect) {
    return CGPointMake(rect.origin.x + rect.size.width/2, rect.origin.y + rect.size.height/2);
}

- (void)setControlsAreVisible:(BOOL)flag {
    if (flag && ![self window]) {        
        UIViewController *viewController = [self makeViewController];
        UIView *contentView = [viewController view];
        if ([self name]) {
            _savedDictionaryRepresentations = [[[NSUserDefaults standardUserDefaults] objectForKey:[self name]] mutableCopy];
        }
        _savedDictionaryRepresentations = _savedDictionaryRepresentations ?: [[NSMutableArray alloc] init];
        _currentSaveIndex = [_savedDictionaryRepresentations count];
        [self validateButtons];
        
        CGSize size = [contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
        CGSize limitSize = [[[UIApplication sharedApplication] keyWindow] frame].size;
        size.width = MIN(size.width, limitSize.width);
        size.height = MIN(size.height, limitSize.height);
        CGRect windowBounds = CGRectMake(0, 0, size.width, size.height);
        
        
        UIWindow *window = [[UIWindow alloc] init];
        [window setBounds:windowBounds];
        [window setCenter:RectCenter([[UIScreen mainScreen] applicationFrame])];
        [window setRootViewController:viewController];
        
        [contentView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [window addSubview:contentView];
        
        // center contentView with autolayout, because we're going to resize window if we show the interaction controller
        id views = NSDictionaryOfVariableBindings(contentView);
        id metrics = @{@"width" : @(size.width), @"height" : @(size.height)};
        [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[contentView(width)]" options:0 metrics:metrics views:views]];
        [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[contentView(height)]" options:0 metrics:metrics views:views]];
        [window addConstraint:[NSLayoutConstraint constraintWithItem:window attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
        [window addConstraint:[NSLayoutConstraint constraintWithItem:window attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
        
        
        [window makeKeyAndVisible];
        [self setWindow:window];
    }
    if (!flag && [self window]) {
        UIWindow *window = [self window];
        [window setHidden:YES];
        _savedDictionaryRepresentations = nil;
        [self setWindow:nil];
    }
}

- (UIGestureRecognizer *)twoFingerTripleTapGestureRecognizer {
    UITapGestureRecognizer *reco = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_toggleVisible:)];
    [reco setNumberOfTapsRequired:3];
    [reco setNumberOfTouchesRequired:2];
    return reco;
}

- (void)_toggleVisible:(id)sender {
    [self setControlsAreVisible:![self controlsAreVisible]];
}
#else
- (NSViewController *)makeViewController {
    NSView *mainView = [[NSView alloc] init];
    
    NSView *lastControl = nil;
    for (_KFSpecItem *def in _KFSpecItems) {
        NSTextField *label = [[NSTextField alloc] init];
        [label setBordered:NO];
        [label setBezeled:NO];
        [label setEditable:NO];
        [label setDrawsBackground:NO];
        [[label cell] setBackgroundStyle:NSBackgroundStyleDark];
        
        NSView *control = [def tuningView];
        [label setTranslatesAutoresizingMaskIntoConstraints:NO];
        [label setStringValue:[[def label] stringByAppendingString:@":"]];
        [label setAlignment:NSRightTextAlignment];
        
        id views = lastControl ? NSDictionaryOfVariableBindings(label, control, lastControl) : NSDictionaryOfVariableBindings(label, control);
        [views enumerateKeysAndObjectsUsingBlock:^(id key, id view, BOOL *stop) {
            [view setTranslatesAutoresizingMaskIntoConstraints:NO];
            [mainView addSubview:view];
        }];
        [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[label]-[control]-(==20@700,>=20)-|" options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
        
        if (lastControl) {
            [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[lastControl]-[control]" options:0 metrics:nil views:views]];
            [mainView addConstraint:[NSLayoutConstraint constraintWithItem:lastControl attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:control attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
        } else {
            [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[control]" options:0 metrics:nil views:views]];
        }
        lastControl = control;
    }
    
    NSView *buttonCarrier = [[NSView alloc] init];
    [buttonCarrier setTranslatesAutoresizingMaskIntoConstraints:NO];
    [mainView addSubview:buttonCarrier];
    NSMutableDictionary *views = [NSDictionaryOfVariableBindings(buttonCarrier) mutableCopy];
    for (NSString *op in @[@"revert", @"save"]) {
        NSButton *button = [[NSButton alloc] init];
        [button setBezelStyle:NSRoundedBezelStyle];
        [button setTitle:[op capitalizedString]];
        [button setTarget:self];
        [button setAction:NSSelectorFromString([op stringByAppendingString:@":"])];
        [button setTranslatesAutoresizingMaskIntoConstraints:NO];
        [views setObject:button forKey:op];
        [self setValue:button forKey:[op stringByAppendingString:@"Button"]];
        [buttonCarrier addSubview:button];
    }
    
    [buttonCarrier addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[revert]-[save]-0-|" options:NSLayoutFormatAlignAllTop metrics:nil views:views]];
    [buttonCarrier addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[save]-0-|" options:NSLayoutFormatAlignAllTop metrics:nil views:views]];
    
    [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(>=20)-[buttonCarrier]-(>=20)-|" options:NSLayoutFormatAlignAllTop metrics:nil views:views]];
    [mainView addConstraint:[NSLayoutConstraint constraintWithItem:views[@"revert"] attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:mainView attribute:NSLayoutAttributeCenterX multiplier:1 constant:-10]];

    [mainView addConstraint:[NSLayoutConstraint constraintWithItem:buttonCarrier attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:mainView attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];

    if (lastControl) {
        [views setObject:lastControl forKey:@"lastControl"];
        [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[lastControl]-[buttonCarrier]-|" options:0 metrics:nil views:views]];
    } else {
        [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[buttonCarrier]-|" options:0 metrics:nil views:views]];
    }
    
    
    NSViewController *viewController = [[NSViewController alloc] init];
    [viewController setView:mainView];
    return viewController;
}

- (BOOL)controlsAreVisible {
    return [self window] != nil;
}

CGPoint RectCenter(CGRect rect) {
    return CGPointMake(rect.origin.x + rect.size.width/2, rect.origin.y + rect.size.height/2);
}

- (void)setControlsAreVisible:(BOOL)flag {
    if (flag && ![self window]) {        
        NSViewController *viewController = [self makeViewController];
        NSView *contentView = [viewController view];
        if ([self name]) {
            _savedDictionaryRepresentations = [[[NSUserDefaults standardUserDefaults] objectForKey:[self name]] mutableCopy];
        }
        _savedDictionaryRepresentations = _savedDictionaryRepresentations ?: [[NSMutableArray alloc] init];
        _currentSaveIndex = [_savedDictionaryRepresentations count];
        
        NSPanel *window = [[NSPanel alloc] initWithContentRect:NSZeroRect styleMask:NSHUDWindowMask|NSTitledWindowMask|NSResizableWindowMask|NSUtilityWindowMask|NSClosableWindowMask backing:NSBackingStoreBuffered defer:NO];
        [window setTitle:[self name]];
        [window setContentView:contentView];
        [window setDelegate:self];
        [window layoutIfNeeded];
        
        [window makeKeyAndOrderFront:nil];
        [self setWindow:window];
        
    }
    if (!flag && [self window]) {
        [[self window] close];
    }
}

- (void)windowWillClose:(NSNotification *)notification {
    _savedDictionaryRepresentations = nil;
    [self setWindow:nil];
}

- (void)_toggleVisible:(id)sender {
    [self setControlsAreVisible:![self controlsAreVisible]];
}

- (void)installMenuWithKeyEquivalent:(NSString *)keyEquivalent modifierMask:(NSUInteger)mask {
    NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:[self name] action:@selector(_toggleVisible:) keyEquivalent:keyEquivalent];
    [menuItem setTarget:self];
    [menuItem setKeyEquivalentModifierMask:mask];
    
    [[NSApp windowsMenu] addItem:menuItem];
}
#endif

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (_KFSpecItem *def in _KFSpecItems) {
        dict[[def key]] = [def objectValue];
    }
    return dict;
}

- (void)restoreFromDictionaryRepresentation:(NSDictionary *)dictionaryRep {
    for (_KFSpecItem *def in _KFSpecItems) {
        id savedVal = [dictionaryRep objectForKey:[def key]];
        if (savedVal) [def setObjectValue:savedVal];
    }
}

- (id)jsonRepresentation {
    NSMutableArray *json = [NSMutableArray array];
    for (_KFSpecItem *def in _KFSpecItems) {
        [json addObject:[def jsonRepresentation]];
    }
    return json;
}

- (NSString *)description {
    NSMutableString *desc = [NSMutableString stringWithFormat:@"<%@:%p \"%@\"", [self class], self, [self name]];
    for (_KFSpecItem *item in _KFSpecItems) {
        [desc appendFormat:@" %@", [item description]];
    }
    [desc appendString:@">"];
    return desc;
}

- (void)log {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[self jsonRepresentation] options:NSJSONWritingPrettyPrinted error:NULL];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"\n%@", jsonString);
}

- (void)save {
    NSDictionary *savedDict = [self dictionaryRepresentation];
    [_savedDictionaryRepresentations addObject:savedDict];
    _currentSaveIndex = [_savedDictionaryRepresentations count];
    [self validateButtons];
    
    if ([self name]) {
        [[NSUserDefaults standardUserDefaults] setObject:_savedDictionaryRepresentations forKey:[self name]];
    }
    
    [self log];
}

- (void)previous {
    if (_currentSaveIndex > 0) {
        _currentSaveIndex--;
        NSDictionary *savedDict = _savedDictionaryRepresentations[_currentSaveIndex];
        [self restoreFromDictionaryRepresentation:savedDict];
    }
    [self validateButtons];
}

- (void)defaults {
    [self log];
    for (_KFSpecItem *item in _KFSpecItems) {
        [item setObjectValue:[item defaultValue]];
    }
    [self validateButtons];
    [self log];
}

- (void)revert {
    [self defaults];
}

#if TARGET_OS_IPHONE
- (void)share {
    [self log];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:[self jsonRepresentation] options:NSJSONWritingPrettyPrinted error:&error];
    NSString *tempFilename = [[self name] ?: @"UnnamedSpec" stringByAppendingPathExtension:@"json"];
    NSURL *tempFileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:tempFilename] isDirectory:NO];
    [data writeToURL:tempFileURL atomically:YES];
    UIDocumentInteractionController *interactionController = [UIDocumentInteractionController interactionControllerWithURL:tempFileURL];
    [self setInteractionController:interactionController];
    [interactionController setDelegate:self];
    
    [[self window] setFrame:[[[self window] screen] applicationFrame]];
    [[self window] layoutIfNeeded];
    [interactionController presentOptionsMenuFromRect:[[self shareButton] bounds] inView:[self shareButton] animated:YES];
}

- (void)documentInteractionControllerDidDismissOptionsMenu:(UIDocumentInteractionController *)controller {
    [self didFinishShare];
}

- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller {
    [self didFinishShare];
}

- (void)didFinishShare {
    [self setInteractionController:nil];
    CGSize contentViewSize = [[[[self window] subviews] lastObject] frame].size;
    [[self window] setBounds:(CGRect){CGPointZero, contentViewSize}];
}

- (void)close {
    [self setControlsAreVisible:NO];
}


- (void)validateButtons {
    [[self previousButton] setEnabled:(_currentSaveIndex > 0)];
}

#else
- (void)save:(id)sender {
    [self log];
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setNameFieldStringValue:[[self name] stringByAppendingString:@".json"]];
    [savePanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSError *error = nil;
            NSData *data = [NSJSONSerialization dataWithJSONObject:[self jsonRepresentation] options:NSJSONWritingPrettyPrinted error:&error];
            if (!data) goto reportError;
            if (![data writeToURL:[savePanel URL] options:NSDataWritingAtomic error:&error]) goto reportError;
            return;
            
        reportError:
            [[self window] presentError:error];
        }
    }];
}

- (void)validateButtons {
}
#endif

@end

#if TARGET_OS_IPHONE
static UIColor *CalloutColor() {
    return [UIColor colorWithWhite:0.219f alpha:1.0];
}

static UIImage *CalloutBezelImage() {
    static UIImage *bezelImage;
    if (!bezelImage) {
        CGFloat bezelRadius = 5.5;
        CGFloat ceilBezelRadius = ceil(bezelRadius);
        CGRect bounds = CGRectMake(0, 0, ceilBezelRadius*2+1, ceilBezelRadius*2+1);
        UIGraphicsBeginImageContextWithOptions(bounds.size, NO, [[UIScreen mainScreen] scale]);
        [CalloutColor() setFill];
        [[UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:bezelRadius] fill];
        UIImage *roundRectImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        bezelImage = [roundRectImage resizableImageWithCapInsets:UIEdgeInsetsMake(ceilBezelRadius, ceilBezelRadius, ceilBezelRadius, ceilBezelRadius)];
    }
    return bezelImage;
}

static UIImage *CalloutArrowImage() {
    static UIImage *arrowImage;
    if (!arrowImage) {
        CGFloat arrowHeight = 10;
        CGRect bounds = CGRectMake(0, 0, (arrowHeight+1)*2, arrowHeight+1);
        UIGraphicsBeginImageContextWithOptions(bounds.size, NO, [[UIScreen mainScreen] scale]);
        [CalloutColor() setFill];
        UIBezierPath *bezierPath = [[UIBezierPath alloc] init];
        [bezierPath moveToPoint:CGPointMake(0,0)];
        [bezierPath addLineToPoint:CGPointMake(bounds.size.width/2, bounds.size.height)];
        [bezierPath addLineToPoint:CGPointMake(bounds.size.width, 0)];
        [bezierPath setLineJoinStyle:kCGLineJoinRound];
        [bezierPath fill];
        arrowImage = UIGraphicsGetImageFromCurrentImageContext();
    }
    return arrowImage;
}


// drawing code generated by http://likethought.com/opacity/
// (I just didn't want to require including image files)

const CGFloat kDrawCloseArtworkWidth = 30.0f;
const CGFloat kDrawCloseArtworkHeight = 30.0f;

static void DrawCloseArtwork(CGContextRef context, CGRect bounds)
{
    CGRect imageBounds = CGRectMake(0.0f, 0.0f, kDrawCloseArtworkWidth, kDrawCloseArtworkHeight);
    CGFloat alignStroke;
    CGFloat resolution;
    CGMutablePathRef path;
    CGRect drawRect;
    CGColorRef color;
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat stroke;
    CGPoint point;
    CGAffineTransform transform;
    CGFloat components[4];
    
    transform = CGContextGetUserSpaceToDeviceSpaceTransform(context);
    resolution = sqrtf(fabsf(transform.a * transform.d - transform.b * transform.c)) * 0.5f * (bounds.size.width / imageBounds.size.width + bounds.size.height / imageBounds.size.height);
    
    CGContextSaveGState(context);
    CGContextClipToRect(context, bounds);
    CGContextTranslateCTM(context, bounds.origin.x, bounds.origin.y);
    CGContextScaleCTM(context, (bounds.size.width / imageBounds.size.width), (bounds.size.height / imageBounds.size.height));
    
    // Layer 1
    
    alignStroke = 0.0f;
    path = CGPathCreateMutable();
    drawRect = CGRectMake(0.0f, 0.0f, 30.0f, 30.0f);
    drawRect.origin.x = (roundf(resolution * drawRect.origin.x + alignStroke) - alignStroke) / resolution;
    drawRect.origin.y = (roundf(resolution * drawRect.origin.y + alignStroke) - alignStroke) / resolution;
    drawRect.size.width = roundf(resolution * drawRect.size.width) / resolution;
    drawRect.size.height = roundf(resolution * drawRect.size.height) / resolution;
    CGPathAddEllipseInRect(path, NULL, drawRect);
    components[0] = 0.219f;
    components[1] = 0.219f;
    components[2] = 0.219f;
    components[3] = 1.0f;
    color = CGColorCreate(space, components);
    CGContextSetFillColorWithColor(context, color);
    CGColorRelease(color);
    CGContextAddPath(context, path);
    CGContextFillPath(context);
    components[0] = 1.0f;
    components[1] = 1.0f;
    components[2] = 1.0f;
    components[3] = 1.0f;
    color = CGColorCreate(space, components);
    CGContextSetStrokeColorWithColor(context, color);
    CGColorRelease(color);
    stroke = 2.0f;
    stroke *= resolution;
    if (stroke < 1.0f) {
        stroke = ceilf(stroke);
    } else {
        stroke = roundf(stroke);
    }
    stroke /= resolution;
    stroke *= 2.0f;
    CGContextSetLineWidth(context, stroke);
    CGContextSetLineCap(context, kCGLineCapSquare);
    CGContextSaveGState(context);
    CGContextAddPath(context, path);
    CGContextEOClip(context);
    CGContextAddPath(context, path);
    CGContextStrokePath(context);
    CGContextRestoreGState(context);
    CGPathRelease(path);
    
    stroke = 2.5f;
    stroke *= resolution;
    if (stroke < 1.0f) {
        stroke = ceilf(stroke);
    } else {
        stroke = roundf(stroke);
    }
    stroke /= resolution;
    alignStroke = fmodf(0.5f * stroke * resolution, 1.0f);
    path = CGPathCreateMutable();
    point = CGPointMake(10.0f, 20.0f);
    point.x = (roundf(resolution * point.x + alignStroke) - alignStroke) / resolution;
    point.y = (roundf(resolution * point.y + alignStroke) - alignStroke) / resolution;
    CGPathMoveToPoint(path, NULL, point.x, point.y);
    point = CGPointMake(20.0f, 10.0f);
    point.x = (roundf(resolution * point.x + alignStroke) - alignStroke) / resolution;
    point.y = (roundf(resolution * point.y + alignStroke) - alignStroke) / resolution;
    CGPathAddLineToPoint(path, NULL, point.x, point.y);
    components[0] = 1.0f;
    components[1] = 1.0f;
    components[2] = 1.0f;
    components[3] = 1.0f;
    color = CGColorCreate(space, components);
    CGContextSetStrokeColorWithColor(context, color);
    CGColorRelease(color);
    CGContextSetLineWidth(context, stroke);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextAddPath(context, path);
    CGContextStrokePath(context);
    CGPathRelease(path);
    
    stroke = 2.5f;
    stroke *= resolution;
    if (stroke < 1.0f) {
        stroke = ceilf(stroke);
    } else {
        stroke = roundf(stroke);
    }
    stroke /= resolution;
    alignStroke = fmodf(0.5f * stroke * resolution, 1.0f);
    path = CGPathCreateMutable();
    point = CGPointMake(10.0f, 10.0f);
    point.x = (roundf(resolution * point.x + alignStroke) - alignStroke) / resolution;
    point.y = (roundf(resolution * point.y + alignStroke) - alignStroke) / resolution;
    CGPathMoveToPoint(path, NULL, point.x, point.y);
    point = CGPointMake(20.0f, 20.0f);
    point.x = (roundf(resolution * point.x + alignStroke) - alignStroke) / resolution;
    point.y = (roundf(resolution * point.y + alignStroke) - alignStroke) / resolution;
    CGPathAddLineToPoint(path, NULL, point.x, point.y);
    components[0] = 1.0f;
    components[1] = 1.0f;
    components[2] = 1.0f;
    components[3] = 1.0f;
    color = CGColorCreate(space, components);
    CGContextSetStrokeColorWithColor(context, color);
    CGColorRelease(color);
    CGContextAddPath(context, path);
    CGContextStrokePath(context);
    CGPathRelease(path);
    
    CGContextRestoreGState(context);
    CGColorSpaceRelease(space);
}

static UIImage *CloseImage() {
    CGRect bounds = CGRectMake(0, 0, kDrawCloseArtworkWidth, kDrawCloseArtworkHeight);
    UIGraphicsBeginImageContextWithOptions(bounds.size, NO, [[UIScreen mainScreen] scale]);
    DrawCloseArtwork(UIGraphicsGetCurrentContext(), bounds);
    UIImage *closeImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return closeImage;
}
#endif
