`timescale 1ns/1ps
`default_nettype none

module pcm_nrz(
    input wire clk,
    input wire reset_n,
    input wire rxd,
    output wire [7:0] tx_data,
    output wire tx_en,
    output wire lock,
    output wire dbg
);

parameter CLK_HZ = 10240000;
parameter BIT_RATE = 51200;
parameter FRAME_SIZE = 128;
parameter SYNC_PATTERN = 26'b00000101_01111001_10110111_11;

localparam CYCLES_PER_BIT = CLK_HZ / BIT_RATE;

/****************************** RX DEBOUNCE ***********************************/
reg rxd1;
reg rxd2;
reg rxd_bit;
reg rxd_bit1;
wire rxd_edge;
assign rxd_edge = rxd_bit != rxd_bit1;

always @(posedge clk) begin
    if (~reset_n) begin
        rxd1 <= 1'b0;
        rxd2 <= 1'b0;
        rxd_bit <= 1'b0;
        rxd_bit1 <= 1'b0;
    end else begin
        rxd2 <= rxd1;
        rxd1 <= rxd;
        rxd_bit1 <= rxd_bit;
        if ((rxd & rxd1 & rxd2) | (~rxd & ~rxd1 & ~rxd2)) begin
            rxd_bit <= rxd;
        end else begin
            rxd_bit <= rxd_bit;
        end
    end
end

/***************************** SAMPLE TIMING **********************************/
localparam COUNT_SIZE = $clog2(CYCLES_PER_BIT);

reg [COUNT_SIZE-1:0] sample_count;
wire bit_sample;
assign dbg=bit_sample;
assign bit_sample = (sample_count == (CYCLES_PER_BIT/2));
always @(posedge clk) begin
    if (~reset_n) begin
        sample_count <= 0;
    end else begin
        if (rxd_edge) begin
            sample_count <= 0;
        end else begin
            if (sample_count == (CYCLES_PER_BIT-1)) begin
                sample_count <= 0;
            end else begin
                sample_count <= sample_count + 1;
            end
        end
    end
end

/********************************* SAMPLING ***********************************/
reg [25:0] rx_bits;
always @(posedge clk) begin
    if (~reset_n) begin
        rx_bits <= 26'b0;
    end else begin
        if (bit_sample) begin
            rx_bits <= {rx_bits[24:0], rxd_bit};
        end else begin
            rx_bits <= rx_bits;
        end
    end
end

/****************************** FRAME SYNCING *********************************/
reg [7:0] frame_count;
wire pos_sync;
assign pos_sync = (frame_count == 8'b0) && (rx_bits == SYNC_PATTERN);
wire neg_sync;
assign neg_sync = (frame_count == 8'b0) && ((~rx_bits) == SYNC_PATTERN);
wire sync;
assign sync = pos_sync || neg_sync;
assign lock = (frame_count > 0);

reg inverted;
always @(posedge clk) begin
    if (~reset_n) begin
        inverted <= 1'b0;
    end else begin
        if (pos_sync) begin
            inverted <= 1'b0;
        end else if (neg_sync) begin
            inverted <= 1'b1;
        end else begin
            inverted <= inverted;
        end
    end
end

reg [2:0] bit_count;
always @(posedge clk) begin
    if (~reset_n) begin
        bit_count <= 3'b0;
    end else begin
        if (sync) begin
            bit_count <= 3'b0;
        end else if (bit_sample) begin
            bit_count <= bit_count + 1;
        end else begin
            bit_count <= bit_count;
        end
    end
end

wire byte_sync;
assign byte_sync = bit_sample && (bit_count == 0);

always @(posedge clk) begin
    if (~reset_n) begin
        frame_count <= 8'b0;
    end else begin
        if (sync) begin
            frame_count <= FRAME_SIZE;
        end else if (tx_en) begin
            if (frame_count > 0) begin
                frame_count <= frame_count - 1;
            end else begin
                frame_count <= frame_count;
            end
        end else begin
            frame_count <= frame_count;
        end
    end
end

assign tx_en = (lock) & byte_sync;
wire [7:0] raw_data;
assign raw_data = rx_bits[25:18];
assign tx_data = (inverted) ? ~raw_data : raw_data;

endmodule
`default_nettype wire
