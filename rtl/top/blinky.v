// ==============================================================
// Module:      blinky
// Project:     PHANTOM-16 Processor (Phase 0 sanity check)
// Author:      Harshit | McMaster University
// Created:     2026-05-03
// Description: Toggles an LED at ~1Hz from a 27MHz clock.
// ==============================================================

module blinky (
    input  wire clk,
    input  wire rst,
    output wire led
);

    reg [24:0] counter_r;

    always @(posedge clk) begin
        if (rst)
            counter_r <= 25'd0;
        else
            counter_r <= counter_r + 25'd1;
    end

    assign led = counter_r[24];

endmodule
