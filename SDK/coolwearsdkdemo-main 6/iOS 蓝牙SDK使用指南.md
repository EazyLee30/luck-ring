# iOS 蓝牙SDK使用指南

##	工程配置

1. 将`BluetoothLibrary.framework`拖入工程

2.  *Targets* ->  *General* -> *Frameworks,Libraries,and Embedded Content* 修改为 `Embed & Sign`

3. info.plist文件中添加蓝牙权限 `Privacy - Bluetooth Always Usage Description`

4.   在需要的地方导入头文件`#import <BluetoothLibrary/BluetoothLibrary.h>`

##	使用指南

### 数据接收
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveBleData:) name:CEProductK6ReceiveDataNoticeKey object:nil];

###	查找设备
	// 开始扫描
	[[CEProductK6 shareInstance] startScan];
	
	// 手动停止扫描
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
       [[CEProductK6 shareInstance] stopScan];
    });
 
 接收设备数据
 	
 	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivePeripherals:) name:ScanPeripheralsNoticeKey object:nil];
 
### 设备的连接与解绑

 初始化单例 `CEProductK6.shareInstance`
 
 	// 连接设备
 	- (void)connect:(CBPeripheral *)peripheral;
 	
 	// 自动连接设备
 	1. 初次连接后调用 - (void)saveConnectedUUid; 方法保存蓝牙uuid
 	2. 自动连接调用 - (void)startAutoConnect; 方法
 
 	// 解绑
 	- (void)releaseBind;

### 扫码连接
	
扫描二维码获取字符串 `coolwear,[mac],[蓝牙名字],[customerId]`

验证前缀是否是`coolwear`, 是则可进行扫码连接,否则不是连接二维码

由于`<CoreBluetooth/CoreBluetooth.h>`无法直接通过mac地址连接蓝牙,app使用以下步骤进行连接
	
	1. 后台扫描设备2秒(具体多久自定义)获取到附近蓝牙设备
	2. 通过二维码扫描获取到的mac地址与第1步得到的设备进行比对查找到目标设备
	3. 调用连接设备方法

### 一键连接音频蓝牙
1. 监听到`DATA_TYPE_FUNCTION_CONTROL`数据,判断`hasEDR`字段
2. `hasEDR = YES` 表示设备支持一键连接, 添加代码```[CE_RequestEdrInfoCmd getEdrInfo:nil]; ```
3. `hasEDR = NO` 不支持一键链接音频蓝牙功能
4. 音频蓝牙信息可在数据类型`DATA_TYPE_BTEDR_ADDR`中查看

### 心率sensor相关的控制命令

`DATA_TYPE_HR_CONTROL`

	typedef enum{
		HR_ CONTROL_TYPE_NULL = 0,
		HR_ CONTROL_TYPE_HR,
		HR_ CONTROL_TYPE_BP,
		HR_ CONTROL_TYPE_O2,
		HR_ CONTROL_TYPE_ECG,
	}HR_CONTROL_TYPE;
	
	onoff:	//0关闭 1打开
	type:	//类型 HR_CONTROL_TYPE

### 心率

> CE_SyncHeartRateCmd

	参数列表
	status: 0关闭检测 1开始检测

数据类型	`DATA_TYPE_REAL_HEART`
	
	数据结构
	{
		"remainItemCount": 	//总共还有多少条数据
		"curItemCount":		//当前数据条目数量
		"heartInfos":	 {
			time: 		//检测时间
			heartNum:   //心率值	
		}
	}

	
### 血氧

> CE_SyncHeartO2Cmd
	
	参数列表
	status: 0关闭检测 1开始检测

数据类型 `DATA_TYPE_REAL_O2`
	
	数据结构
	{
		"remainItemCount": 	//总共还有多少条数据
		"curItemCount":		//当前数据条目数量
		"data":	 {
			time:	//检测时间
			O2:   	//心率值	
		}
	}

### 血压

> CE_SyncBloodPressureCmd
	
	参数列表
	status: 0关闭检测 1开始检测

数据类型 `DATA_TYPE_REAL_BP`
	
	数据结构
	{
		"remainItemCount": 	//总共还有多少条数据
		"curItemCount":		//当前数据条目数量
		"data":	 {
			time:			//检测时间
			systolic:   	//收缩压
			diastolic:   	//舒张压
		}
	}
	
	
### 睡眠
设备只要检测到睡眠情况就会进行数据发送,同一段数据只会发送一次.app需要将数据收集,再进行分析.

