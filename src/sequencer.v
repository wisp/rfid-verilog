`timescale 1ns/1ns

// SEQUENCER: Top level TX module.
// Copyright 2010 University of Washington
// License: http://creativecommons.org/licenses/by/3.0/
// 2008 Dan Yeager

// Connects the TX module to its appropriate clock sources
// 0. !reset
// 1. Preamble is clocked until it's done flag is raised.
// 2. Data is clocked until it's done flag is raised.
// 3. If "docrc" input, CRC module is clocked until it's done flag is raised.
// 4. Dummy "1" bit is clocked out and !txenable signal is sent to TX module.

module sequencer (reset, rtcal_expired, oscclk, m, dr, docrc, trext, trcal, 
                  databitsrc, datadone, dataclk, modout, txsetupdone, txdone);

input reset, rtcal_expired, trext, dr, docrc, databitsrc, datadone, oscclk;
input [9:0] trcal;
input [1:0] m;
output dataclk, modout, txsetupdone, txdone;

reg done;
reg tx_stop;
wire txsetupdone, txdone;

// module connections
wire txclk, txbitclk;
wire violation;
wire crcdone, preambledone; // datadone is an input
wire crcinclk, crcbitin;
wire txbitsrc, crcbitsrc, preamblebitsrc; // databitsrc is an input

wire crcoutclk, preambleclk, dataclk;

// MODULES! :)
txclkdivide U_DIV (reset, oscclk, trcal, dr, txclk);
tx          U_TX0 (reset, rtcal_expired, tx_stop, 
                   txclk, txbitsrc, violation, m, 
                   modout, txbitclk, txsetupdone, txdone);
preamble    U_PRE (reset, preambleclk, m, trext, preamblebitsrc, violation, preambledone);
crc16       U_CRC (reset, crcinclk, crcbitin, crcoutclk, crcbitsrc, crcdone);

// state machine variables
reg [1:0] state;
parameter STATE_PRE  = 2'd0;
parameter STATE_DATA = 2'd1;
parameter STATE_CRC  = 2'd2;
parameter STATE_END  = 2'd3;

// mux the bit source for the tx module
wire [3:0] bitsrc;
assign bitsrc[0] = preamblebitsrc;
assign bitsrc[1] = databitsrc;
assign bitsrc[2] = crcbitsrc;
assign bitsrc[3] = 1;
assign txbitsrc  = bitsrc[state];

reg bit_transition;

// crc gets the data bits too
assign crcbitin  = databitsrc;
assign crcinclk  = txbitclk & (state == STATE_DATA) & docrc;

// send the tx module bit clock to the appropriate module
// Note: Preamble and Data clocks overlap at handoffs
// because these modules need 1 clock for setup. 
assign preambleclk = txbitclk  && (state == STATE_PRE) && (!done);
assign dataclk = txbitclk && (state == STATE_DATA ||(state == STATE_PRE && bit_transition && !done));
assign crcoutclk = txbitclk && (state == STATE_CRC); // crc doesn't need extra pre data clk edge.

always @ (negedge txbitclk or posedge reset) begin
  if (reset) begin
    state      <= 0;
    done       <= 0;
    bit_transition <= 0;
    tx_stop    <= 0;
    
  end else if (done) begin
    // don't do anything after we are done
    // wait for controller to reset us.
  end else if (state == STATE_PRE) begin
    if (bit_transition) begin
      state      <= STATE_DATA;
      bit_transition <= 0;
    end else if (preambledone) begin
      bit_transition <= 1;
    end
    
  end else if (state == STATE_DATA) begin
    if (bit_transition) begin
      if (datadone && docrc) state <= STATE_CRC;
      else if (datadone)     state <= STATE_END;
      bit_transition <= 0;
    end else if (datadone) begin
      bit_transition <= 1;
    end
    
  end else if (state == STATE_CRC) begin
    if (bit_transition) begin
      state      <= STATE_END;
      bit_transition <= 0;
    end else if (crcdone) begin
      bit_transition <= 1;
    end
    
  end else if (state == STATE_END) begin
    if (txdone) begin
      state <= STATE_PRE;
      done  <= 1;
    end else begin
      tx_stop <= 1;
    end
  end // no else required because states are exhaustive
  
end


endmodule
