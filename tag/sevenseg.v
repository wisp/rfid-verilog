

// http://www.lti-systems.com/verilog_03.html

// altera seven seg is logic low.

module sevenseg(displayout,inputbcd);

output [6:0] displayout;
input  [3:0] inputbcd;

reg    [6:0] displayout;      //latch the outputs


parameter bit0 = 7'b0000001;
parameter bit1 = 7'b0000010;
parameter bit2 = 7'b0000100;
parameter bit3 = 7'b0001000;
parameter bit4 = 7'b0010000;
parameter bit5 = 7'b0100000;
parameter bit6 = 7'b1000000;

parameter zero  = ~(bit0 | bit1 | bit2 | bit3 | bit4 | bit5);
parameter one   = ~(bit1 | bit2);
parameter two   = ~(bit0 | bit1 | bit3 | bit4 | bit6);
parameter three = ~(bit0 | bit1 | bit2 | bit3 | bit6);
parameter four  = ~(bit1 | bit2 | bit5 | bit6);
parameter five  = ~(bit0 | bit2 | bit3 | bit5 | bit6);
parameter six   = ~(bit0 | bit2 | bit3 | bit4 | bit5 | bit6);
parameter seven = ~(bit0 | bit1 | bit2);
parameter eight = ~(bit0 | bit1 | bit2 | bit3 | bit4 | bit5 | bit6);
parameter nine  = ~(bit0 | bit1 | bit2 | bit5 | bit6);
parameter blank = ~(7'd0);

always @ (inputbcd)

case (inputbcd)
0:   displayout = zero;
1:   displayout = one;
2:   displayout = two;
3:   displayout = three;
4:   displayout = four;
5:   displayout = five;
6:   displayout = six;
7:   displayout = seven;
8:   displayout = eight;
9:   displayout = nine;

default: displayout = blank;
endcase
   
endmodule
