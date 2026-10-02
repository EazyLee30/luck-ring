//
//  BaseFuncModel.m
//  sdkdemo
//
//  Created by coolwear on 2022/9/22.
//

#import "FuncModel.h"

@implementation FuncModel

- (instancetype)initWithTitle:(NSString *)title type:(NSInteger)type{
    if (self = [super init]){
        _title = title;
        _type = type;
    }
    return self;
}

- (instancetype)initWithTitle:(NSString *)title type:(NSInteger)type page:(NSString *)page{
    if (self = [super init]){
        _title = title;
        _type = type;
        _page = page;
    }
    return self;
}
@end
