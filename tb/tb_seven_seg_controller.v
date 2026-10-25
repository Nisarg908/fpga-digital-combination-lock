`timescale 1ns / 1ps

module tb_seven_seg_controller();
    reg        clk;
    reg        reset;
    reg  [3:0] digit0, digit1, digit2, digit3;
    reg  [3:0] digit_en;
    wire [6:0] seg;
    wire [3:0] an;

    // Instantiate unit under test
    seven_seg_controller uut (
        .clk(clk),
        .reset(reset),
        .digit0(digit0),
        .digit1(digit1),
        .digit2(digit2),
        .digit3(digit3),
        .digit_en(digit_en),
        .seg(seg),
        .an(an)
    );

    // Fast clock
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        digit3 = 4'd2; // Leftmost: '2'
        digit2 = 4'd5; // '5'
        digit1 = 4'd1; // '1'
        digit0 = 4'd7; // Rightmost: '7'
        digit_en = 4'b1111; // All ON

        #20;
        reset = 0;

        // Force refresh counter directly to check all 4 anode stages quickly
        // without waiting 2^18 clock cycles
        #10;
        uut.refresh_counter = 20'b00_000000000000000000; #10; // Digit 0 (an[0] = 0)
        $display("Digit 0 (val=%0d): an=%b, seg=%b (expected seg for 7 = 1111000)", digit0, an, seg);

        uut.refresh_counter = 20'b01_000000000000000000; #10; // Digit 1 (an[1] = 0)
        $display("Digit 1 (val=%0d): an=%b, seg=%b (expected seg for 1 = 1111001)", digit1, an, seg);

        uut.refresh_counter = 20'b10_000000000000000000; #10; // Digit 2 (an[2] = 0)
        $display("Digit 2 (val=%0d): an=%b, seg=%b (expected seg for 5 = 0010010)", digit2, an, seg);

        uut.refresh_counter = 20'b11_000000000000000000; #10; // Digit 3 (an[3] = 0)
        $display("Digit 3 (val=%0d): an=%b, seg=%b (expected seg for 2 = 0100100)", digit3, an, seg);

        // Test blanking
        digit_en = 4'b0000; #10;
        $display("Blank test: an=%b, seg=%b (expected seg = 1111111)", an, seg);

        $finish;
    end
endmodule