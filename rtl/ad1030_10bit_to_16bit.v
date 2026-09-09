//****************************************Copyright (c)***********************************//
//原子哥在线教学平台：www.yuanzige.com
//技术支持：http://www.openedv.com/forum.php
//淘宝店铺：https://zhengdianyuanzi.tmall.com
//关注微信公众平台微信号："正点原子"，免费获取ZYNQ & FPGA & STM32 & LINUX资料。
//版权所有，盗版必究。
//Copyright(C) 正点原子 2023-2033
//All rights reserved                                    
//----------------------------------------------------------------------------------------
// File name:           ad_10bit_to_16bit
// Last modified Date:  2023/2/18 9:20:14
// Last Version:        V1.0
// Descriptions:        数据位宽转换模块
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//
module ad_10bit_to_16bit(
    input                 clk       ,
    input                 rst_n     ,
    input       [1:0]     sel       ,//控制命令
    input       [9:0]     ad_in1    ,//通道一数据
    input       [9:0]     ad_in2    ,//通道二数据
    output  reg [15:0]    ad_out     //输出数据
);

//wire define 
wire [9:0]s_ad_in1;
wire [9:0]s_ad_in2;
  
//十位扩展为十六位	
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        ad_out <= 16'd0;
    else if( sel == 2'b01)
        ad_out<={6'd0,ad_in1};//这样补0为了适应上位机
    else if( sel == 2'b10)
        ad_out<={6'd0,ad_in2};//
    else
        ad_out <= 16'd0;
    end
endmodule
