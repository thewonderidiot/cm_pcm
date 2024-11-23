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

parameter SYNC_PATTERN = 26'b00000101_01111001_10110111_11;

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

reg [7:0] sample_count;
wire bit_sample;
assign dbg=bit_sample;
assign bit_sample = (sample_count == 8'd100);
always @(posedge clk) begin
    if (~reset_n) begin
        sample_count <= 8'b0;
    end else begin
        if (rxd_edge) begin
            sample_count <= 8'b0;
        end else begin
            if (sample_count == 8'd199) begin
                sample_count <= 8'b0;
            end else begin
                sample_count <= sample_count + 1;
            end
        end
    end
end

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

reg [6:0] frame_count;
wire sync;
assign sync = (frame_count == 7'b0) && (rx_bits == SYNC_PATTERN);
assign lock = (frame_count > 0);

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
        frame_count <= 7'b0;
    end else begin
        if (sync) begin
            frame_count <= 7'd127;
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

reg [3:0] keepout_count;
wire keepout;
assign keepout = keepout_count > 0;
always @(posedge clk) begin
    if (~reset_n) begin
        keepout_count <= 3'b0;
    end else begin
        if (sync) begin
            keepout_count <= 3'd0;
        end else if (bit_sample) begin
            if ((frame_count == 7'd0) && (rx_bits[18:0] == SYNC_PATTERN[25:7])) begin
                keepout_count <= 3'd7;
            end else if (keepout_count > 0) begin
                keepout_count <= keepout_count - 1;
            end else begin
                keepout_count <= keepout_count;
            end
        end else begin
            keepout_count <= keepout_count;
        end
    end
end

assign tx_en = (~keepout) & byte_sync;
assign tx_data = rx_bits[25:18];

endmodule;
`default_nettype wire
