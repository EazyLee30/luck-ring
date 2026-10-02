# 开发指南(OC)

## 1.工程配置
* 将**BluetoothLibrary.framework**拖入工程中
 
* 导入头文件`#import <BluetoothLibrary/BluetoothLibrary.h>`

## 2.手表扫描及连接

#### 2.1 初始化
CEProduct SDK入口,通过子类(CEProductK6)进行初始化

	CEProduct *product = [CEProductK6 shareInstance];
#### 2.2 扫描手表

扫描手表前检查蓝牙是否开启，以及是否设置权限允许。通过`ScanPeripheralsNoticeKey`来接收扫描设备

###### 2.2.1 开始扫描
	- (void)startScan;
###### 2.2.2 停止扫描
	- (void)stopScan;
	
#### 2.3 建立连接

###### 3.1 建立连接
	- (void)connect:(CBPeripheral *)peripheral;
###### 3.2 保存已连接设备uuid 可用于自动连接功能
	- (void)saveConnectedUUid;
###### 3.3 自动连接
	- (void)startAutoConnect;
###### 3.4 解除绑定，并且会清除自动重连的设备信息
	- (void)releaseBind;

	
#### 2.4 连接状态检测

###### 2.4.1 状态枚举
	ProductStatus_none,         //还没开始搜索
	ProductStatus_powerOff,     //蓝牙断开
	ProductStatus_searching,    //搜索中
	ProductStatus_connecting,   //正在连接中...
	ProductStatus_disconnected, //连接断开
	ProductStatus_connected,    //连接成功,开始配对
	ProductStatus_completed     //配对完成,可以正常通信
###### 2.4.2 检测当前状态

* 属性`status`
* 通知`ProductStatusChangeNoticeKey`监听状态改变

## 3.手表交互

#### 指令发送使用单例`[CEProductK6 shareInstance]`
	- (void)sendCmdToDevice:(CE_Cmd *)cmd complete:(void(^)(NSError* error))handler;
#### 接收数据
	所有数据均通过此key接收
	CEProductK6ReceiveDataNoticeKey

#### 3.1 App退出

	杀死APP时，向设备发送指令CE_AppExitCmd，无参数
	
####3.2 OTA升级

##### 3.2.1 获取设备信息

	发送指令CE_RequestDevInfoCmd，数据类型：DATA_TYPE_DEVINFO

##### 3.2.2  获取升级数据

	发送指令CE_RequestOTAStatusCmd, 数据类型：DATA_TYPE_OTA_STATUS

##### 3.2.2 升级固件或者字库

> **CE_SendOtaDataCmd**

	- (id)initWithData:(NSData *)otaData 
			 otaStatusInfo:(NSDictionary*)info 
		   	    deviceInfo:(NSDictionary*)deviceInfo 
		   	omplteProgress:(void (^)(CGFloat rate))handler;
	
> 
> otaData:             从服务器下载保存在本地的bin文件
> 
> otaStatusInfo：CE_RequestOTAStatusCmd 指令接收到的数据
> 
> deviceInfo： CE_RequestDevInfoCmd 指令接收到的数据
> 
> complteProgress： 升级进度值

#### 3.3 智能拍照

>  **CE_SendPhotoCmd**
		
	- (instancetype)initWithOnoff:(NSInteger)onoff;
>  onoff 0: close take photo; 1:open take photo function

#### 3.4 传感器开关

用于设置设备sensor开关.当APP进入前后台时都要主动发送data开关状态到设备侧，设备侧根据此开关状态来决定是否可能上传数据到APP,设备侧只有在开关打开时才可以上传sensor数据到APP，这样可起到省电的目的

>  **CE_SensorCmd**

	- (instancetype)initWith:(NSInteger)onoff;

> 	onoff
> 
>  When app enter foreground send onoff = 1.
> 
>   When app enter background or killed send onoff = 0.

#### 3.5 闹钟

> **CE_AlarmItem** 
	
	参数说明:
	repeatDay: 		Alarm repeat day on every day
	isRepeatWeek: 	Repeat alarm every week.
	hour:			The alarm hour
	min:				The alarm minute
	status:			alarm swith status. 0: off, 1: on

> **CE_SyncAlarmK6Cmd**

	- (nonnull instancetype)initWithItems:(nonnull NSArray<CE_AlarmItem *>*)alarmItems;
	
#### 3.6 血压检测

> **CE_SyncBloodPressureCmd**

	status: 0表示关闭检测，1表示打开检测

#### 3.7 同步自定义表盘

