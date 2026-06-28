`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Nathan Cinco
//
// Module Name: sync_debouncer
// Project Name: FPGA Pong
// Target Devices: Nexys A7-100T
// Description:
//   FSM-based pushbutton debouncer. Stage 1 is a two-FF synchronizer (kills
//   metastability on the async input). Stage 2 is a four-state FSM that requires
//   the synchronized input to hold a new level for STABLE_COUNT clocks before the
//   output follows it, rejecting mechanical bounce.
//
//   States:
//     IDLE         - released; output low; waiting for input to go high
//     PRESS_WAIT   - input high; timing it to confirm a real press
//     PRESSED      - confirmed; output high; waiting for input to go low
//     RELEASE_WAIT - input low; timing it to confirm a real release
//   Bounce during a WAIT state returns to the prior stable state and the timer
//   restarts, so chatter never completes a transition.
//////////////////////////////////////////////////////////////////////////////////

module sync_debouncer #(
    parameter STABLE_COUNT = 250000   // ~10 ms at 25 MHz
)(
    input  clk,        // pixel_clk (25 MHz)
    input  reset,
    input  btn_in,     // raw, asynchronous button
    output reg btn_out // debounced level (high while held)
);

    // ---- Stage 1: two-FF synchronizer ----
    // Two flip-flops is the standard minimum depth to let an asynchronous
    // input settle before any synchronous logic samples it, preventing
    // metastability from propagating into the FSM below.
    reg [1:0] sync;
    always @(posedge clk) begin
        if (reset) sync <= 2'b0;
        else       sync <= {sync[0], btn_in};
    end
    wire btn_sync = sync[1];

    // ---- Stage 2: FSM ----
    localparam IDLE         = 2'd0,
               PRESS_WAIT   = 2'd1,
               PRESSED      = 2'd2,
               RELEASE_WAIT = 2'd3;

    reg [1:0]  state;
    reg [17:0] counter;   // 18 bits holds STABLE_COUNT (250000)

    always @(posedge clk) begin
        if (reset) begin
            state   <= IDLE;
            counter <= 0;
            btn_out <= 1'b0;
        end else begin
            case (state)
                // -------- stable: released --------
                IDLE: begin
                    btn_out <= 1'b0;
                    counter <= 0;
                    if (btn_sync)            // input went high: start timing
                        state <= PRESS_WAIT;
                end

                // -------- timing a press --------
                PRESS_WAIT: begin
                    if (!btn_sync)           // bounce back low: abort, restart
                        state <= IDLE;
                    else if (counter >= STABLE_COUNT) begin
                        state   <= PRESSED;  // held long enough: accept
                        counter <= 0;
                    end else
                        counter <= counter + 1;
                end

                // -------- stable: pressed --------
                PRESSED: begin
                    btn_out <= 1'b1;
                    counter <= 0;
                    if (!btn_sync)           // input went low: start timing
                        state <= RELEASE_WAIT;
                end

                // -------- timing a release --------
                RELEASE_WAIT: begin
                    if (btn_sync)            // bounce back high: abort, restart
                        state <= PRESSED;
                    else if (counter >= STABLE_COUNT) begin
                        state   <= IDLE;     // released long enough: accept
                        counter <= 0;
                    end else
                        counter <= counter + 1;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
