//
//  ViewController.m
//  Spring Playground
//
//  Created by Ken Ferry on 4/29/13.
//  Copyright (c) 2013 Ken Ferry.
//  See LICENSE for details.
//

#import "ViewController.h"
#import "KFTunableSpec.h"

@interface ViewController ()

/* There's one main trick in this app.
 
  As far as the user can see, shapeView can be dragged in two dimensions, and when you let go it springs back to the center.
 
  To get accurate initial velocity (so you can fling the shapeView), we actually need to run two animations, one in the X direction and one in the Y direction, with their own independent initial velocities.
  
  But! If you naively try to do 
 
       [UIView animateWithDuration:usingSpringWithDamping:initialSpringVelocity:xVelocity... {
          // change shapeView's X position
       }];
       [UIView animateWithDuration:usingSpringWithDamping:initialSpringVelocity:yVelocity... {
          // change shapeView's Y position
       }];
 
 ..then the second animation will just stomp the first one. They both animate the position property.
 
 We work around this by adding a wrapper view, "verticalMovementView" around shapeView, and do this:
 
       [UIView animateWithDuration:usingSpringWithDamping:initialSpringVelocity:xVelocity... {
          // change shapeView's X position
       }];
       [UIView animateWithDuration:usingSpringWithDamping:initialSpringVelocity:yVelocity... {
          // change verticalMovementView's Y position
       }];
 
 The second animation no longer stomps the first, because it's animating a different view's position.
 
 So, that's the deal with verticalMovementView. 
 
 You can visualize it by doing a two finger-triple tap and flipping the "Show Views" switch.
 */
@property (strong, nonatomic) IBOutlet UIView *shapeView;
@property (strong, nonatomic) IBOutlet UIView *verticalMovementView;

@property (strong, nonatomic) IBOutlet NSLayoutConstraint *xConstraint; // verticalMovementView.centerX = shapeView.centerX + constant
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *yConstraint; // viewControllerView.centerY = verticalMovementView.centerY + constant

@property (strong, nonatomic) IBOutlet UILabel *label;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    KFTunableSpec *spec = [KFTunableSpec specNamed:@"MainSpec"];
#if DEBUG
    [[self view] addGestureRecognizer:[spec twoFingerTripleTapGestureRecognizer]];
#else 
    [[self label] setText:@"Spec tuning UI is only installed in Debug configuration. Please run Debug!\n\n Search for HONK in ViewController.m to see how this is done."];
#endif

    
    [[[self shapeView] layer] setShadowOpacity:1];
    [[[self shapeView] layer] setShadowOffset:CGSizeMake(0,0)];
    
    UIInterpolatingMotionEffect *xMotionEffect = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"layer.shadowOffset.width" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
    UIInterpolatingMotionEffect *yMotionEffect = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"layer.shadowOffset.height" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
    [spec withDoubleForKey:@"Depth" owner:self maintain:^(id owner, double doubleValue) {
        [xMotionEffect setMinimumRelativeValue:@(-doubleValue)];
        [xMotionEffect setMaximumRelativeValue:@(doubleValue)];
        [yMotionEffect setMinimumRelativeValue:@(-doubleValue)];
        [yMotionEffect setMaximumRelativeValue:@(doubleValue)];
    }];
    [[self shapeView] addMotionEffect:xMotionEffect];
    [[self shapeView] addMotionEffect:yMotionEffect];
    
    
    [spec withBoolForKey:@"ShowBackgroundColors" owner:self maintain:^(id owner, BOOL flag) {
        [[owner verticalMovementView] setBackgroundColor:flag ? [UIColor magentaColor] : nil];
    }];
    
    [[[self shapeView] layer] setCornerRadius:[[self shapeView] bounds].size.width/2];
}

- (IBAction)handlePan:(UIPanGestureRecognizer *)reco {
    KFTunableSpec *spec = [KFTunableSpec specNamed:@"MainSpec"];
    switch ([reco state]) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged: {
            CGPoint translation = [reco translationInView:[self view]];
            [[self xConstraint] setConstant:-translation.x];
            [[self yConstraint] setConstant:-translation.y];
        }
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            CGPoint vel = [reco velocityInView:[self view]];
            CGPoint dist = [reco translationInView:[self view]];
            if (ABS(dist.x) < .1) dist.x = 0.1 * (dist.x < 0 ? -1 : 1);
            if (ABS(dist.y) < .1) dist.y = 0.1 * (dist.y < 0 ? -1 : 1);
            
            /* what's up with the -1's in the next line? Well, in UIKit's spring animations, velInUnitSpace is positive when it is in the direction of the final resting place. For example, starting above the resting position and moving upward should be a negative number in unit space, because it's away from the resting position. So, velInUnitSpace should be negative whenever raw velocity and distance are of the same sign. Hence * -1. */;
            CGPoint velInUnitSpace = CGPointMake(vel.x / dist.x * -1, vel.y / dist.y * -1);
            
            
            /* Please note that we're passing the timing option UIViewAnimationOptionCurveLinear for the spring animations!
             
              The default is ease-in-ease-out, which is not desirable on top of a spring animation. The initial velocity in particular will be noticeably wrong if piped through an ease-in-ease-out curve. <rdar://problem/15089038>
             */
            CGFloat dur = [spec doubleForKey:@"SpringDuration"];
            CGFloat damp = [spec doubleForKey:@"SpringDamping"];

            [[self view] layoutIfNeeded];
            [UIView animateWithDuration:dur delay:0 usingSpringWithDamping:damp initialSpringVelocity:velInUnitSpace.x options:UIViewAnimationOptionCurveLinear animations:^{
                [[self xConstraint] setConstant:0];
                [[self view] layoutIfNeeded];
            } completion:NULL];

            [UIView animateWithDuration:dur delay:0 usingSpringWithDamping:damp initialSpringVelocity:velInUnitSpace.y options:UIViewAnimationOptionCurveLinear animations:^{
                [[self yConstraint] setConstant:0];
                [[self view] layoutIfNeeded];
            } completion:NULL];
        }
            break;
        case UIGestureRecognizerStatePossible:
        case UIGestureRecognizerStateFailed:
            break;
    }
}

@end
