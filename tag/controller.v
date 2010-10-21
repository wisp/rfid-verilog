
// Controller module
// Copyright 2010 University of Washington
// License: http://creativecommons.org/licenses/by/3.0/
// 2008 Dan Yeager

// This is the high level smarts of the RFID tag.
// It decides if and what to send upon a 
// packet complete signal from the rx module.
// If we should transmit, it starts up the tx module
// and waits for it to indicate that it is finished.
// We also return a data select signal to the 'top' module
// which mux'es the epc, rn, and adc into the tx module.

// A couple features have been added for EPC compatibility
// 1. Handle persistence
//    During a Write command, the reader asks for two successive
//    req_rn's.  The first is to be our handle. The second is the
//    write data cover code. We store the handle as our current handle
//    and this condition is kept in a reg tagisopen.
//    For reference, see EPC spec - Annex K
//    
// 2. Q-slotting for TDMA based on the rng
//    Query, QueryAdj and QueryRep commands are used to manage
//    the number of time slots. Query and QueryAdj load
//    the slotcounter with Q bits of the RN from the rng.
//    If slotcounter == 0, tag should TX its RN.
//    QueryRep commands cause tag to decrement slotcounter.
//    This feature is enabled via the use_q input.
//    EPC spec - see Annex J
//    
// 3. Unique ID
//    Tags should have unique ID's (uid).  However, the UID
//    should not change in time unless the reader rewrites the ID.
//    Ying's ID generator has unstable bits, which violates SPEC
//    so we have another option to use a static ID.
//    This feature is enabled via the use_uid input.
//    use_uid=1 -> Ying's ID,    use_uid=0 -> static ID