> **CE_SyncCustomFaceCmd**

* **isSupportAccelerate**:  If acceleration is supported, the data will be sent at a very high rate.The default value is NO. Use command `CE_SyncWatchFaceStartCmd` to check whether the device support accelerate.
* **image**   		Background image. The image size depend on the device. Before transferring the picture data, it needs to be processed into an appropriate size.
* **width** The width of the background image required by the device. Different equipment requires different parameters value.
* **height** The height of the background image required by the device.
* **imageType** 
	*  0: Don't change the background image. The image should be null.
	*   1: Use the default background image. The image should be null.
	*   2: Use the image you send. If the image data is null, it will not change the background image.
*   **textColor** The custom face text color.
*   **timePosition** 0: Time label in upper part, 1: Time label in the lower part.
*   **timeAboveType** Elements shown above time label. 0: Close, 1: Date, 2: Sleep time, 3: heart rate value, 4: step.
*   **timeBelowType** Elements shown below time label. The types same as the timeAboveType.
*   **imageColorType** Image's color type. 0: RGB565, 1: RGB888

		- (instancetype)initWithImage:(UIImage *)image 
							    width:(CGFloat)width 
						       height:(CGFloat)height 
						    imageType:(NSInteger)imageType 
						    textColor:(UIColor *)textColor 
						 timePosition:(NSInteger)timePosition 
						timeAboveType:(NSInteger)timeAboveType 
						timeBelowType:(NSInteger)timeBelowType;
						
		- (instancetype)initWithImage:(UIImage *)image 
								width:(CGFloat)width 
							   height:(CGFloat)height 
							imageType:(NSInteger)imageType 
							textColor:(UIColor *)textColor 
						 timePosition:(NSInteger)timePosition 
						timeAboveType:(NSInteger)timeAboveType 
						timeBelowType:(NSInteger)timeBelowType 
					   imageColorType:(NSInteger)imageColorType;

#### 3.8 勿扰模式

> **CE_DisturbItem**

* `start_time_hour`     start hour time. 0 to 24
* `start_time_min`      start minute time. 0 to 59
* `end hour time`		 end hour time
* `end_time_min`		end minute time

> **CE_SyncDisturbCmd**

* `switch_flag`		Switch status. 0: close , 1: open.
* `disturbItems` 		disturb setting items. Only support one item in many device.

		- (instancetype _Nonnull )initWithOnoff:(NSInteger)onoff 
										  items:(nonnull NSArray<CE_DisturbItem *>*)items;

#### 3.9 目标值

> **CE_SyncGoalCmd**

* **step**  Step value
* **distance** distance (meter)
* **calories** calories (cal)
* **sleep** sleepTime (minute)
* **sportTime** sportTime (minute)

#### 3.10 血氧检测

> **CE_SyncHeartO2Cmd**

* **status** 0: off, 1: on

#### 3.11 同步数据
  设备建立连接后，发送指令`CE_SyncHybridCmd`同步基本数据，基本数据包括`DATA_TYPE_USERINFO`,`DATA_TYPE_LANGUAGE_SETTING`,`DATA_TYPE_TIME`,`DATA_TYPE_WEATHER`,`DATA_TYPE_ALARM`,`DATA_TYPE_SET_TARGET` 具体实现见相关指令
  
 ```
 	CE_SyncUserInfoCmd *userInfoCmd = [[CE_SyncUserInfoCmd alloc] init];
    CE_SyncGoalCmd *goalCmd = [[CE_SyncGoalCmd alloc] init];
    YD_SyncLanguageCmd *languageCmd = [[YD_SyncLanguageCmd alloc] init];
    CE_SyncTimeCmd *timeCmd = [[CE_SyncTimeCmd alloc] init];
    CE_SensorCmd *sensorCmd = [[CE_SensorCmd alloc] init];
    CE_SyncPairOKCmd *pairCmd = [[CE_SyncPairOKCmd alloc] init];
    
    NSArray *cmds = @[userInfoCmd, goalCmd, languageCmd, timeCmd, sensorCmd, pairCmd];
    CE_SyncHybridCmd *cmd = [[CE_SyncHybridCmd alloc] initWithItems:cmds];
    [[CEProductK6 shareInstance] sendCmdToDevice:cmd complete:nil];
 ```
#### 3.12 久坐提醒

> **CE_SyncLongSitRemindCmd**

