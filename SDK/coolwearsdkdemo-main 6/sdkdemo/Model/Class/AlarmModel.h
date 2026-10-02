//
//  AlarmModel.h
//  sdkdemo
//
//  Created by coolwear on 2022/9/27.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AlarmDataModel : NSObject
@property (nonatomic, strong) NSArray *alarm_infos;
@end

@interface AlarmModel : NSObject
@property (nonatomic, assign) NSInteger alarmType;
@property (nonatomic, assign) NSInteger hour;
@property (nonatomic, assign) NSInteger min;
@property (nonatomic, assign) NSInteger repeatDay;
@property (nonatomic, assign) NSInteger status;
@property (nonatomic, copy) NSString* name;
@end


NS_ASSUME_NONNULL_END