module controller (reset, clk, rx_overflow, rx_cmd, currentrn, currenthandle,
                   packet_complete, txsetupdone, tx_done, 
                   rx_en, tx_en, docrc, handlematch,
                   bitsrcselect, readfrommsp, readwriteptr, rx_q, rx_updn,
                   use_uid, use_q, comm_enable);
  
  parameter QUERYREP   = 9'b000000001;
  parameter ACK        = 9'b000000010;
  parameter QUERY      = 9'b000000100;
  parameter QUERYADJ   = 9'b000001000;
  parameter SELECT     = 9'b000010000;
  parameter NACK       = 9'b000100000;
  parameter REQRN      = 9'b001000000;
  parameter READ       = 9'b010000000;
  parameter WRITE      = 9'b100000000;

  parameter bitsrcselect_RNG = 2'd0;
  parameter bitsrcselect_EPC = 2'd1;
  parameter bitsrcselect_ADC = 2'd2;
  parameter bitsrcselect_UID = 2'd3;
   
  input reset, clk, rx_overflow, packet_complete, txsetupdone, tx_done;
  input [8:0] rx_cmd;
  input [15:0]  currentrn;
  output [15:0] currenthandle;
  output rx_en, tx_en, docrc; // current_mode 0: rx mode, 1: tx mode
  output [1:0] bitsrcselect;
  input [7:0] readwriteptr;
  output readfrommsp;
  input use_uid, use_q;
  input [3:0] rx_q;
  input [2:0] rx_updn;
  input handlematch, comm_enable;

  reg [3:0] rx_q_reg;
  reg readfrommsp;
  reg [15:0] storedhandle;
  reg [1:0] bitsrcselect;
  reg docrc;
  reg rx_en, tx_en;

  reg commstate;
  parameter STATE_RX      = 1'b0;
  parameter STATE_TX      = 1'b1;

  // See EPC spec Annex K
  // First request RN sets our handle
  // Second request RN sets the current cover code
  // For write data
  reg tagisopen;
  assign currenthandle = tagisopen ? storedhandle : currentrn;


  // Code to handle Q slotting for time-division multiplexing
  // We TX our RN when slot counter == 0 for any of the following commands:
  // They also have special behaviors:
  // Query    -> draw new rn, take Q bits of rn as init slot counter
  // QueryAdj -> draw new rn, adjust stored Q value as per cmd, 
  //             take Q bits of rn as init slot counter (like a query)
  // QueryRep -> decrement existing slot counter value
  reg [14:0] slotcounter;
  
  // For query adjust, we will init slot counter based on q_adj
  wire [3:0] q_adj, q_up, q_dn;
  assign q_up  = (rx_q_reg < 4'd15 && rx_updn[2] && rx_updn[1]) ? rx_q_reg + 4'd1 : rx_q_reg;
  assign q_dn  = (rx_q_reg > 4'd0  && rx_updn[0] && rx_updn[1]) ? rx_q_reg - 4'd1 : rx_q_reg;
  assign q_adj = rx_updn[0] ? q_dn : q_up;
  
  // For query, we init slot counter based on rx_q (from the parser module)
  // This code takes Q bits of our rn as the new slot counter.
  // If we get a query or queryAdj, the state machine will 
  //   set slotcounter = newslotcounter as defined here:
  wire [14:0] newslotcounter;
  wire [3:0] q_ctl;
  assign q_ctl = (rx_cmd == QUERY) ? rx_q : q_adj;

  reg [14:0] slotcountermask;

  always @ (q_ctl) begin
  case(q_ctl)
    0:  slotcountermask = 15'b000000000000000;
    1:  slotcountermask = 15'b000000000000001;
    2:  slotcountermask = 15'b000000000000011;
    3:  slotcountermask = 15'b000000000000111;
    4:  slotcountermask = 15'b000000000001111;
    5:  slotcountermask = 15'b000000000011111;
    6:  slotcountermask = 15'b000000000111111;
    7:  slotcountermask = 15'b000000001111111;
    8:  slotcountermask = 15'b000000011111111;
    9:  slotcountermask = 15'b000000111111111;
    10: slotcountermask = 15'b000001111111111;
    11: slotcountermask = 15'b000011111111111;
    12: slotcountermask = 15'b000111111111111;
    13: slotcountermask = 15'b001111111111111;
    14: slotcountermask = 15'b011111111111111;
    15: slotcountermask = 15'b111111111111111;
    default: slotcountermask = 15'b000000000000000;
  endcase
  end
  assign newslotcounter = currentrn[14:0] & slotcountermask;
  
  always @ (posedge clk or posedge reset) begin
    if (reset) begin
      commstate <= STATE_RX;
      bitsrcselect    <= 2'd0;
      docrc     <= 0;
      tx_en     <= 0;
      rx_en     <= 0;
      tagisopen <= 0;
      rx_q_reg  <= 0;
      slotcounter  <= 0;
      storedhandle <= 0;
      readfrommsp  <= 0;
    end else if (commstate == STATE_TX) begin
      if(txsetupdone) begin
        rx_en <= 0;
      end
      if(tx_done) begin // tx_done
        tx_en     <= 0;
        commstate <= STATE_RX;
      end else begin
        tx_en <= 1;
      end
      end else if (commstate == STATE_RX) begin  // rx mode
        if(packet_complete) begin
          case (rx_cmd)
           QUERYREP: begin
             tagisopen   <= 0;
             slotcounter <= slotcounter - 15'd1;
             if (comm_enable & ((slotcounter-15'd1)==0 | ~use_q)) begin
               commstate     <= STATE_TX;
               bitsrcselect        <= bitsrcselect_RNG;
               docrc         <= 0;
             end else begin
               rx_en <= 0;  // reset rx
             end
           end
           ACK: begin
             tagisopen <= 0;
             if (comm_enable && handlematch) begin
               commstate <= STATE_TX; // send ack.
               bitsrcselect    <= use_uid ? bitsrcselect_UID : bitsrcselect_EPC;
               docrc     <= 1;
             end else begin
             rx_en <= 0;  // reset rx
             end
           end
           QUERY: begin
             tagisopen <= 0;
             rx_q_reg  <= rx_q;
             // load slot counter
             slotcounter <= newslotcounter;
             
             if (comm_enable & (newslotcounter==0 | ~use_q)) begin
               commstate     <= STATE_TX;
               bitsrcselect        <= bitsrcselect_RNG;
               docrc         <= 0;
             end else begin
               rx_en <= 0;  // reset rx
             end
           end
           QUERYADJ: begin
             tagisopen <= 0;
             rx_q_reg  <= q_adj;
             // load slot counter
             slotcounter <= newslotcounter;
             
             if (comm_enable & (newslotcounter==0 | ~use_q)) begin
               commstate     <= STATE_TX;
               bitsrcselect        <= bitsrcselect_RNG;
               docrc         <= 0;
             end else begin
               rx_en <= 0;  // reset rx
             end
           end
           SELECT: begin
             tagisopen <= 0;
             rx_en <= 0;  // reset rx
           end
           NACK: begin
             tagisopen <= 0;
             rx_en     <= 0;  // reset rx
           end
           REQRN: begin
             if (comm_enable && handlematch) begin

               // First request RN opens tag, sets handle
               if (!tagisopen) begin
                 storedhandle <= currentrn;
                 tagisopen    <= 1;
               end

               commstate <= STATE_TX;
               bitsrcselect    <= bitsrcselect_RNG;
               docrc     <= 1;
             end else begin
               rx_en <= 0;  // reset rx
             end
           end
           READ: begin
             if (comm_enable && handlematch) begin
               if (readwriteptr == 0) readfrommsp <= 0;
               else                   readfrommsp <= 1;
               commstate  <= STATE_TX;
               bitsrcselect     <= bitsrcselect_ADC;
               docrc      <= 1;
             end else begin
               rx_en <= 0;  // reset rx
             end
           end
           WRITE: begin
             rx_en <= 0;  // reset rx
           end
          default begin
             rx_en <= 0;  // reset rx
          end
          endcase
        end else if(rx_overflow) begin
          rx_en <= 0;
        end else begin
          rx_en <= 1;
          tx_en <= 0;
        end
      end
    end
endmodule

