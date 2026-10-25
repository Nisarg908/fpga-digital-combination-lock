`timescale 1ns / 1ps

module tb_top_module();
    reg clk, reset, enter_button;
    reg [3:0] sw;
    wire unlock_led, error_led, lockout_led;
    wire [2:0] attempt_leds;
    
    // Instantiate DUT (Device Under Test)
    top_module dut (
        .clk(clk), 
        .reset(reset), 
        .enter_button(enter_button), 
        .sw(sw), 
        .unlock_led(unlock_led), 
        .error_led(error_led), 
        .lockout_led(lockout_led), 
        .attempt_leds(attempt_leds)
    );
    
    // Override the debounce counter threshold for fast simulation
    defparam dut.u_enter_detector.CLK_FREQ_HZ = 1000;
    defparam dut.u_enter_detector.DEBOUNCE_MS = 5;

    // 10ns Clock generator (100 MHz)
    always begin
        #5 clk = ~clk;
    end

    // Real-time signal monitor
    initial begin
        $monitor("Time=%0t | state=%0d | sw=%0d enter_btn=%b pulse=%b | unlock=%b error=%b lockout=%b | attempt_leds=%b", 
                 $time, dut.state, sw, enter_button, dut.enter_pulse, unlock_led, error_led, lockout_led, attempt_leds);
    end

    // Helper task simulating a human button press:
    task press_button(input [3:0] digit);
        begin
            @(negedge clk);
            sw = digit;
            enter_button = 1;          // Press button
            repeat (8) @(negedge clk); // Hold button past debouncer threshold

            enter_button = 0;          // Release button
            repeat (8) @(negedge clk); // Wait for release to debounce
        end
    endtask

    initial begin
        // Initialize inputs
        clk          = 0;
        reset        = 1;
        enter_button = 0;
        sw           = 4'd0;
        
        // Synchronous reset release
        #20;
        @(negedge clk);
        reset = 0;
        #20;

        // ----------------------------------------------------
        // TEST CASE 1: First Attempt - WRONG (Enter: 1-1-1-1)
        // Expected: state -> ERROR_1, attempt_leds -> 3'b001, error_led -> 1
        // ----------------------------------------------------
        $display("\n--- Starting Attempt 1: Wrong Password (1, 1, 1, 1) ---");
        press_button(4'd1); // Digit 0 -> WAIT_1
        press_button(4'd1); // Digit 1 -> WAIT_2
        press_button(4'd1); // Digit 2 -> WAIT_3
        press_button(4'd1); // Digit 3 -> CHECK -> ERROR_1
        #40;

        // ----------------------------------------------------
        // TEST CASE 2: Second Attempt - WRONG (Enter: 9-9-9-9)
        // Expected: state -> ERROR_2, attempt_leds -> 3'b011, error_led -> 1
        // ----------------------------------------------------
        $display("\n--- Starting Attempt 2: Wrong Password (9, 9, 9, 9) ---");
        press_button(4'd9); // Digit 0 -> WAIT_1
        press_button(4'd9); // Digit 1 -> WAIT_2
        press_button(4'd9); // Digit 2 -> WAIT_3
        press_button(4'd9); // Digit 3 -> CHECK -> ERROR_2
        #40;

        // ----------------------------------------------------
        // TEST CASE 3: Third Attempt - WRONG (Enter: 3-3-3-3)
        // Expected: state -> LOCKOUT, attempt_leds -> 3'b111, lockout_led -> 1
        // ----------------------------------------------------
        $display("\n--- Starting Attempt 3: Wrong Password (3, 3, 3, 3) -> LOCKOUT ---");
        press_button(4'd3); // Digit 0 -> WAIT_1
        press_button(4'd3); // Digit 1 -> WAIT_2
        press_button(4'd3); // Digit 2 -> WAIT_3
        press_button(4'd3); // Digit 3 -> CHECK -> LOCKOUT
        #40;

        // ----------------------------------------------------
        // TEST CASE 4: Verify LOCKOUT Immunity
        // Attempting inputs while in LOCKOUT should NOT alter the state
        // ----------------------------------------------------
        $display("\n--- Verifying LOCKOUT State Permanence ---");
        press_button(4'd2); // Try entering correct first digit
        press_button(4'd5); // Try entering correct second digit
        #30;

        // ----------------------------------------------------
        // TEST CASE 5: Hardware Reset Recovery & Successful Unlock
        // Expected: Reset clears LOCKOUT and attempt_leds to 3'b000
        // ----------------------------------------------------
        $display("\n--- Applying Hardware Reset to Clear LOCKOUT ---");
        @(negedge clk);
        reset = 1;
        #20;
        @(negedge clk);
        reset = 0;
        #20;

        $display("\n--- Starting New Attempt After Reset: Correct Password (2, 5, 1, 7) ---");
        press_button(4'd2); // Digit 0 -> WAIT_1
        press_button(4'd5); // Digit 1 -> WAIT_2
        press_button(4'd1); // Digit 2 -> WAIT_3
        press_button(4'd7); // Digit 3 -> CHECK -> UNLOCKED
        #50;

        $display("\n--- All Tests Completed Successfully ---");
        $finish;
    end

endmodule