`timescale 1ns/1ps
`default_nettype none

module test_pcm_nrz;

reg clk = 0;
always #48.828125 clk = !clk;
reg reset_n = 0;

reg rxd = 0;

wire txd;
wire [7:0] hbr_data;
wire [7:0] lbr_data;
wire hbr_en;
wire lbr_en;

wire [7:0] tx_data;
assign tx_data = hbr_en ? hbr_data :
                 lbr_en ? lbr_data :
                 8'b0;

pcm_nrz #(
    .CLK_HZ(10240000),
    .BIT_RATE(51200),
    .FRAME_SIZE(128)
) hbr (
    .clk(clk),
    .reset_n(reset_n),
    .rxd(rxd),
    .tx_data(hbr_data),
    .tx_en(hbr_en)
);

pcm_nrz #(
    .CLK_HZ(10240000),
    .BIT_RATE(1600),
    .FRAME_SIZE(200)
) lbr (
    .clk(clk),
    .reset_n(reset_n),
    .rxd(rxd),
    .tx_data(lbr_data),
    .tx_en(lbr_en)
);

uart_tx #(
    .BIT_RATE(115200),
    .CLK_HZ(10240000)
) tx (
    .clk(clk),
    .resetn(reset_n),
    .uart_txd(txd),
    .uart_tx_en(hbr_en | lbr_en),
    .uart_tx_busy(),
    .uart_tx_data(tx_data) 
);

real dth = 19531.250;
real dtl = 625000.0;

initial begin
    $dumpfile("dump.fst");
    $dumpvars(0, test_pcm_nrz);
    #5000 reset_n = 1;
    #200000;
    rxd = 0;
    #(dth*5) rxd = 1;
    #(dth*1) rxd = 0;
    #(dth*1) rxd = 1;
    #(dth*1) rxd = 0;
    #(dth*1) rxd = 1;
    #(dth*4) rxd = 0;
    #(dth*2) rxd = 1;
    #(dth*2) rxd = 0;
    #(dth*1) rxd = 1;
    #(dth*2) rxd = 0;
    #(dth*1) rxd = 1;
    #(dth*5) rxd = 0;
    #(dth*6) rxd = 0;
    #(dth*992);
    #(dth*5) rxd = 1;
    #(dth*1) rxd = 0;
    #(dth*1) rxd = 1;
    #(dth*1) rxd = 0;
    #(dth*1) rxd = 1;
    #(dth*4) rxd = 0;
    #(dth*2) rxd = 1;
    #(dth*2) rxd = 0;
    #(dth*1) rxd = 1;
    #(dth*2) rxd = 0;
    #(dth*1) rxd = 1;
    #(dth*5) rxd = 0;
    #(dth*6) rxd = 0;
    #(dth*470);
    rxd = 0;
    #(dth*5) rxd = 1;
    #(dth*1) rxd = 0;
    #(dth*1) rxd = 1;
    #(dth*1) rxd = 0;
    #(dth*1) rxd = 1;
    #(dth*4) rxd = 0;
    #(dth*2) rxd = 1;
    #(dth*2) rxd = 0;
    #(dth*1) rxd = 1;
    #(dth*2) rxd = 0;
    #(dth*1) rxd = 1;
    #(dth*5) rxd = 0;
    #(dth*1200);
    #(dtl*1) rxd = 1;
    #(dtl*1) rxd = 0;
    #(dtl*8) rxd = 0;
    #(dtl*5) rxd = 1;
    #(dtl*1) rxd = 0;
    #(dtl*1) rxd = 1;
    #(dtl*1) rxd = 0;
    #(dtl*1) rxd = 1;
    #(dtl*4) rxd = 0;
    #(dtl*2) rxd = 1;
    #(dtl*2) rxd = 0;
    #(dtl*1) rxd = 1;
    #(dtl*2) rxd = 0;
    #(dtl*1) rxd = 1;
    #(dtl*5) rxd = 0;
    #(dtl*6) rxd = 0;
    #(dtl*1568);
    #10000000;
    $finish;
end

endmodule;
`default_nettype wire
