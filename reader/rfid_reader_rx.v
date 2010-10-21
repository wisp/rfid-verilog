

module rfid_reader_rx (
                     // basic connections
                     reset, clk, tag_backscatter,
                     // logistics
                     rx_done, rx_timeout,
                     // modulation infomation
                     miller, trext, divide_ratio,
                     // timing information
                     rtcal_counts, trcal_counts, tari_counts,
                     // received data
                     rx_data, rx_dataidx
                     );

input  reset, clk, tag_backscatter;
output rx_done, rx_timeout;

input [2:0] miller;
input trext;
input divide_ratio;

input [15:0] tari_counts;
input [15:0] rtcal_counts;
input [15:0] trcal_counts;

output [1023:0] rx_data;
output [9:0]    rx_dataidx;

reg [1023:0] rx_data;
reg [9:0]    rx_dataidx;

reg rx_done;

// clock and recovery
reg [15:0]  rx_period;
reg [15:0]  rx_counter;

// timeout detector
assign rx_timeout = (rx_counter > rtcal_counts<<2);

// modulator edge detector -> clock generator for bit slicer
reg previousbit;
reg edgeclk;
reg [15:0] count;
always @ (posedge clk or posedge reset) begin
  if (reset) begin
    previousbit <= 0;
    edgeclk     <= 0;
    count       <= 0;
    rx_counter  <= 0;
  end else begin
    if (tag_backscatter != previousbit) begin
      edgeclk     <= 1;
      previousbit <= tag_backscatter;
      count       <= 0;
    end else begin
      edgeclk    <= 0;
      count      <= count + 1;
      rx_counter <= count + 1;
    end
  end
end

reg [4:0] rx_state;
parameter STATE_CLK_UP   = 0;
parameter STATE_CLK_DN   = 1;
parameter STATE_PREAMBLE = 2;
parameter STATE_DATA1    = 3;
parameter STATE_DATA2    = 4;
parameter STATE_DATA3    = 5;
parameter STATE_DATA4    = 6;
parameter STATE_DATA5    = 7;
parameter STATE_DATA6    = 8;
parameter STATE_DATA7    = 9;
parameter STATE_DATA8    = 10;



wire isfm0, ism2, ism4, ism8;
assign isfm0 = (miller == 0);
assign ism2  = (miller == 1);
assign ism4  = (miller == 2);
assign ism8  = (miller == 3);

wire count_lessthan_period;
assign count_lessthan_period = (rx_counter <= rx_period);

wire fm0_preamble_done;
assign fm0_preamble_done = (rx_dataidx >= 5);

wire [15:0] rx_counter_by2;
assign rx_counter_by2 = rx_counter >> 1;

// bit slicer / parser
always @ (posedge edgeclk or posedge reset) begin
  if (reset) begin
    rx_state   <= 0;
    rx_dataidx <= 0;
    rx_data    <= 0;
  end else begin
  
  case(rx_state)
    STATE_CLK_UP: begin
      rx_state   <= STATE_CLK_DN;
      rx_dataidx <= 0;
      rx_data    <= 0;
    end
    
    STATE_CLK_DN: begin
      if(isfm0 & ~trext) rx_period <= rx_counter_by2;
      else               rx_period <= rx_counter;
      rx_state <= STATE_PREAMBLE;
    end
    
    STATE_PREAMBLE: begin
      if(isfm0) begin
        if( fm0_preamble_done ) begin
          rx_state    <= STATE_DATA1;
          rx_dataidx  <= 0;
        end else begin
          rx_dataidx  <= rx_dataidx + 1;
        end
      end
    end
    
    STATE_DATA1: begin
      if(isfm0) begin
        // data 0
        if( count_lessthan_period ) begin
          rx_state <= STATE_DATA2;
          rx_data[rx_dataidx] <= 0;
          rx_dataidx          <= rx_dataidx + 1;
        // data 1
        end else begin
          rx_data[rx_dataidx] <= 1;
          rx_dataidx          <= rx_dataidx + 1;
        end
      end else begin // todo:
        // data 0
        if( count_lessthan_period ) begin
          rx_state <= STATE_DATA2;
          rx_data[rx_dataidx] <= 0;
          rx_dataidx          <= rx_dataidx + 1;
        // data 1
        end else begin
          rx_data[rx_dataidx] <= 1;
          rx_dataidx          <= rx_dataidx + 1;
        end
      end
    end
    STATE_DATA2: begin
      if(isfm0) begin
        rx_state <= STATE_DATA1;
      end else begin
        rx_state <= STATE_DATA1; // todo:
      end
    end
    
    default begin
      rx_state <= 0;
    end
  endcase
  
  end
end



endmodule

