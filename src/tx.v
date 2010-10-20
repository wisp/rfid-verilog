`timescale 1ns/1ns

// TX
// Copyright 2010 University of Washington
// License: http://creativecommons.org/licenses/by/3.0/
// 2008 Dan Yeager

// TX module converts a binary serial data stream to 
//   a time domain EPC Class 1 Gen 2 modulated waveform.
// This is intended to connect to the tag modulator.
// The clkin should correspond to 2x the link frequency "LF"
//   as described in the EPC specification.
// Violation is driven by the preamble module to facilitate
//   the modulation rule violations in the preamble.
// This module generates a clock for the modules which
//   are to supply data.

// setupdone tells the controller that we have received the 
// count > rtcal signal ("rtcal_expired") so it can turn off the rx module

// txdoneout tells the sequencer that we are totally done sending bits
// and it can turn off the tx module safely without corrupting the transmission

// rtcal_expired: we need to wait for MAX(trcal, 10*Tpri) to transmit.

// txstopin: this is for stopping gracefully. Sequencer sends us a signal to stop
// and we should stop after our current bit is finished and then set the txdoneout flag high
// so the sequencer knows we are done.

// bitinclk and bitin are the preamble, data and crc, serialized by the sequencer.

// m sets the miller modulation, and violationin is used by the preamble to generate
// the protocol violations as per the epc spec.

// bitout goes to the modulator.

module tx (reset, rtcal_expired, txstopin, 
           clkin, bitin, violationin, m, 
           bitout, bitinclk, setupdone, txdoneout);

  input reset, rtcal_expired, txstopin, clkin, bitin, violationin;
  input [1:0] m;
  output bitout, bitinclk, setupdone, txdoneout;
  reg bitout;
  wire bitinclk;

  // after rtcal_expired and 10 Tpri, setupdone = 1 and regular operation commences
  // txstop gets clocked in with bits, but we wait until bit is finished to shut off modout.
  reg setupdone, txstop, txdone, txdoneout;

reg bitoutenable;
  
  reg currentbit, previousbit, phaseinvert;
  reg currentviolation;
  
  wire   millerphaseinvert;
  assign millerphaseinvert = phaseinvert ^ (setupdone & !(currentbit | previousbit) & !currentviolation);
  
  wire   nextphaseinvert;
  assign nextphaseinvert = phaseinvert ^ (currentbit & setupdone);
  
  reg clkphase;
  wire evalclk, evalclkby2;
  wire [3:0] clocks;
  
  wire   tempbit, bitgenclk, nextbitout;
  assign bitgenclk = ~clocks[0];
  assign tempbit = (bitgenclk ^ phaseinvert) & setupdone & !txdone;
  assign nextbitout = (m == 0) ? (tempbit & !currentviolation) : tempbit; // fm0 violation opportunity
  
  wire divreset;
  assign divreset = reset | !setupdone;

  divby2 U_DIV1 (clkin    , divreset, clocks[0]);
  divby2 U_DIV2 (clkin    , divreset, clocks[1]);
  divby2 U_DIV3 (clocks[1], divreset, clocks[2]);
  divby2 U_DIV4 (clocks[2], divreset, clocks[3]);
  
  // Bits are evaluated every eval clock
  assign evalclk = clocks[m] & setupdone;
  
  // fm0 clocks data at the output frequency:
  //   so dataclk = eval clk.
  // miller clocks data at half the evalclk
  //   in order to evaluate both possible phase inversions.
  divby2 U_DIV5 (evalclk, reset, evalclkby2);
  reg    bitinclkoverride; // to clock first bit from preamble module during setup.
  assign bitinclk  = ((m == 0) ? evalclk : evalclkby2) | bitinclkoverride;
  
  // We don't want glitches on the tempbit output, so it is gated
//  with a FF. However, the FF causes the freq. to divide by 2
//  so the FF is clocked with clkin and the tempbit waveform
//  is generated with clkin/2 for FM0 and M2 (M2 get divided via
//  the state machine variable clkphase).
//  Subsequent Miller schemes are again divided by 2.
  always @ (posedge clkin or posedge reset) begin
    if (reset) begin
      bitout <= 0;
    end else begin
      bitout <= nextbitout & bitoutenable;
    end
  end

  // start up circuit
  // we should wait 10 subcarrier periods before tx start
  // also, rtcal_expired must be high before tx start.
  // clkin is 2x the subcarrier frequency
  reg [5:0] subcarriers;
  always @ (posedge clkin or posedge reset) begin
    if (reset) begin
      subcarriers      <= 0;
      bitinclkoverride <= 0;
      txdone           <= 0;
      txdoneout        <= 0;
      setupdone        <= 0;
      
    end else if (subcarriers < 8) begin
      subcarriers      <= subcarriers + 6'd1;
      bitinclkoverride <= 1;
      
    end else if (subcarriers < 17) begin
      subcarriers      <= subcarriers + 6'd1;
      bitinclkoverride <= 0;
      
    end else if (subcarriers == 17) begin // start tx
      if (rtcal_expired) begin
        subcarriers <= subcarriers + 6'd1;
        setupdone   <= 1;
      end
      
    end else if (txstop & !txdone & (m==0)) begin  // end tx
      txdone <= 1;
      subcarriers <= subcarriers + 6'd1;
      
    end else if (txstop & !txdone & (m==1) & (subcarriers >= 19)) begin
      txdone <= 1;
      subcarriers <= subcarriers + 6'd1;
      
    end else if (txstop & !txdone & (m==2) & (subcarriers >= 21)) begin
      txdone <= 1;
      subcarriers <= subcarriers + 6'd1;
      
    end else if (txstop & !txdone & (m==3) & (subcarriers >= 25)) begin
      txdone <= 1;
      subcarriers <= subcarriers + 6'd1;
      
    end else if (txstop & (subcarriers==6'b111111)) begin // overflow
      txdone    <= 1;
      txdoneout <= 1;
                                     
    end else if (txdone) begin // 
      txdoneout <= 1;
      
    end else if (txstop) begin // 
      subcarriers <= subcarriers + 6'd1;
    end
  end

  always @ (posedge evalclk or posedge reset) begin
    if (reset) begin
      previousbit      <= 0;
      currentbit       <= 0;
      phaseinvert      <= 0;
      clkphase         <= 0;
      currentviolation <= 0;
      txstop           <= 0;
      bitoutenable     <= 0;

    end else begin
      
      if (clkphase == 0 | m == 0) begin
        clkphase         <= 1;
        phaseinvert      <= nextphaseinvert;
        currentbit       <= bitin;
        previousbit      <= currentbit;
        currentviolation <= violationin;
        txstop           <= txstopin;

        if(m==0) bitoutenable <= 1;
        
      end else begin
        clkphase    <= 0;
        phaseinvert <= millerphaseinvert;
        bitoutenable <= 1;
      end
      
    end
  end
  
endmodule