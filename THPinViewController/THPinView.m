//
//  THPinView.m
//  THPinViewControllerExample
//
//  Created by Thomas Heß on 21.4.14.
//  Copyright (c) 2014 Thomas Heß. All rights reserved.
//

#import "THPinView.h"
#import "THPinInputCirclesView.h"
#import "THPinNumPadView.h"
#import "THPinNumButton.h"
#import <ReactiveCocoa/ReactiveCocoa.h>

typedef void (^THPinAnimationCompletionBlock)(void);

typedef NS_ENUM(NSInteger, THPinViewControllerStep) {
    THPinViewControllerStepVerifyCurrentPin,
    THPinViewControllerStepEnterNewPin,
    THPinViewControllerStepVerifyNewPin
};

@interface THPinView () <THPinNumPadViewDelegate>

@property (nonatomic, strong) UILabel *promptLabel;
@property (nonatomic, strong) THPinInputCirclesView *inputCirclesView;
@property (nonatomic, strong) THPinNumPadView *numPadView;
@property (nonatomic, strong) UIButton *bottomButton;

@property (nonatomic, assign) CGFloat paddingBetweenPromptLabelAndInputCircles;
@property (nonatomic, assign) CGFloat paddingBetweenInputCirclesAndNumPad;
@property (nonatomic, assign) CGFloat paddingBetweenNumPadAndBottomButton;

@property (nonatomic, strong) NSMutableString *input;

@property (nonatomic, assign) BOOL inputVerified;
@property (nonatomic, strong) NSString *creatingPin;
@property (nonatomic) THPinViewControllerStep viewControllerStep;

@end

@implementation THPinView

