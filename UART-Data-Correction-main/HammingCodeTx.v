`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.10.2024 21:44:39
// Design Name: 
// Module Name: UartTransmitter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module HammingCodeTx( input clk, rst, input [3:0]num, [7:0]bias, input trig, output reg tx, output reg [6:0]seg1, output reg [3:0]an1
    );      
//Display the orignal Value entered -------------------
reg [19:0] refresh_counter;
wire [1:0] activating_ctr;
always@(posedge clk or posedge rst) begin

if(rst==1)
refresh_counter<=1;
else 
refresh_counter<=refresh_counter+1;
end
assign activating_ctr = refresh_counter[19:18];
//-----------------------------------------------------
//Creating anode signals and updating values of 7 segment display
// data is a 16 bit number every 4 bit will be displayed on different 7 segs 

//flip flop for registering last transferred data over uart
reg [3:0]single_disp;

always @(*) begin
case (activating_ctr)
    2'b00:begin
     an1 = 4'b0111;
     single_disp = num/1000;
     end
    2'b01: begin
    an1 = 4'b1011;
    single_disp =(num % 1000)/100;
     end
    2'b10: begin
    an1 = 4'b1101;
    single_disp = ((num % 1000)%100)/10;
     end
    2'b11: begin
     an1 = 4'b1110;
     single_disp = ((num % 1000)%100)%10;
     end
//    default: begin 
//    an = 4'b0111;
//    single_disp = num_display[15:12];
//     end
    endcase
end
//-------Cathode pattern for 7 segment display---------
always@(*) begin
case(single_disp)
        4'b0000: seg1 = 7'b1000000; // "0"     
        4'b0001: seg1 = 7'b1111001; // "1" 
        4'b0010: seg1 = 7'b0100100; // "2" 
        4'b0011: seg1 = 7'b0110000; // "3" 
        4'b0100: seg1 = 7'b0011001; // "4" 
        4'b0101: seg1 = 7'b0010010; // "5" 
        4'b0110: seg1 = 7'b0000010; // "6" 
        4'b0111: seg1 = 7'b1111000; // "7" 
        4'b1000: seg1 = 7'b0000000; // "8"     
        4'b1001: seg1= 7'b0010000; // "9" 
        default: seg1 = 7'b1000000; // "0"
        endcase
end
//----------------------------------------------------------------
// Generating the hamming code
wire [7:0]data;
wire p1, p2, p4, p5;
assign p1 = num[0]^num[1]^num[3]; // 
assign p2 = num[0]^num[2]^num[3]; // 
assign p4 = num[1]^num[2]^num[3]; // 
assign p5 = p1^p2^p4^num[0]^num[1]^num[2]^num[3]; // extra 8th bit (added only since uart sends 8 bit and hamming has 7)

assign data = {p5,num[3], num[2], num[1], p4, num[0], p2, p1}; // 


// Adding the error using bias
wire [7:0]Edata;
assign Edata = data^bias;

parameter idle = 3'b000;
    parameter start_bit = 3'b001;
    parameter data_bits = 3'b010;
    parameter stop_bit = 3'b011;
    parameter cleanup = 3'b100;
    // Setting baud rates and counters 
    parameter clk_speed = 100000000, baud_rate = 115200; //Fpga clk speed and uart parameter
    parameter clk_cycles = clk_speed/baud_rate;
    reg indicator;
    
    //trigger debounce
    reg prev_state;
    reg debounced_trigger;
    always@(posedge clk) begin
    if(trig&(~prev_state))
    debounced_trigger <= 1'b1;
    else
    debounced_trigger <= 1'b0;
    prev_state <= trig;
    end
    //variable declerations
    reg [2:0]state = 0;
    reg [25:0]clk_ctr = 0;
    reg [2:0]no_bits = 0;
    //State machine
    always@(posedge clk, posedge rst) begin
    if(rst==1) begin
        state <= idle;
        clk_ctr <= 0;
        no_bits <= 0;
        tx <= 1'b1;
        indicator <= 0;
    end
    else begin
    case(state)
    // IDLE STATE 
    idle: begin
        indicator <= 1'b0;
        clk_ctr <= 0;
        tx <= 1'b1;
        if(debounced_trigger==1'b1) 
        state<=start_bit;
        else
        state <= idle;
        end
    //START BIT STATE
    start_bit: begin
        if(clk_ctr <= (clk_cycles-1)) begin
        tx<=1'b0;
        clk_ctr<=clk_ctr+1;
        state<=start_bit;
        end
        else begin
        clk_ctr <= 0;
        state <= data_bits;
        end
        end
        //DATA BITS STATE
        data_bits: begin
        tx<=Edata[no_bits];
        if(clk_ctr == clk_cycles-1) begin 
         
        clk_ctr <= 0;
        if(no_bits<7) begin
        no_bits<=no_bits+1;
        state <= data_bits;
        end
        else begin
        state <= stop_bit;
        no_bits<=0;
        clk_ctr<=0;
        end
        end
        else begin 
        clk_ctr <= clk_ctr+1;
        state <= data_bits;
        end
        end
        //STOP BIT STATE
        stop_bit: begin
        if(clk_ctr < clk_cycles-1) begin
        clk_ctr<=clk_ctr+1;
        state<=stop_bit;
        tx <= 1'b1;
        end
        else begin
        clk_ctr<=0;
        indicator <= 1'b1;
        tx<=1'b1;
        state<=cleanup;
        end
        end
        //CLEANUP STATE
        cleanup: begin
        indicator <= 1'b0;
        state <= idle;
        no_bits <= 0;
        clk_ctr <= 0;
        tx <= 1'b1;
        end
        default: state <= idle; 
        endcase
        end
        end
    
endmodule
