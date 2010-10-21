`timescale 1ns/1ns

// Divide by 2
// Copyright 2010 University of Washington
// License: http://creativecommons.org/licenses/by/3.0/
// 2008 Dan Yeager

module divby2 (in, reset, out);
output out;
input in, reset;

reg out;

always @ (posedge in or posedge reset) begin
  if (reset) begin
    out <= 0;
  end else begin
    out <= ~out;
  end
end

endmodule

