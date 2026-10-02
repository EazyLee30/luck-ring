//
//  BaseModel.m
//  sdkdemo
//
//  Created by coolwear on 2022/9/27.
//

#import "BaseModel.h"

@implementation BaseModel

- (Class)model{
    if (self.DataType == DATA_TYPE_DEVINFO) return DeviceInfoModel.class;
    if (self.DataType == DATA_TYPE_MESSAGE_ALARM) return SwtModel.class;
    if (self.DataType == DATA_TYPE_CALL_ALARM) return SwtModel.class;
    if (self.DataType == DATA_TYPE_SITTING_REMIND) return LongSitModel.class;
    if (self.DataType == DATA_TYPE_MESSAGE_SWITCH) return AppSwtModel.class;
    if (self.DataType == DATA_TYPE_TARGET_ALARM) return SwtModel.class;
    if (self.DataType == DATA_TYPE_DRINK_ALARM) return SwtModel.class;
    if (self.DataType == DATA_TYPE_TIME) return DateModel.class;
    if (self.DataType == DATA_TYPE_FORGET_DISTURB) return DisturbModel.class;
    if (self.DataType == DATA_TYPE_HAND_RISE_SWITCH) return SwtModel.class;
    if (self.DataType == DATA_TYPE_HEART_AUTO_SWITCH) return SwtModel.class;
    if (self.DataType == DATA_TYPE_PHOTOGRAPH_ONOFF) return SwtModel.class;
    if (self.DataType == DATA_TYPE_CONTACT_SYNC) return ContactModel.class;
    if (self.DataType == DATA_TYPE_REAL_HEART) return RealtimeHeartRateModel.class;
    return nil;
}

- (id)dataObject{
    if (self.DataType == DATA_TYPE_DEV_SYNC) {
        return self.Data;
    }
    if (self.DataType == DATA_TYPE_REAL_HEART){
        NSArray* infos = self.Data[@"heartInfos"];
        NSDictionary* dic = infos.firstObject;
        return [RealtimeHeartRateModel mj_objectWithKeyValues:dic];;
    }
    return [self.model mj_objectWithKeyValues:self.Data];
}

@end
