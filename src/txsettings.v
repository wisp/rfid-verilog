

// Transmit settings
// Copyright 2010 University of Washington
// License: http://creativecommons.org/licenses/by/3.0/
// 2008 Dan Yeager

// This stores tx settings
// Settings are refreshed from a query command

module txsettings(reset, trcal_in,  m_in,  dr_in,  trext_in, querycomplete,
                         trcal_out, m_out, dr_out, trext_out);

input reset, dr_in, trext_in, querycomplete;
input [9:0] trcal_in;
input [1:0] m_in;

output dr_out, trext_out;
output [9:0] trcal_out;
output [1:0] m_out;

reg       dr_out, trext_out;
reg [9:0] trcal_out;
reg [1:0] m_out;


  always @ (posedge querycomplete or posedge reset) begin
	if (reset) begin
      dr_out    <= 0;
      trext_out <= 0;
      trcal_out <= 0;
      m_out     <= 0;
	end	else begin
      dr_out    <= dr_in;
      trext_out <= trext_in;
      trcal_out <= trcal_in;
      m_out     <= m_in;
	end
  end
endmodule
