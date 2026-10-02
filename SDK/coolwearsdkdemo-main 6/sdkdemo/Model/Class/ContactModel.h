//
//  ContactModel.h
//  sdkdemo
//
//  Created by coolwear on 2022/9/30.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ContactModel : NSObject
@property (nonatomic, assign) NSInteger idx;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *tel;
@end

NS_ASSUME_NONNULL_END
