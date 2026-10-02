//
//  LoadingView.h
//  sdkdemo
//
//  Created by coolwear on 2022/9/21.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LoadingHUD : UIView

@property (nonatomic, strong) UIView *hud;

@property (nonatomic, strong) UIImageView *imageView;

- (void)showToView:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
