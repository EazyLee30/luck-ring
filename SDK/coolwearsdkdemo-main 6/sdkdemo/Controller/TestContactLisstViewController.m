//
//  TestContactLisstViewController.m
//  sdkdemo
//
//  Created by coolwear on 2022/10/18.
//

#import "TestContactLisstViewController.h"

@interface TestContactLisstViewController ()

@end

@implementation TestContactLisstViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // 第一步监听通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveData:) name:CEProductK6ReceiveDataNoticeKey object:nil];
    
    // 第二步开始同步
    [CE_SyncContactCmd syncAtIndex:0 handler:nil];
}

- (void)receiveData:(NSNotification *)noti{
    
    K6_DataFuncType funcType = (K6_DataFuncType)[noti.userInfo[@"DataType"] intValue];
    if (funcType == DATA_TYPE_CONTACT_SYNC){
        NSDictionary *data = noti.userInfo[@"Data"];
        NSInteger idx = [data[@"idx"] intValue];
        if (idx == 0){
            //同步结束
        }else{
            //继续同步下一个联系人
            [CE_SyncContactCmd syncAtIndex:idx+1 handler:nil];
        }
    }

}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
