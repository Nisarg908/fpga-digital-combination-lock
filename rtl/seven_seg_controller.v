`timescale 1ns / 1ps

module seven_seg_controller (
    input  wire       clk,          // 100 MHz clock
    input  wire       reset,
    input  wire [3:0] digit0,       // Rightmost digit (an[0])
    input  wire [3:0] digit1,       // Digit 1 (an[1])
    input  wire [3:0] digit2,       // Digit 2 (an[2])
    input  wire [3:0] digit3,       // Leftmost digit (an[3])
    input  wire [3:0] digit_en,     // Active-high enable for each digit (1 = ON, 0 = BLANK)
    output reg  [6:0] seg,          // Active-low segments: {g, f, e, d, c, b, a}
    output reg  [3:0] an            // Active-low anodes: an[3:0]
);

    // Refresh counter for display multiplexing:
    // With 100 MHz clock, refresh[19:18] gives ~95 Hz refresh rate across all 4 digits
    reg [19:0] refresh_counter;
    wire [1:0] digit_select;
    reg  [3:0] active_nibble;
    reg        active_en;

    always @(posedge clk) begin
        if (reset)
            refresh_counter <= 20'd0;
        else
            refresh_counter <= refresh_counter + 1'b1;
    end

    assign digit_select = refresh_counter[19:18];

    // Multiplexer for anode activation and digit nibble selection
    always @(*) begin
        case (digit_select)
            2'b00: begin // Rightmost digit (Digit 0)
                an            = 4'b1110;
                active_nibble = digit0;
                active_en     = digit_en[0];
            end
            2'b01: begin // Digit 1
                an            = 4'b1101;
                active_nibble = digit1;
                active_en     = digit_en[1];
            end
            2'b10: begin // Digit 2
                an            = 4'b1011;
                active_nibble = digit2;
                active_en     = digit_en[2];
            end
            2'b11: begin // Leftmost digit (Digit 3)
                an            = 4'b0111;
                active_nibble = digit3;
                active_en     = digit_en[3];
            end
        endcase
    end

    // 7-segment BCD decoder (Active-Low segments: 0 = Lit, 1 = Off)
    always @(*) begin
        if (!active_en) begin
            seg = 7'b1111111; // Blank display
        end else begin
            case (active_nibble)
                4'd0: seg = 7'b1000000;
                4'd1: seg = 7'b1111001;
                4'd2: seg = 7'b0100100;
                4'd3: seg = 7'b0110000;
                4'd4: seg = 7'b0011001;
                4'd5: seg = 7'b0010010;
                4'd6: seg = 7'b0000010;
                4'd7: seg = 7'b1111000;
                4'd8: seg = 7'b0000000;
                4'd9: seg = 7'b0010000;
                default: seg = 7'b1111111; // Blank for values > 9
            endcase
        end
    end

endmodule