- (instancetype)initWithDelegate:(id<THPinViewDelegate>)delegate
{
    self = [super init];
    if (self)
    {
        _delegate = delegate;
        _input = [NSMutableString string];
        
        _promptLabel = [[UILabel alloc] init];
        _promptLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _promptLabel.textAlignment = NSTextAlignmentCenter;
        _promptLabel.font = [UIFont systemFontOfSize:(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 22.0f : 18.0f];
        [_promptLabel setContentCompressionResistancePriority:UILayoutPriorityFittingSizeLevel
                                                      forAxis:UILayoutConstraintAxisHorizontal];
        [self addSubview:_promptLabel];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[promptLabel]|" options:0 metrics:nil
                                                                       views:@{ @"promptLabel" : _promptLabel }]];
        
        _inputCirclesView = [[THPinInputCirclesView alloc] initWithPinLength:[_delegate pinLengthForPinView:self]];
        _inputCirclesView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_inputCirclesView];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:_inputCirclesView attribute:NSLayoutAttributeCenterX
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:self attribute:NSLayoutAttributeCenterX
                                                        multiplier:1.0f constant:0.0f]];
        
        _numPadView = [[THPinNumPadView alloc] initWithDelegate:self];
        _numPadView.translatesAutoresizingMaskIntoConstraints = NO;
        _numPadView.backgroundColor = self.backgroundColor;
        RAC(_numPadView, backgroundColor) = RACObserve(self, backgroundColor);
        [self addSubview:_numPadView];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:_numPadView attribute:NSLayoutAttributeCenterX
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:self attribute:NSLayoutAttributeCenterX
                                                        multiplier:1.0f constant:0.0f]];
        
        _bottomButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _bottomButton.translatesAutoresizingMaskIntoConstraints = NO;
        _bottomButton.titleLabel.font = [UIFont systemFontOfSize:16.0f];
        _bottomButton.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [_bottomButton setContentCompressionResistancePriority:UILayoutPriorityFittingSizeLevel
                                                       forAxis:UILayoutConstraintAxisHorizontal];
        [self updateBottomButton];
        [self addSubview:_bottomButton];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            // place button right of zero number button
            [self addConstraint:[NSLayoutConstraint constraintWithItem:_bottomButton attribute:NSLayoutAttributeCenterX
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self attribute:NSLayoutAttributeRight
                                                            multiplier:1.0f constant:-[THPinNumButton diameter] / 2.0f]];
            [self addConstraint:[NSLayoutConstraint constraintWithItem:_bottomButton attribute:NSLayoutAttributeCenterY
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self attribute:NSLayoutAttributeBottom
                                                            multiplier:1.0f constant:-[THPinNumButton diameter] / 2.0f]];
            [self addConstraint:[NSLayoutConstraint constraintWithItem:_bottomButton attribute:NSLayoutAttributeWidth
                                                             relatedBy:NSLayoutRelationLessThanOrEqual toItem:nil attribute:0
                                                            multiplier:0.0f constant:[THPinNumButton diameter]]];
        } else {
            // place button beneath the num pad on the right
            [self addConstraint:[NSLayoutConstraint constraintWithItem:_bottomButton attribute:NSLayoutAttributeRight
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self attribute:NSLayoutAttributeRight
                                                            multiplier:1.0f constant:0.0f]];
            [self addConstraint:[NSLayoutConstraint constraintWithItem:_bottomButton attribute:NSLayoutAttributeWidth
                                                             relatedBy:NSLayoutRelationLessThanOrEqual
                                                                toItem:self attribute:NSLayoutAttributeWidth
                                                            multiplier:0.4f constant:0.0f]];
        }
        
        NSMutableString *vFormat = [NSMutableString stringWithString:@"V:|[promptLabel]-(paddingBetweenPromptLabelAndInputCircles)-[inputCirclesView]-(paddingBetweenInputCirclesAndNumPad)-[numPadView]"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            _paddingBetweenPromptLabelAndInputCircles = 22.0f;
            _paddingBetweenInputCirclesAndNumPad = 52.0f;
        } else {
            [vFormat appendString:@"-(paddingBetweenNumPadAndBottomButton)-[bottomButton]"];
            BOOL isFourInchScreen = (fabs(CGRectGetHeight([[UIScreen mainScreen] bounds]) - 568.0f) < DBL_EPSILON);
            if (isFourInchScreen) {
                _paddingBetweenPromptLabelAndInputCircles = 22.5f;
                _paddingBetweenInputCirclesAndNumPad = 41.5f;
                _paddingBetweenNumPadAndBottomButton = 19.0f;
            } else {
                _paddingBetweenPromptLabelAndInputCircles = 15.5f;
                _paddingBetweenInputCirclesAndNumPad = 14.0f;
                _paddingBetweenNumPadAndBottomButton = -7.5f;
            }
        }
        [vFormat appendString:@"|"];
        
        NSDictionary *metrics = @{ @"paddingBetweenPromptLabelAndInputCircles" : @(_paddingBetweenPromptLabelAndInputCircles),
                                   @"paddingBetweenInputCirclesAndNumPad" : @(_paddingBetweenInputCirclesAndNumPad),
                                   @"paddingBetweenNumPadAndBottomButton" : @(_paddingBetweenNumPadAndBottomButton) };
        NSDictionary *views = @{ @"promptLabel" : _promptLabel,
                                 @"inputCirclesView" : _inputCirclesView,
                                 @"numPadView" : _numPadView,
                                 @"bottomButton" : _bottomButton };
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:vFormat options:0 metrics:metrics views:views]];

        RAC(self, promptLabel.text) = [RACSignal switch:RACObserve(self, viewControllerStep)
                                                  cases:@{
                                                          @(THPinViewControllerStepVerifyCurrentPin): RACObserve(self, promptTitle),
                                                          @(THPinViewControllerStepEnterNewPin): RACObserve(self, promptChooseTitle),
                                                          @(THPinViewControllerStepVerifyNewPin): RACObserve(self, promptVerifyTitle)
                                                  }
                                                default:RACObserve(self, promptTitle)];

        RAC(self, viewControllerStep) = [RACObserve(self, viewControllerType) map:^id(NSNumber *type) {
            if (type.integerValue == THPinViewControllerTypeCreatePin) {
                return @(THPinViewControllerStepEnterNewPin);
            } else {
                return @(THPinViewControllerStepVerifyCurrentPin);
            }
        }];
    }
    return self;
}

