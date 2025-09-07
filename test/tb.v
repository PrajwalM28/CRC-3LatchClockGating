`timescale 1ns/1ps
`default_nettype none

module tb_crc3;
    reg clk;
    reg rst_n;
    reg [7:0] ui_in;
    wire [7:0] uo_out;

    // DUT
    tt_um_crc3 dut (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(8'b0),
        .uio_out(),
        .uio_oe(),
        .ena(1'b1),
        .clk(clk),
        .rst_n(rst_n)
    );

    // 100 MHz
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("crc3_codeword.vcd");
        $dumpvars(0, tb_crc3);

        // Reset
        rst_n = 0; ui_in = 8'b0;
        #20 rst_n = 1;

        // Enable shifting
        ui_in[0] = 1'b1;

        // Send message 10101 (MSB-first) then 3 padding zeros
        // bit times aligned to clock edges (matching gated_clk behavior)
        ui_in[1] = 1; #10;  // 1
        ui_in[1] = 0; #10;  // 0
        ui_in[1] = 1; #10;  // 1
        ui_in[1] = 0; #10;  // 0
        ui_in[1] = 1; #10;  // 1
        ui_in[1] = 0; #10;  // padding
        ui_in[1] = 0; #10;  // padding
        ui_in[1] = 0; #10;  // padding

        // Keep enable high for one extra cycle (optional, safe)
        #10;

        // Disable
        ui_in[0] = 1'b0; #20;

        // At this point uo_out should be 8'hAD
        $display("uo_out = %02h (expected AD)", uo_out);

        $finish;
    end
endmodule
