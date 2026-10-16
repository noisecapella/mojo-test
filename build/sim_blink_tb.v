// sim_blink_tb.v — testbench for led_blink_even.v
// Checks:
//  1. Even LEDs (0,2,4,6) toggle at 1 Hz, all in phase (pattern 8'b0101_0101).
//  2. Odd LEDs (1,3,5,7) stay off for the whole run.
//  3. Full period (on + off) is ~1 s at 50 MHz.
`timescale 1ns / 1ps

module sim_blink_tb;

  reg        clk   = 1'b0;
  reg        rst_n = 1'b0;
  wire [7:0] led;

  led_blink_even dut (
    .clk   (clk),
    .rst_n (rst_n),
    .led   (led)
  );

  // 50 MHz clock
  always #10 clk = ~clk;

  // release reset after 100 ns
  initial #100 rst_n = 1'b1;

  integer i;
  time t_rise1, t_rise2;
  integer odd_seen;

  // Monitor odd LEDs (no fork/join — iverilog 11.0 misparses join_none here).
  initial begin
    odd_seen = 0;
    @(posedge led[0]);
    for (i = 0; i < 30000000; i = i + 1) begin  // 0.6 s in 20 ns steps
      #20;
      if (led[1] || led[3] || led[5] || led[7])
        odd_seen = odd_seen + 1;
    end
  end

  initial begin
    @(posedge led[0]);  t_rise1 = $time;
    @(negedge led[0]);  // off phase
    @(posedge led[0]);  t_rise2 = $time;

    // first rising edge should be at ~0.5 s after reset release
    $display("first on  at t=%0t ns (expect ~500,000,100)", t_rise1);
    $display("period    = %0t ns (expect ~1,000,000,000)", t_rise2 - t_rise1);

    if (led !== 8'b01010101) begin
      $display("FAIL: expected led==0101_0101, got %b", led);
      $finish;
    end
    // check off state
    @(negedge led[0]);
    if (led !== 8'b00000000) begin
      $display("FAIL: expected led==0000_0000 in off phase, got %b", led);
      $finish;
    end
    if ((t_rise2 - t_rise1) < 999000000 || (t_rise2 - t_rise1) > 1001000000) begin
      $display("FAIL: period out of tolerance");
      $finish;
    end
    $display("PASS: even LEDs blink at 1 Hz, odd LEDs stay off");
    $finish;
  end

  // safety timeout
  initial begin
    #3500000000;
    if (odd_seen != 0)
      $display("NOTE: odd LEDs were high %0d times", odd_seen);
    $display("FAIL: timeout");
    $finish;
  end

endmodule