* **onoff** Switch staus. 0：close, 1：open
* **repeatDay** WeekRepeatDay
* **startHour** start hour. 0 to 24.
* **startMinute** start minute. 0 to 59.
* **endHour** end hour
* **endMinute** end minute

		- (instancetype)initWithOnoff:(NSInteger)onoff 
						weekRepeatDay:(WeekRepeatDay)repeatDay 
						    startHour:(NSInteger)startHour 
						  startMinute:(NSInteger)startMinute 
						      endHour:(NSInteger)endHour 
						    endMinute:(NSInteger)endMinute;

#### 3.13 月经周期提醒

> **CE_SyncMenstrualCycleCmd**

* **startTime**  Menstrual cycle start time
* **duration** 	Menstrual cycle duration
* **period**		Menstrual cycle period
* **onOff**		Reminder switch status. 0: off, 1: on.
* **reminderMintue**	Reminder mintue. Values between 0 and 60.
* **reminderHour**		Reminder hour. Values between 0 and 24.
* **menstrualNoticeAdvance**	One day's advance notice menstrual. 0: off, 1: on.
* **ovulationNoticeAdvance**	One day's advance notice ovulation. 0: off, 1: on.
* **ovulationPeakNoticeAdvance**	One day's advance notice ovulation peak. 0: off, 1: on.
* **ovulationEndNoticeAdvance**	One day's advance notice ovulation end. 0: off, 1: on.
 
> **MenstrualCycleType**

* **MenstrualCycleTypeNone**
* **MenstrualCycleTypeNonPregnancy**   	Menstrual cycle at non-pregnancy period
* **MenstrualCycleTypePregnancy**			Menstrual cycle at pregnancy period	
#### 3.14 配对

> **CE_SyncPairOKCmd**

用于向设备侧确认是否配对完成。当APP成功与设备连接绑定后(如扫描二维码或输入配对数字)，
 APP应主动告之设备侧，设备侧根据配对的状态信息来做相应的操作 (如退出二维码界面，或保存相关的配对信息等)，该命令使用数据类型为`DATA_TYPE_PAIR_FINISH`
 
	参数
	firstPairStatus：0: normal, 1: first times pair
	
#### 3.15 同步系统表盘

> CE_SyncSystemFaceDataCmd

* **isSupportAccelerate**  If acceleration is supported, the data will be sent at a very high rate.
 The default value is NO. Use command `CE_SyncWatchFaceStartCmd` to check whether the device support accelerate.
 		
```
	CE_SyncSystemFaceDataCmd *watchFaceDataCmd = [[CE_SyncSystemFaceDataCmd alloc] init];
	watchFaceDataCmd.data = fileData;
    watchFaceDataCmd.isSupportAccelerate = NO;
    watchFaceDataCmd.syncProgress = ^(CGFloat progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // do something
        });
    };
    [CEProductK6.shareInstance sendCmdToDevice:watchFaceDataCmd complete:^(NSError *error) {
		// do something
    }];
```
> **CE_SyncWatchFaceStartCmd**

Determine whether the device supports high-speed data transmission mode.
 The current data types supported by the high-speed data mode are `CE_SyncSystemFaceDataCmd`, `CE_SyncCustomFaceCmd`.
 
#### 3.16 设置时间

> **CE_SyncTimeCmd**

* **absTime**  timestamp since 1970
* **offsetTime** time zone offset
* **format**  0:12-hour, 1:24-hour
* **mdFormat** 0: month-day, 1: day-month

		- (instancetype)initWithAbsTime:(double)absTime 
		 						 offset:(NSInteger)offsetTime 
		 						 format:(NSInteger)format 
		 					   mdFormat:(NSInteger)mdFormat;

#### 3.17 同步用户信息

> **CE_SyncUserInfoCmd**

* **sex** 1: 女 0: 男
* **lrHand**： 1:右手 0: 左手		

#### 3.18 App消息通知设置

> **CE_SyncWatchMenuCmd**

* **allSwitch** Master switch. If master switch disabled, all of the message alert will be closed.

```
	CE_SyncWatchMenuCmd *watchCmd = [[CE_SyncWatchMenuCmd alloc] init];;
    watchCmd.allSwitch = YES;
    watchCmd.qq = YES ;
    watchCmd.email = YES ;
    watchCmd.wechat = YES ;
    watchCmd.facebook = YES ;
    watchCmd.twitter = YES;
    watchCmd.whatsapp = YES ;
    watchCmd.instagram = YES ;
    watchCmd.skype = YES ;
    watchCmd.linkedIn = YES ;
    watchCmd.line = YES;
    watchCmd.kakaoTalk = YES;
    watchCmd.telegram = YES;
    watchCmd.other = YES ;
    [[CEProductK6 shareInstance] sendCmdToDevice:watchCmd complete:^(NSError *error) {
 
    }];
```
   
