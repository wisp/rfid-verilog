
// RFID Reader for testing epc class 1 gen 2 tags.


// rigidly assume clock = 7.812mhz. (this makes our divide ratios work out nicely)
// for an 8mhz crystal, we are off by about 2%

`timescale 1ns/1ns

module rfid_reader (
                    // basic setup connections
                    reset, clk, tag_backscatter, reader_modulation
                    );

input  reset, clk, tag_backscatter;
output reader_modulation;

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

// Query parameters
parameter DR         = 1'd0;     // 0 = 8, 1 = 64/3
parameter M          = 2'd0;     // 0 to 3
parameter TREXT      = 1'd0;     // 0 or 1
parameter SEL        = 2'd0;     // 0 or 1
parameter SESSION    = 2'd0;     // 0 or 1
parameter TARGET     = 1'd0;     // 0 or 1
parameter Q          = 4'd2;     // 0 to 15

// TX Timing info
parameter DELIM      = 16'd15000; // delimiter = 15us
parameter PW         = 16'd1000;  // 
parameter TARI       = 16'd6250;  // 
parameter RTCAL      = 16'd18750; // 2.5*TARI<RTCAL<3*TARI
parameter TRCAL      = 16'd25000; // >RTCAL

wire [2:0]  miller;
assign      miller        = M;
wire        trext;
assign      trext         = TREXT;
wire        divide_ratio;
assign      divide_ratio  = DR;
wire [15:0] tari_ns;
assign      tari_ns       = TARI;
wire [15:0] trcal_ns;
assign      trcal_ns      = TRCAL;

wire [2:0] q_adj;
assign     q_adj    = 0;
wire [3:0] slot_q;
assign     slot_q   = Q;
wire [1:0] session;
assign     session  = SESSION;
wire [1:0] select;
assign     select   = SEL;
wire       target;
assign     target   = TARGET;

reg [3:0] send_packet_type;
reg       start_tx;

reg  [15:0] tx_handle;
wire [15:0] rx_handle;

wire reader_done, rx_timeout, rx_packet_complete, reader_running;

rfid_reader_packet_rxtx UREADER (
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


// divide time periods by 128 ns via shift right 7 to get clock cycles
parameter CLK_EXP = 7;

wire [15:0] startup_counts;
assign      startup_counts = 16'd50000 >> CLK_EXP;


reg [5:0] reader_state;
parameter STATE_INIT     = 0;
parameter STATE_QUERY    = 1;
parameter STATE_QUERYREP = 2;
parameter STATE_ACK      = 3;
parameter STATE_REQRN    = 4;
parameter STATE_READ     = 5;
parameter STATE_REQMASK  = 6;
parameter STATE_WRITE    = 7;

reg started;
reg [15:0] counter;

always @ (posedge clk or posedge reset) begin
  if (reset) begin
    reader_state   <= 0;
    started        <= 0;
    tx_handle      <= 0;
    start_tx       <= 0;
    counter        <= 0;
    send_packet_type <= 0;
  end else begin
    case(reader_state)
      STATE_INIT: begin
        if (!started) begin
          counter <= 0;
          started <= 1;
        end else begin
          if (counter >= startup_counts) begin
            reader_state <= STATE_QUERY;
            started      <= 0;
          end else begin
            counter <= counter + 1;
          end
        end
      end
      
      STATE_QUERY: begin
        send_packet_type <= QUERY;
        
        if (!started && reader_running) begin
          start_tx     <= 0;
          started      <= 1;
        end else if (!started && !reader_running) begin
          start_tx     <= 1;
        end else if (started && reader_done && rx_packet_complete) begin
          tx_handle    <= rx_handle;
          reader_state <= STATE_ACK;
          started      <= 0;
        end else if (started && reader_done && !rx_packet_complete) begin
          reader_state <= STATE_QUERYREP;
          started      <= 0;
        end
      end
      
      STATE_QUERYREP: begin
        send_packet_type <= QUERYREP;
        
        if (!started && reader_running) begin
          start_tx     <= 0;
          started      <= 1;
        end else if (!started && !reader_running) begin
          start_tx     <= 1;
        end else if (started && reader_done && rx_packet_complete) begin
          tx_handle    <= rx_handle;
          reader_state <= STATE_ACK;
          started      <= 0;
        end else if (started && reader_done && !rx_packet_complete) begin
          reader_state <= STATE_QUERYREP;
          started      <= 0;
        end
      end
      
      STATE_ACK: begin
        send_packet_type <= ACK;
        
        if (!started && reader_running) begin
          start_tx     <= 0;
          started      <= 1;
        end else if (!started && !reader_running) begin
          start_tx     <= 1;
        end else if (started && reader_done && rx_packet_complete) begin
          tx_handle    <= rx_handle;
          reader_state <= STATE_REQRN;
          started      <= 0;
        end else if (started && reader_done && !rx_packet_complete) begin
          reader_state <= STATE_QUERY;
          started      <= 0;
        end
      end
      
      STATE_REQRN: begin
        send_packet_type <= REQRN;
        
        if (!started && reader_running) begin
          start_tx     <= 0;
          started      <= 1;
        end else if (!started && !reader_running) begin
          start_tx     <= 1;
        end else if (started && reader_done && rx_packet_complete) begin
          tx_handle    <= rx_handle;
          reader_state <= STATE_READ;
          started      <= 0;
        end else if (started && reader_done && !rx_packet_complete) begin
          reader_state <= STATE_QUERY;
          started      <= 0;
        end
      end
      
      STATE_READ: begin
        send_packet_type <= READ;
        
        if (!started && reader_running) begin
          start_tx     <= 0;
          started      <= 1;
        end else if (!started && !reader_running) begin
          start_tx     <= 1;
        end else if (started && reader_done && rx_packet_complete) begin
          tx_handle    <= rx_handle;
          reader_state <= STATE_QUERY;
          started      <= 0;
        end else if (started && reader_done && !rx_packet_complete) begin
          reader_state <= STATE_QUERY;
          started      <= 0;
        end
      end
      
      default: begin
        reader_state <= 0;
      end
    endcase
  end
end


endmodule
