`timescale 1ns/1ns

// READ: Tag response to a 'read' command.
// Copyright 2010 University of Washington
// License: http://creativecommons.org/licenses/by/3.0/
// 2008 Dan Yeager

// readbit* = talking to tx module

// read_sample_* = talking to external source (adc or msp430)
//                 which supplies sample data to be transmitted.

// handle = current handle from random number generator

module read(reset, readbitclk, readbitout, readbitdone, 
           read_sample_ctl, read_sample_clk, read_sample_datain, 
           handle);
input  reset, readbitclk;
output readbitout, readbitdone;
input  read_sample_datain;
output read_sample_ctl, read_sample_clk;
input [15:0] handle;
  
wire [32:0] packet;
assign packet[32]    = 1'b0;
assign packet[31:16] = 16'h0000;
assign packet[15:0]  = handle[15:0];

reg [5:0] bitoutcounter;
reg read_sample_ctl;

wire read_sample_clk, readbitout, readbitdone;

assign read_sample_clk = readbitclk & (bitoutcounter > 15);
assign readbitout = (bitoutcounter!=32 && bitoutcounter>15) ? read_sample_datain : packet[bitoutcounter];
assign readbitdone = (bitoutcounter == 0);
reg    initialized;

always @ (posedge readbitclk or posedge reset) begin
  if (reset) begin
    bitoutcounter   <= 0;
    initialized     <= 0;
    read_sample_ctl <= 0;
  end else if (!initialized) begin
    initialized     <= 1;
    read_sample_ctl <= 1;
    bitoutcounter   <= 32;
  end else if (!readbitdone) begin
    bitoutcounter <= bitoutcounter - 4'd1;
    if (bitoutcounter >= 15) read_sample_ctl <= 1;
    else                     read_sample_ctl <= 0;
  end else begin
    read_sample_ctl<= 0;
  end // ~reset
end // always

endmodule

