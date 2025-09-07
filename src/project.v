/*
 * CRC-3 with latch-based clock gating (fixed & synthesizable)
 * Polynomial: x^3 + x + 1 (binary 1011)
 * Message: 5 bits serial (MSB-first), then 3 padding zeros
 * Final output = codeword {message[4:0], crc[2:0]} when bit_count == 8
 *
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_crc3 (
    input  wire [7:0] ui_in,    // Dedicated inputs: ui_in[0]=enable, ui_in[1]=serial bit
    output wire [7:0] uo_out,   // Dedicated outputs: final codeword when ready, else 0
    input  wire [7:0] uio_in,   // IOs: Input path (unused)
    output wire [7:0] uio_out,  // IOs: Output path (unused)
    output wire [7:0] uio_oe,   // IOs: OE (unused)
    input  wire       ena,      // Platform enable (usually tied high)
    input  wire       clk,      // Clock
    input  wire       rst_n     // Active-low reset
);

    // Active-high reset
    wire reset   = ~rst_n;
    wire enable  = ui_in[0];
    wire data_in = ui_in[1];

    // Internal state
    reg  [4:0] msg_reg;    // holds 5-bit message as it's shifted in (MSB first)
    reg  [2:0] crc_reg;    // 3-bit CRC LFSR
    reg  [3:0] bit_count;  // 0..8

    // Unused IOs must be tied off
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // Output: only present when all 8 bits processed
    // (wire, combinational — will reflect updated regs after the rising edge)
    assign uo_out = (bit_count == 4'd8) ? {msg_reg, crc_reg} : 8'b0;

    // Latch-based clock gating (latched on negedge for better glitch safety)
    reg latched_enable;
    always @(negedge clk or posedge reset) begin
        if (reset)
            latched_enable <= 1'b0;
        else
            latched_enable <= enable & ena;
    end
    wire gated_clk = clk & latched_enable;

    // next_bit selects serial input for first 5 cycles, then 0 for padding
    wire next_bit = (bit_count < 4'd5) ? data_in : 1'b0;

    // CRC update on gated clock edges
    // Polynomial: x^3 + x + 1  => taps: bit2 and bit0 (binary 1011)
    always @(posedge gated_clk or posedge reset) begin
        if (reset) begin
            msg_reg   <= 5'b0;
            crc_reg   <= 3'b0;
            bit_count <= 4'd0;
        end else if (enable) begin
            // shift message register only during first 5 serial bits (MSB-first)
            if (bit_count < 4'd5)
                msg_reg <= {msg_reg[3:0], data_in};

            // perform CRC shift/division for up to 8 cycles (5 data + 3 zeros)
            if (bit_count < 4'd8) begin
                crc_reg   <= { next_bit ^ crc_reg[2] ^ crc_reg[0], crc_reg[2:1] };
                bit_count <= bit_count + 1'b1;
            end
        end
    end

endmodule
