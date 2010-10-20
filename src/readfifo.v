`timescale 1ns/1ns

// READ FIFO: Tag response to a 'read' command.
// Copyright 2010 University of Washington
// License: http://creativecommons.org/licenses/by/3.0/
// 2008 Dan Yeager

// readbit* = talking to tx module

// fifo_nextout -> tells the fifo to clock out the next read address
// fifo_start   -> tells the fifo that this is the first byte of the packet.
//                 the fifo will either restart the read pointer
//                 to the value at the last fifo_start or it will continue counting
//                 and update the starting pointer to the current address.
// fifo_datain  -> fifo output byte at the current address

// handle = current handle from random number generator

module readfifo(reset, readbitclk, readbitout, readbitdone, 
                fifo_nextout, fifo_datain, fifo_start,
                handle, readwords);
input  reset, readbitclk;
output readbitout, readbitdone;

output       fifo_start;
output       fifo_nextout;
input [7:0]  fifo_datain;

input [15:0] handle;
input [7:0]  readwords; // number of words to read

wire [8:0] readbytes;
assign     readbytes = (readwords == 0) ? 10 : (readwords << 1);

reg [8:0] bytecounter;
reg [3:0] bitoutcounter;
reg fifo_nextout;
reg fifo_start;

wire readbitout, readbitdone, bytecounterdone;

reg initialized, send_handle;
assign readbitout      = (bytecounter == 0) ? 1'b0 : (send_handle ? handle[bitoutcounter] : fifo_datain[bitoutcounter[2:0]]);

assign bytecounterdone = (bytecounter >= readbytes && bitoutcounter == 0) || send_handle;
assign readbitdone     = (send_handle && bitoutcounter == 0);

always @ (posedge readbitclk or posedge reset) begin
  if (reset) begin
    bitoutcounter   <= 0;
    initialized     <= 0;
    bytecounter     <= 0;
    send_handle     <= 0;
    fifo_nextout    <= 0;
    fifo_start      <= 0;
  end else if (!initialized) begin
    initialized     <= 1;
    fifo_start      <= 1;
  end else if (bytecounter == 0) begin
    bytecounter     <= 1;
    bitoutcounter   <= 4'd7;
    // this clock will restart fifo to last packet or do nothing:
    fifo_nextout    <= 1;
  end else if (!send_handle) begin
    fifo_start      <= 0;
    if (bytecounterdone) begin
      send_handle   <= 1;
      bitoutcounter <= 4'd15;
      fifo_nextout  <= 1;
    end else if (bitoutcounter == 0) begin
      bitoutcounter <= 4'd7;
      bytecounter   <= bytecounter + 9'b1;
      fifo_nextout  <= 1;
    end else begin
      bitoutcounter <= bitoutcounter - 4'd1;
      fifo_nextout  <= 0;
    end
  end else if (!readbitdone) begin
    bitoutcounter <= bitoutcounter - 4'd1;
    fifo_nextout  <= 0;
  end else begin
    
  end // ~reset
end
endmodule

