//
//  LongSitModel.h
//  ;
//
//  Created by coolwear on 2022/9/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 114
@interface LongSitModel : NSObject
@property (nonatomic, assign) NSInteger endHour;
@property (nonatomic, assign) NSInteger endMin;
@property (nonatomic, assign) NSInteger startHour;
@property (nonatomic, assign) NSInteger startMin;
@property (nonatomic, assign) BOOL isOpen;
@property (nonatomic, assign) BOOL noon_onoff;
@property (nonatomic, assign) BOOL week_repeat;
@end

NS_ASSUME_NONNULL_END
