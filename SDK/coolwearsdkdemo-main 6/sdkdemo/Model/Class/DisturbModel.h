//
//  DisturbModel.h
//  sdkdemo
//
//  Created by coolwear on 2022/9/27.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DisturbModel : NSObject
@property (nonatomic, assign) NSInteger count;
@property (nonatomic, strong) NSArray *disturbs;
@property (nonatomic, assign) BOOL switch_flag;
@end

NS_ASSUME_NONNULL_END
