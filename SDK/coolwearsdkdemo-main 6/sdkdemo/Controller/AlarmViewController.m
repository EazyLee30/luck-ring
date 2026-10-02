//
//  AlarmViewController.m
//  sdkdemo
//
//  Created by coolwear on 2022/9/22.
//

#import "AlarmViewController.h"

@interface AlarmViewController ()
@property (nonatomic, strong) UILabel *lab;
@end

@implementation AlarmViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"闹钟提醒";
    
    UIButton *addBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 100, self.view.bounds.size.width, 55)];
    addBtn.backgroundColor = UIColor.blueColor;
    [addBtn setTitle:@"添加闹钟" forState:UIControlStateNormal];
    [addBtn addTarget:self action:@selector(addAlarm) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:addBtn];
    
    self.lab = [[UILabel alloc] init];
    self.lab.frame = CGRectMake(20, CGRectGetMaxY(addBtn.frame) + 12, self.view.bounds.size.width, 30);
    [self.view addSubview:self.lab];
}

- (void)addAlarm{
    NSMutableArray *alarmArray = [NSMutableArray array];
    
    CE_AlarmItem *item = [[CE_AlarmItem alloc] init];
    item.status = 1;
    item.hour = [self dateComponets].hour;
    item.min = [self dateComponets].minute+1;
    item.repeatDay = 0;
    item.name = @"下一分钟的闹钟";
    item.isRepeatWeek = NO;
    [alarmArray addObject:item];
    
    CE_SyncAlarmK6Cmd *alarmCmd = [[CE_SyncAlarmK6Cmd alloc] init];
    alarmCmd.alarmItems = alarmArray;
    [[CEProductK6 shareInstance] sendCmdToDevice:alarmCmd complete:^(NSError *error) {
        if (!error) {
            self.lab.text = [NSString stringWithFormat:@"%@ %hhu:%hhu",item.name,item.hour,item.min];
        }
    }];
}

- (NSDateComponents *)dateComponets{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSUInteger unitFlags =  NSCalendarUnitHour | NSCalendarUnitMinute;
    NSDateComponents *dateComponent = [calendar components:unitFlags fromDate:NSDate.date];
    return dateComponent;
}

@end
