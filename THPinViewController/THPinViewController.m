//
//  THPinViewController.m
//  THPinViewController
//
//  Created by Thomas Heß on 11.4.14.
//  Copyright (c) 2014 Thomas Heß. All rights reserved.
//

#import "THPinViewController.h"
#import "UIImage+ImageEffects.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import "RACEXTScope.h"

@interface THPinViewController () <THPinViewDelegate>

@property (nonatomic, strong) THPinView *pinView;
@property (nonatomic, strong) UIView *blurView;
@property (nonatomic, assign) NSArray *blurViewContraints;

@end

@implementation THPinViewController

- (instancetype)initWithDelegate:(id<THPinViewControllerDelegate>)delegate
{
    self = [super init];
    if (self) {
        _delegate = delegate;
        _backgroundColor = [UIColor whiteColor];
        _translucentBackground = NO;
        _promptTitle = NSLocalizedStringFromTable(@"prompt_title", @"THPinViewController", nil);
        _promptChooseTitle = NSLocalizedStringFromTable(@"prompt_choose_title", @"THPinViewController", nil);
        _promptVerifyTitle = NSLocalizedStringFromTable(@"prompt_verify_title", @"THPinViewController", nil);
        _viewControllerType = THPinViewControllerTypeStandard;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.pinView = [[THPinView alloc] initWithDelegate:self];
    
    RAC(self.pinView, promptTitle) = RACObserve(self, promptTitle);
    RAC(self.pinView, promptChooseTitle) = RACObserve(self, promptChooseTitle);
    RAC(self.pinView, promptVerifyTitle) = RACObserve(self, promptVerifyTitle);
    RAC(self.pinView, promptColor) = RACObserve(self, promptColor);
    RAC(self.pinView, hideLetters) = RACObserve(self, hideLetters);
    RAC(self.pinView, disableCancel) = RACObserve(self, disableCancel);
    self.pinView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.pinView];

    RACSignal *viewBackgroundColor = [RACSignal if:RACObserve(self, translucentBackground)
                                               then:[RACSignal return:[UIColor clearColor]]
                                               else:RACObserve(self, backgroundColor)];
    RAC(self.view, backgroundColor) = viewBackgroundColor;
    RAC(self.pinView, backgroundColor) = viewBackgroundColor;

    [self rac_liftSelector:@selector(translucencyChanged:) withSignals:RACObserve(self, translucentBackground).distinctUntilChanged, nil];

    // center pin view
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.pinView attribute:NSLayoutAttributeCenterX
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view attribute:NSLayoutAttributeCenterX
                                                         multiplier:1.0f constant:0.0f]];
    CGFloat pinViewYOffset = 0.0f;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        pinViewYOffset = -9.0f;
    } else {
        BOOL isFourInchScreen = (fabs(CGRectGetHeight([[UIScreen mainScreen] bounds]) - 568.0f) < DBL_EPSILON);
        if (isFourInchScreen) {
            pinViewYOffset = 25.5f;
        } else {
            pinViewYOffset = 18.5f;
        }
    }
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.pinView attribute:NSLayoutAttributeCenterY
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view attribute:NSLayoutAttributeCenterY
                                                         multiplier:1.0f constant:pinViewYOffset]];
}

#pragma mark - Blur

- (void)translucencyChanged:(BOOL)translucent {
    if(self.blurView != nil) {
        [self.blurView removeFromSuperview];
        self.blurView = nil;
    }
    if (self.blurViewContraints != nil) {
        [self.view removeConstraints:self.blurViewContraints];
    }
    if(translucent) {
        self.blurView = [[UIImageView alloc] initWithImage:[self blurredContentImage]];
        self.blurView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view insertSubview:self.blurView belowSubview:self.pinView];
        NSDictionary *views = @{ @"blurView" : self.blurView };
        NSMutableArray *constraints =
                [NSMutableArray arrayWithArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[blurView]|"
                                                                                       options:0 metrics:nil views:views]];
        [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[blurView]|"
                                                                                 options:0 metrics:nil views:views]];
        self.blurViewContraints = constraints;
        [self.view addConstraints:self.blurViewContraints];
    }
}


