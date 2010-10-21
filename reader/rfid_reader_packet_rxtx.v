
// RFID Reader for testing epc class 1 gen 2 tags.


// rigidly assume clock = 7.812mhz. (this makes our divide ratios work out nicely)
// for an 8mhz crystal, we are off by about 2%

`timescale 1ns/1ns

module rfid_reader_packet_rxtx (
                    // basic setup connections
                    reset, clk, tag_backscatter, reader_modulation,
                    // modulation settings
                    miller, trext, divide_ratio, tari_ns, trcal_ns,
                    // tag state settings
                    slot_q, q_adj, session, target, select,
                    // command to send, posedge send trigger
                    send_packet_type, start_tx, reader_done, rx_timeout, rx_packet_complete, reader_running,
                    // tx payload info
                    tx_handle,
                    // rx payload info
                    rx_handle
                    );

input  reset, clk, tag_backscatter;
output reader_modulation;

input [2:0] miller;
input trext;
input divide_ratio;
input [15:0] tari_ns;
input [15:0] trcal_ns;

input [2:0] q_adj;
input [3:0] slot_q;
input [1:0] session;
input [1:0] select;
input       target;

input [3:0] send_packet_type;
input start_tx;
output reader_done, rx_timeout, rx_packet_complete, reader_running;

input  [15:0] tx_handle;
output [15:0] rx_handle;

// Packets (valid tx_cmd values)
parameter QUERYREP   = 0;
parameter ACK        = 1;
parameter QUERY      = 2;
parameter QUERYADJ   = 3;
parameter SELECT     = 4;
parameter NACK       = 5;
parameter REQRN      = 6;
parameter READ       = 7;
parameter WRITE      = 8;
parameter KILL       = 9;
parameter LOCK       = 10;
parameter ACCESS     = 11;
parameter BLOCKWRITE = 12;
parameter BLOCKERASE = 13;

// divide time periods by 128 ns via shift right 7 to get clock cycles
parameter CLK_EXP = 7;

wire [15:0] delim_counts;
wire [15:0] pw_counts;
wire [15:0] tari_counts;
wire [15:0] rtcal_counts;
wire [15:0] trcal_counts;

assign delim_counts   = 16'd15000 >> CLK_EXP;
assign pw_counts      = 16'd1000  >> CLK_EXP;
assign tari_counts    = (tari_ns >> CLK_EXP)                   - pw_counts;
assign rtcal_counts   = (tari_ns >> (CLK_EXP-1)) + tari_counts - pw_counts;
assign trcal_counts   = (trcal_ns >> CLK_EXP)                  - pw_counts;

wire rx_done, tx_done, tx_reader_running, send_trcal;
reg  rx_reset, tx_go;
reg  reader_done;
wire tag_found, rx_timeout;

reg [6:0]   tx_packet_length;
reg [127:0] tx_packet_data;

wire [1023:0] rx_data;
wire [9:0]    rx_dataidx;

wire   rx_packet_complete;
assign rx_packet_complete = ((send_packet_type == QUERYREP && rx_dataidx >= 16 ) ||  // QueryRep
                             (send_packet_type == ACK      && rx_dataidx >= 112) ||  // Ack
                             (send_packet_type == QUERY    && rx_dataidx >= 16 ) ||  // Query
                             (send_packet_type == QUERYADJ && rx_dataidx >= 16 ) ||  // QueryAdj
                             (send_packet_type == SELECT   && rx_dataidx >= 0  ) ||  // Select
                             (send_packet_type == NACK     && rx_dataidx >= 0  ) ||  // Nack
                             (send_packet_type == REQRN    && rx_dataidx >= 32 ) ||  // ReqRN
                             (send_packet_type == READ     && rx_dataidx >= 49 ) ||  // Read
                             (send_packet_type == WRITE    && rx_dataidx >= 33 ));   // Write
                            
assign send_trcal = (send_packet_type == QUERY);

rfid_reader_tx U_TX (
                     // basic signals
                     reset, clk, reader_modulation,
                     // control signals
                     tx_done, tx_reader_running, tx_go, send_trcal,
                     // timing information
                     delim_counts, pw_counts, rtcal_counts, trcal_counts, tari_counts,
                     // payload information
                     tx_packet_length, tx_packet_data
                     );
                     
rfid_reader_rx U_RX (
                     // basic signals
                     rx_reset, clk, tag_backscatter,
                     // logistics
                     rx_done, rx_timeout,
                     // modulation infomation
                     miller, trext, divide_ratio,
                     // timing information
                     rtcal_counts, trcal_counts, tari_counts,
                     // received data
                     rx_data, rx_dataidx
                     );




// All the things we can receive from tags
// and their endian-correct outputs
reg  [15:0] handlein;
wire [15:0] rx_handle;

endianflip16 U_FLIP_HANDLE(handlein, rx_handle);

reg [5:0] reader_state;
parameter STATE_IDLE = 0;
parameter STATE_TX   = 1;
parameter STATE_RX   = 2;

reg [15:0] count;

assign reader_running = (reader_state != STATE_IDLE) && (!reader_done);

always @ (posedge clk or posedge reset) begin
  if (reset) begin
    reader_state     <= 0;
    rx_reset         <= 0;
    reader_done      <= 0;
    count            <= 0;
    
    handlein         <= 0;
  end else begin
    case(reader_state)
      STATE_IDLE: begin
        
        rx_reset <= 1;
        
        if(start_tx) begin
          reader_state <= STATE_TX;
          reader_done  <= 0;
        end

      end
      STATE_TX: begin
        
        rx_reset <= 1;
        
        if(tx_done) begin
          tx_go <= 0;
          reader_state <= STATE_RX;
        end else if(!tx_reader_running) begin
          tx_go <= 1;
        end else begin
        end
        
      end
      STATE_RX: begin
        
        rx_reset <= 0;
        
        if (rx_packet_complete) begin // packet complete
          if (send_packet_type == REQRN) begin
            handlein <= rx_data[15:0];
          end
    
          if (send_packet_type == QUERY || send_packet_type == QUERYREP || send_packet_type == QUERYADJ) begin
            handlein <= rx_data[15:0];
          end
        end
        
        if (rx_timeout) begin
          reader_done  <= 1;
        end
        
        if (start_tx) begin
          reader_state <= STATE_IDLE; // reset
          
          $display(" ");
        end
        
        
        
      end
      default: begin
        reader_state <= 0;
      end
    endcase
  end
end


always @ (send_packet_type) begin

          // Construct packet:
          case(send_packet_type)
            QUERYREP: begin
              $display("Sending QueryRep...");
              tx_packet_length      <= 4;
              tx_packet_data[127:4] <= 0;
              tx_packet_data[3:2]   <= 2'b 00;
              tx_packet_data[1:0]   <= session;
            end
            ACK: begin
              $display("Sending Ack...");
              tx_packet_length       <= 18;
              tx_packet_data[127:18] <= 0;
              tx_packet_data[17:16]  <= 2'b01;
              tx_packet_data[15:0]   <= tx_handle;
            end
            QUERY: begin
              $display("Sending Query...");
              tx_packet_length       <= 22;
              tx_packet_data[127:22] <= 0;
              tx_packet_data[21:18]  <= 4'b 1000;
              tx_packet_data[17:5]   <= {divide_ratio,miller,trext,select,session,target,slot_q};
              tx_packet_data[4:0]    <= 5'd0; // todo: crc
            end
            QUERYADJ: begin
              $display("Sending Query Adj...");
              tx_packet_length      <= 9;
              tx_packet_data[127:9] <= 0;
              tx_packet_data[8:5]   <= 4'b 1001; // cmd
              tx_packet_data[4:3]   <= session;
              tx_packet_data[2:0]   <= q_adj;  // Q up/down
            end
            SELECT: begin
              $display("Sending Select...");
              tx_packet_length       <= 45;
              tx_packet_data[127:45] <= 0;
              tx_packet_data[44:41]  <= 4'b 1010;
              tx_packet_data[40:30]  <= 11'b 10101010111;  // TODO
              tx_packet_data[29:0]   <= 0;
            end
            NACK: begin
              $display("Sending Nack...");
              tx_packet_length <= 8;
              tx_packet_data[127:8] <= 0;
              tx_packet_data[7:0]   <= 8'b 11000000;
            end
            REQRN: begin
              $display("Sending Req_rn...");
              tx_packet_length  <= 40;
              tx_packet_data[127:40] <= 0;
              tx_packet_data[39:32] <= 8'b11000001;
              tx_packet_data[31:16] <= tx_handle;
              tx_packet_data[15:0]  <= 15'd0; // todo: crc
            end
            READ: begin
              $display("Sending Read...");
              tx_packet_length  <= 58;
              tx_packet_data[127:58] <= 0;
              tx_packet_data[57:50] <= 8'b 11000010;
              tx_packet_data[49:48] <= 2'b 11; // bank
              tx_packet_data[47:40] <= 8'd0;   // ebv ptr
              tx_packet_data[39:32] <= 8'd1;   // word count
              tx_packet_data[31:16] <= tx_handle;
              tx_packet_data[15:0]  <= 15'd0;  // todo: crc
            end
            WRITE: begin
              $display("Sending Write...");
              tx_packet_length <= 59;
              tx_packet_data[127:58] <= 0;
              tx_packet_data[58:51]  <= 8'b 11000011;
              tx_packet_data[50:40]  <= 11'b 10101010111;
              tx_packet_data[39:0]   <= 0;
            end
            KILL: begin
              $display("Sending Kill...");
              tx_packet_length <= 59;
              tx_packet_data[127:59] <= 0;
              tx_packet_data[58:51]  <= 8'b 11000100;
              tx_packet_data[50:40]  <= 11'b 10101010111;
              tx_packet_data[39:0]   <= 0;
            end
            LOCK: begin
              $display("Sending Lock...");
              tx_packet_length <= 60;
              tx_packet_data[127:60] <= 0;
              tx_packet_data[59:52]  <= 8'b 11000101;
              tx_packet_data[51:41]  <= 11'b 10101010111;
              tx_packet_data[40:0]   <= 0;
            end
            ACCESS: begin
              $display("Sending Access...");
              tx_packet_length <= 56;
              tx_packet_data[127:56] <= 0;
              tx_packet_data[55:48]  <= 8'b 11000110;
              tx_packet_data[47:37]  <= 11'b 10101010111;
              tx_packet_data[36:0]   <= 0;
            end
            BLOCKWRITE: begin
              $display("Sending Block Write...");
              tx_packet_length <= 59;
              tx_packet_data[127:59] <= 0;
              tx_packet_data[58:51]  <= 8'b 11000110;
              tx_packet_data[50:40]  <= 11'b 10101010111;
              tx_packet_data[39:0]   <= 0;
            end
            BLOCKERASE: begin
              $display("Sending Block Erase...");
              tx_packet_length <= 59;
              tx_packet_data[127:59] <= 0;
              tx_packet_data[58:51]  <= 8'b 11000100;
              tx_packet_data[50:40]  <= 11'b 10101010111;
              tx_packet_data[39:0]   <= 0;
            end
            default: begin
              tx_packet_length <= 0;
              tx_packet_data[127:0] <= 0;
            end
      
          endcase // case(mode)
end




endmodule

// The rx gets bits msb first
// but stores them reverse endian
// which minimizes the overhead in the rx
// module. Unfortunately, we have to flip
// the results afterwards.
module endianflip16(flipin, flipout);
  input  [15:0] flipin;
  output [15:0] flipout;
  assign flipout[15] = flipin[0];
  assign flipout[14] = flipin[1];
  assign flipout[13] = flipin[2];
  assign flipout[12] = flipin[3];
  assign flipout[11] = flipin[4];
  assign flipout[10] = flipin[5];
  assign flipout[9] = flipin[6];
  assign flipout[8] = flipin[7];
  assign flipout[7] = flipin[8];
  assign flipout[6] = flipin[9];
  assign flipout[5] = flipin[10];
  assign flipout[4] = flipin[11];
  assign flipout[3] = flipin[12];
  assign flipout[2] = flipin[13];
  assign flipout[1] = flipin[14];
  assign flipout[0] = flipin[15];
endmodule

