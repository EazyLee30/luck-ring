//
//  CustomDialViewController.m
//  sdkdemo
//
//  Created by coolwear on 2022/9/21.
//

#import "CustomDialViewController.h"

@interface CustomDialViewController ()
@property (nonatomic, strong) UIImageView *imageV;
@property (nonatomic, strong) UIColor *textColor;
@end

@implementation CustomDialViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveBleData:) name:CEProductK6ReceiveDataNoticeKey object:nil];
    [self initUI];
}

- (void)initUI{
    
    self.view.backgroundColor = UIColor.whiteColor;
    self.textColor = UIColor.redColor;
    
    self.imageV = [[UIImageView alloc] init];
    self.imageV.image = [UIImage imageNamed:@"custom"];
    [self.view addSubview:self.imageV];
    
    UILabel *timeLabel = [[UILabel alloc] init];
    timeLabel.text = @"11:05";
    timeLabel.textAlignment = NSTextAlignmentCenter;
    timeLabel.textColor = self.textColor;
    [self.imageV addSubview:timeLabel];
    
    UILabel *timeTopLab = [[UILabel alloc] init];
    timeTopLab.font = [UIFont systemFontOfSize:12];
    timeTopLab.textColor = self.textColor;
    timeTopLab.text = @"21/09";
    timeTopLab.textAlignment = NSTextAlignmentCenter;
    [self.imageV addSubview:timeTopLab];
    
    UILabel *timeBottomLab = [[UILabel alloc] init];
    timeBottomLab.font = [UIFont systemFontOfSize:12];
    timeBottomLab.textColor = self.textColor;
    timeBottomLab.text = @"89";
    timeBottomLab.textAlignment = NSTextAlignmentCenter;
    [self.imageV addSubview:timeBottomLab];
    
    timeLabel.frame = CGRectMake(0, 20, 200, 21);
    timeTopLab.frame = CGRectMake(0, 3, 200, 18);
    timeBottomLab.frame = CGRectMake(0, 39, 200, 18);
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Sure" style:UIBarButtonItemStylePlain target:self action:@selector(sureAction)];
}

- (void)viewWillLayoutSubviews{
    if (@available(iOS 11.0, *)) {
         self.imageV.frame = CGRectMake(0, self.view.safeAreaInsets.top, 200, 200);
    }else{
        self.imageV.frame = CGRectMake(0, 0, 200, 200);
    }
}

- (void)sureAction{
    // 检查是否支持新协议
    CE_SyncWatchFaceStartCmd *watchfaceStartCmd = [[CE_SyncWatchFaceStartCmd alloc] init];
    [CEProductK6.shareInstance sendCmdToDevice:watchfaceStartCmd complete:^(NSError *error) {
        if (error){
            [self syncImageWithAccelerate:NO];
        }
    }];
}


- (void)syncImageWithAccelerate:(BOOL)isAccelerate{
    
    LoadingHUD *hud = [[LoadingHUD alloc] init];
    
    CE_SyncCustomFaceCmd *cmd = [self configureCustomFaceCmdWithAcclerate:isAccelerate];
    cmd.syncProgress = ^(CGFloat progress) {
        NSLog(@"😂😂😂😂😂%.2f",progress);
        if (progress >= 1) {
            [hud removeFromSuperview];
            [self.navigationController popViewControllerAnimated:YES];
        }
    };

    [hud showToView:self.view.window];
    [CEProductK6.shareInstance sendCmdToDevice:cmd complete:^(NSError *error) {
        if (!error) {
        }
    }];
}

- (CE_SyncCustomFaceCmd *)configureCustomFaceCmdWithAcclerate:(BOOL)isAccelerate {
    
    UIImage *origin = [UIImage imageNamed:@"custom"];
    UIImage *image = [self image:origin resize:CGSizeMake(240, 284)];
    
    CE_SyncCustomFaceCmd *cmd = [[CE_SyncCustomFaceCmd alloc] initWithImage:image
                                                                      width:image.size.width
                                                                     height:image.size.height
                                                                  imageType:2
                                                                  textColor:UIColor.redColor
                                                               timePosition:0
                                                              timeAboveType:3
                                                              timeBelowType:0
                                                             imageColorType:0];
    cmd.isSupportAccelerate = isAccelerate;
    return cmd;
}

- (UIImage *)image:(UIImage *)image resize:(CGSize)size{
    UIGraphicsBeginImageContext(size);
    UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.mainScreen.scale);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

- (void)receiveBleData:(NSNotification *)noti{
    NSDictionary *dic = noti.userInfo;
    if ([dic[@"DataType"] integerValue] == 134) {
        [self syncImageWithAccelerate:YES];
    }
}
@end
    

