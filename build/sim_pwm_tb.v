// sim_pwm_tb.v -- testbench for led_pwm_cycle.v
// Checks:
//  1. PWM period of a 50% LED is ~1 ms (1 kHz).
//  2. Window A (t = 50 ms .. 550 ms, phase 0): duty per LED is
//       led[0]=25%, led[1]=75%, led[2]=100%, led[3]=25%,
//       led[4]=75%, led[5]=100%, led[6]=25%, led[7]=75%
//  3. Window B (t = 1050 ms .. 1550 ms, phase 1, after one 1 s step):
//       led[0]=75%, led[1]=100%, led[2]=25%, led[3]=75%,
//       led[4]=100%, led[5]=25%, led[6]=75%, led[7]=100%
// Sampling is every 11 us (does not divide the 1 ms PWM period, so no
// aliasing: the sample phase drifts through the whole PWM cycle over each
// 0.5 s window, giving an accurate duty estimate).
// All declarations at module scope, no digit separators, no fork/join_none
// (iverilog 11.0 gotchas).
`timescale 1ns / 1ps

module sim_pwm_tb;

  reg        clk   = 1'b0;
  reg        rst_n = 1'b0;
  wire [7:0] led;

  led_pwm_cycle dut (
    .clk   (clk),
    .rst_n (rst_n),
    .led   (led)
  );

  // 50 MHz clock
  always #10 clk = ~clk;

  // release reset after 100 ns
  initial #100 rst_n = 1'b1;

  integer i;
  integer totalA;
  integer totalB;
  integer lvlA;
  integer lvlB;
  integer fail;
  integer hiA [0:7];
  integer hiB [0:7];
  time t_r1;
  time t_r2;

  // PWM period measurement on led[1] (starts at 75%). All LEDs are high at
  // t=0 (combinational, pwm_cnt=0, every duty > 0), so skip to the first
  // real negedge, then measure posedge-to-posedge: one 1 ms PWM period.
  initial begin
    @(negedge led[1]);
    @(posedge led[1]);  t_r1 = $time;
    @(posedge led[1]);  t_r2 = $time;
    $display("pwm period of led[1] = %0d ns (expect 1000000)", t_r2 - t_r1);
    if (t_r2 - t_r1 < 999900 || t_r2 - t_r1 > 1000100) begin
      $display("FAIL: pwm period out of tolerance");
      $finish;
    end
    $display("pwm period check OK");
  end

  // Duty-cycle measurement in windows A and B.
  initial begin
    fail = 0;
    for (i = 0; i < 8; i = i + 1) begin
      hiA[i] = 0;
      hiB[i] = 0;
    end
    totalA = 0;
    totalB = 0;

    // 150000 samples * 11 us = 1.65 s
    for (i = 0; i < 150000; i = i + 1) begin
      #11000;
      if ($time >= 50000000 && $time <= 550000000) begin
        totalA = totalA + 1;
        for (i = 0; i < 8; i = i + 1)
          if (led[i] == 1'b1) hiA[i] = hiA[i] + 1;
      end
      if ($time >= 1050000000 && $time <= 1550000000) begin
        totalB = totalB + 1;
        for (i = 0; i < 8; i = i + 1)
          if (led[i] == 1'b1) hiB[i] = hiB[i] + 1;
      end
    end

    $display("samples: window A = %0d, window B = %0d", totalA, totalB);

    // Window A: level = i mod 3  (0=25%, 1=75%, 2=100%)
    for (i = 0; i < 8; i = i + 1) begin
      lvlA = i - 3 * (i / 3);
      $display("A led[%0d] duty = %0d/%0d (expect level %0d)", i, hiA[i], totalA, lvlA);
      if (lvlA == 0 && (hiA[i] * 1000 < totalA * 230 || hiA[i] * 1000 > totalA * 270)) begin
        $display("FAIL: A led[%0d] should be ~25%%, was %0d/%0d", i, hiA[i], totalA);
        fail = 1;
      end
      if (lvlA == 1 && (hiA[i] * 1000 < totalA * 730 || hiA[i] * 1000 > totalA * 770)) begin
        $display("FAIL: A led[%0d] should be ~75%%, was %0d/%0d", i, hiA[i], totalA);
        fail = 1;
      end
      if (lvlA == 2 && hiA[i] != totalA) begin
        $display("FAIL: A led[%0d] should be 100%%, was %0d/%0d", i, hiA[i], totalA);
        fail = 1;
      end
    end

    // Window B: level = (i mod 3 + 1) mod 3
    for (i = 0; i < 8; i = i + 1) begin
      lvlB = i - 3 * (i / 3);
      if (lvlB == 2) lvlB = 0; else lvlB = lvlB + 1;
      $display("B led[%0d] duty = %0d/%0d (expect level %0d)", i, hiB[i], totalB, lvlB);
      if (lvlB == 0 && (hiB[i] * 1000 < totalB * 230 || hiB[i] * 1000 > totalB * 270)) begin
        $display("FAIL: B led[%0d] should be ~25%%, was %0d/%0d", i, hiB[i], totalB);
        fail = 1;
      end
      if (lvlB == 1 && (hiB[i] * 1000 < totalB * 730 || hiB[i] * 1000 > totalB * 770)) begin
        $display("FAIL: B led[%0d] should be ~75%%, was %0d/%0d", i, hiB[i], totalB);
        fail = 1;
      end
      if (lvlB == 2 && hiB[i] != totalB) begin
        $display("FAIL: B led[%0d] should be 100%%, was %0d/%0d", i, hiB[i], totalB);
        fail = 1;
      end
    end

    if (fail == 1) begin
      $display("FAIL: duty-cycle checks failed");
      $finish;
    end
    $display("PASS: PWM cycle 25/75/100%% with 1 s step, start pattern correct");
    $finish;
  end

  // safety timeout (well past the 1.65 s of sampling)
  initial begin
    #4000000000;
    $display("FAIL: timeout");
    $finish;
  end

endmodule
