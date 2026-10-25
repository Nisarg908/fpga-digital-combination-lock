`timescale 1ns / 1ps

module top_module(
    input  wire clk, reset, enter_button,
    input  wire [3:0] sw,
    output wire unlock_led, error_led, lockout_led, 
    output reg  [2:0] attempt_leds,
    output wire [6:0] seg,
    output wire [3:0] an
);

    parameter IDLE=4'd0, WAIT_1=4'd1, WAIT_2=4'd2, WAIT_3=4'd3, 
              CHECK=4'd4, UNLOCKED=4'd5, ERROR_1=4'd6, ERROR_2=4'd7, LOCKOUT=4'd8;

    reg [3:0] state, next_state;
    reg [3:0] buffer [0:3];
    reg [3:0] password [0:3];

    wire enter_pulse;

    // Debounce & single-cycle pulse generator for ENTER
    enter_detector #(
        .CLK_FREQ_HZ(100_000_000),
        .DEBOUNCE_MS(10)
    ) u_enter_detector (
        .clk(clk),
        .reset(reset),
        .btn_in(enter_button),
        .btn_pulse(enter_pulse)
    );

    initial begin
        password[0] = 4'd2;  
        password[1] = 4'd5;  
        password[2] = 4'd1;
        password[3] = 4'd7;  
    end

    // Combinational next-state logic
    always @(*) begin
        case(state)
            IDLE: begin 
                if (enter_pulse) next_state = WAIT_1;
                else             next_state = IDLE;
            end
            WAIT_1: begin 
                if (enter_pulse) next_state = WAIT_2;
                else             next_state = WAIT_1;
            end
            WAIT_2: begin 
                if (enter_pulse) next_state = WAIT_3;
                else             next_state = WAIT_2;
            end
            WAIT_3: begin 
                if (enter_pulse) next_state = CHECK;
                else             next_state = WAIT_3;
            end
            CHECK: begin 
                if (buffer[0] == password[0] && buffer[1] == password[1] && 
                    buffer[2] == password[2] && buffer[3] == password[3]) begin
                    next_state = UNLOCKED;
                end
                else if (attempt_leds[0] == 1'b0)
                    next_state = ERROR_1;
                else if (attempt_leds[1] == 1'b0)
                    next_state = ERROR_2;
                else
                    next_state = LOCKOUT;
            end
            UNLOCKED: next_state = UNLOCKED;
            LOCKOUT:  next_state = LOCKOUT;
            ERROR_1: begin
                if (enter_pulse) next_state = WAIT_1;
                else             next_state = ERROR_1;                                    
            end
            ERROR_2: begin
                if (enter_pulse) next_state = WAIT_1;
                else             next_state = ERROR_2;                                    
            end
            default:  next_state = IDLE;
        endcase
    end

    // Sequential state register, buffer updates, and attempt_leds
    always @(posedge clk) begin
        if (reset) begin
            state        <= IDLE;
            attempt_leds <= 3'b000;
            buffer[0]    <= 4'd0;
            buffer[1]    <= 4'd0;
            buffer[2]    <= 4'd0;
            buffer[3]    <= 4'd0;
        end
        else begin
            state <= next_state;

            // Latch switch data strictly on enter_pulse
            if (enter_pulse) begin
                if (state == IDLE || state == ERROR_1 || state == ERROR_2)
                    buffer[0] <= sw;
                else if (state == WAIT_1)
                    buffer[1] <= sw;
                else if (state == WAIT_2)
                    buffer[2] <= sw;
                else if (state == WAIT_3)
                    buffer[3] <= sw;
            end

            // Failure tally updates in CHECK state
            if (state == CHECK) begin
                if (buffer[0] != password[0] || buffer[1] != password[1] || 
                    buffer[2] != password[2] || buffer[3] != password[3]) begin
                    if (attempt_leds[0] == 1'b0)
                        attempt_leds[0] <= 1'b1;
                    else if (attempt_leds[1] == 1'b0)
                        attempt_leds[1] <= 1'b1;
                    else
                        attempt_leds[2] <= 1'b1;
                end
            end
        end          
    end    

    // Status LED outputs
    assign unlock_led  = (state == UNLOCKED);
    assign error_led   = (state == ERROR_1 || state == ERROR_2);
    assign lockout_led = (state == LOCKOUT);

    // -------------------------------------------------------------
    // Display Multiplexing & Live Switch Preview Logic
    // -------------------------------------------------------------
    reg [3:0] disp_d0, disp_d1, disp_d2, disp_d3;
    reg [3:0] disp_en;

    always @(*) begin
        case (state)
            IDLE, ERROR_1, ERROR_2: begin
                disp_d3 = sw;          // Live preview on leftmost digit
                disp_d2 = 4'd0;
                disp_d1 = 4'd0;
                disp_d0 = 4'd0;
                disp_en = 4'b1000;     // Only leftmost digit enabled
            end
            WAIT_1: begin
                disp_d3 = buffer[0];   // Retained first digit
                disp_d2 = sw;          // Live preview on second digit
                disp_d1 = 4'd0;
                disp_d0 = 4'd0;
                disp_en = 4'b1100;     // Digits 3 and 2 enabled
            end
            WAIT_2: begin
                disp_d3 = buffer[0];   // Retained first digit
                disp_d2 = buffer[1];   // Retained second digit
                disp_d1 = sw;          // Live preview on third digit
                disp_d0 = 4'd0;
                disp_en = 4'b1110;     // Digits 3, 2, and 1 enabled
            end
            WAIT_3: begin
                disp_d3 = buffer[0];   // Retained first digit
                disp_d2 = buffer[1];   // Retained second digit
                disp_d1 = buffer[2];   // Retained third digit
                disp_d0 = sw;          // Live preview on rightmost digit
                disp_en = 4'b1111;     // All 4 digits enabled
            end
            default: begin // CHECK, UNLOCKED, LOCKOUT
                disp_d3 = buffer[0];   // All digits retained[cite: 1]
                disp_d2 = buffer[1];
                disp_d1 = buffer[2];
                disp_d0 = buffer[3];
                disp_en = 4'b1111;
            end
        endcase
    end

    // Seven-segment display driver instantiation
    seven_seg_controller u_ssd (
        .clk(clk),
        .reset(reset),
        .digit0(disp_d0),     // Mapped to rightmost digit an[0]
        .digit1(disp_d1),     // Mapped to an[1]
        .digit2(disp_d2),     // Mapped to an[2]
        .digit3(disp_d3),     // Mapped to leftmost digit an[3]
        .digit_en(disp_en),
        .seg(seg),
        .an(an)
    );

endmodule
