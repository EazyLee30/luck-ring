//
//  RealTestViewController.m
//  sdkdemo
//
//  Created by coolwear on 2023/5/8.
//

#import "RealTestViewController.h"

@interface RealTestViewController ()
@property (nonatomic, strong) UIButton* testBtn;
@property (nonatomic, strong) UILabel* testLab;
@end

@implementation RealTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColor.whiteColor;
    
    self.testLab = [UILabel new];
    self.testLab.text = @"0";
    self.testLab.frame = CGRectMake(0, 100, self.view.frame.size.width, 44);
    self.testLab.backgroundColor = UIColor.lightGrayColor;
    [self.view addSubview:self.testLab];
    
    self.testBtn = [UIButton new];
    [self.testBtn setTitle:@"开始检测" forState:UIControlStateNormal];
    self.testBtn.backgroundColor = UIColor.orangeColor;
    [self.testBtn addTarget:self action:@selector(testAction:) forControlEvents:UIControlEventTouchUpInside];
    self.testBtn.frame = CGRectMake(0, CGRectGetMaxY(self.testLab.frame), 100, 44);
    [self.view addSubview:self.testBtn];
}

- (void)testAction:(UIButton *)sender{
    
}

- (void)getRealheartRate{
    CE_SyncHeartRateCmd *cmd = [CE_SyncHeartRateCmd new];
    cmd.status = 1;
    [CEProductK6.shareInstance sendCmdToDevice:cmd complete:nil];
    
}

@end
