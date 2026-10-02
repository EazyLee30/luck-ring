//
//  DemoViewController.m
//  sdkdemo
//
//  Created by coolwear on 2022/9/20.
//

#import "FuncListViewController.h"
#import "ListSwtCell.h"
#import "DialViewController.h"
#import "AppViewController.h"
#import "AlarmViewController.h"
#import "FuncModel.h"
#import "RealTestViewController.h"

@interface FuncListViewController ()<UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *data;
@end

@implementation FuncListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(dataReceiveFinish:) name:@"DataReceivceFinish" object:nil];
    [self initData];
    [self initUI];
    
}


- (void)initData{
        
    FuncModel *dial = [[FuncModel alloc] initWithTitle:@"表盘" type:0 page:@"DialViewController"];
    FuncModel *app = [[FuncModel alloc] initWithTitle:@"app通知提醒" type:0 page:@"AppViewController"];
    FuncModel *alarm = [[FuncModel alloc] initWithTitle:@"闹钟" type:0 page:@"AlarmViewController"];
    FuncModel *sms = [[FuncModel alloc] initWithTitle:@"短信提醒" type:1];
    FuncModel *call = [[FuncModel alloc] initWithTitle:@"来电提醒" type:1];
    FuncModel *longsit = [[FuncModel alloc] initWithTitle:@"久坐提醒" type:1];
    FuncModel *goal = [[FuncModel alloc] initWithTitle:@"达标提醒" type:1];
    FuncModel *water = [[FuncModel alloc] initWithTitle:@"喝水提醒" type:1];
    FuncModel *time = [[FuncModel alloc] initWithTitle:@"时间格式" type:1];
    FuncModel *date = [[FuncModel alloc] initWithTitle:@"日期格式" type:1];
    FuncModel *find = [[FuncModel alloc] initWithTitle:@"查找手环" type:2];
    FuncModel *disturb = [[FuncModel alloc] initWithTitle:@"勿扰模式" type:1];
    FuncModel *raise = [[FuncModel alloc] initWithTitle:@"抬腕亮屏" type:1];
    FuncModel *autoHr = [[FuncModel alloc] initWithTitle:@"自动心率检测" type:1];
    FuncModel *takePhoto = [[FuncModel alloc] initWithTitle:@"智拍" type:1];
    FuncModel *ota = [[FuncModel alloc] initWithTitle:@"OTA" type:2];
    FuncModel *weather = [[FuncModel alloc] initWithTitle:@"发送天气" type:2];
    FuncModel *contact = [[FuncModel alloc] initWithTitle:@"联系人" type:0 page:@"ContactViewController"];
    FuncModel *realhr = [[FuncModel alloc] initWithTitle:@"实时心率" type:2];
    FuncModel *realo2 = [[FuncModel alloc] initWithTitle:@"实时血压" type:2];
    FuncModel *realbp = [[FuncModel alloc] initWithTitle:@"实时血氧" type:2];
    self.data = @[dial, app, alarm, sms, call, longsit, goal, water, time, date, find, disturb, raise, autoHr, takePhoto, ota, weather, contact, realhr, realo2, realbp];
    
}

- (void)initUI{
    
    
    self.title = self.sp.name;
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:self action:@selector(backAction:)];
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.rowHeight = 55;
    self.tableView.frame = self.view.bounds;
    [self.view addSubview:self.tableView];
    
}

- (void)dataReceiveFinish:(NSNotification *)noti{
    [self.tableView reloadData];
}

