`timescale 1ns/1ps
`default_nettype none

module test_pcm_nrz;

reg clk = 0;
always #48.828125 clk = !clk;
reg reset_n = 0;

reg rxd = 0;

wire txd;
wire [7:0] tx_data;
wire tx_en;

pcm_nrz pcm_nrz1(
    .clk(clk),
    .reset_n(reset_n),
    .rxd(rxd),
    .tx_data(tx_data),
    .tx_en(tx_en)
);

uart_tx #(
    .BIT_RATE(115200),
    .CLK_HZ(10240000)
) tx (
    .clk(clk),
    .resetn(reset_n),
    .uart_txd(txd),
    .uart_tx_en(tx_en),
    .uart_tx_busy(),
    .uart_tx_data(tx_data) 
);

real dt = 19531.250;

initial begin
    $dumpfile("dump.fst");
    $dumpvars(0, test_pcm_nrz);
    #5000 reset_n = 1;
    #200000;
    rxd = 0;
    #(dt*5) rxd = 1;
    #(dt*1) rxd = 0;
    #(dt*1) rxd = 1;
    #(dt*1) rxd = 0;
    #(dt*1) rxd = 1;
    #(dt*4) rxd = 0;
    #(dt*2) rxd = 1;
    #(dt*2) rxd = 0;
    #(dt*1) rxd = 1;
    #(dt*2) rxd = 0;
    #(dt*1) rxd = 1;
    #(dt*5) rxd = 0;
    #(dt*6) rxd = 0;
    #(dt*496);
    #(dt*5) rxd = 1;
    #(dt*1) rxd = 0;
    #(dt*1) rxd = 1;
    #(dt*1) rxd = 0;
    #(dt*1) rxd = 1;
    #(dt*4) rxd = 0;
    #(dt*2) rxd = 1;
    #(dt*2) rxd = 0;
    #(dt*1) rxd = 1;
    #(dt*2) rxd = 0;
    #(dt*1) rxd = 1;
    #(dt*5) rxd = 0;
    #(dt*6) rxd = 0;
    #(dt*470);
    rxd = 0;
    #(dt*5) rxd = 1;
    #(dt*1) rxd = 0;
    #(dt*1) rxd = 1;
    #(dt*1) rxd = 0;
    #(dt*1) rxd = 1;
    #(dt*4) rxd = 0;
    #(dt*2) rxd = 1;
    #(dt*2) rxd = 0;
    #(dt*1) rxd = 1;
    #(dt*2) rxd = 0;
    #(dt*1) rxd = 1;
    #(dt*5) rxd = 0;
    #10000000;
    $finish;
end

endmodule;
`default_nettype wire
