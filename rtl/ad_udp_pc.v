// PDM microphone PCM audio over UDP top module.
// Send one-byte UDP command 0x01 to start streaming and 0x00 to stop.

module ad_udp_pc(
    input              sys_clk     ,   // system clock, 50 MHz
    input              sys_rst_n   ,   // active-low reset
    // Ethernet RGMII interface
    input              eth_rxc     ,
    input              eth_rx_ctl  ,
    input       [3:0]  eth_rxd     ,
    output             eth_txc     ,
    output             eth_tx_ctl  ,
    output      [3:0]  eth_txd     ,
    output             eth_rst_n   ,
    // PDM microphone interface
    output             mic_clk     ,
    input              mic_data    ,
    // Hardware debug LEDs
    output      [1:0]  led
);

// Board MAC address 00-11-22-33-44-55
parameter BOARD_MAC       = 48'h00_11_22_33_44_55;
// Board IP address 192.168.1.10
parameter BOARD_IP        = {8'd192,8'd168,8'd1,8'd10};
// Default destination MAC address ff-ff-ff-ff-ff-ff
parameter DES_MAC_DEFAULT = 48'hff_ff_ff_ff_ff_ff;
// Default PC IP address 192.168.1.102
parameter DES_IP_DEFAULT  = {8'd192,8'd168,8'd1,8'd102};
// 0: PDM microphone, 1: internal triangle wave for Ethernet diagnostics
parameter USE_FAKE_AUDIO  = 1'b0;
// 1: start streaming immediately after reset, 0: wait for UDP command 0x01
parameter AUTO_STREAM     = 1'b1;
// PDM diagnostics and phase selection
parameter MIC_SAMPLE_ON_HIGH = 1'b1;
parameter MIC_OUTPUT_DENSITY = 1'b0;

wire            clk_50m;
wire            clk_50m_deg250;
wire            clk_200m;
wire            locked;
wire            rst_n;

wire            eth_tx_clk;
wire            eth_rx_clk;
wire            udp_tx_start_en;
wire   [15:0]   udp_tx_byte_num;
wire   [7:0]    udp_tx_data;
wire            udp_rec_pkt_done;
wire            udp_rec_en;
wire   [7:0]    udp_rec_data;
wire   [15:0]   udp_rec_byte_num;
wire            udp_tx_req;
wire            udp_tx_done;

wire            transfer_flag;
wire            stream_enable;
wire   [1:0]    ctrl;
wire   [15:0]   mic_pcm_data;
wire            mic_pcm_valid;
wire   [15:0]   fake_pcm_data;
wire            fake_pcm_valid;
wire   [15:0]   tx_pcm_data;
wire            tx_pcm_valid;
reg    [25:0]   heartbeat_cnt;
reg             led_heartbeat;
reg    [22:0]   mic_edge_hold_cnt;
reg             mic_data_d0;
reg             mic_data_d1;
reg             mic_edge_seen;

assign rst_n = sys_rst_n & locked;
assign tx_pcm_data  = USE_FAKE_AUDIO ? fake_pcm_data  : mic_pcm_data;
assign tx_pcm_valid = USE_FAKE_AUDIO ? fake_pcm_valid : mic_pcm_valid;
assign stream_enable = AUTO_STREAM ? 1'b1 : transfer_flag;
assign led[0] = led_heartbeat;
assign led[1] = mic_edge_seen;

clk_wiz_0 u_clk_wiz_0 (
    .clk_out1           (clk_50m         ),
    .clk_out2           (clk_50m_deg250  ),
    .clk_out3           (clk_200m        ),
    .reset              (~sys_rst_n      ),
    .locked             (locked          ),
    .clk_in1            (sys_clk         )
);

pdm_mic_pcm #(
    .CLK_DIV            (24              ),
    .DECIMATION         (64              ),
    .CIC_SHIFT          (3               ),
    .SAMPLE_ON_HIGH     (MIC_SAMPLE_ON_HIGH),
    .OUTPUT_DENSITY     (MIC_OUTPUT_DENSITY)
) u_pdm_mic_pcm (
    .clk                (clk_50m_deg250  ),
    .rst_n              (rst_n           ),
    .pdm_clk            (mic_clk         ),
    .pdm_data           (mic_data        ),
    .pcm_data           (mic_pcm_data    ),
    .pcm_valid          (mic_pcm_valid   )
);

