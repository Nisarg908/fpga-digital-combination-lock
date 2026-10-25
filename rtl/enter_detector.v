`timescale 1ns / 1ps

module enter_detector #(
    parameter CLK_FREQ_HZ   = 100_000_000, // 100 MHz clock (Basys 3 / Artix-7)
    parameter DEBOUNCE_MS   = 10           // 10 ms debounce threshold
)(
    input  wire clk,
    input  wire reset,
    input  wire btn_in,
    output wire btn_pulse
);

    localparam integer COUNT_MAX = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;

    // 1. Two-stage synchronizer to avoid metastability
    reg sync_0, sync_1;
    always @(posedge clk) begin
        if (reset) begin
            sync_0 <= 1'b0;
            sync_1 <= 1'b0;
        end else begin
            sync_0 <= btn_in;
            sync_1 <= sync_0;
        end
    end

    // 2. Debounce counter
    reg [19:0] count;
    reg debounced_state;

    always @(posedge clk) begin
        if (reset) begin
            count           <= 20'd0;
            debounced_state <= 1'b0;
        end else if (sync_1 != debounced_state) begin
            count <= count + 1'b1;
            if (count >= COUNT_MAX - 1) begin
                debounced_state <= sync_1;
                count           <= 20'd0;
            end
        end else begin
            count <= 20'd0;
        end
    end

    // 3. Rising-edge pulse generator
    reg debounced_d1;
    always @(posedge clk) begin
        if (reset)
            debounced_d1 <= 1'b0;
        else
            debounced_d1 <= debounced_state;
    end

    assign btn_pulse = (debounced_state && !debounced_d1);

endmodule