//
//  DataReceiver.m
//  sdkdemo
//
//  Created by coolwear on 2022/9/21.
//

#import "DataReceiver.h"
#import "DeviceInfoModel.h"
#import <BluetoothLibrary/BluetoothLibrary.h>

@implementation DataReceiver

+ (instancetype)shared{
    static DataReceiver *single = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        single = [[DataReceiver alloc] _init];
    });
    return single;
}


- (instancetype)_init {
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveBleData:) name:CEProductK6ReceiveDataNoticeKey object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bluetoothStatusChanged:) name:ProductStatusChangeNoticeKey object:nil];
//        [self initSubject];
    }
    return self;
}

- (void)receiveBleData:(NSNotification *)noti{
    
    NSDictionary *receiveData = [noti userInfo];
    NSDictionary *data = receiveData[@"Data"];
    if (!data) {
        return;
    }
    
    K6_DataFuncType dataFuncType = [receiveData[@"DataType"] integerValue];
    switch (dataFuncType) {
        case DATA_TYPE_SLEEP: {
 //            [self parseSleepData:(NSArray *)data];
            break;
        }
            
        case DATA_TYPE_USER_CHANGE:
            // 在配对完成后处理
            break;
        case DATA_TYPE_DEVINFO:
        case DATA_TYPE_BATTERY_INFO:
        case DATA_TYPE_OTA_STATUS:
        case DATA_TYPE_ALARM:
        case DATA_TYPE_MESSAGE_NOTICE:
        case DATA_TYPE_SITTING_REMIND:
        case DATA_TYPE_FORGET_DISTURB:
        case DATA_TYPE_CALL_ALARM:
        case DATA_TYPE_MESSAGE_ALARM:
        case DATA_TYPE_HAND_RISE_SWITCH:
        case DATA_TYPE_HEART_AUTO_SWITCH:
        case DATA_TYPE_DRINK_ALARM:
        case DATA_TYPE_TARGET_ALARM:
        case DATA_TYPE_TIME:
        case DATA_TYPE_USERINFO: {
//            [self saveReceiveData:data type:dataFuncType];
            break;
        }
         
        case DATA_TYPE_REAL_SPORT:
        case DATA_TYPE_HISTORY_SPORT: {
//                            [self analysisSportData:data];
            break;
        }
        
        case DATA_TYPE_REAL_HEART:
        case DATA_TYPE_EXERCISE_HEART:
        case DATA_TYPE_HISTORY_HEART:{
//            [self parseHeartData:data funType:dataFuncType];
            break;
        }
        
        case DATA_TYPE_MIX_SPORT: {
//            [self parseMixSportData:data];
            break;
        }
    
        case DATA_TYPE_DEV_SYNC: {
            // 强制校正设备类型，从设备里面选择连接设备已经指定了设备类型（列表里面是按照名称过滤，在测试时可能会出现与实际类型不符合）
            // 接收到设备数据时会包含实际设备类型
//            [YDUserDataManager saveDeviceType:[CEProductK6 shareInstance].pid];
//            
//            // 收到混杂数据（数组） 循环解析数据, 需要 重新保存到app本地
//            for (NSDictionary *subDic in data) {
//                K6_DataFuncType subType = [subDic[@"DataType"] intValue];
//                NSDictionary *subData = subDic[@"Data"];
//                [self saveReceiveData:subData type:subType];
//            }
            break;
        }
        
        case DATA_TYPE_FIND_PHONE_OR_DEVICE: {
            
            break;
        }
            
        case DATA_TYPE_PHOTOGRAPH_ONOFF:{
            //拍照 不带 有效数据
        
            break;
        }
            
        case DATA_TYPE_APP_SPORT: {
//            [self.sportingStatusSubject sendNext:receiveData];
        }
            break;
            
        case DATA_TYPE_REAL_BP: {
            NSArray *bpDictionaryArray = data[@"data"];
            NSMutableArray *bpArray = [NSMutableArray array];
//            for (NSDictionary *dic in bpDictionaryArray) {
//                YDBloodPressureModel *bp = [YDBloodPressureModel mj_objectWithKeyValues:dic];
//                [bpArray addObject:bp];
//            }
//            [YDBloodPressureModel saveArrayToDB:bpArray complete:^{
//                DLog(@"血压数据存储到数据库");
//            }];
//            [self.bloodPressureSubject sendNext:bpArray];
        }
            break;
        case DATA_TYPE_REAL_O2: {
            NSArray *o2DictionaryArray = data[@"data"];
            NSMutableArray *o2Array = [NSMutableArray array];
//            for (NSDictionary *dic in o2DictionaryArray) {
//                YDBloodOxygenModel *model = [YDBloodOxygenModel modelWithDict:dic];
//                if (model.time > 0) {
//                    [o2Array addObject:model];
//                }
//            }
//            [YDBloodOxygenModel saveArrayToDB:o2Array complete:nil];
//            [self.bloodOxygenSubject sendNext:o2Array];
        }
            break;

        case DATA_TYPE_HR_CONTROL: {
            // app没有用到所以删除了
            
//            NSInteger onoff = integerFromObject(data, @"onoff");
//            [self.controlStatusSubject sendNext:[NSNumber numberWithInteger:onoff]];
        }
            break;

        case DATA_TYPE_WATCH_FACE_INFO: {
           
        }
            break;
            
        case DATA_TYPE_WATCH_FACE_START: {
            
        }
            break;
        case DATA_TYPE_CONTACT_SYNC: {
         
        }
            break;
        case DATA_TYPE_ALIPAY_RAW_DATA:{
        
        }
            break;

        case DATA_TYPE_MOTION_DATA: {

        }
            break;
        default:
            break;
    }
    [NSNotificationCenter.defaultCenter postNotificationName:@"DataReceivceFinish" object:nil];
}

