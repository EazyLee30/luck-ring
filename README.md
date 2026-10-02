# Luck Ring iOS 读数

结论：**能做**。SDK 是闭环的 iOS framework，协议、数据类型、命令全部齐全，构建已通过。真机上插上 ring 就能读数。

## 关键约束

`BluetoothLibrary.framework` 只有 arm64 **真机** slice（`lipo` 确认非 fat），没有模拟器架构。
`SUPPORTED_PLATFORMS` 设成 `iphoneos`，模拟器不能作为 destination —— 必须真机 + 蓝牙。

厂商 demo 工程原样构建通过（`BUILD SUCCEEDED`），说明 SDK 与当前 Xcode 26.3 没有兼容性问题。

## 布局

```
SDK/SDK/BluetoothLibrary.framework     新版，93 个 header，iOS SDK 26 编译
SDK/coolwearsdkdemo-main 6/            厂商 demo，含 Pods 与示例代码
ios/                                    本文所述的精简读数 app
```

两版 framework 二进制 SHA 不同（新版更全，带 `CE_GestureCmd`、`CE_ExternWeatherCmd`、`DataStruct.h` 等）。选新版。

## 读数 app

`ios/` 下是一个无 CocoaPods 依赖的 UIKit app，用 xcodegen 生成工程：

- `RingBLE.swift` — SDK 封装。扫描、连接、配对握手、各类读数命令
- `DataLog.swift` — JSONL 落盘 + `funcType` 名称表 + 控制台格式化
- `ScanViewController` — 扫到设备列表（过滤 `version > 4`，与厂商 demo 一致）
- `ReaderViewController` — 读数按钮面板 + 实时 hex/数据控制台

### 构建

```bash
cd ios && xcodegen generate
xcodebuild -project LuckRingReader.xcodeproj -scheme LuckRingReader \
  -destination 'generic/platform=iOS' build
```

已验证：`CODE_SIGNING_ALLOWED=NO` 下 `BUILD SUCCEEDED`，framework 正确 embed 进 `Frameworks/`。

装真机需要在 Xcode 里选自己的开发者账号签名（`Signing & Capabilities`）。

## 连接后自动发生什么

`ProductStatus_completed` 之后 SDK 触发握手：开 sensor 开关 → 系统配对 → 同步时间 → 同步用户档案 → 确认配对 → 读设备信息 / 电量 / OTA 状态 / 全部信息 → 保存自动重连 UUID。

**首次配对需要点一下 ring 屏幕确认。**

## 能读到什么

`DATA_TYPE_*` 共 60+ 种。注意区分两类：

- **主动请求**：`CE_RequestDevInfoCmd`、`CE_RequestBatteryCmd`、`CE_RequestAllInfoCmd` 等，按钮直接触发
- **设备推送**：步数、睡眠、心率历史。SDK 里没有对应的 Request 命令 —— 必须 `CE_SensorCmd` on，设备才主动上流

所以「读点数据」的关键是 sensor 开关，不是发命令。app 已在握手和 `Sensor ON` 按钮两处打开。

实时测量走 `CE_SyncHeartRateCmd` / `CE_SyncBloodPressureCmd` / `CE_SyncHeartO2Cmd`（`status = 1`），结果异步回来。

## 原始数据抓包

`CEProductK6` 暴露两个 block，不用反编译就能拿完整报文：

```swift
productK6.receiveOriginalDataHandler = { data in /* 设备 → app */ }
productK6.sendOriginalDataHandler    = { data in /* app → 设备 */ }
```

app 已把它们全部写进 JSONL 的 `rx` / `tx` 条目。

协议帧结构（从 `-[CE_K6Protocol constructData:...]` 反汇编得到）：10 字节头 + 每包 19 字节 body，单包上限 20 字节；头里含 funcType、cmdType、流水号、包序号、body 长度。CRC 是 `crc_dspWithReg:dataCrc:`，poly `0x8005`。

## 注意事项

- `CE_ClearDataCmd` 会**清掉 ring 上的历史数据**，UI 里已加二次确认
- `CE_SendOtaDataCmd` 是固件升级，没接
- 后台运行靠 `UIBackgroundModes: bluetooth-central`；`applicationWillResignActive` 里关 sensor 省电
- 捕获文件落在 app 的 `Documents/captures/`，`UIFileSharingEnabled` 打开，可以从「文件」App 直接取

## 还没做的

- ring 自身的电量/佩戴状态等 ring 专属字段：SDK 层的 `DATA_TYPE_*` 已覆盖通用部分，ring 特有字段要等实测 `DATA_TYPE_HISTORY_TEMP`(47)、`DATA_TYPE_SET_VALUABLE_ASSISTANT`(48) 回什么
- 协议层复刻（不依赖 framework 直接讲 BLE）：帧格式已知，但 GATT UUID 藏在 binary 里没挖出来