// ==============================================================
// Module:      alu
// Project:     PHANTOM-16 Processor
// Author:      Harshit | McMaster University
// Created:     2026-05-20
// Description: Purely combinational 16-bit Arithmetic Logic Unit.
//              Performs the eight R-type operations plus LUI,
//              selected by a 4-bit alu_op. Outputs a 16-bit result
//              and a zero flag (result == 0). Instantiated inside
//              ex_stage.v. The alu_op encoding for the R-type ops
//              deliberately matches the 3-bit funct field so the
//              control unit can form alu_op = {1'b0, funct}.
// ==============================================================

module alu (
    input  wire [15:0] a,
    input  wire [15:0] b,
    input  wire [3:0]  alu_op,
    output reg  [15:0] result,
    output wire        zero
);

    // ALU operation codes (low 8 match R-type funct)
    localparam ALU_ADD = 4'b0000;
    localparam ALU_SUB = 4'b0001;
    localparam ALU_AND = 4'b0010;
    localparam ALU_OR  = 4'b0011;
    localparam ALU_XOR = 4'b0100;
    localparam ALU_SLL = 4'b0101;
    localparam ALU_SRL = 4'b0110;
    localparam ALU_SRA = 4'b0111;
    localparam ALU_LUI = 4'b1000;

    always @(*) begin
        case (alu_op)
            ALU_ADD: result = a + b;
            ALU_SUB: result = a - b;
            ALU_AND: result = a & b;
            ALU_OR:  result = a | b;
            ALU_XOR: result = a ^ b;
            ALU_SLL: result = a << b[2:0];
            ALU_SRL: result = a >> b[2:0];
            ALU_SRA: result = $signed(a) >>> b[2:0];
            ALU_LUI: result = b << 10;
            default: result = 16'h0000;
        endcase
    end

    assign zero = (result == 16'h0000);

endmodule

