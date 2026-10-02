//
//  DataManager.h
//  sdkdemo
//
//  Created by coolwear on 2022/9/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DataManager : NSObject
@property (nonatomic, strong) DeviceInfoModel *devInfo;
@property (nonatomic, strong) AlarmDataModel *alarms;
@property (nonatomic, strong) LongSitModel *longSit;
@property (nonatomic, strong) DisturbModel *disturb;
@property (nonatomic, strong) AppSwtModel *appswt;
@property (nonatomic, strong) DateModel *date;
@property (nonatomic, strong) SwtModel *smsSwt;
@property (nonatomic, strong) SwtModel *callSwt;
@property (nonatomic, strong) SwtModel *targetSwt;
@property (nonatomic, strong) SwtModel *waterSwt;
@property (nonatomic, strong) SwtModel *raiseSwt;
@property (nonatomic, strong) SwtModel *autoHrSwt;
@property (nonatomic, strong) SwtModel *takePhotoSwt;
@property (nonatomic, strong) NSMutableArray<ContactModel *> *contactData;
@property (nonatomic, strong) RealtimeHeartRateModel *heartModel;

+ (instancetype)shared;

- (void)storage:(BaseModel *)model;

@end

NS_ASSUME_NONNULL_END