- (void)backAction:(id)sender{
    [[CEProductK6 shareInstance] releaseBind];
    [self dismissViewControllerAnimated:YES completion:nil];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.data.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    FuncModel *model = self.data[indexPath.row];
    
    if (model.type == 1) {
        ListSwtCell* cell = [[ListSwtCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = model.title;
        cell.swt.tag = indexPath.row;
        [cell.swt addTarget:self action:@selector(swtAction:) forControlEvents:UIControlEventTouchUpInside];
        [self updateCell:cell atIndexPath:indexPath];
        return cell;
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
    }
    if (model.type != 1) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }else{
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    cell.textLabel.text = model.title;
    if (model.type == 2 && indexPath.row == 18){
        cell.detailTextLabel.text = @(DataManager.shared.heartModel.heartNum).stringValue;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{

    FuncModel *model = self.data[indexPath.row];
    if (model.type == 0) {
        Class class = NSClassFromString(model.page);
        if ([class isKindOfClass:RealTestViewController.class]){
            RealTestViewController* vc = [[RealTestViewController alloc] init];
            vc.type = indexPath.row;
            [self.navigationController pushViewController:vc animated:YES];
        }else{
            UIViewController *vc = [class new];
            [self.navigationController pushViewController:vc animated:YES];
        }

    }
    if (10 == indexPath.row) {
        YD_SyncFindDevCmd *tFindDevCmd = [[YD_SyncFindDevCmd alloc] initWithOnoff:1];
        [[CEProductK6 shareInstance] sendCmdToDevice:tFindDevCmd complete:nil];
    }
 
    if (15 == indexPath.row) {
        OtaViewController *vc = [[OtaViewController alloc] init];
        vc.customerId = DataManager.shared.devInfo.customer_id;
        [self.navigationController pushViewController:vc animated:YES];
    }
    if (16 == indexPath.row){
        [self sendWeather];
    }
    if (18 == indexPath.row){
        CE_SyncHeartRateCmd *cmd = [[CE_SyncHeartRateCmd alloc] init];
        cmd.status = 1;
        [CEProductK6.shareInstance sendCmdToDevice:cmd complete:nil];

    }
    if (19 == indexPath.row) {
        CE_SyncBloodPressureCmd *cmd = [[CE_SyncBloodPressureCmd alloc] init];
        cmd.status = 1;
        [CEProductK6.shareInstance sendCmdToDevice:cmd complete:nil];
    }
    if (20 == indexPath.row) {
        CE_SyncHeartO2Cmd *cmd = [[CE_SyncHeartO2Cmd alloc] init];
        cmd.status = 1;
        [CEProductK6.shareInstance sendCmdToDevice:cmd complete:nil];
    }

}

- (void)swtAction:(UISwitch *)swt{
    
    NSInteger tag = swt.tag;
    if (3 == tag){
        YD_SyncSMSAlarmCmd *tSMSAlarmCmd = [[YD_SyncSMSAlarmCmd alloc] init];
        tSMSAlarmCmd.onoff = swt.on;
        [[CEProductK6 shareInstance] sendCmdToDevice:tSMSAlarmCmd complete:nil];
    }else if (4 == tag){
        YD_SyncCallAlarmCmd *tSMSAlarmCmd = [[YD_SyncCallAlarmCmd alloc] initWithOnoff:swt.on];
        [[CEProductK6 shareInstance] sendCmdToDevice:tSMSAlarmCmd complete:nil];
    }else if (5 == tag){
        CE_SyncLongSitRemindCmd *longSitCmd = [[CE_SyncLongSitRemindCmd alloc] init];
        longSitCmd.onoff = swt.on;
        longSitCmd.repeatDay = 0;
        longSitCmd.startTimeHour = 9;
        longSitCmd.startTimemin = 0;
        longSitCmd.endTimeHour = 20;
        longSitCmd.endTimeMin = 0;
        longSitCmd.noon_onoff = swt.on;
        [[CEProductK6 shareInstance] sendCmdToDevice:longSitCmd complete:nil];
    }else if (6 == tag) {
        YD_SyncFinishGoalCmd *tSMSAlarmCmd = [[YD_SyncFinishGoalCmd alloc] init];
        tSMSAlarmCmd.onoff = swt.on;
        [[CEProductK6 shareInstance] sendCmdToDevice:tSMSAlarmCmd complete:nil];
    }else if (7 == tag){
        YD_SyncDrinkAlarmCmd *drinkCmd = [[YD_SyncDrinkAlarmCmd alloc] init];
        drinkCmd.onoff = swt.on;
        drinkCmd.start_hour = 9;
        drinkCmd.start_min = 0;
        drinkCmd.end_hour = 20;
        drinkCmd.end_min = 59;
        drinkCmd.interval = 30;
        [[CEProductK6 shareInstance] sendCmdToDevice:drinkCmd complete:nil];
    }else if (8 == tag){
        DataManager.shared.date.format = swt.on;
        uint32_t absTime = [[NSDate date] timeIntervalSince1970];
        NSInteger offsetTime = (uint32_t)[NSTimeZone defaultTimeZone].secondsFromGMT;
        CE_SyncTimeCmd *timeCmd = [[CE_SyncTimeCmd alloc] initWithAbsTime:absTime
                                                                   offset:offsetTime
                                                                   format:DataManager.shared.date.format
                                                                 mdFormat:DataManager.shared.date.mdFormat];
        [[CEProductK6 shareInstance] sendCmdToDevice:timeCmd complete:nil];
    }else if (9 == tag){
        DataManager.shared.date.mdFormat = swt.on;
        uint32_t absTime = [[NSDate date] timeIntervalSince1970];
        NSInteger offsetTime = (uint32_t)[NSTimeZone defaultTimeZone].secondsFromGMT;
        CE_SyncTimeCmd *timeCmd = [[CE_SyncTimeCmd alloc] initWithAbsTime:absTime
                                                                   offset:offsetTime
                                                                   format:DataManager.shared.date.format
                                                                 mdFormat:DataManager.shared.date.mdFormat];
        [[CEProductK6 shareInstance] sendCmdToDevice:timeCmd complete:nil];
    }else if (11 == tag){
        CE_SyncDisturbCmd *disturbCmd = [[CE_SyncDisturbCmd alloc] init];
        NSMutableArray *disturbsArray = [NSMutableArray array];
        CE_DisturbItem *item = [[CE_DisturbItem alloc] init];
        item.start_time_hour = 9;
        item.start_time_min = 0;
        item.end_time_hour = 20;
        item.end_time_min = 59;
        [disturbsArray addObject:item];
        disturbCmd.disturbItems = disturbsArray;
        disturbCmd.switch_flag = swt.on;
        [[CEProductK6 shareInstance] sendCmdToDevice:disturbCmd complete:nil];
    }else if (12 == tag){
        YD_SyncUpBrightCmd *upBrightCmd = [[YD_SyncUpBrightCmd alloc] init];
        upBrightCmd.onoff = swt.on;
        upBrightCmd.start_hour = 9;
        upBrightCmd.start_min = 0;
        upBrightCmd.end_hour = 20;
        upBrightCmd.end_min = 59;
        [[CEProductK6 shareInstance] sendCmdToDevice:upBrightCmd complete:nil];
    }else if (13 == tag){
        YD_SyncAutoHeartCmd *autoHeartCmd = [[YD_SyncAutoHeartCmd alloc] init];
        autoHeartCmd.onoff = swt.on;
        [[CEProductK6 shareInstance] sendCmdToDevice:autoHeartCmd complete:nil];
    }else if (14 == tag){
        CE_SendPhotoCmd* photoCmd = [[CE_SendPhotoCmd alloc] init];
        photoCmd.onoff = swt.on;
        [[CEProductK6 shareInstance] sendCmdToDevice:photoCmd complete:nil];
    }
}

- (void)sendWeather{
    CE_SyncWeatherCmd *weatherCmd = [[CE_SyncWeatherCmd alloc] init];
    weatherCmd.time = (uint32_t)[[NSDate date] timeIntervalSince1970];
    NSInteger index = 0;
    // weatherModel.forecasts 数组长度小于3数据会发送，设备侧不会处理
    for (int i=0; i<3; i++) {
        CE_WeatherItem *weatherItem = [[CE_WeatherItem alloc] init];
       
        // weatherType = 0，使用旧协议的天气类型
        weatherItem.weather = 0;
        if (index == 0) {
            weatherItem.low_temperature = 28;
            weatherItem.high_temperature = 31;
            weatherCmd.todyWeather = weatherItem;
        } else if (index == 1) {
            weatherItem.low_temperature = 27;
            weatherItem.high_temperature = 32;
            weatherCmd.tomorrowWeather = weatherItem;
        } else if (index == 2) {
            weatherItem.low_temperature = 29;
            weatherItem.high_temperature = 30;
            weatherCmd.dayAfterTomorrowWeather = weatherItem;
        }else {
            break;
        }
        index ++;
    }
    
    [[CEProductK6 shareInstance] sendCmdToDevice:weatherCmd complete:^(NSError *error) {
        if (error == nil){
            NSLog(@"😄😄😄😄😄😄😄 send success");
        }
    }];
}

- (void)updateCell:(ListSwtCell *)cell atIndexPath:(NSIndexPath *)indexPath{
    
    DataManager *shared = DataManager.shared;
    if (3 == indexPath.row){
        cell.swt.on = shared.smsSwt.onoff;
    }
    if (4 == indexPath.row){
        cell.swt.on = shared.callSwt.onoff;
    }
    if (5 == indexPath.row) {
        cell.swt.on = shared.longSit.isOpen;
    }
    if (6 == indexPath.row) {
        cell.swt.on = shared.targetSwt.onoff;
    }
    if (7 == indexPath.row){
        cell.swt.on = shared.waterSwt.isOpen;
    }
    if (8 == indexPath.row) {
        cell.swt.on = shared.date.format;
        cell.detailTextLabel.text = shared.date.format == 0 ? @"12小时制" : @"24小时制";
    }
    if (9 == indexPath.row) {
        cell.swt.on = shared.date.mdFormat;
        cell.detailTextLabel.text = shared.date.mdFormat == 0 ? @"月-日" : @"日-月";
    }
    if (11 == indexPath.row){
        cell.swt.on = shared.disturb.switch_flag;
    }
    if (12 == indexPath.row){
        cell.swt.on = shared.raiseSwt.onoff;
    }
    if (13 == indexPath.row){
        cell.swt.on = shared.autoHrSwt.onoff;
    }
    if (14 == indexPath.row){
        cell.swt.on = shared.takePhotoSwt.onoff;
    }
}


@end
