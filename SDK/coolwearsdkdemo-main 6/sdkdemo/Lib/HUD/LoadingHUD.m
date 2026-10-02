//
//  LoadingView.m
//  sdkdemo
//
//  Created by coolwear on 2022/9/21.
//

#import "LoadingHUD.h"
#import "UIImage+GIF.h"

@implementation LoadingHUD

- (instancetype)initWithFrame:(CGRect)frame{
    
    if (self = [super initWithFrame:frame]) {
        
        self.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.5];
        
        UIView *bg = [UIView new];
        bg.frame = CGRectMake(0, 0, 125, 125);
        bg.backgroundColor = UIColor.whiteColor;
        bg.layer.cornerRadius = 10;
        [self addSubview:bg];
        self.hud = bg;
    
        
        _imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 75, 75)];
        [self addSubview:_imageView];
        
        NSString *path = [[NSBundle mainBundle] pathForResource:@"loading" ofType:@"gif"];
        NSData *data = [NSData dataWithContentsOfFile:path];
        UIImage *image = [UIImage sd_imageWithGIFData:data];
        self.imageView.image = image;
        
    }
    return self;
    
}

- (void)showToView:(UIView *)view{
    self.frame = view.frame;
    [view addSubview:self];

    self.hud.center = self.center;
    self.imageView.center = self.center;
    
}

@end
