//
//  BaseModel.h
//  sdkdemo
//
//  Created by coolwear on 2022/9/27.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BaseModel : NSObject
@property (nonatomic, strong) id Data;
@property (nonatomic, assign) K6_DataFuncType DataType;
@property (nonatomic, copy) NSString *DataType_Description;
@property (nonatomic, copy) NSString *error_msg;

- (Class)model;

- (id)dataObject;

@end

NS_ASSUME_NONNULL_END
