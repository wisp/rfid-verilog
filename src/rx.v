
// RX
// Copyright 2010 University of Washington
// License: http://creativecommons.org/licenses/by/3.0/
// 2008 Dan Yeager

// RX module converts EPC Class 1 Gen 2 time domain protocol
// to a serial binary data stream
// Sample bitout on bitclk positive edges.

// TR cal measurement provided for TX clock calibration.
// RT cal for debugging purposes and possibly adjustment
//   of oscillator frequency if necessary.

module rx (reset, clk, demodin, bitout, bitclk, rx_overflow_reset, trcal, rngbitout);

  input reset, clk, demodin;
  output bitout, bitclk, rx_overflow_reset, rngbitout;
  output [9:0] trcal;

  reg bitout, bitclk, rngbitout;
  reg [9:0] trcal, rtcal;

  // States
  parameter STATE_DELIMITER = 5'd0;
  parameter STATE_DATA0     = 5'd1;
  parameter STATE_RTCAL     = 5'd2;
  parameter STATE_TRCAL     = 5'd4;
  parameter STATE_BITS      = 5'd8;
  reg [4:0] commstate;
  
  parameter STATE_WAIT_DEMOD_LOW  = 4'd0;
  parameter STATE_WAIT_DEMOD_HIGH = 4'd1;
  parameter STATE_EVAL_BIT        = 4'd2;
  parameter STATE_RESET_COUNTER   = 4'd4;
  reg [3:0] evalstate;
  
  wire[9:0] count;
  wire clkb;
  assign clkb = ~clk;
  reg counterreset, counterenable;
  wire overflow;
  wire counter_reset_in;
  assign counter_reset_in = counterreset|reset;
  counter10 counter (clkb, counter_reset_in, counterenable, count, overflow);
  assign  rx_overflow_reset = overflow | ((commstate == STATE_BITS) && (count > rtcal));
  
always @ (posedge clk or posedge reset) begin
     
if( reset ) begin
    bitout <= 0;
    bitclk <= 0;
    rtcal  <= 10'd0;
    trcal  <= 10'd0;
    rngbitout     <= 0;
    counterreset  <= 0;
    counterenable <= 0;
    commstate <= STATE_DELIMITER;
    evalstate <= STATE_WAIT_DEMOD_LOW;

// process normal operation
end else begin

  if(evalstate == STATE_WAIT_DEMOD_LOW) begin
    if (demodin == 0) begin
      evalstate <= STATE_WAIT_DEMOD_HIGH;
      if(commstate != STATE_DELIMITER) counterenable <= 1;
      else                             counterenable <= 0;
      counterreset <= 0;
    end

  end else if(evalstate == STATE_WAIT_DEMOD_HIGH) begin
    if (demodin == 1) begin
      evalstate     <= STATE_EVAL_BIT;
      counterenable <= 1;
      counterreset  <= 0;
    end
    
  end else if(evalstate == STATE_EVAL_BIT) begin
    counterreset <= 1;
    evalstate    <= STATE_RESET_COUNTER;
    bitclk       <= 0;
    rngbitout    <= count[0];
    
    case(commstate)
      STATE_DELIMITER: begin
        commstate <= STATE_DATA0;
      end
      STATE_DATA0: begin
        commstate <= STATE_RTCAL;
      end
      STATE_RTCAL: begin
        rtcal <= count;
        commstate <= STATE_TRCAL;
      end
      STATE_TRCAL: begin
        if(count > rtcal) begin
          trcal  <= count;
        end else if(count[8:0] > rtcal[9:1]) begin // divide rtcal by 2
          bitout <= 1;
          commstate <= STATE_BITS;
        end else begin
          bitout <= 0;
          commstate <= STATE_BITS;
        end
      end
      STATE_BITS: begin
         if(count[8:0] > rtcal[9:1]) begin // data 1 (divide rtcal by 2)
           bitout <= 1;
         end else begin // data 0
           bitout <= 0;
         end
      end
      default: begin
        counterreset <= 0;
        commstate    <= 0;
      end
    endcase // case(mode)
    
    
  end else if(evalstate == STATE_RESET_COUNTER) begin
    if(commstate == STATE_BITS) begin
      bitclk <= 1;
    end
    counterreset <= 0;
    evalstate    <= STATE_WAIT_DEMOD_LOW;
      
  end else begin // unknown state, reset.
    evalstate <= 0;
  end
end // ~reset
end // always @ clk

endmodule // 