#### 3.19 同步天气

> **CE_WeatherItem**

* weather

		 New weather type code
		 code       mean
		 10         sunny 晴
		 11         partly cloudy  多云
		 12         cloudy day 阴天
	     13         shower 阵雨
		 14         Thundershower 雷阵雨
		 15         Light rain 小雨
		 16         Moderate rain 中雨
		 17         heavy rain大雨
		 18         Sleet雨夹雪
		 19         Light snow小雪
		 20         Moderate snow中雪
		 21         The heavy snow大雪
		 22         haze雾霾
		 23         The wind风
		         
		deprecated below:
		Old version of weather code
		code       mean
		0          sunny
		1          cloudy
		2          partly_cloudy
		3          rain
		4          snow


* **low_temperature**  

		lowest temperature value of the day. Unit of value is Celsius.

* **high_temperature**
		
		highest temperature value of the day. Unit of value is Celsius.

* **PM**
	
		air quality value. Could ignore this value.

> **CE_SyncWeatherCmd**

* **time**

		Current time's timestamps

* **todyWeather**

		today's weather

* **tomorrowWeather**

		tomorrow's weather

* **dayAfterTomorrowWeather**

		the day after tomorrow's wether


#### 3.20 单位设置

> **CE_UnitSettingCmd**

* weight

		weight unit. 0: kilogram, 1: pound, 2: stone
		
* distance

		distance unit. 0: meters, 1: miles

* weather

		weather unit. 0: Celsius, 1: Fahrenheit


#### 3.21 选择表盘
	
> **YD_SyncFaceIndexCmd**

		/// initialize sync face index command
		/// A device generally has several dials, depending on the device.
		/// The watch face can be switched by sending the face index.
		/// @param index Index of the watch face you choosed.


#### 3.22 同步运动

> **YD_SyncSportCmd** Application workout status set from device

* type

		Workout type. Define your own.

* status

		Workout status. See enum SPORT_STATUS_SYNC.

* time

		Workout time with unit seconds.

* distance

		Workout distance.

> **SPORT_STATUS_TYPE**

	SPORT_STATUS_STOP = 0, // Stop workout
    SPORT_STATUS_START,    // Start workout
    SPORT_STATUS_PAUSE,    // Pause workout
    SPORT_STATUS_CONTINUE, // Resume from pause
    SPORT_STATUS_STOP_FORCE, // Force stop wokout
    SPORT_STATUS_SYNC, // Needed send app workout data to device. You can't send this type to device.


#### 3.23 手机联系人

> **ContactCmdType**

* name

		联系人姓名

* phone

		手机号码

* cmdType
		
		详情见ContactCmdType

* removeIndex

		删除索引

* syncIndex

		同步索引

> **ContactCmdType**

	ContactCmdTypeAdd, //add
    ContactCmdTypeDelete, //delete
    ContactCmdTypeClear, //clear
    ContactCmdTypeSync  //synchronous

> 同步联系人,数据类型`DATA_TYPE_CONTACT_SYNC`

	ContactCmd *cmd = [[ContactCmd alloc] init];
    cmd.cmdType = ContactCmdTypeSync;
    cmd.syncIndex = index;
    [[CEProductK6 shareInstance] sendCmdToDevice:cmd complete:nil];

注意联系人是一条一条进行同步

####  3.24 实时检测心率

> **CE_SyncHeartRateCmd**

* status
	
		// 0:close，1:open

#### 3.25 自动心率设置	

**YD_SyncAutoHeartCmd**

auto heart rate detection setting command
	
* onoff 

		/// Automatic heart rate detection. Once every 10 minutes.
		/// 0: close, 1: open.

* hr24hOnoff

		/// Heart rate measurement for 24 hours
		/// Valid when DATA_TYPE_FUNCTION_CONTROL hasHR24h is true	
#### 3.25 来电设置

> **YD_SyncCallAlarmCmd**

* onoff

		onoff Switch status. 0: close, 1: open.

#### 3.26 喝水提醒

> **YD_SyncDrinkAlarmCmd**

* onoff
		
		 Switch status. 0: off, 1: on
		 
* startHour 

		startHour. 0-24
		
* startMintue 

		startMintue. 0-59
		
* endHour 

		endHour
		
* endMinute 

		endMinute
		
