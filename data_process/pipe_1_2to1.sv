`timescale 1ns/1ps

    //tip 1) single ch valid（in端3个信号），而其他ch无效，则一直输出该通道；若都有效，采用channel_voter交替输出，仲裁轮询器缓解数据压力，防止单通道阻塞，均分带宽
module pipe_1_2to1 #(
    parameter integer             DATA_WIDTH          = 32,
    parameter integer             ENABLE_CH0_PRIORITY = 0
) (
    input  logic                  clk,
    input  logic                  rst,

    output logic                  in_0_ready,
    input  logic                  in_0_valid,
    input  logic [DATA_WIDTH-1:0] in_0_data,

    output logic                  in_1_ready,
    input  logic                  in_1_valid,
    input  logic [DATA_WIDTH-1:0] in_1_data,

    input  logic                  out_ready,
    output logic                  out_valid,
    output logic [DATA_WIDTH-1:0] out_data,
    output logic                  out_id// 0 for ch 0, 1 for ch 1
);

//------------------------------

// channel_voter and ENABLE_CH0_PRIORITY cfg
logic channel_voter; // 0 for ch 0, 1 for ch 1

generate
    //ENABLE_CH0_PRIORITY=1, always ch0
    if(ENABLE_CH0_PRIORITY) begin : fixed_channel_voter

        assign channel_voter = 1'b0;

    end else begin : no_fixed_channel_voter

        always_ff@(posedge clk `ifdef ASYNC_RST or posedge rst `endif) begin
            if(rst) begin
                //default channel 0
                channel_voter <= 1'b0;
            end else begin
                //out_valid, out_ready握手完成一次输出，更换channel，交替输出，防止单一channel占据高带宽
                channel_voter <= (&{out_valid, out_ready}) ? ~out_id : channel_voter;
            end
        end

    end

endgenerate

//--------------------------------

logic                  out_0_ready;
logic                  out_0_valid;
logic [DATA_WIDTH-1:0] out_0_data;

logic                  out_1_ready;
logic                  out_1_valid;
logic [DATA_WIDTH-1:0] out_1_data;

assign out_valid = out_0_valid | out_1_valid;
assign out_data = (out_id) ? out_1_data : out_0_data;

always_comb begin
    casex({out_0_valid, out_1_valid, channel_voter})
        3'b10X, 3'b110: begin 
            out_0_ready = out_ready;
            out_1_ready = 1'b0;
            out_id = 1'b0;
        end
        3'b01X, 3'b111: begin 
            out_0_ready = 1'b0;
            out_1_ready = out_ready;
            out_id = 1'b1;
        end
        default: begin 
            out_0_ready = out_ready;
            out_1_ready = 1'b0;
            out_id = 1'b0;
        end
    endcase
end

pipe_1_single #(
    .DATA_WIDTH           (DATA_WIDTH )
) pipe_1_single_inst0 (
    .clk                  (clk        ),
    .rst                  (rst        ),

    .in_ready             (in_0_ready ),
    .in_valid             (in_0_valid ),
    .in_data              (in_0_data  ),

    .out_ready            (out_0_ready),
    .out_valid            (out_0_valid),
    .out_data             (out_0_data ) 
);

pipe_1_single #(
    .DATA_WIDTH           (DATA_WIDTH )
) pipe_1_single_inst1 (
    .clk                  (clk        ),
    .rst                  (rst        ),

    .in_ready             (in_1_ready ),
    .in_valid             (in_1_valid ),
    .in_data              (in_1_data  ),

    .out_ready            (out_1_ready),
    .out_valid            (out_1_valid),
    .out_data             (out_1_data ) 
);

// -------------------------------------------
    
endmodule