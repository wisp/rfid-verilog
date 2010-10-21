

// rigidly assume clock = 10mhz.

module rfid_reader_tx (
                       // basic setup connections
                       reset, clk, reader_modulation,
                       // control signals
                       tx_done, tx_running, tx_go, send_trcal,
                       // timing information
                       delim_counts, pw_counts, rtcal_counts, trcal_counts, tari_counts,
                       // payload information
                       tx_packet_length, tx_packet_data
                       );

input  reset, clk, send_trcal, tx_go;
output reader_modulation;
output tx_done, tx_running;

input [15:0] delim_counts, pw_counts, rtcal_counts, trcal_counts, tari_counts;

input [6:0]   tx_packet_length;
input [127:0] tx_packet_data;

reg [2:0] tx_state;
parameter STATE_IDLE         = 3'd0;
parameter STATE_DELIM        = 3'd2;
parameter STATE_DATA0        = 3'd3;
parameter STATE_RTCAL        = 3'd4;
parameter STATE_TRCAL        = 3'd5;
parameter STATE_DATA         = 3'd6;
parameter STATE_WAIT_FOR_RX  = 3'd7;

reg modout;
assign reader_modulation = modout;

reg [15:0] count;
reg [6:0] current_tx_bit;

reg tx_done, tx_running;

wire current_bit, data0_bit_end, data0_bit_transition, data1_bit_end, data1_bit_transition, bit_transition, bit_end;
wire [15:0] data0_end_count, data1_end_count, data0_tran_count, data1_tran_count; 
assign current_bit          = tx_packet_data[current_tx_bit];
assign data0_end_count      = tari_counts+pw_counts;
assign data1_end_count      = tari_counts+tari_counts+pw_counts;
assign data0_tran_count     = tari_counts;
assign data1_tran_count     = tari_counts+tari_counts;
assign data0_bit_end        = (count >= data0_end_count);
assign data0_bit_transition = (count >= data0_tran_count);
assign data1_bit_end        = (count >= data1_end_count);
assign data1_bit_transition = (count >= data1_tran_count);
assign bit_transition       = data1_bit_transition | (!current_bit & data0_bit_transition);
assign bit_end              = data1_bit_end | (!current_bit & data0_bit_end);

wire rtcal_end, rtcal_transition, trcal_end, trcal_transition;
wire [15:0] rtcal_end_count, trcal_end_count; 

assign rtcal_end_count  = rtcal_counts+pw_counts;
assign trcal_end_count  = trcal_counts+pw_counts;
assign rtcal_end        = (count >= rtcal_end_count);
assign rtcal_transition = (count >= rtcal_counts);
assign trcal_end        = (count >= trcal_end_count);
assign trcal_transition = (count >= trcal_counts);

always @ (posedge clk or posedge reset) begin
  if (reset) begin
    tx_state <= 0;
    modout   <= 0;
    count    <= 0;
    current_tx_bit <= 0;
    tx_done        <= 0;
    tx_running     <= 0;
    
  end else begin
    case(tx_state)
      STATE_IDLE: begin
        tx_done    <= 0;
        if(tx_go) begin
          tx_state   <= STATE_DELIM;
          count      <= 1;
          tx_running <= 1;
          modout     <= 0;
          current_tx_bit <= tx_packet_length - 1;
        end else begin
          tx_running <= 0;
          modout     <= 1;
        end
      end

      STATE_DELIM: begin
        if( count >= delim_counts ) begin
          modout   <= 1;
          count    <= 1;
          tx_state <= STATE_DATA0;
        end else begin
          count    <= count + 1;
        end
      end

      STATE_DATA0: begin
        if( data0_bit_end ) begin
          tx_state <= STATE_RTCAL;
          count    <= 1;
          modout   <= 1;
        end else if ( data0_bit_transition ) begin
          modout <= 0;
          count  <= count + 1;
        end else begin
          count <= count + 1;
        end
      end

      STATE_RTCAL: begin
        if( rtcal_end ) begin
          if (send_trcal) tx_state <= STATE_TRCAL;
          else            tx_state <= STATE_DATA;
          count  <= 1;
          modout <= 1;
        end else if( rtcal_transition ) begin
          modout <= 0;
          count  <= count + 1;
        end else begin
          count <= count + 1;
        end
      end
      
      STATE_TRCAL: begin
        if( trcal_end ) begin
          tx_state <= STATE_DATA;
          count    <= 1;
          modout   <= 1;
        end else if( trcal_transition ) begin
          modout <= 0;
          count  <= count + 1;
        end else begin
          count <= count + 1;
        end
      end

      STATE_DATA: begin
        if (bit_end) begin
          count    <= 1;
          modout   <= 1;
          
          if (current_tx_bit == 0) begin
            tx_state <= STATE_WAIT_FOR_RX;
            tx_done  <= 1;
          end else begin
            current_tx_bit <= current_tx_bit - 1;
          end
          
        end else if (bit_transition) begin
          modout <= 0;
          count  <= count + 1;
        end else begin
          count <= count + 1;
        end
      end
      
      STATE_WAIT_FOR_RX: begin
         modout   <= 1;
         if(!tx_go) tx_state <= 0;
      end

      default: begin
        tx_state <= 0;
      end
    endcase
  end
end

endmodule