数据类型 `DATA_TYPE_SLEEP`

	数据结构
	{
		"remainItemCount": 	//总共还有多少条数据
		"curItemCount":		//当前数据条目数量
		"sleepInfos":	 {
			SleepStartTime:	//睡眠开始时间
			SleepType: 		//睡眠状态
		}
	}
	
	睡眠类型
	typedef enum
	{ 
		SLEEP_NONE = 0,
		SLEEP_START,	//睡眠开始
		SLEEP_DEEP,		//深睡
		SLEEP_LIGHT,	//浅睡
		SLEEP_WAKEUP	//苏醒
	} SLEEP_STATUS_TYPE;

备注: 一次完整的睡眠开始一定是`SLEEP_START` 结束一定是`SLEEP_WAKEUP`

### 用户信息设置
> CE_SyncUserInfoCmd
	
	userId:	//用户id
	sex:	//性别
	age:	//年龄
	hight:	//身高
	weight:	//体重
	lrHand:	//用户左右手习惯  0:左手 ，1：右手

### 语言设置
> YD_SyncLanguageCmd
	
	0：英语
	1：中文
	2：Spanish(西班牙)
	3：Italian(意大利)
	4：Portuguese(葡萄牙)
	5：French(法语) 
	6：Japanese(日语)
	7：俄语 
	8：韩语
	9：德语 
	10：繁体中文
	11：阿拉伯语 
	12：印尼语 
	13：土耳其语 
	14：乌克兰语
	15：希伯来语 
	16：波兰语 
	17：印地语 
	18：克罗地亚语 
	19：希腊语
	20：泰语
	21：越南语 
	22：波斯语
	23：荷兰语
	24：罗马尼亚语
	25：加利西亚语(gallego)
	26：巴斯克语(euskera)
	27：加泰罗尼亚语(catalán)

### 闹钟设置

 > CE_SyncAlarmK6Cmd
 	
 	alarmItems: CE_AlarmItem对象数组
 
 > CE_AlarmItem
 
 	repeatDay:		//周重复设置WeekRepeatDay枚举,具体见SDK
 	isRepeatWeek:	//是否每周重复,设备返回时候直接判断repeatDay 的值即可
 	hour:			//闹钟提醒的小时
 	min: 			//闹钟提醒的分钟
 	status:			//闹钟提醒状态 0:关闭 1:打开
 
 > CE_RequestAlarmInfoCmd 闹钟数据获取

	数据类型 DATA_TYPE_ALARM
	
 	alarm_infos: {
 		alarmType:  //闹钟类型0普通闹钟 1智能闹钟(暂时未开放,默认0)
 		repeatDay:	//最高位表示是否重复,1表示重复,0表示不重复(等同repeatDay=127),当重复时接收到的数据需要减去128才是正确的repeatDay
 		hour:  		//闹钟提醒的小时
 		min:  		//闹钟提醒的分钟
 		status:		//闹钟提醒状态 0:关闭 1:打开
 		name:		//闹钟名字(暂时未开放)
 	}

### 同步时间到设备

> CE_SyncTimeCmd
	
	参数说明:
	absTime:	//时间戳，是相对于1970-1-1的时间 单位 秒
	offsetTime:	//是相对于伦敦0时区的偏移时区值 单位 秒
	format:		//0:12小时制, 1:24小时制.
	mdFormat; 	//日期格式 0: 月-日, 1: 日-月
	
### 设置第三方app通知信息 CE_SyncWatchMenuCmd
	
	设置指令 CE_SyncWatchMenuCmd
	数据同步 DATA_TYPE_MESSAGE_SWITCH
	参数说明
	allSwitch: Bool  //总开关
	email: Bool
	facebook: Bool
	instagram: Bool
	kakaoTalk: Bool
	line: Bool
	linkedIn: Bool
	other: Bool
	qq: Bool
	skype: Bool
	telegram: Bool
	twitter: Bool
	wechat: Bool
	whatsapp: Bool

### 来电提醒设置 	
	设置指令 YD_SyncCallAlarmCmd
	数据同步 DATA_TYPE_CALL_ALARM
	参数说明
	onoff: //0关闭 1开启
	
### 短信提醒设置
	设置指令: YD_SyncSMSAlarmCmd
	数据同步: DATA_TYPE_MESSAGE_ALARM
	参数说明
	onoff: //0关闭 1开启

