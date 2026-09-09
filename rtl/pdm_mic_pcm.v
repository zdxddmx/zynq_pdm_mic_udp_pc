module pdm_mic_pcm #(
    parameter integer CLK_DIV     = 16,
    parameter integer DECIMATION  = 64,
    parameter integer CIC_SHIFT   = 3,
    parameter         SAMPLE_ON_HIGH = 1'b1,
    parameter         OUTPUT_DENSITY = 1'b0
) (
    input             clk,
    input             rst_n,
    output            pdm_clk,
    input             pdm_data,
    output reg [15:0] pcm_data,
    output reg        pcm_valid
);

reg [7:0] clk_div_cnt;
reg pdm_clk_r;
reg [7:0] decim_cnt;
reg pdm_data_meta;
reg pdm_data_sync;
reg [7:0] ones_count;

reg signed [31:0] int1;
reg signed [31:0] int2;
reg signed [31:0] int3;
reg signed [31:0] comb_delay1;
reg signed [31:0] comb_delay2;
reg signed [31:0] comb_delay3;

wire pdm_sample_edge;
wire signed [31:0] pdm_sample;
wire signed [31:0] int1_next;
wire signed [31:0] int2_next;
wire signed [31:0] int3_next;
wire signed [31:0] comb1_next;
wire signed [31:0] comb2_next;
wire signed [31:0] comb3_next;
wire signed [31:0] scaled_pcm;
wire [7:0] ones_count_next;
wire signed [31:0] density_pcm;

localparam signed [31:0] DENSITY_MID = DECIMATION / 2;

assign pdm_clk = pdm_clk_r;
assign pdm_sample_edge = (clk_div_cnt == (CLK_DIV / 4 - 1)) && (pdm_clk_r == SAMPLE_ON_HIGH);
assign pdm_sample = pdm_data_sync ? 32'sd1 : -32'sd1;

assign int1_next = int1 + pdm_sample;
assign int2_next = int2 + int1_next;
assign int3_next = int3 + int2_next;

assign comb1_next = int3_next - comb_delay1;
assign comb2_next = comb1_next - comb_delay2;
assign comb3_next = comb2_next - comb_delay3;
assign scaled_pcm = comb3_next >>> CIC_SHIFT;
assign ones_count_next = ones_count + {7'd0, pdm_data_sync};
assign density_pcm = ($signed({24'd0, ones_count_next}) - DENSITY_MID) <<< 10;

function [15:0] sat16;
    input signed [31:0] value;
    begin
        if(value > 32'sd32767)
            sat16 = 16'h7fff;
        else if(value < -32'sd32768)
            sat16 = 16'h8000;
        else
            sat16 = value[15:0];
end
endfunction

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        pdm_data_meta <= 1'b0;
        pdm_data_sync <= 1'b0;
    end
    else begin
        pdm_data_meta <= pdm_data;
        pdm_data_sync <= pdm_data_meta;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        clk_div_cnt <= 8'd0;
        pdm_clk_r   <= 1'b0;
    end
    else if(clk_div_cnt == (CLK_DIV / 2 - 1)) begin
        clk_div_cnt <= 8'd0;
        pdm_clk_r   <= ~pdm_clk_r;
    end
    else begin
        clk_div_cnt <= clk_div_cnt + 8'd1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        decim_cnt   <= 8'd0;
        int1        <= 32'sd0;
        int2        <= 32'sd0;
        int3        <= 32'sd0;
        comb_delay1 <= 32'sd0;
        comb_delay2 <= 32'sd0;
        comb_delay3 <= 32'sd0;
        ones_count  <= 8'd0;
        pcm_data    <= 16'd0;
        pcm_valid   <= 1'b0;
    end
    else begin
        pcm_valid <= 1'b0;

        if(pdm_sample_edge) begin
            int1 <= int1_next;
            int2 <= int2_next;
            int3 <= int3_next;

            if(decim_cnt == DECIMATION - 1) begin
                decim_cnt   <= 8'd0;
                comb_delay1 <= int3_next;
                comb_delay2 <= comb1_next;
                comb_delay3 <= comb2_next;
                ones_count  <= 8'd0;
                pcm_data    <= OUTPUT_DENSITY ? sat16(density_pcm) : sat16(scaled_pcm);
                pcm_valid   <= 1'b1;
            end
            else begin
                decim_cnt  <= decim_cnt + 8'd1;
                ones_count <= ones_count_next;
            end
        end
    end
end

endmodule
