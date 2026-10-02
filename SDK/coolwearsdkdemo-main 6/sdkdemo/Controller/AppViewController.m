//
//  AppViewController.m
//  sdkdemo
//
//  Created by coolwear on 2022/9/22.
//

#import "AppViewController.h"
#import "ListSwtCell.h"

@interface AppViewController ()<UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *titles;
@property (nonatomic, strong) AppSwtModel *data;
@end

@implementation AppViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.data = DataManager.shared.appswt;
    
    self.titles = @[
        @"QQ", @"Wechat",@"Email", @"Facebook",@"Twitter", @"WhatsApp",
        @"Instagram", @"Skype",
        @"LinkedIn", @"Line",
        @"Kakao Talk",@"Telegram",
        @"Other",];
  
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.rowHeight = 55;
    self.tableView.frame = self.view.bounds;
    [self.tableView registerClass:ListSwtCell.class forCellReuseIdentifier:@"cell"];
    [self.view addSubview:self.tableView];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [self sync];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.data.allSwitch ? self.titles.count : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    ListSwtCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = self.titles[indexPath.row];
    cell.swt.on = [self openWithIndexPath:indexPath];
    cell.swt.tag = indexPath.row;
    [cell.swt addTarget:self action:@selector(swtOpen:) forControlEvents:UIControlEventValueChanged];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
    return 55;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 55)];
    v.backgroundColor = UIColor.whiteColor;
    UILabel *tl = [[UILabel alloc] initWithFrame:CGRectMake(15, 17, 150, 21)];
    tl.text = @"开启APP通知提醒";
    [v addSubview:tl];
    
    UISwitch *swt = [[UISwitch alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 65, 12.5, 60, 30)];
    swt.on = self.data.allSwitch;
    [swt addTarget:self action:@selector(totalSwtAction:) forControlEvents:UIControlEventValueChanged];
    [v addSubview:swt];
    
    return v;
}

- (BOOL)openWithIndexPath:(NSIndexPath *)indexPath{
    NSInteger tag = indexPath.row;
    if (0 == tag) {
        return self.data.qq;
    }else if (1 == tag) {
        return self.data.wechat;
    }else if (2 == tag) {
        return self.data.email;
    }else if (3 == tag) {
        return self.data.facebook;
    }else if (4 == tag) {
        return self.data.twitter;
    }else if (5 == tag){
        return self.data.whatsapp;
    }else if (6 == tag){
        return self.data.instagram;
    }else if (7 == tag){
        return self.data.skype;
    }else if (8 == tag){
        return self.data.linkedIn;
    }else if (9 == tag){
        return self.data.line;
    }else if (10 == tag){
        return self.data.kakaoTalk;
    }else if (11 == tag){
        return self.data.telegram;
    }
    return self.data.other;
}

- (void)swtOpen:(UISwitch *)swt{
    
    NSInteger tag = swt.tag;
    BOOL on = swt.on;
    if (0 == tag) {
        self.data.qq = on;
    }else if (1 == tag) {
        self.data.wechat = on;
    }else if (2 == tag) {
        self.data.email = on;
    }else if (3 == tag) {
        self.data.facebook = on;
    }else if (4 == tag) {
        self.data.twitter = on;
    }else if (5 == tag){
        self.data.whatsapp = on;
    }else if (6 == tag){
        self.data.instagram = on;
    }else if (7 == tag){
        self.data.skype = on;
    }else if (8 == tag){
        self.data.linkedIn = on;
    }else if (9 == tag){
        self.data.line = on;
    }else if (10 == tag){
        self.data.kakaoTalk = on;
    }else if (11 == tag){
        self.data.telegram = on;
    }else{
        self.data.other = on;
    }
    
}

- (void)totalSwtAction:(UISwitch *)swt{
    self.data.allSwitch = swt.on;
    [self.tableView reloadData];
}

- (void)sync{
    CE_SyncWatchMenuCmd *watchCmd = [[CE_SyncWatchMenuCmd alloc] init];;
    watchCmd.allSwitch = self.data.allSwitch;
    watchCmd.qq = self.data.qq ;
    watchCmd.email = self.data.email ;
    watchCmd.wechat = self.data.wechat ;
    watchCmd.facebook = self.data.facebook ;
    watchCmd.twitter = self.data.twitter ;
    watchCmd.whatsapp = self.data.whatsapp ;
    watchCmd.instagram = self.data.instagram ;
    watchCmd.skype = self.data.skype ;
    watchCmd.linkedIn = self.data.linkedIn ;
    watchCmd.line = self.data.line ;
    watchCmd.kakaoTalk = self.data.kakaoTalk;
    watchCmd.telegram = self.data.telegram;
    watchCmd.other = self.data.other ;
    [[CEProductK6 shareInstance] sendCmdToDevice:watchCmd complete:^(NSError *error) {

    }];
}

@end
