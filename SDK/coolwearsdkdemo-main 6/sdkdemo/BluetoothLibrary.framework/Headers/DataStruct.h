//
//  DataStruct.h
//  BluetoothLibrary
//
//  Created by kwan on 2020/9/9.
//  Copyright © 2020 kwan. All rights reserved.
//

#ifndef DataStruct_h
#define DataStruct_h

typedef struct {
    unsigned char type;          //0:未知, 1: 非孕期, 2: 孕期.
    unsigned char start_time[4];   //月经或孕期开始时间
    unsigned char day_num;      //月经持续天数
    unsigned char peroid;        //月经周期
    unsigned char remind_onoff;  //提醒总开关，0:关，1:开
    unsigned char remind_time[2]; //提醒时间, [0]:分，[1]:时
    unsigned char remind_mode_menstrual;  //月经前一天提醒，0：关，1：开
    unsigned char remind_mode_ovulation;    //排卵开始前一天提醒,0：关，1：开
    unsigned char remind_mode_ovulation_peak;//排卵日前一天提醒，0：关，1：开
    unsigned char remind_mode_end_ovulation;    //排卵结束前一天提醒，0：关，1：开
    unsigned char reserved[8];    //保留字节
} woman_stage_info_struct;

typedef struct {
    unsigned char lcd_width[2];
    unsigned char lcd_height[2];
    unsigned char RGB;
    unsigned char download_dia[2];
    unsigned char platform;
    unsigned char reserved[11];
} hardware_info_struct;

#endif /* DataStruct_h */
