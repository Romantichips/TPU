// -------------------------------------------
// Author:  
// Version: 0.1
// Date:    2024-09-06
// -------------------------------------------

`include "top.svh"

module xxm_scfifo #(
    parameter                              MEMORY_TYPE = "auto", // "auto", "block", "distributed", "ultra"
    parameter integer                      DATA_WIDTH  = 32,
    parameter integer                      FIFO_DEPTH  = 32,
    parameter integer                      PROG_FULL_THRESH = FIFO_DEPTH-8
) (
    input  logic                           clk,
    input  logic                           rst,

    input  logic [DATA_WIDTH-1:0]          in_data,
    input  logic                           wrreq,
    output logic [$clog2(FIFO_DEPTH):0]    usedw,
    output logic                           full,
    output logic                           prog_full,

    input  logic                           rdreq,
    output logic [DATA_WIDTH-1:0]          out_data,
    output logic                           empty
);

// -------------------------------------------

xxm_scfifo_mixed_width #(
    .MEMORY_TYPE         (MEMORY_TYPE     ),
    .WR_DATA_WIDTH       (DATA_WIDTH      ),
    .WR_FIFO_DEPTH       (FIFO_DEPTH      ),
    .RD_DATA_WIDTH       (DATA_WIDTH      ),
    .PROG_FULL_THRESH    (PROG_FULL_THRESH)
) xxm_scfifo_mixed_width (
    .clk                 (clk      ),
    .rst                 (rst      ),

    .in_data             (in_data  ),
    .wrreq               (wrreq    ),
    .usedw               (usedw    ),
    .full                (full     ),
    .prog_full           (prog_full),

    .rdreq               (rdreq    ),
    .out_data            (out_data ),
    .empty               (empty    )
);

// -------------------------------------------

endmodule