/// 保存数据
- (void)saveReceiveData:(NSDictionary *)dicData type:(K6_DataFuncType)type{
    NSLog(@"saveReceiveData %@ type: %zi", dicData, type);
    switch (type) {
        case DATA_TYPE_DEVINFO:{
//            CEDeviceInfoModel* model = [CEDeviceInfoModel mj_objectWithKeyValues:dicData];
//
//            [WatchK6.requester bind:YES];
//            [WatchK6.informant bind:model];
//            [WatchK6.connector snycDialInfo];
//
//            [OTAInspector.shared syncData:model];
//            [self.deviceInfoSubject sendNext:model];

//            DLog(@"接收到设备信息：customerID=%i", model.customer_id);
        }
            break;
        case DATA_TYPE_BATTERY_INFO:{
//            NSInteger electricity = [dicData[@"battery_capacity"] integerValue];
//            WatchK6.informant.electricity = electricity;
        }
            break;
        case DATA_TYPE_OTA_STATUS:{
            // 处理 OTA 在 YDOTAManager
        }
            break;
        case DATA_TYPE_ALARM:{
//            [AlarmStore store:dicData];
        }
            break;
        case DATA_TYPE_SET_TARGET:{
        }
            break;
        case DATA_TYPE_MESSAGE_NOTICE:{
            
        }
            break;
        case DATA_TYPE_SITTING_REMIND:{
    
        }
            break;
        case DATA_TYPE_FORGET_DISTURB:{

        }
            break;
        case DATA_TYPE_USERINFO:{
  
        }
            break;
            
        case DATA_TYPE_UNIT_SETTING:{
//            [UnitStore store:dicData];
        }
            break;
            
        case DATA_TYPE_CALL_ALARM: {

        }
            break;
            
        case DATA_TYPE_MESSAGE_ALARM: {
           
        }
            break;
            
        case DATA_TYPE_HAND_RISE_SWITCH: {
          
        }
            break;
            
        case DATA_TYPE_HEART_AUTO_SWITCH: {
           
        }
            break;
            
        case DATA_TYPE_DRINK_ALARM: {
          
        }
            break;
            
        case DATA_TYPE_TARGET_ALARM: {
//            BOOL onoff = [dicData[@"onoff"] boolValue];
//            [ReachGoalStorage store:onoff];
        }
            break;
            
        case DATA_TYPE_TIME: {
//            CETimeFormatModel *model = [CETimeFormatModel mj_objectWithKeyValues:dicData];
//            [model saveToDB:nil];
        }
            break;
        
        case DATA_TYPE_MESSAGE_SWITCH: {
            
        }
            break;
            
        case DATA_TYPE_FUNCTION_CONTROL: {
            
        }
            break;
        
        case DATA_TYPE_WOMAN_STAGE_INFO: {
        
        }
            break;
            
        case DATA_TYPE_HARDWARE_INFO: {
        
        }
            break;
        case DATA_TYPE_BTEDR_ADDR:{

        }
            break;
        default: {
        }
            break;
    }
}

