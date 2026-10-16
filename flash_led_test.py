#!/usr/bin/env python3
"""Flash a test bitstream to a Mojo V3 to blink the LEDs.

Protocol (from mojo-arduino/mojo_loader.ino):
  - AVR firmware resets the FPGA (PROGRAM low, INIT high) and waits for a
    command. It is triggered into loader mode by 5 DTR falling edges within
    250 ms (lineStateEvent in the firmware).
  - host sends 'R' (load to RAM) -> AVR echoes 'R'
  - host sends 4-byte size -> AVR echoes 'O'
      NOTE: the firmware accumulates the size as
          transferSize |= (bt << (byteCount++ * 8))
      i.e. FIRST byte received is the LEAST significant -> the size MUST be
      sent LITTLE-ENDIAN. (Sending big-endian makes the AVR wait for a
      bogus ~358 MB transfer; the FPGA still configures because bytes are
      clocked in as they arrive, but the final 'D' ack never comes.)
  - host sends the bitstream bytes -> AVR echoes 'D' when done
  - AVR then clocks the raw data into the Spartan-6 in single (master serial)
    mode over the 8-bit FPGA data bus + CCLK.
"""
import argparse
import sys
import time

import serial

BAUD = 9600  # nominal; the 32U4's native USB CDC ignores the baud rate


def pulse_loader_trigger(ser: serial.Serial) -> None:
    """Send 5 clean DTR falling edges inside the firmware's 250 ms window."""
    # Start from a known-HIGH state so every pulse below produces a
    # falling edge (if DTR is already low, a 'low' set is a no-op and we
    # would only deliver 4 edges -- not enough to trigger the loader).
    ser.dtr = True
    time.sleep(0.05)
    for _ in range(5):
        ser.dtr = False
        time.sleep(0.02)
        ser.dtr = True
        time.sleep(0.02)
    ser.flushInput()
    ser.flushOutput()
    time.sleep(0.3)  # give the AVR time to enter loader mode


def flash(port: str, bitstream: bytes) -> None:
    ser = serial.Serial(port, BAUD, timeout=5)
    try:
        # Trigger the AVR loader (it resets the FPGA while doing so).
        # Retry a couple of times in case a trigger pulse was missed.
        resp = b""
        for attempt in range(1, 4):
            pulse_loader_trigger(ser)
            ser.write(b"R")
            resp = ser.read(1)
            print(f"after 'R' (attempt {attempt}):", resp)
            if resp == b"R":
                break
        if resp != b"R":
            sys.exit("Mojo did not answer 'R' -- check the port / USB connection")

        size = len(bitstream)
        ser.write(size.to_bytes(4, "little"))  # firmware expects little-endian
        resp = ser.read(1)
        print("after size:", resp)
        if resp != b"O":
            sys.exit("Mojo did not acknowledge the transfer size")

        print(f"sending {size} bytes (actual CDC rate unknown; this can "
              f"take a minute or two)...")
        t0 = time.time()
        ser.write(bitstream)
        resp = ser.read(1)
        dt = time.time() - t0
        print(f"transfer done in {dt:.1f} s; final response:", resp)
        if resp != b"D":
            print("WARNING: no 'D' ack -- the bitstream may not have loaded.")
            sys.exit(1)
        print("OK: Mojo V3 reports the bitstream was loaded. Check the LEDs!")
    finally:
        ser.close()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("-p", "--port", default="/dev/ttyACM0")
    ap.add_argument("-b", "--bitstream", required=True, help="path to the .bit file")
    args = ap.parse_args()
    try:
        with open(args.bitstream, "rb") as f:
            data = f.read()
    except OSError as e:
        sys.exit(f"cannot read bitstream file {args.bitstream}: {e}")
    print(f"bitstream: {args.bitstream} ({len(data)} bytes, "
          f"magic={data[:4].hex() if len(data) >= 4 else 'n/a'})")
    flash(args.port, data)


if __name__ == "__main__":
    main()
