`timescale 1ns/1ps
`default_nettype none

module pcm_fpga(
    input wire clk,
    input wire rst,
    input wire rxd,
    output wire txd,
    output wire lock,
    output wire dbg
);

wire rst_n;
assign rst_n = ~rst;

assign dbg = 1'b0;

wire [7:0] hbr_data;
wire hbr_en;
wire hbr_lock;
wire hbr_dbg;

wire [7:0] lbr_data;
wire lbr_en;
wire lbr_lock;
wire lbr_dbg;

// Generate a 10.24MHz clock
wire pcm_clk;
pcm_clock_div pcm_div(
    .clk_in1(clk),
    .reset(rst),
    .locked(),
    .clk_out1(pcm_clk)
);

// High-bit-rate: 128-word frames at 51.2kbps
pcm_nrz #(
    .CLK_HZ(10240000),
    .BIT_RATE(51200),
    .FRAME_SIZE(128)
) hbr (
    .clk(pcm_clk),
    .reset_n(rst_n),
    .rxd(rxd),
    .tx_data(hbr_data),
    .tx_en(hbr_en),
    .lock(hbr_lock),
    .dbg(hbr_dbg)
);

// Low-bit-rate: 200-word frames at 1.6kbps
pcm_nrz #(
    .CLK_HZ(10240000),
    .BIT_RATE(1600),
    .FRAME_SIZE(200)
) lbr (
    .clk(pcm_clk),
    .reset_n(rst_n),
    .rxd(rxd),
    .tx_data(lbr_data),
    .tx_en(lbr_en),
    .lock(lbr_lock),
    .dbg(lbr_dbg)
);

// Merge and transmit outputs of the two cores
wire [7:0] tx_data;
assign tx_data = hbr_en ? hbr_data :
                 lbr_en ? lbr_data :
                 8'b0;
                 
assign lock = lbr_lock | hbr_lock;

uart_tx #(
    .BIT_RATE(115200),
    .CLK_HZ(10240000)
) tx (
    .clk(pcm_clk),
    .resetn(rst_n),
    .uart_txd(txd),
    .uart_tx_en(hbr_en | lbr_en),
    .uart_tx_busy(),
    .uart_tx_data(tx_data) 
);

endmodule
`default_nettype wire
