//
//  RealtimeHeartRateModel.h
//  sdkdemo
//
//  Created by coolwear on 2023/5/8.
//

#import "BaseModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface RealtimeHeartRateModel : BaseModel
@property (nonatomic, assign) NSInteger time;
@property (nonatomic, assign) NSInteger heartNum;
@end

NS_ASSUME_NONNULL_END
