
// Top level which connects all the top-level functional blocks.
// Copyright 2010 University of Washington
// License: http://creativecommons.org/licenses/by/3.0/
// 2008 Dan Yeager

// The controller chooses if and what packet is sent.

// RX converts RFID protocol into a serial data stream
//    and provides TRCAL, the tx clock divider calibration
//    and the lsb of the counter as a random number stream.

// CMDPARSE and PACKETPARSE decode the serial bit stream
//    and help the controller make decisions.

// TX converts a serial bit stream to RFID protocol.
//    It is wrapped in a SEQUENCER which provides the proper
//    clock to TX and sequences the preamble, DATA and crc in time.

// The controller connects one of 4 DATA sources to the sequencer.
//    Options are RNG (random number), EPC (ID), READ (response to READ packet)
//    and WRITE (response to WRITE packet).

module top(reset, clk, demodin, modout, // regular IO
           adc_sample_ctl, adc_sample_clk, adc_sample_datain,    // adc connections
           msp_sample_ctl, msp_sample_clk, msp_sample_datain, // msp430 connections
           uid_byte_in, uid_addr_out, uid_clk_out,
           writedataout, writedataclk, 
           use_uid, use_q, comm_enable,
           debug_clk, debug_out);

  // Regular IO
  // Oscillator input, master reset, demodulator input
  input  reset, clk, demodin;

  // Modulator output
  output modout;

  // Functionality control
  input use_uid, use_q, comm_enable;

  // EPC ID source
  input  [7:0] uid_byte_in;
  output [3:0] uid_addr_out;
  output       uid_clk_out;

  // ADC connections
  input  adc_sample_datain;
  output adc_sample_clk, adc_sample_ctl;

  // MSP430 connections
  input  msp_sample_datain;
  output msp_sample_clk, msp_sample_ctl;
  output writedataout, writedataclk;

  // Debugging IO
  input  debug_clk;
  output debug_out;

  // CONTROLLER module connections
  wire rx_en, tx_en, docrc;
  wire [15:0] currentrn;     // current rn
  wire [15:0] currenthandle; // current handle

  // RX module connections
  wire rx_reset, rxtop_reset, bitclk, bitout;
  wire rx_overflow;

  // PACKET PARSE module connections
  wire       handlematch;
  wire [1:0] readwritebank;
  wire [7:0] readwriteptr;
  wire [7:0] readwords;
  wire       writedataout, writedataclk;
  wire [3:0] rx_q;
  wire [2:0] rx_updn;

  // CMDPARSE module connections
  wire packet_complete, cmd_complete;
  wire [8:0] rx_cmd;

  // TX module connections
  wire tx_reset, txsetupdone, tx_done;

  // TX settings module wires
  wire dr_in, dr_out;
  wire trext_in, trext_out;
  wire [1:0] m_in, m_out;
  wire [9:0] trcal_in, trcal_out;

  // Signal to tx settings module to store TR modulation settings.
  parameter QUERY = 9'b000000100;
  wire query_complete;
  assign query_complete = packet_complete && (rx_cmd==QUERY);

  // RNG connections
  wire rngbitin, rngbitinclk;
  // Signal to RNG to clock in new bits for query, queryadj, reqrn
  assign rngbitinclk = bitclk & (rx_cmd[2] | rx_cmd[3] | (rx_cmd[6] & handlematch));

  // TX module connections
  wire txbitclk, txbitsrc, txdatadone;
  
  // RX and TX module reset signals
  assign tx_reset    = reset | !tx_en;
  assign rx_reset    = reset | !rx_en;
  assign rxtop_reset = reset | !rx_en;

  // mux control for transmit data source
  wire [1:0] bitsrcselect;
  parameter BITSRC_RNG  = 0;
  parameter BITSRC_EPC  = 1;
  parameter BITSRC_READ = 2;
  parameter BITSRC_UID  = 3;

  // mux the bit source for the tx module
  wire [3:0] bitsrc;
  wire rngbitsrc, epcbitsrc, readbitsrc, uidbitsrc;
  assign bitsrc[0] = rngbitsrc;
  assign bitsrc[1] = epcbitsrc;
  assign bitsrc[2] = readbitsrc;
  assign bitsrc[3] = uidbitsrc;
  assign txbitsrc  = bitsrc[bitsrcselect];

  // mux control for data source done flag
  wire [3:0] datadone;
  wire rngdatadone, epcdatadone, readdatadone, uiddatadone;
  assign datadone[0] = rngdatadone;
  assign datadone[1] = epcdatadone;
  assign datadone[2] = readdatadone;
  assign datadone[3] = uiddatadone;
  assign txdatadone  = datadone[bitsrcselect];

  // mux control for tx data clock
  wire   rngbitclk, epcbitclk, readbitclk, uidbitclk;
  assign rngbitclk  = (bitsrcselect == BITSRC_RNG ) ? txbitclk : 1'b0;
  assign epcbitclk  = (bitsrcselect == BITSRC_EPC ) ? txbitclk : 1'b0;
  assign readbitclk = (bitsrcselect == BITSRC_READ) ? txbitclk : 1'b0;
  assign uidbitclk  = (bitsrcselect == BITSRC_UID ) ? txbitclk : 1'b0;

  // MUX connection from READ to MSP or ADC
  wire readfrommsp;
  wire readfromadc = !readfrommsp;
  wire read_sample_ctl, read_sample_clk, read_sample_datain;

  // ADC connections
  assign adc_sample_ctl     = read_sample_ctl    & readfromadc;
  assign adc_sample_clk     = read_sample_clk    & readfromadc;

  // MSP430 connections
  assign msp_sample_ctl     = read_sample_ctl    & readfrommsp;
  assign msp_sample_clk     = read_sample_clk    & readfrommsp;

  assign read_sample_datain = readfromadc ? adc_sample_datain : msp_sample_datain;

  // Serial debug interface for viewing registers:
  reg [3:0] debug_address;
  reg debug_out;
  always @ (posedge debug_clk or posedge reset) begin
    if(reset) begin
      debug_address <= 4'd0;
    end else begin
      debug_address <= debug_address + 4'd1;
    end
  end
  always @ (debug_address) begin
  case(debug_address)
    0:  debug_out = packet_complete;
    1:  debug_out = cmd_complete;
    2:  debug_out = handlematch;
    3:  debug_out = docrc;
    4:  debug_out = rx_en;
    5:  debug_out = tx_en;
    6:  debug_out = bitout;
    7:  debug_out = bitclk;
    8:  debug_out = rngbitin;
    9:  debug_out = rx_overflow;
    10: debug_out = tx_done;
    11: debug_out = txsetupdone;
    12: debug_out = 1'b0;
    13: debug_out = 1'b1;
    14: debug_out = 1'b0;
    15: debug_out = 1'b1;
    default: debug_out = 1'b0;
  endcase
  end

  // MODULES! :)

  controller U_CTL (reset, clk, rx_overflow, rx_cmd, currentrn, currenthandle,
                    packet_complete, txsetupdone, tx_done, 
                    rx_en, tx_en, docrc, handlematch,
                    bitsrcselect, readfrommsp, readwriteptr, rx_q, rx_updn,
                    use_uid, use_q, comm_enable);

  txsettings U_SET (reset, trcal_in,  m_in,  dr_in,  trext_in, query_complete,
                           trcal_out, m_out, dr_out, trext_out);

  rx        U_RX  (rx_reset, clk, demodin, bitout, bitclk, rx_overflow, trcal_in, rngbitin);
  cmdparser U_CMD (rxtop_reset, bitout, bitclk, rx_cmd, packet_complete, cmd_complete,
                   m_in, trext_in, dr_in);

  packetparse U_PRSE (rx_reset, bitout, bitclk, rx_cmd, rx_q, rx_updn,
                      currenthandle, currentrn, handlematch,
                      readwritebank, readwriteptr, readwords,
                      writedataout, writedataclk );

  rng       U_RNG  (tx_reset, reset, rngbitin, rngbitinclk, rngbitclk, rngbitsrc, rngdatadone, currentrn);
  epc       U_EPC  (tx_reset, epcbitclk, epcbitsrc, epcdatadone);
  read      U_READ (tx_reset, readbitclk, readbitsrc, readdatadone, 
                    read_sample_ctl, read_sample_clk, read_sample_datain, 
                    currenthandle);
  uid       U_UID  (tx_reset, uidbitclk, uidbitsrc, uiddatadone, 
                    uid_byte_in, uid_addr_out, uid_clk_out);

  sequencer U_SEQ (tx_reset, rx_overflow, clk, m_out, dr_out, docrc, trext_out, 
                   trcal_out, txbitsrc, txdatadone, txbitclk, modout, txsetupdone, tx_done);

endmodule
