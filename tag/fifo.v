
// FIFO
// Copyright 2010 University of Washington
// License: http://creativecommons.org/licenses/by/3.0/
// 2008 Dan Yeager



module fifo (reset, 
             data_in, data_out, 
             next_in, next_out, 
             empty, full, 
             firstbyte, restart);

parameter WIDTH   = 8;
parameter DEPTH   = 64;
parameter CONTROL = 6; // this must address depth numbers

input  reset, next_in, next_out;
output empty, full;
input  firstbyte, restart;
input  [(WIDTH-1):0] data_in;
output [(WIDTH-1):0] data_out;

reg [(WIDTH-1):0] data [(DEPTH-1):0];

reg [(CONTROL-1):0] write_addr;
reg [(CONTROL-1):0] read_addr;
reg [(CONTROL-1):0] current_addr;

wire [(CONTROL-1):0] full_compare;
assign full_compare = (read_addr == 0) ? (DEPTH-1) : read_addr - 1;

assign data_out = empty ? 0 : data[current_addr];
assign empty = (write_addr == current_addr);
assign full  = (write_addr == full_compare);

always @ (posedge next_in or posedge reset) begin
  if (reset) begin
    write_addr <= 0;
  end else begin
    if(!full) begin
      write_addr       <= write_addr + 1;
      data[write_addr] <= data_in;
    end
  end
end

always @ (posedge next_out or posedge reset) begin
  if (reset) begin
    read_addr    <= 0;
    current_addr <= 0;
  end else begin
    if (firstbyte) begin
       if (restart) current_addr <= read_addr;
       else         read_addr    <= current_addr;
    end else if (!empty) begin
      current_addr <= current_addr + 1;
    end
  end  
end

endmodule