### 达标提醒
	设置指令: YD_SyncFinishGoalCmd
	数据同步: DATA_TYPE_TARGET_ALARM
	参数说明
	onoff: //0关闭 1开启

### 喝水提醒
	设置指令: YD_SyncDrinkAlarmCmd
	参数说明:
	onoff:			//开关 0关闭 1开启
	start_hour:		//提醒开始时间(小时)
	start_min:		//提醒开始时间(分钟)
	end_hour:		//提醒结束时间(小时)
	end_min:		//提醒结束时间(分钟)
	interval:		//提醒间隔 0:30分钟 1:1小时 2:2小时 3:3小时
	
	数据同步: DATA_TYPE_DRINK_ALARM
	参数说明
	isOpen: 		//0关闭 1开启
	startHour:		//提醒开始时间(小时)
	startMin:		//提醒开始时间(分钟)
	endHour:		//提醒结束时间(小时)
	endMin:			//提醒结束时间(分钟)
	interval:		//提醒间隔 0:30分钟 1:1小时 2:2小时 3:3小时

### 抬腕亮屏设置
	设置指令: YD_SyncUpBrightCmd
	参数说明:
	onoff:			//开关 0关闭 1开启
	start_hour:		//提醒开始时间(小时)
	start_min:		//提醒开始时间(分钟)
	end_hour:		//提醒结束时间(小时)
	end_min:		//提醒结束时间(分钟)
	
	数据同步: DATA_TYPE_HAND_RISE_SWITCH
	参数说明
	onoff: 			//0关闭 1开启
	startHour:		//提醒开始时间(小时)
	startMin:		//提醒开始时间(分钟)
	endHour:		//提醒结束时间(小时)
	endMin:			//提醒结束时间(分钟)

### 自动心率检测设置

	设置指令: YD_SyncAutoHeartCmd
	数据同步: DATA_TYPE_HAND_RISE_SWITCH
	参数说明:
	onoff:			//自动心率,每10分钟检测一次, 0关闭 1开启
	hr24hOnoff:		//24小时心率测量

### 同步APP运动

> YD_SyncSportCmd
	
	参数说明:
	type:			//APP运动类型，跑步，骑行……
	status:			//APP运动的当前状态，详见：SPORT_STATUS_TYPE 
	time:			//APP运动的总时长,单位秒
	distance:		//APP运动的总距离,单位米
	
	typedef enum{
		SPORT_STATUS_STOP = 0, 		//停止
		SPORT_STATUS_START,			//开始
		SPORT_STATUS_PAUSE,			//暂停
		SPORT_STATUS_CONTINUE, 		//继续
		SPORT_STATUS_STOP_FORCE, 	//强制停止
		SPORT_STATUS_SYNC, 			//运动数据同步请求
	}SPORT_STATUS_TYPE;

### 运动数据

`DATA_TYPE_REAL_SPORT` 和 `DATA_TYPE_HISTORY_SPORT`
	
	{
		"remainItemCount": 	//总共还有多少条数据
		"curItemCount":		//当前数据条目数量
		"sportInfos":	 {
			startSecs: 		//距离1970的秒钟值
			walkSteps:		//运动的绝对步数	
			walkDistance:	//运动的绝对距离
			walkCalories:	//运动的卡路里
			walkDuration:	//持续的时间，单位秒
		}
	}
	

### 表盘

> 检查表盘传输是否支持高速通道
	
	1. 发送指令 CE_SyncWatchFaceStartCmd
	2. 监听 DATA_TYPE_WATCH_FACE_START 是否有回调,有则表示支持高速传输,否则不支持在指令发送完成回调中处理下一步任务

> CE_SyncCustomFaceCmd 同步表盘图片
	
	初始化方法:
	- (instancetype)initWithImage:(UIImage *)image 
							width:(CGFloat)width 
						   height:(CGFloat)height 
						imageType:(NSInteger)imageType 
						textColor:(UIColor *)textColor 
					 timePosition:(NSInteger)timePosition 
					timeAboveType:(NSInteger)timeAboveType 
					timeBelowType:(NSInteger)timeBelowType 
				   imageColorType:(NSInteger)imageColorType;
	
	image: 				//要传输的图片(需裁剪到表盘大小)
	width:  			//表盘宽度
	height: 			//表盘高度
	imageType:			//图片类型:0.不改变图片 1：默认的系统背景图片 2：自定义背景图片
	textColor:			//文本颜色
	timePosition:		//时间标签位置: 0：时间标签在上部，1：时间标签在下部
	timeAboveType:		//时间标签上方显示的元素 0：关闭，1：日期，2：睡眠时间，3：心率值，4：步数
	timeBelowType:		//时间标签下方显示的元素 类型同timeAboveType
	imageColorType:		//图像的颜色类型 0: RGB565, 1: RGB888
	isSupportAccelerate://是否支持加速传输, 默认为NO, 使用指令 CE_SyncWatchFaceStartCmd 检查设备是否支持加速
	syncProgress:		//图片传输进度