- (void)bluetoothStatusChanged:(NSNotification *)noti {
    
//    [self stopTimer];
    NSInteger status = [noti.object intValue];
    if ([[noti object] intValue] < ProductStatus_connected) {
//        [self findPhoneForOnoff:NO];
    }
    
    if ([[noti object] intValue] == ProductStatus_completed) {
        [self syncData];
//        [WeatherManager.shared update];
    }
    
    //如果断开蓝牙设备了，就10秒轮询自动连接一次
    if (status == ProductStatus_powerOff ||
        status == ProductStatus_disconnected) {
//        [self startTimer];
    }
    
//    WatchK6.informant.name = CEProductK6.shareInstance.peripheral.name;
//    [self.connectionStatusSubject sendNext:@(status)];
}

- (void)syncData {

    CE_SyncHybridCmd *tHybridCmd = [[CE_SyncHybridCmd alloc] init];
    
    CE_SyncUserInfoCmd *infoCmd = [self userInfoCmd];
    
    CE_SyncGoalCmd *gCmd = [self goalCmd];
    
    YD_SyncLanguageCmd *lCmd = [[YD_SyncLanguageCmd alloc] initWithLanguage:0];
    
    CE_SyncTimeCmd *tCmd = [self timeCmd];
    
    CE_SensorCmd *sensorCmd = [[CE_SensorCmd alloc] init];
    sensorCmd.onoff = 1;

    CE_SyncPairOKCmd *tPairOkCmd = [[CE_SyncPairOKCmd alloc] init];
    tPairOkCmd.firstPairStatus = 0;

    tHybridCmd.infoItems = @[infoCmd, gCmd, lCmd, tCmd, sensorCmd, tPairOkCmd];
    [[CEProductK6 shareInstance] sendCmdToDevice:tHybridCmd complete:nil];
}

- (CE_SyncUserInfoCmd *)userInfoCmd{
    CE_SyncUserInfoCmd *cmd = [[CE_SyncUserInfoCmd alloc] init];
    cmd.userId = 0;
    cmd.sex = 0;
    cmd.age = 18;
    cmd.height = 170;
    cmd.weight = 60;
    cmd.lrHand = 1;
    return cmd;
}

- (CE_SyncGoalCmd *)goalCmd{
    CE_SyncGoalCmd *cmd = [[CE_SyncGoalCmd alloc] init];
    cmd.sleep = 480;
    cmd.step = 2000;
    cmd.distance = 5000;
    cmd.calories = 1200;
    cmd.sportTime = 30;
    return cmd;
}
- (CE_SyncTimeCmd *)timeCmd{
    CE_SyncTimeCmd *timeCmd = [[CE_SyncTimeCmd alloc] init];
    timeCmd.absTime = [[NSDate date] timeIntervalSince1970];
    timeCmd.offsetTime = (uint32_t)[NSTimeZone defaultTimeZone].secondsFromGMT;
    timeCmd.format = 1;
    timeCmd.mdFormat = 1;
    return timeCmd;
}
@end
