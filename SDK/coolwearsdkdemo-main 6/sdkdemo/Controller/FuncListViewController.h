//
//  DemoViewController.h
//  sdkdemo
//
//  Created by coolwear on 2022/9/20.
//

#import <UIKit/UIKit.h>
#import <BluetoothLibrary/BluetoothLibrary.h>

NS_ASSUME_NONNULL_BEGIN

@interface FuncListViewController : UIViewController
@property (nonatomic, strong) SearchPeripheral *sp;
@end

NS_ASSUME_NONNULL_END