>**YD_SyncFaceIndexCmd** 选择表盘

	index: 表盘索引

>**CE_SyncPhotoDialCmd** 相册表盘(目前仅支持3张表盘图片)

	参数列表
	timeX:					//时间标签x坐标
	timeY:					//时间标签y坐标
	timeUp:					//时间标签上方显示的元素 0：关闭，1：日期，2：睡眠时间，3：心率值，4：步数
	timeDown:				//时间标签下方显示的元素 类型同timeUp
	model:					//图片切换模式 0: 点击屏幕切换 1: 自动切换
	timeInterval:			//图片切换间隔时间, model=1时有效
	imgs:					//要传输到表盘图片(大小需裁剪成表盘大小)
	imgNum:					//表盘数量
	width:					//表盘宽度
	height:					//表盘高度
	color:					//文本颜色
	isSupportAccelerate:	//是否支持加速传输, 默认为NO, 使用指令 CE_SyncWatchFaceStartCmd 检查设备是否支持加速
	syncProgress:			//图片传输进度
	
	方法:
	- (void)prepare; 		//初始化指令后,需调用此方法做准备工作,再开始发送指令

### APP功能控制

`DATA_TYPE_FUNCTION_CONTRO` 参数说明如下
	
	showBP:					//是否支持血压功能
	showO2:					//是否支持血氧功能
	showECG:				//是否支持ECG功能
	weatherType:			//天气类型：0表示旧协议5种天气，1表示新协议14种天气
	hasHR24h:				//是否支持24小时连续心率检测
	hasMenstrualCycle:		//是否支持女性生理周期功能
	hasContacts:			//是否支持通讯录功能
	hasRealtimeWeather:		//是否支持实时天气功能
	hasEDR:					//是否拥有EDR设备
	supportOneConnect:		//是否支持一次连接通话蓝牙功能
	hasQrPush:				//是否支持二维码推送功能
	manualHr:				//是否支持手动心率测量功能
	hasPhotoAlbum:			//是否支持相册表盘功能
	startLogo:				//是否支持开关机logo功能
	hasAlipay:				//是否支持支付宝功能
	
### 女性生理期设置
	
>**CE_SyncMenstrualCycleCmd**
	
	menstrualCycleType:			//类型,详见MenstrualCycleType
	startTime:					//月经或孕期开始时间
	duration:					//月经持续天数
	period:						//月经周期
	onOff:						//提醒总开关，0:关，1:开
	reminderMintue:				//提醒时间 分
	reminderHour:				//提醒时间 时
	menstrualNoticeAdvance:		//月经前一天提醒，0：关，1：开
	ovulationNoticeAdvance:		//排卵开始前一天提醒,0：关，1：开
	ovulationPeakNoticeAdvance:	//排卵日前一天提醒，0：关，1：开
	ovulationEndNoticeAdvance:	//排卵结束前一天提醒，0：关，1：开
	
	typedef NS_ENUM(uint8_t, MenstrualCycleType) {
		MenstrualCycleTypeNone = 0,		//未知
		MenstrualCycleTypeNonPregnancy,	//非孕期
		MenstrualCycleTypePregnancy 	//孕期
	};

### 硬件信息

硬件信息`DATA_TYPE_HARDWARE_INFO`

	width:	//手表宽度
	height:	//手表高度
	rgb:	//0: RGB_565, 1: RGB_888

音频蓝牙信息`DATA_TYPE_BTEDR_ADDR`
	
	name: //音频蓝牙名称

### 天气

实时天气同步`CE_WeatherCurrCmd`
	
	cond_code:	//天气图标
	tmp:		//温度
	wind_sc:	//风力
	hum:		//湿度

三天天气同步`CE_SyncWeatherCmd`

	time:						//第一天天气时间
	todyWeather:				//第一天天气,详见CE_WeatherItem
	tomorrowWeather:			//第二天天气,详见CE_WeatherItem
	dayAfterTomorrowWeather:	//第三天天气,详见CE_WeatherItem

