`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Nathan Cinco
//
// Create Date: 05/31/2026
// Module Name: tb_clk_gen_25MHz
// Project Name: FPGA Pong
// Target Devices: Simulation Only
// Description:
//   Self-checking testbench for the 25 MHz clock divider. Drives a 100 MHz
//   input clock and asserts:
//     1. While reset is asserted, the internal counter (and therefore the
//        output) is held at zero -- and an async reset applied mid-count
//        clears it immediately, without waiting for a clock edge.
//     2. The output period is 40 ns (exactly 4x the input period).
//     3. The output is 50% duty (high time == low time == 20 ns), and the
//        period is stable across consecutive cycles.
////////////////////////////////////////////////////////////////////////////////////
module tb_clk_gen_25MHz();

    localparam IN_PERIOD       = 10;             // 100 MHz input clock period (ns)
    localparam EXPECTED_PERIOD = 4 * IN_PERIOD;  // 25 MHz output -> 40 ns
    localparam EXPECTED_HALF   = EXPECTED_PERIOD / 2;

    reg  clk_100MHz;
    reg  reset;
    wire clk_25MHz;

    integer errors = 0;

    time t_rise1, t_fall, t_rise2, t_rise3;
    time high_time, low_time, period, period2;
    reg [1:0] pre_reset_count;

    // ---- DUT ----
    clk_gen_25MHz uut (
        .clk_100MHz (clk_100MHz),
        .reset      (reset),
        .clk_25MHz  (clk_25MHz)
    );

    // ---- 100 MHz stimulus clock ----
    initial clk_100MHz = 1'b0;
    always #(IN_PERIOD/2) clk_100MHz = ~clk_100MHz;

    task check(input cond, input [383:0] label);
        begin
            if (cond)
                $display("[PASS] %0s @%0t", label, $time);
            else begin
                $display("[FAIL] %0s @%0t", label, $time);
                errors = errors + 1;
            end
        end
    endtask

    // ---- stimulus & checks ----
    initial begin
        reset = 1'b1;

        // ---- 1. Reset holds the counter/output at zero ----
        repeat (3) @(posedge clk_100MHz);
        check(uut.counter === 2'd0, "reset_holds_counter_zero");
        check(clk_25MHz   === 1'b0, "reset_holds_output_low");

        reset = 1'b0;

        // ---- 2 & 3. Period == 40 ns, 50% duty, stable across cycles ----
        // Span two full output periods: rise -> fall -> rise -> rise.
        @(posedge clk_25MHz); t_rise1 = $time;
        @(negedge clk_25MHz); t_fall  = $time;
        @(posedge clk_25MHz); t_rise2 = $time;
        @(posedge clk_25MHz); t_rise3 = $time;

        high_time = t_fall  - t_rise1;
        low_time  = t_rise2 - t_fall;
        period    = t_rise2 - t_rise1;
        period2   = t_rise3 - t_rise2;

        check(period == EXPECTED_PERIOD,                         "output_period_40ns_4x_input");
        check(high_time == EXPECTED_HALF && low_time == EXPECTED_HALF, "output_duty_50pct");
        check(period2 == period,                                "output_period_stable");
        $display("       period=%0d ns, high=%0d ns, low=%0d ns (next period=%0d ns)",
                 period, high_time, low_time, period2);

        // ---- 1b. Async reset mid-count clears immediately (no clock edge) ----
        wait (uut.counter !== 2'd0);   // catch it partway through a count
        pre_reset_count = uut.counter;
        reset = 1'b1;
        #1;                            // well under one input period: no posedge occurs
        check(uut.counter === 2'd0, "async_reset_clears_counter");
        check(clk_25MHz   === 1'b0, "async_reset_clears_output");
        $display("       (counter was %0d, cleared with no intervening clk edge)",
                 pre_reset_count);
        reset = 1'b0;

        if (errors == 0)
            $display("==== ALL TESTS PASSED ====");
        else
            $display("==== %0d TEST(S) FAILED ====", errors);
        $finish;
    end

    // ---- safety timeout ----
    initial begin
        #1000;
        $display("[FATAL] timeout -- sim hung");
        $finish;
    end

endmodule
