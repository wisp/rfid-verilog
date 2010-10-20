
// FGPA Test of TOP functional block.
// Copyright 2010 University of Washington
// License: http://creativecommons.org/licenses/by/3.0/
// 2008 Dan Yeager

// Maps FPGA IO onto RFID tag (top.v)

module toptest(LEDR, LEDG, GPIO_0, KEY, SW, EXT_CLOCK,
               HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7);
  input  [3:0]  KEY;
  inout  [35:0] GPIO_0;
  output [17:0] LEDR;
  output [8:0]  LEDG;
  input         EXT_CLOCK;
  input  [17:0] SW;
  output [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7;

  // basic tag IO
  wire clk, reset, demodin, modout;

/*
  assign HEX0 = 7'd0;
  assign HEX1 = 7'd0;
  assign HEX2 = 7'd0;
*/
  assign HEX3 = 7'd0;
  assign HEX4 = 7'd0;
  assign HEX5 = 7'd0;
  assign HEX6 = 7'd0;
  assign HEX7 = 7'd0;

  // Functionality control
  wire use_uid, use_q, comm_enable;

  // write data connections
  wire writedataout, writedataclk;

  // EPC ID source
  wire [7:0] uid_byte_in;
  wire [3:0] uid_addr_out;
  wire       uid_clk_out;

  // debugging connections
  wire debug_clk, debug_out;

  assign debug_clk = SW[5];

  assign GPIO_0[35:3] = 33'bZ;
  
  // Basic tag connections
  assign clk         =  EXT_CLOCK;
  assign reset       = ~KEY[1];
  assign demodin     =  GPIO_0[3];

  assign use_q       = SW[4];
  assign comm_enable = SW[3];
  assign use_uid     = SW[2];
  assign uid_byte_in = SW[17:10];
    

  // red LED debugging connections
  assign LEDR[17] = reset;  // assign reset to LED for sanity check.
  assign LEDR[16] = 0;
  assign LEDR[15] = 0;
  assign LEDR[14] = 0;
  assign LEDR[13] = 0;
  assign LEDR[12] = 0;
  assign LEDR[11] = 0;
  assign LEDR[10] = 0;
  assign LEDR[9]  = 0;
  assign LEDR[8]  = 0;
  assign LEDR[7:2] = 0;

  assign LEDG[8:0]   = 0;

  assign GPIO_0[2] = modout;
  assign GPIO_0[1] = debug_clk;
  assign GPIO_0[0] = debug_out;
/*
sevenseg U_SEG0 (HEX0,readwritebank_reg);
sevenseg U_SEG1 (HEX1,readwriteptr_reg);
sevenseg U_SEG2 (HEX2,readwords_reg);
sevenseg U_SEG3 (HEX3,4'd3);
sevenseg U_SEG4 (HEX4,slotcounter[3:0]);
sevenseg U_SEG5 (HEX5,slotcounter[7:4]);
sevenseg U_SEG6 (HEX6,slotcounter[11:8]);
sevenseg U_SEG7 (HEX7,{1'b0,slotcounter[14:12]});
*/

wire [7:0] data_in;
wire [7:0] fifo_datain;
wire       next_in, fifo_nextout;
wire empty, full, fifo_start, fifo_repeat;

assign LEDR[0] = full;
assign LEDR[1] = empty;

assign data_in = SW[17:10];
assign next_in = SW[9];


parameter CONTROL = 4; // this must address depth numbers

wire [(CONTROL-1):0] write_addr;
wire [(CONTROL-1):0] read_addr;
wire [(CONTROL-1):0] current_addr;

sevenseg U_SEG0 (HEX0, write_addr);
sevenseg U_SEG1 (HEX1, read_addr);
sevenseg U_SEG2 (HEX2, current_addr);

top U_TOP (reset, clk, demodin, modout, // regular IO
           fifo_nextout, fifo_datain, fifo_start, fifo_repeat,    // fifo connections
           uid_byte_in, uid_addr_out, uid_clk_out,
           writedataout, writedataclk, 
           use_uid, use_q, comm_enable,
           debug_clk, debug_out);

fifo U_FIFO (reset, 
             data_in, fifo_datain, 
             next_in, fifo_nextout, 
             empty, full, 
             fifo_start, fifo_repeat, write_addr, read_addr, current_addr);

endmodule
