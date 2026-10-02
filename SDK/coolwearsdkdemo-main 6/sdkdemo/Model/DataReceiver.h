//
//  DataReceiver.h
//  sdkdemo
//
//  Created by coolwear on 2022/9/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DataReceiver : NSObject

@property (nonatomic, assign) BOOL isFirstPaired; // 是否为首次连接配对(首次连接有震动)

//@property (nonatomic, strong) RACReplaySubject <CEDeviceInfoModel *>*deviceInfoSubject;
//@property (nonatomic, strong) RACReplaySubject <NSNumber *>*connectionStatusSubject;
//@property (nonatomic, strong) RACSubject <NSArray<YDBloodPressureModel *>*>*bloodPressureSubject;
//@property (nonatomic, strong) RACSubject <NSArray<YDBloodOxygenModel *>*>*bloodOxygenSubject;
//@property (nonatomic, strong) RACSubject <NSArray<CEDisturbModel *>*>*doNotDisturbSubjet;
//@property (nonatomic, strong) RACSubject <NSNumber *>*takePhotoSubject;                 //拍照控制 0 设备关闭拍照功能 1 拍照
//@property (nonatomic, strong) RACSubject <DialConfigureModel *>*watchFaceSubject;       //表盘配置
//@property (nonatomic, strong) RACSubject <YDFunctionControl *>*functionControlSubject;  //功能模块
//@property (nonatomic, strong) RACSubject *watchfaceTransmitAccelerateSubject;           //图片高速传输功能
//@property (nonatomic, strong) RACSubject *sleepUpdateSubject;                           //睡眠数据
//@property (nonatomic, strong) RACSubject *heartRateRecordSubject;                       //心率回调
//@property (nonatomic, strong) RACSubject <CEDevDaySportModel *> *stepSubject;           //实时步数回调
//@property (nonatomic, strong) RACSubject *contactSubject;                               //通讯录回调
//@property (nonatomic, strong) RACSubject *sportingStatusSubject;                        //运动状态
//@property (nonatomic, strong) RACSubject *controlStatusSubject;                        //手表佩戴状态
//@property (nonatomic, strong) RACSubject *refreshSubject;                        //刷新状态
//
//@property (nonatomic, strong) RACSubject <CERaiseScreenModel *>*raiseToWakeSubjcect;

+ (instancetype)shared;

- (void)syncData;

@end

NS_ASSUME_NONNULL_END
