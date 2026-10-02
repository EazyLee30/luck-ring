//
//  AppDelegate+CE.h
//  Daewoo
//
//  Created by LiJie on 2017/1/11.
//  Copyright © 2017年 celink. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate (CE)

// 初始化基本设置和一些第三方组件
- (void)setupDefaultConfigure;

- (BOOL)customApplication:(UIApplication *)application OpenURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options;

@end
