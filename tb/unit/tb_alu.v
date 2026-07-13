// ==============================================================
// Testbench:   tb_alu
// Project:     PHANTOM-16 Processor
// Author:      Harshit | McMaster University
// Created:     2026-05-20
// Description: Drives the ALU with the 10 test cases from PRD §7.1
//              covering every operation plus the edge cases for
//              add-overflow wrap and arithmetic-vs-logical right
//              shift. Counts pass/fail and prints a summary.
// ==============================================================

`timescale 1ns / 1ps

module tb_alu;

    reg  [15:0] a;
    reg  [15:0] b;
    reg  [3:0]  alu_op;
    wire [15:0] result;
    wire        zero;

    integer pass_count;
    integer fail_count;

    alu dut (
        .a      (a),
        .b      (b),
        .alu_op (alu_op),
        .result (result),
        .zero   (zero)
    );

    // Mirror of the ALU op codes for readability in test calls
    localparam [3:0] ALU_ADD = 4'b0000;
    localparam [3:0] ALU_SUB = 4'b0001;
    localparam [3:0] ALU_AND = 4'b0010;
    localparam [3:0] ALU_OR  = 4'b0011;
    localparam [3:0] ALU_XOR = 4'b0100;
    localparam [3:0] ALU_SLL = 4'b0101;
    localparam [3:0] ALU_SRL = 4'b0110;
    localparam [3:0] ALU_SRA = 4'b0111;
    localparam [3:0] ALU_LUI = 4'b1000;

    task check;
        input [255:0] name;
        input [15:0]  exp_result;
        input         exp_zero;
        begin
            #1;  // let combinational logic settle
            if (result === exp_result && zero === exp_zero) begin
                $display("PASS  %0s  ->  result=0x%04h zero=%b",
                         name, result, zero);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL  %0s  ->  expected result=0x%04h zero=%b, got result=0x%04h zero=%b",
                         name, exp_result, exp_zero, result, zero);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("sim/alu.vcd");
        $dumpvars(0, tb_alu);

        pass_count = 0;
        fail_count = 0;

        $display("");
        $display("=== tb_alu: PHANTOM-16 ALU verification ===");
        $display("");

        // PRD test 1: ADD no overflow
        a = 16'h0005; b = 16'h0003; alu_op = ALU_ADD;
        check("ADD no overflow", 16'h0008, 1'b0);

        // PRD test 2: ADD overflow wrap to zero
        a = 16'hFFFF; b = 16'h0001; alu_op = ALU_ADD;
        check("ADD overflow wrap", 16'h0000, 1'b1);

        // PRD test 3: SUB positive result
        a = 16'h000A; b = 16'h0003; alu_op = ALU_SUB;
        check("SUB positive", 16'h0007, 1'b0);

        // PRD test 4: SUB produces zero
        a = 16'h0005; b = 16'h0005; alu_op = ALU_SUB;
        check("SUB to zero", 16'h0000, 1'b1);

        // PRD test 5: AND
        a = 16'hFF0F; b = 16'h0FF0; alu_op = ALU_AND;
        check("AND", 16'h0F00, 1'b0);

        // PRD test 6: OR
        a = 16'hF00F; b = 16'h0FF0; alu_op = ALU_OR;
        check("OR", 16'hFFFF, 1'b0);

        // PRD test 7: XOR
        a = 16'hAAAA; b = 16'h5555; alu_op = ALU_XOR;
        check("XOR", 16'hFFFF, 1'b0);

        // PRD test 8: SLL by 4
        a = 16'h0001; b = 16'h0004; alu_op = ALU_SLL;
        check("SLL by 4", 16'h0010, 1'b0);

        // PRD test 9: SRL by 4
        a = 16'h0010; b = 16'h0004; alu_op = ALU_SRL;
        check("SRL by 4", 16'h0001, 1'b0);

        // PRD test 10: SRA preserves sign bit
        a = 16'h8000; b = 16'h0001; alu_op = ALU_SRA;
        check("SRA negative", 16'hC000, 1'b0);

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