单独一天天气`CE_WeatherItem`
	
	weather://旧协议类型:0. sunny, 1. cloudy, 2. partly_cloudy, 3. rain, 4. snow.
			//新协议类型: 10.晴，11.多云，12.阴天，13.阵雨，14.雷阵雨，15.小雨，16.中雨，17.大雨，18. 雨夹雪，19.小雪，20.中雪，21.大雪，22.雾霾，23.风沙
			//协议类型见 DATA_TYPE_FUNCTION_CONTRO
	low_temperature:	//当天的最低温度值。 数值单位为摄氏度.e
	high_temperature:	//当天的最高温度值。 数值单位为摄氏度。
	PM:					//空气质量值。 可以忽略这个值
	
### 推送二维码 
> **CE_SyncQRCmd**

	添加二维码方法
	+ (void)sendQrWithName:(NSString *)name
               	   content:(NSString *)content
                 	 qrIdx:(NSInteger)qrIdx
                    qrType:(QR_TYPE)qrType
                  complete:(CECmdErrorBlock)complete;
    name:		//二维码名字最大20个字节
    content:	//二维码内容
    qrIdx:		//二维码index
    qrType:		//二维码类型,详见QR_TYPE
    complete:	//完成回调
    
    删除二维码方法
    + (void)removeQrWithIdx:(NSInteger)idx;  
    idx: 		//二维码索引
    
    一次性清空所有二维码方法
    + (void)clearQr;
    
### 开关机自定义logo

> **CE_SyncOnoffScreenCmd**

	添加logo图片
	type:					//类型:0:添加 1:删除
	image:					//图片对象,需裁剪成表盘大小
	power_flag:				//0:开机logo 1: 关机logo
	width:					//图片宽度
	height:					//图片高度
	isSupportAccelerate:	//高速传输,详见CE_SyncWatchFaceStartCmd,默认YES
	
	- (void)prepare;		//传输指令前,调用该方法

	删除logo图片
	type: 		//类型:0:添加 1:删除
	power_flag:	//0:开机logo 1:关机logo
	
	
### 设备信息

`DATA_TYPE_DEVINFO`

	items:			//内部字段
	customer_id:	//内部字段
	customer_id_h:	//内部字段
	picture_id:		//内部字段
	font_id:		//内部字段
	code_id:		//内部字段
	hardware_id:	//内部字段
	ID:				//客户id
	macAddr:		//mac地址
	version:		//软件版本号

### 电池电量
`DATA_TYPE_BATTERY_INFO`

	battery_capacity: //电量大小0到100
	
### IOS的App退出

指令`CE_AppExitCmd`

	+ (void)send; //app推出直接调用即可

### app设置sensor数据的发送开启状态
	
指令`CE_SensorCmd`

	onoff: //设置数据开关的状态，0：关闭，1：打开
	
	直接调用
	+ (void)open;	//打开
	+ (void)close;	//关闭

### 混合数据类型参数信息

`CE_SyncHybridCmd`
	
	infoItems: //可组合数据包, 
	//用户信息,详见CE_SyncUserInfoCmd
	//语言设置,详见YD_SyncLanguageCmd
	//时间同步,详见CE_SyncTimeCmd
	//天气信息,详见天气模块
	//闹钟信息,详见闹钟模块
	//目标值,详见CE_SyncGoalCmd

### 发现手环
`YD_SyncFindDevCmd`

	onOff: //0: 关闭, 1: 开启
	
### 同步目标值
指令`CE_SyncGoalCmd`
	
	step:		//步数目标
	distance:	//距离目标, 单位:  米
	calories:	//卡路里目标, 单位:  卡路里
	sleep:		//睡眠目标, 单位:  分钟
	sportTime:	//运动时长, 单位：分钟

### 拍照
	CE_SendPhotoCmd
	onOff: //0: 关闭, 1: 开启

### 久坐提醒
	
	数据类型 DATA_TYPE_SITTING_REMIND
	
	同步设置: CE_SyncLongSitRemindCmd
	
	onoff:				//是否开启同步提醒
	repeatDay:			//最高位表示是否重复,1表示重复,0表示不重复(等同repeatDay=127),当重复时接收到的数据需要减去128才是正确的repeatDay
	startTimeHour:		//开始时间小时
	startTimemin:		//开始时间分钟
	endTimeHour:		//结束时间小时
	endTimeMin:			//结束时间分钟
	noon_onoff:			//午休免打扰	