fake_audio_gen #(
    .CLK_HZ             (50_000_000      ),
    .SAMPLE_RATE        (32_550          ),
    .STEP               (16'sd2000       ),
    .AMP_POS            (16'sd20000      ),
    .AMP_NEG            (-16'sd20000     )
) u_fake_audio_gen (
    .clk                (clk_50m_deg250  ),
    .rst_n              (rst_n           ),
    .sample_data        (fake_pcm_data   ),
    .sample_valid       (fake_pcm_valid  )
);

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n) begin
        heartbeat_cnt <= 26'd0;
        led_heartbeat <= 1'b0;
    end
    else if(heartbeat_cnt == 26'd24_999_999) begin
        heartbeat_cnt <= 26'd0;
        led_heartbeat <= ~led_heartbeat;
    end
    else begin
        heartbeat_cnt <= heartbeat_cnt + 26'd1;
    end
end

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n) begin
        mic_data_d0       <= 1'b0;
        mic_data_d1       <= 1'b0;
        mic_edge_seen     <= 1'b0;
        mic_edge_hold_cnt <= 23'd0;
    end
    else begin
        mic_data_d0 <= mic_data;
        mic_data_d1 <= mic_data_d0;

        if(mic_data_d0 ^ mic_data_d1) begin
            mic_edge_seen     <= 1'b1;
            mic_edge_hold_cnt <= 23'd5_000_000;
        end
        else if(mic_edge_hold_cnt != 23'd0) begin
            mic_edge_hold_cnt <= mic_edge_hold_cnt - 23'd1;
        end
        else begin
            mic_edge_seen <= 1'b0;
        end
    end
end

start_transfer_ctrl u_start_transfer_ctrl (
    .clk                (eth_rx_clk      ),
    .rst_n              (rst_n           ),
    .udp_rec_pkt_done   (udp_rec_pkt_done),
    .udp_rec_en         (udp_rec_en      ),
    .udp_rec_data       (udp_rec_data    ),
    .udp_rec_byte_num   (udp_rec_byte_num),
    .ctrl               (ctrl            ),
    .transfer_flag      (transfer_flag   )
);

img_data_pkt u_img_data_pkt (
    .rst_n              (rst_n           ),
    .clk                (clk_50m_deg250  ),
    .img_data           (tx_pcm_data     ),
    .img_data_valid     (tx_pcm_valid    ),
    .transfer_flag      (stream_enable   ),
    .eth_tx_clk         (eth_tx_clk      ),
    .udp_tx_req         (udp_tx_req      ),
    .udp_tx_done        (udp_tx_done     ),
    .udp_tx_start_en    (udp_tx_start_en ),
    .udp_tx_data        (udp_tx_data     ),
    .udp_tx_byte_num    (udp_tx_byte_num )
);

eth_top #(
    .BOARD_MAC          (BOARD_MAC       ),
    .BOARD_IP           (BOARD_IP        ),
    .DES_MAC_DEFAULT    (DES_MAC_DEFAULT ),
    .DES_IP_DEFAULT     (DES_IP_DEFAULT  )
) u_eth_top (
    .sys_rst_n          (rst_n           ),
    .clk_200m           (clk_200m        ),
    .eth_rxc            (eth_rxc         ),
    .eth_rx_ctl         (eth_rx_ctl      ),
    .eth_rxd            (eth_rxd         ),
    .eth_txc            (eth_txc         ),
    .eth_tx_ctl         (eth_tx_ctl      ),
    .eth_txd            (eth_txd         ),
    .eth_rst_n          (eth_rst_n       ),

    .gmii_rx_clk        (eth_rx_clk      ),
    .gmii_tx_clk        (eth_tx_clk      ),
    .udp_tx_start_en    (udp_tx_start_en ),
    .tx_data            (udp_tx_data     ),
    .tx_byte_num        (udp_tx_byte_num ),
    .udp_tx_done        (udp_tx_done     ),
    .tx_req             (udp_tx_req      ),
    .rec_pkt_done       (udp_rec_pkt_done),
    .rec_en             (udp_rec_en      ),
    .rec_data           (udp_rec_data    ),
    .rec_byte_num       (udp_rec_byte_num)
);

endmodule