- (CGSize)intrinsicContentSize
{
    CGFloat height = (self.promptLabel.intrinsicContentSize.height + self.paddingBetweenPromptLabelAndInputCircles +
                      self.inputCirclesView.intrinsicContentSize.height + self.paddingBetweenInputCirclesAndNumPad +
                      self.numPadView.intrinsicContentSize.height);
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
        height += self.paddingBetweenNumPadAndBottomButton + self.bottomButton.intrinsicContentSize.height;
    }
    return CGSizeMake(self.numPadView.intrinsicContentSize.width, height);
}

#pragma mark - Properties

- (UIColor *)promptColor
{
    return self.promptLabel.textColor;
}

- (void)setPromptColor:(UIColor *)promptColor
{
    self.promptLabel.textColor = promptColor;
}

- (BOOL)hideLetters
{
    return self.numPadView.hideLetters;
}

- (void)setHideLetters:(BOOL)hideLetters
{
    self.numPadView.hideLetters = hideLetters;
}

- (void)setDisableCancel:(BOOL)disableCancel
{
    if (self.disableCancel == disableCancel) {
        return;
    }
    _disableCancel = disableCancel;
    [self updateBottomButton];
}

#pragma mark - Public

- (void)updateBottomButton
{
    if ([self.input length] == 0) {
        self.bottomButton.hidden = self.disableCancel;
        [self.bottomButton setTitle:NSLocalizedStringFromTable(@"cancel_button_title", @"THPinViewController", nil)
                           forState:UIControlStateNormal];
        [self.bottomButton removeTarget:self action:@selector(delete:) forControlEvents:UIControlEventTouchUpInside];
        [self.bottomButton addTarget:self action:@selector(cancel:) forControlEvents:UIControlEventTouchUpInside];
    } else {
        self.bottomButton.hidden = NO;
        [self.bottomButton setTitle:NSLocalizedStringFromTable(@"delete_button_title", @"THPinViewController", nil)
                           forState:UIControlStateNormal];
        [self.bottomButton removeTarget:self action:@selector(cancel:) forControlEvents:UIControlEventTouchUpInside];
        [self.bottomButton addTarget:self action:@selector(delete:) forControlEvents:UIControlEventTouchUpInside];
    }
}

#pragma mark - User Interaction

- (void)cancel:(id)sender
{
    [self.delegate cancelButtonTappedInPinView:self];
}

- (void)delete:(id)sender
{
    if ([self.input length] < 2) {
        [self resetInput];
    } else {
        [self.input deleteCharactersInRange:NSMakeRange([self.input length] - 1, 1)];
        [self.inputCirclesView unfillCircleAtPosition:[self.input length]];
    }
}

#pragma mark - THPinNumPadViewDelegate

- (void)pinNumPadView:(THPinNumPadView *)pinNumPadView numberTapped:(NSUInteger)number
{
    NSUInteger pinLength = [self.delegate pinLengthForPinView:self];
    
    if ([self.input length] >= pinLength) {
        return;
    }
    
    [self.input appendString:[NSString stringWithFormat:@"%lu", (unsigned long)number]];
    [self.inputCirclesView fillCircleAtPosition:[self.input length] - 1];
    
    [self updateBottomButton];
    
    if ([self.input length] < pinLength) {
        return;
    }
    
    if (self.viewControllerType == THPinViewControllerTypeCreatePin || self.viewControllerType == THPinViewControllerTypeChangePin) {
        if(self.viewControllerType == THPinViewControllerTypeChangePin && !self.inputVerified) {
            self.creatingPin = nil;
            if ([self.delegate pinView:self isPinValid:self.input])
            {
                self.inputVerified = YES;
                [self slideCirclesAndLabelToStep:THPinViewControllerStepEnterNewPin forward:YES completion:^{
                    [self resetInput];
                }];
            } else {
                [self.inputCirclesView shakeWithCompletion:^{
                    [self resetInput];
                    [self.delegate incorrectPinWasEnteredInPinView:self];
                }];
            }
        } else if (self.creatingPin == nil) {
            self.creatingPin = self.input;
            [self slideCirclesAndLabelToStep:THPinViewControllerStepVerifyNewPin forward:YES completion:^{
                [self resetInput];
            }];
        } else if ([self.creatingPin isEqualToString:self.input]) {
            double delayInSeconds = 0.3f;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self.delegate pin:self.creatingPin wasCreatedInPinView:self];
            });
        } else {
            [self.inputCirclesView shakeWithCompletion:^{
                self.creatingPin = nil;
                [self slideCirclesAndLabelToStep:THPinViewControllerStepEnterNewPin forward:NO completion:^{
                    [self resetInput];
                }];
            }];
        }
        return;
    }
    
    if ([self.delegate pinView:self isPinValid:self.input])
    {
        double delayInSeconds = 0.3f;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self.delegate correctPinWasEnteredInPinView:self];
        });
        
    } else {
        
        [self.inputCirclesView shakeWithCompletion:^{
            [self resetInput];
            [self.delegate incorrectPinWasEnteredInPinView:self];
        }];
    }
}

