`timescale 1ns/1ps
module tb;
  reg clk = 0;
  reg rst_n = 1;
  wire [7:0] led;
  always #10 clk = ~clk; // 50 MHz (board clock)
  // (100 ns delay per loop iter)

  led_test dut(.clk(clk), .rst_n(rst_n), .led(led));

  integer i;
  reg [7:0] prev;
  integer changes;

  initial begin
    prev = 8'hxx;
    changes = 0;
    // 50 MHz board clock. Run 10 s, sample every 2.6 ms (~one chase step).
    // Chase step = 2.5 ms (expect ~1200 changes), blink toggle = 1 s.
    for (i = 0; i < 3846; i = i + 1) begin // 3846 * 2.6ms ~ 10 s
      #2600000; // 2.6 ms at 1ns scale (~one chase step)
      if (led !== prev) begin
        $display("t=%0t  led=%b", $time, led);
        prev = led;
        changes = changes + 1;
      end
    end
    $display("Total changes observed: %0d", changes);
    if (changes > 5) $display("PASS: LEDs are changing");
    else $display("FAIL: LEDs not changing");
    $finish;
  end
endmodule
