// ==============================================================
// Testbench:   tb_register_file
// Project:     PHANTOM-16 Processor
// Author:      Harshit | McMaster University
// Created:     2026-05-20
// Description: Verifies the 8x16 register file's key properties:
//              reset, basic write/read, R0-read-returns-zero,
//              R0-write-is-ignored, dual-port simultaneous read,
//              write-after-read same-cycle semantics, and
//              we-low prevents writes.
// ==============================================================

`timescale 1ns / 1ps

module tb_register_file;

    reg         clk;
    reg         rst;
    reg  [2:0]  rs1_addr;
    wire [15:0] rs1_data;
    reg  [2:0]  rs2_addr;
    wire [15:0] rs2_data;
    reg         we;
    reg  [2:0]  rd_addr;
    reg  [15:0] rd_data;

    integer pass_count;
    integer fail_count;

    register_file dut (
        .clk      (clk),
        .rst      (rst),
        .rs1_addr (rs1_addr),
        .rs1_data (rs1_data),
        .rs2_addr (rs2_addr),
        .rs2_data (rs2_data),
        .we       (we),
        .rd_addr  (rd_addr),
        .rd_data  (rd_data)
    );

    // 100 MHz clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    task check;
        input [255:0] name;
        input [15:0]  got;
        input [15:0]  expected;
        begin
            if (got === expected) begin
                $display("PASS  %0s  ->  0x%04h", name, got);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL  %0s  ->  expected 0x%04h, got 0x%04h",
                         name, expected, got);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Helper: perform a write on the next rising edge, then settle
    task do_write;
        input [2:0]  addr;
        input [15:0] value;
        begin
            @(negedge clk);
            we      = 1'b1;
            rd_addr = addr;
            rd_data = value;
            @(posedge clk);
            @(negedge clk);
            we      = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("sim/register_file.vcd");
        $dumpvars(0, tb_register_file);

        pass_count = 0;
        fail_count = 0;

        // Initialize all inputs
        rst      = 1'b1;
        we       = 1'b0;
        rs1_addr = 3'b000;
        rs2_addr = 3'b000;
        rd_addr  = 3'b000;
        rd_data  = 16'h0000;

        $display("");
        $display("=== tb_register_file: PHANTOM-16 register file verification ===");
        $display("");

        // -----------------------------------------------------------------
        // Test 1: After reset, all registers read as zero
        // -----------------------------------------------------------------
        @(posedge clk);
        @(posedge clk);
        rst = 1'b0;
        @(negedge clk);
        rs1_addr = 3'd3;
        #1;
        check("Reset: R3 reads zero", rs1_data, 16'h0000);

        rs1_addr = 3'd7;
        #1;
        check("Reset: R7 reads zero", rs1_data, 16'h0000);

        // -----------------------------------------------------------------
        // Test 2: Basic write then read
        // -----------------------------------------------------------------
        do_write(3'd3, 16'hCAFE);
        rs1_addr = 3'd3;
        #1;
        check("Write R3=CAFE, read R3", rs1_data, 16'hCAFE);

        // -----------------------------------------------------------------
        // Test 3: Writes to R0 are silently ignored
        // -----------------------------------------------------------------
        do_write(3'd0, 16'hDEAD);
        rs1_addr = 3'd0;
        #1;
        check("Write R0=DEAD ignored", rs1_data, 16'h0000);

        // -----------------------------------------------------------------
        // Test 4: R0 reads always return zero, even if storage is weird
        //         (already covered above, but worth checking on both ports)
        // -----------------------------------------------------------------
        rs2_addr = 3'd0;
        #1;
        check("R0 read on port B", rs2_data, 16'h0000);

        // -----------------------------------------------------------------
        // Test 5: Two independent read ports at the same time
        // -----------------------------------------------------------------
        do_write(3'd5, 16'h1234);
        do_write(3'd6, 16'h5678);
        rs1_addr = 3'd5;
        rs2_addr = 3'd6;
        #1;
        check("Dual read port A (R5)", rs1_data, 16'h1234);
        check("Dual read port B (R6)", rs2_data, 16'h5678);

        // -----------------------------------------------------------------
        // Test 6: Write-after-read semantics.
        //         When we write R4 in the same cycle we read it, the
        //         read must return the OLD value (write happens at the
        //         clock edge, but the read is combinational off the
        //         current register storage).
        // -----------------------------------------------------------------
        do_write(3'd4, 16'hAAAA);         // Prime R4 with old value
        @(negedge clk);
        rs1_addr = 3'd4;
        rd_addr  = 3'd4;
        rd_data  = 16'hBBBB;
        we       = 1'b1;
        #1;
        // Read happens combinationally off storage, which still holds AAAA
        check("Same-cycle read returns OLD value", rs1_data, 16'hAAAA);
        @(posedge clk);                    // Write BBBB fires here
        @(negedge clk);
        we = 1'b0;
        #1;
        check("Next-cycle read returns NEW value", rs1_data, 16'hBBBB);

        // -----------------------------------------------------------------
        // Test 7: we=0 prevents writes
        // -----------------------------------------------------------------
        do_write(3'd2, 16'h0F0F);          // Prime R2
        @(negedge clk);
        rd_addr = 3'd2;
        rd_data = 16'hF0F0;                // Try to overwrite
        we      = 1'b0;                    // ...but we is low
        @(posedge clk);
        @(negedge clk);
        rs1_addr = 3'd2;
        #1;
        check("we=0 blocks write to R2", rs1_data, 16'h0F0F);

        // -----------------------------------------------------------------
        // Summary
        // -----------------------------------------------------------------
        $display("");
        $display("=== Results: %0d passed, %0d failed ===", pass_count, fail_count);
        $display("");

        if (fail_count == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** %0d FAILURES ***", fail_count);

        $finish;
    end

endmodule
