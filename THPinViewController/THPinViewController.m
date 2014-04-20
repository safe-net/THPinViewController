//
//  THPinViewController.m
//  THPinViewController
//
//  Created by Thomas Heß on 11.4.14.
//  Copyright (c) 2014 Thomas Heß. All rights reserved.
//

#import "THPinViewController.h"
#import "THPinInputCircleView.h"
#import "THPinNumPadView.h"

@interface THPinViewController () <THPinNumPadViewDelegate>

@property(nonatomic, strong) UILabel *promptLabel;
@property(nonatomic, strong) UIView *inputCirclesView;
@property(nonatomic, strong) NSMutableArray *inputCirclesViews;
@property(nonatomic, strong) UIButton *bottomButton;
@property(nonatomic, assign) CGFloat bottomButtonYPos;

@property(nonatomic, strong) NSMutableString *inputPin;

@property(nonatomic, assign) NSUInteger numShakes;
@property(nonatomic, assign) NSInteger shakeDirection;
@property(nonatomic, assign) CGFloat shakeAmplitude;

@end

@implementation THPinViewController

- (instancetype)initWithDelegate:(id<THPinViewControllerDelegate>)delegate
{
    self = [super init];
    if (self) {
        self.delegate = delegate;
        self.promptTitle = NSLocalizedStringFromTable(@"prompt_title", @"THPinViewController", nil);
        self.inputPin = [NSMutableString string];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    CGFloat y = 20.0f;
    
    BOOL isFourInchScreen = (fabs(CGRectGetHeight([[UIScreen mainScreen] bounds]) - 568.0f) < DBL_EPSILON);
    
    y += (isFourInchScreen) ? 55.0f : 25.0f;
    self.promptLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, y, CGRectGetWidth(self.view.bounds), 22.0f)];
    self.promptLabel.textAlignment = NSTextAlignmentCenter;
    self.promptLabel.textColor = self.promptColor;
    self.promptLabel.text = self.promptTitle;
    self.promptLabel.font = [UIFont systemFontOfSize:18.0f];
    [self.view addSubview:self.promptLabel];
    
    y += (isFourInchScreen) ? 38.0f : 31.0f;
    [self drawInputCirclesAtYPos:y];
    
    y += (isFourInchScreen) ? 45.0f : 33.0f;
    THPinNumPadView *numPadView = [[THPinNumPadView alloc] initWithDelegate:self];
    numPadView.frame = CGRectMake((CGRectGetWidth(self.view.bounds) - numPadView.intrinsicContentSize.width) / 2.0f, y,
                                  numPadView.intrinsicContentSize.width, numPadView.intrinsicContentSize.height);
    [self.view addSubview:numPadView];
    
    self.bottomButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.view addSubview:self.bottomButton];
    y += (isFourInchScreen) ? 357.0f : 331.0f;
    self.bottomButtonYPos = y;
    [self updateBottomButton];
}

#pragma mark - UI

- (void)drawInputCirclesAtYPos:(CGFloat)yPos
{
    NSUInteger pinLength = [self.delegate pinLengthForPinViewController:self];
    CGFloat inputCirclesViewWidth = [THPinInputCircleView diameter] * pinLength;
    inputCirclesViewWidth += 2.0f * [THPinInputCircleView diameter] * (pinLength - 1); // double diameter padding between circles
    CGRect inputCirclesFrame = CGRectMake((CGRectGetWidth(self.view.bounds) - inputCirclesViewWidth) / 2.0f, yPos,
                                          inputCirclesViewWidth, [THPinInputCircleView diameter]);
    self.inputCirclesView = [[UIView alloc] initWithFrame:inputCirclesFrame];
    [self.view addSubview:self.inputCirclesView];
    
    self.inputCirclesViews = [NSMutableArray array];
    for (NSUInteger i = 0; i < 4; i++) {
        CGRect frame = CGRectMake(i * 3.0f * [THPinInputCircleView diameter], 0.0f,
                                  [THPinInputCircleView diameter], [THPinInputCircleView diameter]);
        THPinInputCircleView* circleView = [[THPinInputCircleView alloc] initWithFrame:frame];
        [self.inputCirclesView addSubview:circleView];
        [self.inputCirclesViews addObject:circleView];
    }
}

