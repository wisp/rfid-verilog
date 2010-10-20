`timescale 1ns/1ns

// EPC: generate tag response to an ACK.
// Copyright 2010 University of Washington
// License: http://creativecommons.org/licenses/by/3.0/
// 2008 Dan Yeager

//  2 byte  PC: 0x30, 0x00
// 12 byte EPC: 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55

module epc(reset, epcclk, epcbitout, epcdone);
input reset, epcclk;
output epcbitout, epcdone;

wire [111:0] epc;
assign epc = 112'h3000aabbccddeeff012345678910;

reg [6:0] bitoutcounter;
assign epcbitout = epc[bitoutcounter];
assign epcdone = (bitoutcounter == 0);
reg    initialized;

always @ (posedge epcclk or posedge reset) begin
  if (reset) begin
    bitoutcounter <= 0;
    initialized   <= 0;
  end else if (!initialized) begin
    bitoutcounter <= 111;
    initialized <= 1;
  end else if (!epcdone) begin
    bitoutcounter <= bitoutcounter - 7'd1;
  end else begin
  end // ~reset
end // always

endmodule