- (UIView *) findContentView {
    NSArray *windows = [UIApplication sharedApplication].windows;
    for (UIWindow *window in windows) {
        UIView *view = [window viewWithTag:THPinViewControllerContentViewTag];
        if(view) {
            return view;
        }
    }
    return nil;
}

- (UIImage*)blurredContentImage
{

    UIView *contentView = [self findContentView];

    if (! contentView) {
        return nil;
    }
    UIGraphicsBeginImageContext(self.view.bounds.size);
    [contentView drawViewHierarchyInRect:self.view.bounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image applyBlurWithRadius:20.0f tintColor:[UIColor colorWithWhite:1.0f alpha:0.25f]
                saturationDeltaFactor:1.8f maskImage:nil];
}

#pragma mark - THPinViewDelegate

- (NSUInteger)pinLengthForPinView:(THPinView *)pinView
{
    NSUInteger pinLength = [self.delegate pinLengthForPinViewController:self];
    NSAssert(pinLength > 0, @"PIN length must be greater than 0");
    return MAX(pinLength, (NSUInteger)1);
}

- (BOOL)pinView:(THPinView *)pinView isPinValid:(NSString *)pin
{
    return [self.delegate pinViewController:self isPinValid:pin];
}

- (void)pin:(NSString *)pin wasCreatedInPinView:(THPinView *)pinView
{
    if ([self.delegate respondsToSelector:@selector(pinViewController:createdPin:)]) {
        [self.delegate pinViewController:self createdPin:pin];
    }
    [self dismissViewControllerAnimated:YES completion:^{
        if ([self.delegate respondsToSelector:@selector(pinViewControllerDidDismissAfterPinEntryWasSuccessful:)]) {
            [self.delegate pinViewControllerDidDismissAfterPinEntryWasSuccessful:self];
        }
    }];
}

- (void)cancelButtonTappedInPinView:(THPinView *)pinView
{
    if ([self.delegate respondsToSelector:@selector(pinViewControllerWillDismissAfterPinEntryWasCancelled:)]) {
        [self.delegate pinViewControllerWillDismissAfterPinEntryWasCancelled:self];
    }
    [self dismissViewControllerAnimated:YES completion:^{
        if ([self.delegate respondsToSelector:@selector(pinViewControllerDidDismissAfterPinEntryWasCancelled:)]) {
            [self.delegate pinViewControllerDidDismissAfterPinEntryWasCancelled:self];
        }
    }];
}

- (void)correctPinWasEnteredInPinView:(THPinView *)pinView
{
    if ([self.delegate respondsToSelector:@selector(pinViewControllerWillDismissAfterPinEntryWasSuccessful:)]) {
        [self.delegate pinViewControllerWillDismissAfterPinEntryWasSuccessful:self];
    }
    [self dismissViewControllerAnimated:YES completion:^{
        if ([self.delegate respondsToSelector:@selector(pinViewControllerDidDismissAfterPinEntryWasSuccessful:)]) {
            [self.delegate pinViewControllerDidDismissAfterPinEntryWasSuccessful:self];
        }
    }];
}

- (void)incorrectPinWasEnteredInPinView:(THPinView *)pinView
{
    if ([self.delegate userCanRetryInPinViewController:self]) {
        if ([self.delegate respondsToSelector:@selector(incorrectPinEnteredInPinViewController:)]) {
            [self.delegate incorrectPinEnteredInPinViewController:self];
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(pinViewControllerWillDismissAfterPinEntryWasUnsuccessful:)]) {
            [self.delegate pinViewControllerWillDismissAfterPinEntryWasUnsuccessful:self];
        }
        [self dismissViewControllerAnimated:YES completion:^{
            if ([self.delegate respondsToSelector:@selector(pinViewControllerDidDismissAfterPinEntryWasUnsuccessful:)]) {
                [self.delegate pinViewControllerDidDismissAfterPinEntryWasUnsuccessful:self];
            }
        }];
    }
}

@end
