`timescale 1ns/1ps

module pipe_1_1to2 #(
    parameter integer             DATA_WIDTH = 32
    //no actual meaning, just reference, actual width由例化该模块的大模块赋值
    //tip:将1股data根据id写进单极fifo的某个channel中（共2个）
) (
    input  logic                  clk,
    input  logic                  rst,

    output logic                  in_ready,
    input  logic                  in_valid,
    input  logic                  in_id, // 0 for ch 0, 1 for ch 1
    input  logic [DATA_WIDTH-1:0] in_data,

    input  logic                  out_0_ready,
    output logic                  out_0_valid,
    output logic [DATA_WIDTH-1:0] out_0_data,

    input  logic                  out_1_ready,
    output logic                  out_1_valid,
    output logic [DATA_WIDTH-1:0] out_1_data
);

//func：depand on diff channel id, transfer data to the corresponding channel (0 or 1)

// -------------------------------------------

logic in_0_ready;
logic in_1_ready;
//assign in_ready = (in_id) ? in_1_ready : in_0_ready;

pipe_1_single #(
    .DATA_WIDTH           (DATA_WIDTH         )
) pipe_1_single_inst0 (
    .clk                  (clk                ),
    .rst                  (rst                ),

    .in_ready             (in_0_ready         ),
    .in_valid             (in_valid & (~in_id)),
    .in_data              (in_data            ),

    .out_ready            (out_0_ready        ),
    .out_valid            (out_0_valid        ),
    .out_data             (out_0_data         ) 
);

pipe_1_single #(
    .DATA_WIDTH           (DATA_WIDTH         )
) pipe_1_single_inst1 (
    .clk                  (clk                ),
    .rst                  (rst                ),

    .in_ready             (in_1_ready         ),
    .in_valid             (in_valid & ( in_id)),
    .in_data              (in_data            ),

    .out_ready            (out_1_ready        ),
    .out_valid            (out_1_valid        ),
    .out_data             (out_1_data         ) 
);

// -------------------------------------------
    
endmodule