// ==============================================================
// Module:      register_file
// Project:     PHANTOM-16 Processor
// Author:      Harshit | McMaster University
// Created:     2026-05-20
// Description: 8-entry x 16-bit general-purpose register file with
//              two combinational read ports and one synchronous
//              write port. R0 is hardwired to zero: writes to R0
//              are silently ignored, reads of R0 always return
//              16'h0000. Reads and writes to the same address in
//              the same cycle follow write-after-read semantics
//              (the read returns the OLD value; the MEM-WB
//              forwarding path handles the resulting hazard).
// ==============================================================

module register_file (
    input  wire         clk,
    input  wire         rst,

    // Read port A
    input  wire [2:0]   rs1_addr,
    output wire [15:0]  rs1_data,

    // Read port B
    input  wire [2:0]   rs2_addr,
    output wire [15:0]  rs2_data,

    // Write port
    input  wire         we,          // write-enable from WB stage
    input  wire [2:0]   rd_addr,
    input  wire [15:0]  rd_data
);

    // Storage: 8 x 16-bit. R0 slot is never actually used.
    reg [15:0] regs_r [0:7];

    integer i;

    // Synchronous write with R0 protection and reset
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 8; i = i + 1)
                regs_r[i] <= 16'h0000;
        end else if (we && (rd_addr != 3'b000)) begin
            regs_r[rd_addr] <= rd_data;
        end
    end

    // Combinational reads with R0 hardwired to zero
    assign rs1_data = (rs1_addr == 3'b000) ? 16'h0000 : regs_r[rs1_addr];
    assign rs2_data = (rs2_addr == 3'b000) ? 16'h0000 : regs_r[rs2_addr];

endmodule