* intervalLevel 

		drink water reminder interval. Four level support:
        0: 30 minutes, 1: 1 hour, 2: 2 hours, 3: 3 hours
        

#### 3.27 查找设备

> **YD_SyncFindDevCmd**

* onoff

		onoff Switch status. 0: close, 1: open.


#### 3.28 目标达成

> **YD_SyncFinishGoalCmd**

* onoff

		onoff Switch status. 0: close, 1: open.

#### 3.29 语言设置

**YD_SyncLanguageCmd**

	 language 
	 0: English(英语) 1: Simple-Chinese(简体中文), 2: Spanish(西班牙) 3: Italian(意大利), 
	 4: Portuguese(葡萄牙), 5: French(法语), 6: Japanese(日语), 7: Russian(俄语), 8: Korean(韩语), 
	 9: German(德语), 10: Traditional-Chinese(繁体中文), 11: Arabic(阿拉伯语) 12: Indonesian(印度尼西亚语), 
	 13: Turkish(土耳其语), 14: Ukrainian(乌克兰语), 15: Hebrew(希伯来语), 16 波兰语, 17 印地语， 18克罗地亚语

#### 3.30 短信提醒

> **YD_SyncSMSAlarmCmd**

* onoff

		onoff Switch status. 0: close, 1: open.

#### 3.31 抬腕亮屏

> **YD_SyncUpBrightCmd**

* onoff 

		Switch status. 0: off, 1: on.
* startHour 

		start hour. 0 - 24
*  startMintue 

		start minute. 0 - 59
*  endHour 

		end hour. 0 - 24
*  endMinute 

		end minute.  0 - 59

#### 3.32 获取闹钟信息

> **CE_RequestAlarmInfoCmd**

* `DATA_TYPE_ALARM`

#### 3.33 获取混合数据

> **CE_RequestAllInfoCmd**

* `DATA_TYPE_DEVINFO`
* `DATA_TYPE_BATTERY_INFO`
* `DATA_TYPE_SETTING`
* `DATA_TYPE_ALARM`

#### 3.34 获取设备电量数据

> **CE_RequestBatteryCmd**

* `DATA_TYPE_BATTERY_INFO`

#### 3.35 获取设备信息

> **CE_RequestDevInfoCmd**

*  `DATA_TYPE_DEVINFO`

#### 3.36 获取勿扰模式信息

> **CE_RequestDisturbCmd**

* `DATA_TYPE_FORGET_DISTURB`

#### 3.37 获取目标数据

> **CE_RequestGoalCmd**

* `DATA_TYPE_SET_TARGET`

#### 3.38 获取久坐提醒数据

> **CE_RequestLongSitCmd**

*  `DATA_TYPE_SITTING_REMIND`

#### 3.39 请求配对信息

> **CE_RequestSystemPairStatusCmd**

* `DATA_TYPE_BLE_PAIR_STATUS`

#### 3.40 请求用户信息

> **CE_RequestUserInfo**

* `DATA_TYPE_USERINFO`

#### 3.41 获取表盘信息

> **YD_RequestWatchFaceSettingCmd**

* `DATA_TYPE_WATCH_FACE_INFO`


## 接收数据

#### 实时步数  `DATA_TYPE_REAL_SPORT `

	sportInfos:  //当天的运动数据
	
		startSecs: Int			//某次运动开始的时间
		walkDistance: Int		//当日总距离
		walkDuration: Int		//当日总时长
		walkSteps: Int			//当日总步数
		walkCalories: Int     	//当日消耗总卡路里

#### 睡眠数据 `DATA_TYPE_SLEEP`
	
	sleepInfos: Array 		//某段睡眠总数据
	SleepStartTime: Int		//睡眠开始时间
	SleepType: Int			//睡眠状态
	/// 睡眠状态需要APP自定义
	typedef enum
	{
    		SLEEP_NONE = 0,
    		SLEEP_START,		//睡眠开始
    		SLEEP_DEEP,		    //深睡
    		SLEEP_LIGHT,		//浅睡
    		SLEEP_WAKEUP		//苏醒
	} SleepType;
		
#### 心率数据 `DATA_TYPE_REAL_HEART`
	time: Int 		//测量时间
	heartNum: Int	//心率值

#### 血压数据 `DATA_TYPE_REAL_BP`
	
	time: Int 		//测量时间
	systolic: Int	//收缩压
	diastolic: Int	//舒张压
	
#### 血氧数据 `DATA_TYPE_REAL_O2`
	
	time: Int 		//测量时间
	O2: Int			//血氧
