//
//  CEBleConnect.h
//  K2SDKDemo
//
//  Created by cxq on 2016/12/19.
//  Copyright © 2016年 celink. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
//搜索到的设备
#import "SearchPeripheral.h"
@class CEBleConnect;

@protocol CEConnectDelegate <NSObject>

/**  刚开始搜索回调,已经搜索到的设备 */
- (void)peripheralDidStartScan:(NSArray <SearchPeripheral *> *)peripherals connect:(CEBleConnect *)connect;

/**  发现新的设备回调,已经搜索到的设备 */
- (void)peripheralDidDiscoverd:(NSArray <SearchPeripheral *> *)peripherals connect:(CEBleConnect *)connect;

/**   开始连接设备回调, 正在连接的设备 */
- (void)peripheralDidStartConnect:(CBPeripheral *)peripheral connect:(CEBleConnect *)connect;

/**  蓝牙状态变更回调, 蓝牙状态 */
- (void)bluetoothCentralManagerDidUpdateState:(CBCentralManagerState)state;

/**  设备已连接成功的回调, 已经连接的设备 */
- (void)peripheralDidConnected:(CBPeripheral *)peripheral connect:(CEBleConnect *)connect;

/**  设备已断开连接的回调, 已经断开的设备 */
- (void)peripheralDidDisConnected:(CBPeripheral *)peripheral connect:(CEBleConnect *)connect;

/**  Connection state ERROR  */
- (void)peripheralConnectionError:(NSError*)error peripheral:(CBPeripheral *)peripheral;

@end



@interface CEBleConnect : NSObject

@property (nonatomic,weak) id <CEConnectDelegate> delegate;

/**  正在连接的设备 */
@property (nonatomic,strong,readonly) CBPeripheral *connectingPeripheral;


/**  开始搜索拥有指定服务ID的设备 ,YES:正在搜索， NO:没有打开蓝牙 */
- (BOOL)startScanPeripheralsWithServiceId:(NSString *)sid;

/** 停止搜索*/
- (void)stopScan;

/**  连接指定的设备 */
- (void)connectPeripheral:(CBPeripheral *)peripheral;

/**  已经找到的 所有设备 */
- (NSArray<SearchPeripheral*> *)discoveredDevices;

/**  连接指定identifier的设备 */
- (void)reconnectWithUUid:(NSString *)identifier;


/**  取消当前的连接 */
- (void)cancelConnect;


@end
