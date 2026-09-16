//****************************************Copyright (c)***********************************//
//原子哥在线教学平台：www.yuanzige.com
//鎶?鏈敮鎸侊細http://www.openedv.com/forum.php
//淘宝店铺：https://zhengdianyuanzi.tmall.com
//鍏虫敞寰俊鍏紬骞冲彴寰俊鍙凤細"姝ｇ偣鍘熷瓙"锛屽厤璐硅幏鍙朲YNQ & FPGA & STM32 & LINUX璧勬枡銆?
//鐗堟潈鎵?鏈夛紝鐩楃増蹇呯┒銆?
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
    //鍥惧儚鐩稿叧淇″彿
    input                 clk            ,   //鏃堕挓
    input        [15 :0]  img_data       ,   //鏈夋晥鏁版嵁 
    input                 img_data_valid ,   //鏈夋晥鏁版嵁鍐欏叆鑴夊啿
    
    input                 transfer_flag  ,   //鍥惧儚寮?濮嬩紶杈撴爣蹇?,1:寮?濮嬩紶杈? 0:鍋滄浼犺緭
    //浠ュお缃戠浉鍏充俊鍙? 
    input                 eth_tx_clk     ,   //浠ュお缃戝彂閫佹椂閽?
    input                 udp_tx_req     ,   //UDP鍙戦?佹暟鎹姹備俊鍙?
    input                 udp_tx_done    ,   //UDP鍙戦?佹暟鎹畬鎴愪俊鍙?                               
    output  reg           udp_tx_start_en,   //UDP寮?濮嬪彂閫佷俊鍙?
    output       [7 :0]   udp_tx_data    ,   //UDP鍙戦?佺殑鏁版嵁
    output  reg  [15:0]   udp_tx_byte_num    //UDP鍗曞寘鍙戦?佺殑鏈夋晥瀛楄妭鏁?
    );    
    
//reg define
reg             tx_busy_flag    ;  //鍙戦?佸繖淇″彿鏍囧織                              

//wire define                   
wire   [13:0]   fifo_rdusedw    ;  //褰撳墠FIFO缂撳瓨鐨勪釜鏁?

//*****************************************************
//**                    main code
//*****************************************************  

//鎺у埗浠ュお缃戝彂閫佺殑瀛楄妭鏁?
always @(posedge eth_tx_clk or negedge rst_n) begin
    if(!rst_n)
        udp_tx_byte_num <= 16'd0;
    else 
        udp_tx_byte_num <= 16'd1200;
end

//鎺у埗浠ュお缃戝彂閫佸紑濮嬩俊鍙?
always @(posedge eth_tx_clk or negedge rst_n) begin
    if(!rst_n) begin
        udp_tx_start_en <= 1'b0;
        tx_busy_flag    <= 1'b0;
    end
    //涓婁綅鏈烘湭鍙戦??"寮?濮?"鍛戒护鏃?,浠ュお缃戜笉鍙戦?佸浘鍍忔暟鎹?
    else if(transfer_flag == 1'b0) begin
        udp_tx_start_en <= 1'b0;
        tx_busy_flag    <= 1'b0;        
    end
    else begin
        udp_tx_start_en <= 1'b0;
        //褰揊IFO涓殑涓暟婊¤冻闇?瑕佸彂閫佺殑瀛楄妭鏁版椂
        if(tx_busy_flag == 1'b0 && fifo_rdusedw >= 1200) begin
            udp_tx_start_en <= 1'b1;                     //寮?濮嬫帶鍒跺彂閫佷竴鍖呮暟鎹?
            tx_busy_flag    <= 1'b1;
        end
        else if(udp_tx_done) 
            tx_busy_flag <= 1'b0;
    end
end

//寮傛FIFO
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
