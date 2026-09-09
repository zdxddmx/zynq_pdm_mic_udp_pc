//****************************************Copyright (c)***********************************//
//原子哥在线教学平台：www.yuanzige.com
//�?术支持：http://www.openedv.com/forum.php
//淘宝店铺：https://zhengdianyuanzi.tmall.com
//关注微信公众平台微信号："正点原子"，免费获取ZYNQ & FPGA & STM32 & LINUX资料�?
//版权�?有，盗版必究�?
//Copyright(C) 正点原子 2023-2033
//All rights reserved                              
//----------------------------------------------------------------------------------------
// File name:           img_data_pkt
// Last modified Date:  2023/2/18 9:20:14
// Last Version:        V1.0
// Descriptions:        图像封装模块(添加帧头)    
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module img_data_pkt(
    input                 rst_n          ,   //复位信号，低电平有效
    //图像相关信号
    input                 clk            ,   //时钟
    input        [15 :0]  img_data       ,   //有效数据 
    input                 img_data_valid ,   //有效数据写入脉冲
    
    input                 transfer_flag  ,   //图像�?始传输标�?,1:�?始传�? 0:停止传输
    //以太网相关信�? 
    input                 eth_tx_clk     ,   //以太网发送时�?
    input                 udp_tx_req     ,   //UDP发�?�数据请求信�?
    input                 udp_tx_done    ,   //UDP发�?�数据完成信�?                               
    output  reg           udp_tx_start_en,   //UDP�?始发送信�?
    output       [7 :0]   udp_tx_data    ,   //UDP发�?�的数据
    output  reg  [15:0]   udp_tx_byte_num    //UDP单包发�?�的有效字节�?
    );    
    
//reg define
reg             tx_busy_flag    ;  //发�?�忙信号标志                              

//wire define                   
wire   [13:0]   fifo_rdusedw    ;  //当前FIFO缓存的个�?

//*****************************************************
//**                    main code
//*****************************************************  

//控制以太网发送的字节�?
always @(posedge eth_tx_clk or negedge rst_n) begin
    if(!rst_n)
        udp_tx_byte_num <= 16'd0;
    else 
        udp_tx_byte_num <= 16'd1200;
end

//控制以太网发送开始信�?
always @(posedge eth_tx_clk or negedge rst_n) begin
    if(!rst_n) begin
        udp_tx_start_en <= 1'b0;
        tx_busy_flag    <= 1'b0;
    end
    //上位机未发�??"�?�?"命令�?,以太网不发�?�图像数�?
    else if(transfer_flag == 1'b0) begin
        udp_tx_start_en <= 1'b0;
        tx_busy_flag    <= 1'b0;        
    end
    else begin
        udp_tx_start_en <= 1'b0;
        //当FIFO中的个数满足�?要发送的字节数时
        if(tx_busy_flag == 1'b0 && fifo_rdusedw >= 1200) begin
            udp_tx_start_en <= 1'b1;                     //�?始控制发送一包数�?
            tx_busy_flag    <= 1'b1;
        end
        else if(udp_tx_done) 
            tx_busy_flag <= 1'b0;
    end
end

//异步FIFO
async_fifo_2048x8b u_async_fifo_2048x8b (
  .rst          (~transfer_flag          ),   // input wire rst
  .wr_clk       (clk                     ),   // input wire wr_clk
  .rd_clk       (eth_tx_clk              ),   // input wire rd_clk
  .din          (img_data                ),   // input wire [7 : 0] din
  .wr_en        (img_data_valid && ~full  ),   // input wire wr_en
  .rd_en        (udp_tx_req  && ~empty   ),   // input wire rd_en
  .dout         (udp_tx_data             ),   // output wire [7 : 0] dout
  .full         (full                    ),   // output wire full
  .empty        (empty                   ),   // output wire empty
  .rd_data_count(fifo_rdusedw            ),   // output wire [10 : 0] rd_data_count
  .wr_rst_busy  (                        ),   // output wire wr_rst_busy
  .rd_rst_busy  (                        )    // output wire rd_rst_busy
);  

endmodule
