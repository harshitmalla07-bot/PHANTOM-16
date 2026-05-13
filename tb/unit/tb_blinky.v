`timescale 1ns / 1ps

module tb_blinky;

    reg  clk;
    reg  rst;
    wire led;

    blinky dut (
        .clk (clk),
        .rst (rst),
        .led (led)
    );

    initial clk = 1'b0;
    always #18 clk = ~clk;

    initial begin
        $dumpfile("sim/blinky.vcd");
        $dumpvars(0, tb_blinky);

        rst = 1'b1;
        #100;
        rst = 1'b0;

        #2000;

        $display("Counter value at end of sim: %d", dut.counter_r);
        $display("LED state: %b", led);
        $finish;
    end

endmodule
