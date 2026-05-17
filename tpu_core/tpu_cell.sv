`timescale 1ns/1ps

`include "top.svh"

module tpu_cell #(
    parameter                        HEIGHT_ORDER = 0
) (
    input  logic                     clk,
    input  logic                     rst_n,
    
    //logic [1:0] n_size, 2'd0 is 8, 2'd1 is 16, 2'd2 is 32
    //logic [2:0] precision, 3'd0 is int4, 3'd1 is int8, 3'd2 is fp16, 3'd3 is fp32, 3'd4 is int32
    input  logic [1:0]               n_size,
    input  logic [2:0]               AB_precision,

    input  logic [`MAX_DATA_BIT-1:0] in_data,
    input  logic                     in_data_valid,

    input  logic [`MAX_DATA_BIT-1:0] in_weight,
    input  logic [4:0]               in_weight_addr,
    input  logic                     in_weight_valid,

    output logic [`MAX_DATA_BIT-1:0] out_data,
    output logic                     out_data_valid,

    output logic [`MAX_DATA_BIT-1:0] out_weight,
    //空接
    output logic [4:0]               out_weight_addr,
    output logic                     out_weight_valid,

    input  logic [`MAX_DATA_BIT-1:0] c_in,
    output logic [`MAX_DATA_BIT-1:0] c_out
);

//---------------------

//always_ff @(posedge clk) begin
//    out_data <= in_data;
//    out_weight <= in_weight;
//    out_weight_addr <= in_weight_addr;
//end
//
//always_ff @(posedge clk or negedge rst_n) begin
//    if (!rst_n) begin
//        out_data_valid <= 1'b0;
//        out_weight_valid <= 1'b0;
//    end else begin
//        out_data_valid <= in_data_valid;
//        out_weight_valid <= in_weight_valid;
//    end
//end
//
////---------------------
//
//logic [`MAX_DATA_BIT-1:0] tmp_weight;
//
//always_ff @(posedge clk) begin
//    if(&{in_weight_valid, in_weight_addr[2:0] == HEIGHT_ORDER}) begin
//        tmp_weight <= in_weight;
//    end
//end
//
//mac mac (
//    .clk          (clk),
//
//    .AB_precision (AB_precision),
//
//    .a            (in_data),
//    .b            (tmp_weight),
//    .c            (c_in),
//    .result       (c_out)
//);

//---------------------

//endmodule

// `timescale 1ns/1ps

// `include "top.svh"

// module tpu_cell #(
//     parameter                        HEIGHT_ORDER = 0
// ) (
//     input  logic                     clk,
//     input  logic                     rst_n,
    
//     input  logic [1:0]               n_size,
//     input  logic [2:0]               AB_precision,

//     input  logic [`MAX_DATA_BIT-1:0] in_data,
//     input  logic                     in_data_valid,

//     input  logic [`MAX_DATA_BIT-1:0] in_weight,
//     input  logic [4:0]               in_weight_addr,
//     input  logic                     in_weight_valid,

//     output logic [`MAX_DATA_BIT-1:0] out_data,
//     output logic                     out_data_valid,

//     output logic [`MAX_DATA_BIT-1:0] out_weight,
//     output logic [4:0]               out_weight_addr,
//     output logic                     out_weight_valid,

//     input  logic [`MAX_DATA_BIT-1:0] c_in,
//     output logic [`MAX_DATA_BIT-1:0] c_out
// );

//---------------------
//data flow
always_ff @(posedge clk) begin
    out_data <= in_data;
    out_weight <= in_weight;
    out_weight_addr <= in_weight_addr;
end

//control flow
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_data_valid <= 1'b0;
        out_weight_valid <= 1'b0;
    end else begin
        out_data_valid <= in_data_valid;
        out_weight_valid <= in_weight_valid;
    end
end

//---------------------

 logic [3:0][`MAX_DATA_BIT-1:0] weight_block;
 always_ff @(posedge clk) begin
     if(&{in_weight_valid, in_weight_addr[2:0] == HEIGHT_ORDER}) begin
        //block number, 8colum 1 block, maxium bolck =4
         case(in_weight_addr[4:3])
         2'b00:weight_block[0]<=in_weight;
         2'b01:weight_block[1]<=in_weight;
         2'b10:weight_block[2]<=in_weight;
         2'b11:weight_block[3]<=in_weight;
         endcase
     end 
 end

//-----------------------
 logic [1:0]       weight_counter;   // weight chose counter
 always_ff @(posedge clk) begin
     if (!rst_n) begin
        weight_counter <= 0;
    end else if (in_data_valid) begin
         case (n_size)
             2'd0: weight_counter <= 0;                        // 8 bit default 0
             2'd1: weight_counter <= (weight_counter + 1) % 2; // ret=0/1, cycle, which means weight_block[0]/weight_block[1] switch
             2'd2: weight_counter <= (weight_counter + 1) % 4; // ret=0/1/2/3 cycle, which means weight_block[0]/weight_block[1]/weight_block[2]/weight_block[3] switch
         endcase
     end
 end

 mac mac (
     .clk          (clk),
     .AB_precision (AB_precision),
     .a            (in_data),
     .b            (weight_block[weight_counter]),
     .c            (c_in),
     .result       (c_out)
 );

 endmodule