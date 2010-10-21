

// ADC Controller
// Copyright 2010 University of Washington
// License: http://creativecommons.org/licenses/by/3.0/
// 2008 Dan Yeager

// This module takes in the oscillator (target 8mhz +/- 50%) and divides it down into two signals
// The first is a trigger (roughly 200khz) which we use to trigger and adc reading
// The second is the adc clock, which we output to the adc upon getting a trigger.
// We also output oscillator divided by 8 for Helen's chopper amp, which divides
// again down to roughly 10khz.

// We also keep a shift register to collect the adc serial data output into a 8 bit bus,
// which is provided to the fifo.  The fifo clocks in the data when the adc sends
// a sync pulse.  The sync pulse also tells us to stop clocking the adc
// and wait for another trigger.


module adc_control (reset, osc_in, adc_data, adc_sync, trigger_ctl, adc_clk, adc_ctl, fifo_data, fifo_nextin, chopper_clock);

input  reset, osc_in, adc_data, adc_sync;
input [1:0] trigger_ctl;
output adc_clk, adc_ctl, chopper_clock, fifo_nextin;
output [7:0] fifo_data;


divby2 U_DIV1  (osc_in    , reset, clkby2);
divby2 U_DIV2  (clkby2    , reset, clkby4);
divby2 U_DIV3  (clkby4    , reset, clkby8);     // nominally 1 mhz
divby2 U_DIV4  (clkby8    , reset, clkby16);
divby2 U_DIV10 (clkby16   , reset, clkby32);
divby2 U_DIV5  (clkby32   , reset, clkby64);
divby2 U_DIV6  (clkby64   , reset, clkby128);
divby2 U_DIV7  (clkby128  , reset, clkby256);
divby2 U_DIV8  (clkby256  , reset, clkby512);
divby2 U_DIV9  (clkby512  , reset, clkby1000);  // nominally 1 khz
divby2 U_DIV11 (clkby1000 , reset, clkby2000); // 512 hz
divby2 U_DIV12 (clkby2000 , reset, clkby4000); // 256 hz
divby2 U_DIV13 (clkby4000 , reset, clkby8000);   // 128 hz
divby2 U_DIV14 (clkby8000 , reset, clkby16000);   // 64 hz

reg [7:0] fifo_data;

reg [1:0] counter;

reg adc_on, lasttrigger, trigger, fifo_nextin;
wire ctl_clk, start_adc;

assign ctl_clk   = clkby8;
assign adc_clk   = ctl_clk & adc_on;
assign start_adc = trigger ^ lasttrigger;
assign adc_ctl   = adc_on;

always @ (clkby2000 or clkby4000 or clkby8000 or clkby16000 or trigger_ctl) begin
  case(trigger_ctl)
    0: begin
      trigger = clkby2000;
    end
    1: begin
      trigger = clkby4000;
    end
    2: begin
      trigger = clkby8000;
    end
    3: begin
      trigger = clkby16000;
    end
  endcase
end

always @ (posedge adc_clk or posedge reset) begin
  if (reset) begin
    fifo_data[7:0] = 0;
  end else if (!adc_sync) begin
    fifo_data[7:1] <= fifo_data[6:0];
    fifo_data[0]   <= adc_data;
  end
end

reg send_fifo_nextin;

always @ (posedge ctl_clk or posedge reset) begin
  if (reset) begin
    adc_on      <= 0;
    fifo_nextin <= 0;
    counter     <= 0;
    send_fifo_nextin <= 0;
  end else if (!adc_on & !send_fifo_nextin) begin
    lasttrigger <= trigger;
    fifo_nextin <= 0;
    counter     <= 0;
    if (start_adc) adc_on <= 1;
  end else if (counter != 2'b11) begin
    counter <= counter + 1;
  end else if (adc_sync & !send_fifo_nextin) begin
    adc_on           <= 0;
    send_fifo_nextin <= 1;
  end else if(adc_sync)  begin
    fifo_nextin      <= 1;
    send_fifo_nextin <= 0;
  end
end

endmodule

