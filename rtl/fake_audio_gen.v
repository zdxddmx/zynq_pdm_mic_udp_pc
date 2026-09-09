module fake_audio_gen #(
    parameter integer CLK_HZ      = 50_000_000,
    parameter integer SAMPLE_RATE = 48_000,
    parameter signed [15:0] STEP    = 16'sd2000,
    parameter signed [15:0] AMP_POS = 16'sd20000,
    parameter signed [15:0] AMP_NEG = -16'sd20000
) (
    input             clk,
    input             rst_n,
    output reg [15:0] sample_data,
    output reg        sample_valid
);

reg [31:0] rate_acc;
reg signed [15:0] sample;
reg direction_up;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rate_acc     <= 32'd0;
        sample       <= AMP_NEG;
        direction_up <= 1'b1;
        sample_data  <= 16'd0;
        sample_valid <= 1'b0;
    end
    else begin
        sample_valid <= 1'b0;

        if(rate_acc >= CLK_HZ - SAMPLE_RATE) begin
            rate_acc     <= rate_acc + SAMPLE_RATE - CLK_HZ;
            sample_valid <= 1'b1;
            sample_data  <= sample;

            if(direction_up) begin
                if(sample >= AMP_POS - STEP) begin
                    sample       <= AMP_POS;
                    direction_up <= 1'b0;
                end
                else begin
                    sample <= sample + STEP;
                end
            end
            else begin
                if(sample <= AMP_NEG + STEP) begin
                    sample       <= AMP_NEG;
                    direction_up <= 1'b1;
                end
                else begin
                    sample <= sample - STEP;
                end
            end
        end
        else begin
            rate_acc <= rate_acc + SAMPLE_RATE;
        end
    end
end

endmodule
