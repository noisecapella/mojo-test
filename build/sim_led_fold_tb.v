// sim_led_fold_tb.v — sped-up check of the folding sequence.
`timescale 1ns/1ns
module tb;
  reg clk = 0;
  reg rst_n = 0;
  wire [7:0] led;
  integer i;
  reg [7:0] expected [0:7];

  led_fold #(.TICKS_PER_STEP(10)) dut(.clk(clk), .rst_n(rst_n), .led(led));

  always #5 clk = ~clk;

  initial begin
    expected[0] = 8'h01; expected[1] = 8'h80;   // 1, 8
    expected[2] = 8'h02; expected[3] = 8'h40;   // 2, 7
    expected[4] = 8'h04; expected[5] = 8'h20;   // 3, 6
    expected[6] = 8'h08; expected[7] = 8'h10;   // 4, 5
    repeat (5) @(negedge clk);
    rst_n = 1;
    // Step windows start on a posedge; sample at each window's CENTER:
    // t=100,200,300,... (45-55 ns away from every boundary).
    repeat (5) @(negedge clk);
    for (i = 0; i < 16; i = i + 1) begin
      if (led !== expected[i % 8]) begin
        $display("FAIL at step %0d: led=%b expected=%b", i, led, expected[i%8]);
        $finish;
      end
      repeat (10) @(negedge clk);
    end
    // verify exactly one LED on at every sample
    $display("PASS: folding sequence correct over 16 steps");
    $finish;
  end

  // one-hot check at every cycle: exactly one LED on
  integer j, n;
  always @(posedge clk) begin
    if (rst_n) begin
      n = 0;
      for (j = 0; j < 8; j = j + 1) n = n + led[j];
      if (n != 1) begin
        $display("FAIL: led=%b has %0d bits on", led, n); $finish;
      end
    end
  end
endmodule