- (void)updateBottomButton
{
    if ([self.inputPin length] == 0) {
        [self.bottomButton setTitle:NSLocalizedStringFromTable(@"cancel_button_title", @"THPinViewController", nil)
                           forState:UIControlStateNormal];
        [self.bottomButton removeTarget:self action:@selector(delete:) forControlEvents:UIControlEventTouchUpInside];
        [self.bottomButton addTarget:self action:@selector(cancel:) forControlEvents:UIControlEventTouchUpInside];
    } else {
        [self.bottomButton setTitle:NSLocalizedStringFromTable(@"delete_button_title", @"THPinViewController", nil)
                           forState:UIControlStateNormal];
        [self.bottomButton removeTarget:self action:@selector(cancel:) forControlEvents:UIControlEventTouchUpInside];
        [self.bottomButton addTarget:self action:@selector(delete:) forControlEvents:UIControlEventTouchUpInside];
    }
    [self.bottomButton sizeToFit];
    self.bottomButton.frame = (CGRect) {
        .origin.x = CGRectGetWidth(self.view.bounds) - CGRectGetWidth(self.bottomButton.frame) - 15.0f,
        .origin.y = self.bottomButtonYPos,
        .size = self.bottomButton.frame.size
    };
}

#define TOTAL_NUM_SHAKES 6
#define INITIAL_SHAKE_AMPLITUDE 40.0f

- (void)shakeInputCircles
{
    self.numShakes = 0;
    self.shakeDirection = -1;
    self.shakeAmplitude = INITIAL_SHAKE_AMPLITUDE;
    [self shakeInputCirclesView];
}

- (void)shakeInputCirclesView
{
    [UIView animateWithDuration:0.03f animations:^ {
        self.inputCirclesView.transform = CGAffineTransformMakeTranslation(self.shakeDirection * self.shakeAmplitude, 0.0f);
    } completion:^(BOOL finished) {
        if (self.numShakes < TOTAL_NUM_SHAKES)
        {
            self.numShakes++;
            self.shakeDirection = -1 * self.shakeDirection;
            self.shakeAmplitude = (TOTAL_NUM_SHAKES - self.numShakes) * (INITIAL_SHAKE_AMPLITUDE / TOTAL_NUM_SHAKES);
            [self shakeInputCirclesView];
            
        } else {
            
            self.inputCirclesView.transform = CGAffineTransformIdentity;
            [self resetInput];
        }
    }];
}

#pragma mark - Properties

- (void)setPromptTitle:(NSString *)promptTitle
{
    if ([self.promptTitle isEqualToString:promptTitle]) {
        return;
    }
    _promptTitle = [promptTitle copy];
    self.promptLabel.text = self.promptTitle;
}

- (void)setPromptColor:(UIColor *)promptColor
{
    if ([self.promptColor isEqual:promptColor]) {
        return;
    }
    _promptColor = promptColor;
    self.promptLabel.textColor = self.promptColor;
}

#pragma mark - User Interaction

- (void)cancel:(id)sender
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

- (void)delete:(id)sender
{
    if ([self.inputPin length] < 2) {
        [self resetInput];
    } else {
        [self.inputPin deleteCharactersInRange:NSMakeRange([self.inputPin length] - 1, 1)];
        [self.inputCirclesViews[[self.inputPin length]] setFilled:NO];
    }
}

#pragma mark - THPinNumPadViewDelegate

- (void)pinNumPadView:(THPinNumPadView *)pinNumPadView numberTapped:(NSUInteger)number
{
    NSUInteger pinLength = [self.delegate pinLengthForPinViewController:self];
    
    if ([self.inputPin length] >= pinLength) {
        return;
    }
    
    [self.inputPin appendString:[NSString stringWithFormat:@"%d", number]];
    [self.inputCirclesViews[[self.inputPin length] - 1] setFilled:YES];
    
    [self updateBottomButton];
    
    if ([self.inputPin length] < pinLength) {
        return;
    }
    
    if ([self.delegate pinViewController:self isPinValid:self.inputPin])
    {
        double delayInSeconds = 0.3f;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            if ([self.delegate respondsToSelector:@selector(pinViewControllerWillDismissAfterPinEntryWasSuccessful:)]) {
                [self.delegate pinViewControllerWillDismissAfterPinEntryWasSuccessful:self];
            }
            [self dismissViewControllerAnimated:YES completion:^{
                if ([self.delegate respondsToSelector:@selector(pinViewControllerDidDismissAfterPinEntryWasSuccessful:)]) {
                    [self.delegate pinViewControllerDidDismissAfterPinEntryWasSuccessful:self];
                }
            }];
        });
        
    } else {
        
        [self shakeInputCircles];
        
        if ([self.delegate userCanRetryInPinViewController:self]) {
            if ([self.delegate respondsToSelector:@selector(pinViewControllerWrongPinEntered:)]) {
                [self.delegate pinViewControllerWrongPinEntered:self];
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
    
}

#pragma mark - Util

- (void)resetInput
{
    self.inputPin = [NSMutableString string];
    for (THPinInputCircleView *view in self.inputCirclesViews) {
        view.filled = NO;
    }
    [self updateBottomButton];
}

@end