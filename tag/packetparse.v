`timescale 1ns/1ns

// PACKET PARSE 
// Copyright 2010 University of Washington
// License: http://creativecommons.org/licenses/by/3.0/
// 2008 Dan Yeager

// This module parses the received packets.
// Currently it supports:

// Handle checking for ack, req_rn, read, write (not kill).
// This tells us if the reader requested handle matches our own.
// The last bit for ACK is tricky because the controller wants to know
// as soon as the last bit clock edge occurs if the handle passed and
// ack doesn't have any bits after the requested handle to clock this module.
// So, there is a special case for the last bit of ack.

// todo: EBV parsing

// todo: PTR parsing for read and write.

// todo: Data decoding for write.

module packetparse(reset, bitin, bitinclk, packettype, rx_q, rx_updn,
                   currenthandle, currentrn, handlematch,
                   readwritebank, readwriteptr, readwords,
                   writedataout, writedataclk );
input reset, bitin, bitinclk;
input [8:0]  packettype;

input [15:0] currenthandle;
input [15:0] currentrn;
output handlematch;
output [3:0] rx_q;
output [2:0] rx_updn;

output [1:0] readwritebank;
output [7:0] readwriteptr;
output [7:0] readwords;
output writedataout, writedataclk;


reg [3:0] handlebitcounter;
reg [5:0] bitincounter;
reg       handlematch;
reg       matchfailed;

reg [3:0] rx_q;
reg [2:0] rx_updn;
reg [1:0] readwritebank;
reg [7:0] readwriteptr;
reg [7:0] readwords;
reg       writedataen;
reg       writedataengated;
reg       bankdone;
reg       ptrdone;
reg       ebvdone;
reg       datadone;

reg writedataout;
wire writedataclk;
assign writedataclk = bitinclk & writedataengated;

/*
// check functionality by intentionally breaking with fake rn
wire [15:0] fixedrn;
assign fixedrn = 16'h0001;
wire thisbitmatches;
assign thisbitmatches = (bitin == fixedrn[~handlebitcounter]);
assign bit1matches    = (bitin == fixedrn[14]);
*/

// real rn
wire thisbitmatches;
assign thisbitmatches = (bitin == currenthandle[~handlebitcounter]);

wire lastbit;
assign lastbit  = (handlebitcounter == 15);

wire handlematchout;
assign handlematchout = handlematch | 
       ((handlebitcounter == 15) && packettype[1] && thisbitmatches);

  parameter ACK        = 9'b000000010;
  parameter QUERY      = 9'b000000100;
  parameter QUERYADJ   = 9'b000001000;
  parameter REQRN      = 9'b001000000;
  parameter READ       = 9'b010000000;
  parameter WRITE      = 9'b100000000;

// gate the write-data clk en to the negative edges
// so it doesn't glitch.
always @ (negedge bitinclk or posedge reset) begin
  if (reset) begin
    writedataengated <= 0;
  end else begin
    writedataengated <= writedataen;
  end
end

always @ (posedge bitinclk or posedge reset) begin
  if (reset) begin
    handlebitcounter <= 0;
    bitincounter     <= 0;
    handlematch      <= 0;
    matchfailed      <= 0;

    bankdone         <= 0;
    ptrdone          <= 0;
    ebvdone          <= 0;
    datadone         <= 0;

    writedataen      <= 0;
    writedataout     <= 0;
    
    rx_q             <= 4'd0;
    rx_updn          <= 3'd0;

    readwritebank    <= 2'd0;
    readwriteptr     <= 8'd0;
    readwords        <= 8'd0;

// check for read, write, req_rn, ack
  end else begin
    case(packettype)
      QUERY: begin
        if (!ptrdone) begin
          if (bitincounter >= 8) begin  // ptr done
            ptrdone      <= 1;
            bitincounter <= 0;
          end else begin
            bitincounter <= bitincounter + 6'd1;
          end
        // read the 4 q bits
        end else if (bitincounter == 0) begin
          bitincounter <= bitincounter + 6'd1;
          rx_q[3] <= bitin;
        end else if (bitincounter == 1) begin
          bitincounter <= bitincounter + 6'd1;
          rx_q[2] <= bitin;
        end else if (bitincounter == 2) begin
          bitincounter <= bitincounter + 6'd1;
          rx_q[1] <= bitin;
        end else if (bitincounter == 3) begin
          bitincounter <= bitincounter + 6'd1;
          rx_q[0] <= bitin;
        end
      end
      QUERYADJ: begin
        if (!ptrdone) begin
          if (bitincounter >= 1) begin  // ptr done
            ptrdone      <= 1;
            bitincounter <= 0;
          end else begin
            bitincounter <= bitincounter + 6'd1;
          end
        // read the 3 up/dn bits
        end else if (bitincounter == 0) begin
          bitincounter <= bitincounter + 6'd1;
          rx_updn[2] <= bitin;
        end else if (bitincounter == 1) begin
          bitincounter <= bitincounter + 6'd1;
          rx_updn[1] <= bitin;
        end else if (bitincounter == 2) begin
          bitincounter <= bitincounter + 6'd1;
          rx_updn[0] <= bitin;
        end
      end
      ACK: begin
        if (!matchfailed && !lastbit && thisbitmatches) begin
          handlebitcounter <= handlebitcounter + 4'd1;
        // check the last bit of the handle
        end else if (!matchfailed && lastbit && thisbitmatches) begin
          handlematch <= 1;
        end else if (!handlematch) begin
          matchfailed <= 1;
        end
      end
      REQRN: begin
        if (!matchfailed && !lastbit && thisbitmatches) begin
          handlebitcounter <= handlebitcounter + 4'd1;
        // check the last bit of the handle
        end else if (!matchfailed && lastbit && thisbitmatches) begin
          handlematch <= 1;
        end else if (!handlematch) begin
          matchfailed <= 1;
        end
      end
      READ: begin
        // read: we start comparing after ebv is done and words is done.
        if (!bankdone && (bitincounter == 0)) begin
          bitincounter <= bitincounter + 6'd1;
          readwritebank[1] <= bitin;
        end else if (!bankdone && (bitincounter >= 1)) begin
          bankdone <= 1;
          bitincounter <= 0;
          readwritebank[0] <= bitin;

        // if bitctr==0, see if the ebv is done
        end else if (!ebvdone && (bitincounter == 0)) begin
          if (!bitin) begin  // last ebv byte indicator
            ebvdone        <= 1;
            bitincounter   <= 1;
          end else begin
            bitincounter <= bitincounter + 6'd1;
          end
        // wait out the ebv if its not done
        end else if (!ebvdone && (bitincounter < 7)) begin
          bitincounter <= bitincounter + 6'd1;
        // restart to the next ebv byte
        end else if (!ebvdone && (bitincounter >= 7)) begin
          bitincounter <= 0;

        // read in the last 7 ebv byte bits as ptr
        end else if (!ptrdone) begin
          if (bitincounter >= 7) begin  // ptr done
            ptrdone      <= 1;
            bitincounter <= 0;
          end else begin
            bitincounter <= bitincounter + 6'd1;
          end
          readwriteptr[~bitincounter[2:0]] <= bitin;

        // read the 8 word bits
        end else if (ptrdone && (bitincounter < 8)) begin
          bitincounter <= bitincounter + 6'd1;
          readwords[~bitincounter[2:0]] <= bitin;

        // check the first and middle bits of the handle
        end else if (!matchfailed && !lastbit && thisbitmatches) begin
          handlebitcounter <= handlebitcounter + 4'd1;
        // check the last bit
        end else if (!matchfailed && lastbit && thisbitmatches) begin
          handlematch <= 1;
        end else if (!handlematch) begin
          matchfailed <= 1;
        end
      end
      WRITE: begin
        // write: we start comparing after ebv is done and data is done.
        if (!bankdone && (bitincounter == 0)) begin
          bitincounter <= bitincounter + 6'd1;
          readwritebank[1] <= bitin;
        end else if (!bankdone && (bitincounter >= 1)) begin
          bankdone <= 1;
          bitincounter <= 0;
          readwritebank[0] <= bitin;

        // if bitctr==0, see if the ebv is done
        end else if (!ebvdone && (bitincounter == 0)) begin
          if (!bitin) begin  // last ebv byte indicator
            ebvdone      <= 1;
            bitincounter <= 1;
          end else begin
            bitincounter <= bitincounter + 6'd1;
          end
        // wait out the ebv if its not done
        end else if (!ebvdone && (bitincounter < 7)) begin
          bitincounter <= bitincounter + 6'd1;
        // restart to the next ebv byte
        end else if (!ebvdone && (bitincounter >= 7)) begin
          bitincounter <= 0;

        // read in the last 7 ebv byte bits as ptr
        end else if (!ptrdone) begin
          if (bitincounter >= 7) begin  // ptr done
            ptrdone      <= 1;
            bitincounter <= 0;
            writedataen  <= 1;
          end else begin
            bitincounter <= bitincounter + 6'd1;
          end
          readwriteptr[~bitincounter[2:0]] <= bitin;

        // get the 16 data bits
        end else if (!datadone) begin
          if (bitincounter >= 15) begin  // data done
            datadone     <= 1;
            bitincounter <= 0;
            writedataen  <= 0;
          end else begin
            bitincounter <= bitincounter + 6'd1;
          end
          writedataout <= bitin ^ currentrn[~bitincounter[3:0]];

        // check the first and middle bits of the handle
        end else if (!matchfailed && !lastbit && thisbitmatches) begin
          handlebitcounter <= handlebitcounter + 4'd1;
        // check the last bit
        end else if (!matchfailed && lastbit && thisbitmatches) begin
          handlematch <= 1;
        end else if (!handlematch) begin
          matchfailed <= 1;
        end else begin
          writedataen <= 0;
        end
      end
      default begin // do nothing. 
        // either cmd is not yet received or we don't need to check handle.
      end
    endcase
  end // ~reset
end // always

endmodule

