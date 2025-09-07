/* 
 * Copyright (c) 2024 BMSCE04
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_crc3 (
    input  wire [7:0] ui_in,    // ui_in[0]=enable, ui_in[1]=serial bit
    output wire [7:0] uo_out,   // 8-bit {msg[4:0], crc[2:0]} after 8 cycles; otherwise 0
    input  wire [7:0] uio_in,   // unused
    output wire [7:0] uio_out,  // unused
    output wire [7:0] uio_oe,   // unused
    input  wire       ena,      // platform enable
    input  wire       clk,      // clock (do NOT gate)
    input  wire       rst_n     // active-low reset
);

    // Active-high reset
    wire reset   = ~rst_n;

    // Inputs
    wire enable  = ui_in[0];
    wire data_in = ui_in[1];

    // Internal state
    reg  [4:0] msg_reg;    // shifts in 5 data bits (MSB-first)
    reg  [2:0] crc_reg;    // CRC-3 (poly x^3 + x + 1)
    reg  [3:0] bit_count;  // 0..8
    reg  [7:0] out_reg;    // registered output

    // Tie off IOs
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // Lint-friendly consumption of unused inputs
    // (prevents UNUSED warnings without affecting logic)
    wire _unused_inputs;
    assign _unused_inputs = &{1'b0, ui_in[7:2], uio_in, 1'b0};

    // Drive outputs
    assign uo_out = out_reg;

    // Synchronous design, no gated clocks, no latches
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            msg_reg   <= 5'b0;
            crc_reg   <= 3'b0;
            bit_count <= 4'd0;
            out_reg   <= 8'b0;
        end else if (ena) begin
            // Only operate while 'enable' is high; otherwise hold/reset cleanly
            if (enable) begin
                // next data bit (pad zeros after 5 message bits)
                wire next_bit = (bit_count < 4'd5) ? data_in : 1'b0;

                // compute "next" values (so we can capture final result the same cycle)
                wire [4:0] msg_next = (bit_count < 4'd5) ? {msg_reg[3:0], data_in} : msg_reg;
                wire [2:0] crc_next = { next_bit ^ crc_reg[2] ^ crc_reg[0], crc_reg[2:1] };

                if (bit_count < 4'd8) begin
                    msg_reg   <= msg_next;
                    crc_reg   <= crc_next;
                    bit_count <= bit_count + 1'b1;

                    // After the 8th step completes (i.e., when bit_count was 7),
                    // present the codeword on the very next cycle via registered output.
                    if (bit_count == 4'd7)
                        out_reg <= {msg_next, crc_next};
                    else
                        out_reg <= 8'b0;
                end else begin
                    // Hold the result while enable stays high; TT prefers stable outputs
                    out_reg <= {msg_reg, crc_reg};
                end
            end else begin
                // When enable deasserts, return to idle/clear output
                msg_reg   <= 5'b0;
                crc_reg   <= 3'b0;
                bit_count <= 4'd0;
                out_reg   <= 8'b0;
            end
        end
    end

endmodule

`default_nettype wire
