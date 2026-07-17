`timescale 1ns/1ps

`include "top.svh"

module data_tilt #(
    parameter integer                DATA_WIDTH = 512
) (
    input  logic                     clk,
    input  logic                     rst_n,
    
    input  logic [DATA_WIDTH-1:0]    in_data      ,
    input  logic                     in_data_valid,

    //Tip1:很重要的是，该模块在实现单32bit数据时延的同时，将原本1 valid 1 line的valid 信号拆分成了16个valid, 1 valid 1 data，16 valid 1 line
    output logic [`TPU_WIDTH-1:0][`MAX_DATA_BIT-1:0] out_data,
    output logic [`TPU_WIDTH-1:0]                    out_data_valid
    // no ready to handshake, cause 1)TPU的握手需求通常存在于上游的AXI，下游数据处理直接运行 2）该模块无fifo等寄存器，不会暂停，所谓的tmp不过是流水线移位操作，不会暂停 3）如果ready=0反压，那么下游没法继续延时每一块数据了
);

// Tip2:The delay value between neighboring out_data (out_data_valid) is `ADD_DELAY\
// 2个data为例，dataA进入PE1，做乘积时间为t1,做加法时间为t2，显然dataA在该PE1里面用时t1+t2。dataB在t2时进入PE2，经过乘积时间t1，正好到了t1+t2时刻，直接搬PE1的乘加结果作为PE2加法操作的一部分，无延时

// a blocked data seperated into singel datas
logic [`TPU_WIDTH-1:0][`MAX_DATA_BIT-1:0] data_in_split;
genvar i;
generate
    for (i=0; i<`TPU_WIDTH; i++) begin
        assign data_in_split[i] = in_data[(i+1)*`MAX_DATA_BIT - 1 -: `MAX_DATA_BIT];
    end
endgenerate

// Delayed data and valid signals
logic [`TPU_WIDTH-1:0][`MAX_DATA_BIT-1:0] tmp_data;
logic [`TPU_WIDTH-1:0]                    tmp_valid;

// Instantiate delay modules for each channel
generate
    for (i=0; i<`TPU_WIDTH; i++) begin
        // Data(Data) delay instance
        delay #(
            .WIDTH_NUM(`MAX_DATA_BIT),
            .DELAY_NUM(i * `ADD_DELAY)
        ) data_delay_inst (
            .clk(clk),
            .data_in(data_in_split[i]),
            .data_out(tmp_data[i])
        );

        // Valid(Control) delay instance
        delay #(
            .WIDTH_NUM(1),
            .DELAY_NUM(i * `ADD_DELAY)
        ) valid_delay_inst (
            .clk(clk),
            .data_in(in_data_valid),
            .data_out(tmp_valid[i])
        );
    end
endgenerate

//Tip:delay output signal cannot directly connect to out_data_valid and out_data, cause for control flow, has rst_n reset, but for delay module, no reset
// Control flow:tmp2out
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_data_valid <= '0;
    end else begin
        out_data_valid <= tmp_valid;
    end
end

// Data flow:tmp2out
always_ff @(posedge clk) begin
    out_data <= tmp_data;
end

// -------------------------------------------

endmodule