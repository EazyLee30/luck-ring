//
//  DeviceModel.m
//  sdkdemo
//
//  Created by coolwear on 2022/9/27.
//

#import "DeviceInfoModel.h"

@implementation DeviceInfoModel

- (NSInteger)customer_id{
    if (_items > 11){
        return ((_customer_id_h << 8) + _customer_id);
    }
    return _customer_id;
}

@end
