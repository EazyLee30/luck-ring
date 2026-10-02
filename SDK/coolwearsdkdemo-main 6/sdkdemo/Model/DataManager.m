//
//  DataManager.m
//  sdkdemo
//
//  Created by coolwear on 2022/9/21.
//

#import "DataManager.h"

@implementation DataManager

+ (instancetype)shared{
    static DataManager *single = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        single = [[DataManager alloc] init];
    });
    return single;
}

- (void)storage:(BaseModel *)model{

    if (model.DataType == DATA_TYPE_DEV_SYNC){
        for (NSDictionary *dic in model.dataObject){
            BaseModel *sub = [BaseModel mj_objectWithKeyValues:dic];
            [self storage:sub];
        }
    }
    if (model.DataType == DATA_TYPE_DEVINFO) {
        self.devInfo = model.dataObject;
    }
    if (model.DataType == DATA_TYPE_MESSAGE_ALARM){
        self.smsSwt = model.dataObject;
    }
    if (model.DataType == DATA_TYPE_CALL_ALARM){
        self.callSwt = model.dataObject;
    }
    if (model.DataType == DATA_TYPE_SITTING_REMIND){
        self.longSit = model.dataObject;
    }
    if (model.DataType == DATA_TYPE_MESSAGE_SWITCH) {
        self.appswt = model.dataObject;
    }
    if (model.DataType == DATA_TYPE_TARGET_ALARM){
        self.targetSwt = model.dataObject;
    }
    if (model.DataType == DATA_TYPE_DRINK_ALARM){
        self.waterSwt = model.dataObject;
    }
    if (model.DataType == DATA_TYPE_TIME){
        self.date = model.dataObject;
    }
    if (model.DataType == DATA_TYPE_FORGET_DISTURB){
        self.disturb = model.dataObject;
    }
    if (model.DataType == DATA_TYPE_HAND_RISE_SWITCH){
        self.raiseSwt = model.dataObject;
    }
    if (model.DataType == DATA_TYPE_HEART_AUTO_SWITCH) {
        self.autoHrSwt = model.dataObject;
    }
    if (model.DataType == DATA_TYPE_PHOTOGRAPH_ONOFF){
        self.takePhotoSwt = model.dataObject;
    }
    if (model.DataType == DATA_TYPE_CONTACT_SYNC) {
        ContactModel *contact = model.dataObject;
        if (contact.idx > 0){
            [self.contactData addObject:contact];
            [CE_SyncContactCmd syncAtIndex:contact.idx+1 handler:nil];
        }else{
            [NSNotificationCenter.defaultCenter postNotificationName:@"SyncContactEnd" object:nil userInfo:nil];
        }
    }
    if (model.DataType == DATA_TYPE_REAL_HEART){
        self.heartModel = model.dataObject;
    }
    
}

@end