#pragma mark - Util

- (void)slideCirclesAndLabelToStep:(THPinViewControllerStep)step forward:(BOOL)forward completion:(THPinAnimationCompletionBlock)completion {
    CABasicAnimation* slideOutAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
    slideOutAnimation.autoreverses = NO;
    slideOutAnimation.duration = 0.2f;
    slideOutAnimation.beginTime = 0.0f;
    slideOutAnimation.toValue = [NSValue valueWithCATransform3D:CATransform3DMakeTranslation(forward ? -200 : 200, 0, 0) ];
    slideOutAnimation.removedOnCompletion = NO;
    slideOutAnimation.fillMode = kCAFillModeForwards;
    slideOutAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    
    CABasicAnimation* slideInAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
    slideInAnimation.autoreverses = NO;
    slideInAnimation.duration = 0.2f;
    slideInAnimation.beginTime = 0.2f;
    slideInAnimation.fromValue = [NSValue valueWithCATransform3D:CATransform3DMakeTranslation(forward ? 200 : -200, 0, 0) ];
    slideInAnimation.toValue = [NSValue valueWithCATransform3D:CATransform3DMakeTranslation(0, 0, 0) ];
    slideInAnimation.removedOnCompletion = NO;
    slideInAnimation.fillMode = kCAFillModeForwards;
    slideInAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    
    CABasicAnimation* opacityOutAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityOutAnimation.autoreverses = NO;
    opacityOutAnimation.toValue = @0.0F;
    opacityOutAnimation.duration = 0.2f;
    opacityOutAnimation.beginTime = 0.0f;
    opacityOutAnimation.removedOnCompletion = NO;
    opacityOutAnimation.fillMode = kCAFillModeForwards;
    opacityOutAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    
    CABasicAnimation* opacityInAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityInAnimation.autoreverses = NO;
    opacityInAnimation.toValue = @1.0F;
    opacityInAnimation.duration = 0.2f;
    opacityInAnimation.beginTime = 0.2f;
    opacityInAnimation.removedOnCompletion = NO;
    opacityInAnimation.fillMode = kCAFillModeForwards;
    opacityInAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    
    CAAnimationGroup* slideGroup = [[CAAnimationGroup alloc] init];
    slideGroup.duration = 0.4f;
    slideGroup.animations = @[slideOutAnimation, opacityOutAnimation, opacityInAnimation, slideInAnimation];
    
    [self.promptLabel.layer addAnimation:slideGroup forKey:@"slideAnimation"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(slideGroup.duration/2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.viewControllerStep = step;
    });
    [self.inputCirclesView animateWithAnimation:slideGroup andCompletion:^{
        if (completion) {
            completion();
        }
    }];
}

- (void)resetInput
{
    self.input = [NSMutableString string];
    [self.inputCirclesView unfillAllCircles];
    [self updateBottomButton];
}

@end
