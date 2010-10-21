`timescale 1ns/1ns

// Tx Clock Divide
// Copyright 2010 University of Washington
// License: http://creativecommons.org/licenses/by/3.0/
// 2008 Dan Yeager

// dr == 0 => 8
// dr == 1 => 64/3

// txclk = oscclk / ((dr) ? ((13+trcal+trcal+trcal)>>7) : (4+trcal)>>4))

// static offsets of 13 and 4 center the rounding error on 0%

// tx only uses positive edges, so we don't need to be symmetric
// this allows arbitrary divide ratios.

module txclkdivide(reset, oscclk, trcal, dr, txclk);
input reset, oscclk, dr;
input [9:0] trcal; // max: 1023
output txclk;
reg    txclk;
reg  [6:0]  counter;

// trcal3 = 3 * trcal
wire [10:0] trcal2;
assign trcal2[10:1] = trcal;
assign trcal2[0] = 1'b0;
wire [11:0] trcal3;
assign trcal3 = trcal2 + trcal;

wire [11:0] dr1numerator;
assign      dr1numerator = (11'd75+trcal3); // max: 12 bits
wire [11:0] dr0numerator;
assign      dr0numerator = (11'd4+trcal); // max: 11 bits

wire [6:0]  tempdivider;
assign      tempdivider = dr ? ({1'b0, dr1numerator[11:7]}) : (dr0numerator[9:4]); // max dr0 = 64, dr1 = 24 -> 7 bits.
wire [6:0]  divider;
assign      divider = (tempdivider >= 7'd2) ? tempdivider : 7'd2;

always @ (posedge oscclk or posedge reset) begin
  if (reset) begin
    txclk   = 0;
    counter = 0;
  end else if (counter >= (divider-1)) begin
    txclk   = 1;
    counter = 0;
  end else if (counter == ((divider-1) >> 1)) begin
    counter = counter + 7'd1;
    txclk   = 0;
  end else begin
    counter = counter + 7'd1;
  end // ~reset
end // always

endmodule
