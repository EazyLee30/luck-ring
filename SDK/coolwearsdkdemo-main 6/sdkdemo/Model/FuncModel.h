//
//  BaseFuncModel.h
//  sdkdemo
//
//  Created by coolwear on 2022/9/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FuncModel : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) NSInteger type; //0-跳转 1-开关 2-箭头不跳转
@property (nonatomic, copy) NSString *page;

- (instancetype)initWithTitle:(NSString *)title type:(NSInteger)type;
- (instancetype)initWithTitle:(NSString *)title type:(NSInteger)type page:(NSString *)page;;
@end

NS_ASSUME_NONNULL_END
