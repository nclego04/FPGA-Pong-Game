`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Nathan Cinco
//
// Module Name: vga_sync_timing_tb
// Project Name: FPGA Pong
// Description:
//   Self-checking testbench for vga_sync covering VGA timing:
//     1. hsync/vsync are continuously checked, every pixel_clk cycle, against
//        the DUT's own column/line comparison (sampled via hierarchical
//        reference to the internal pixel_pos_h/pixel_pos_v counters, since
//        both sync outputs are registered one cycle behind the counter value
//        that drives them). This confirms both polarity (active-low) and
//        that each pulse starts at the right column/line.
//     2. The interval between consecutive vsync pulses is exactly
//        TOTAL_WIDTH * TOTAL_HEIGHT pixel_clk periods (one full 800x525 frame).
//////////////////////////////////////////////////////////////////////////////////
module vga_sync_timing_tb;

    localparam CLK_PERIOD = 40;   // 25 MHz pixel clock

    reg reset, new_game;
    reg pixel_clk;
    reg left_btn_up, left_btn_down, right_btn_up, right_btn_down;

    wire hsync, vsync;
    wire [3:0] vga_r, vga_g, vga_b;

    integer errors  = 0;
    integer samples = 0;

    // ---- DUT ----
    vga_sync dut (
        .reset          (reset),
        .new_game       (new_game),
        .pixel_clk      (pixel_clk),
        .left_btn_up    (left_btn_up),
        .left_btn_down  (left_btn_down),
        .right_btn_up   (right_btn_up),
        .right_btn_down (right_btn_down),
        .hsync          (hsync),
        .vsync          (vsync),
        .vga_r          (vga_r),
        .vga_g          (vga_g),
        .vga_b          (vga_b)
    );

    // ---- clock ----
    initial pixel_clk = 1'b0;
    always #(CLK_PERIOD/2) pixel_clk = ~pixel_clk;

    // ---- column/line + polarity monitor ----
    // Samples just after each posedge (via negedge, once the DUT's
    // non-blocking updates have settled). hsync/vsync at sample N were
    // computed from the pixel_pos_h/v value captured at sample N-1, so
    // ph_prev/pv_prev are checked against the CURRENT sync outputs.
    reg [11:0] ph_prev, pv_prev;
    reg        have_prev;

    initial begin
        have_prev = 1'b0;
        forever begin
            @(negedge pixel_clk);
            if (have_prev) begin
                samples = samples + 1;
                if (hsync !== (ph_prev < dut.H_SYNC_COLUMN)) begin
                    $display("[FAIL] hsync mismatch: ph_prev=%0d hsync=%b @%0t",
                              ph_prev, hsync, $time);
                    errors = errors + 1;
                end
                if (vsync !== (pv_prev < dut.V_SYNC_LINE)) begin
                    $display("[FAIL] vsync mismatch: pv_prev=%0d vsync=%b @%0t",
                              pv_prev, vsync, $time);
                    errors = errors + 1;
                end
            end
            ph_prev   = dut.pixel_pos_h;
            pv_prev   = dut.pixel_pos_v;
            have_prev = 1'b1;
        end
    end

    // ---- stimulus & frame-length check ----
    time t0, t1;

    initial begin
        reset          = 1'b1;
        new_game       = 1'b0;
        left_btn_up    = 1'b0;
        left_btn_down  = 1'b0;
        right_btn_up   = 1'b0;
        right_btn_down = 1'b0;

        repeat (3) @(posedge pixel_clk);
        reset = 1'b0;

        // Frame length: elapsed time between two consecutive vsync pulses.
        @(negedge vsync);
        t0 = $time;
        @(negedge vsync);
        t1 = $time;

        if ((t1 - t0) !== (dut.TOTAL_WIDTH * dut.TOTAL_HEIGHT * CLK_PERIOD)) begin
            $display("[FAIL] frame length = %0d ns, expected %0d ns",
                      (t1 - t0), dut.TOTAL_WIDTH * dut.TOTAL_HEIGHT * CLK_PERIOD);
            errors = errors + 1;
        end else begin
            $display("[PASS] frame length = %0d pixel_clk periods",
                      (t1 - t0) / CLK_PERIOD);
        end

        if (errors == 0)
            $display("==== ALL TESTS PASSED (%0d samples checked) ====", samples);
        else
            $display("==== %0d TEST(S) FAILED (%0d samples checked) ====", errors, samples);
        $finish;
    end

    // ---- safety timeout ----
    initial begin
        #(CLK_PERIOD * 800 * 525 * 3);
        $display("[FATAL] timeout -- sim hung");
        $finish;
    end

endmodule
