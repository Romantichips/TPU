`timescale 1ns/1ps

    //tip-func：用reg构成的类单极fifo，用于缓存数据，缓解data流压力，多打拍，提高f
module pipe_1_single #(
    parameter integer             DATA_WIDTH = 32
) (
    input  logic                  clk,
    input  logic                  rst,

//输入端（上游-本模块）：输入in_valid代表外部主机输入到该模块从机的数据有效；输出in_ready：该模块从机输入数据就绪，可以接受主机的外部输入。完成输入端数据的握手。
    output logic                  in_ready,
    input  logic                  in_valid,
    input  logic [DATA_WIDTH-1:0] in_data,

//输出端（本模块-下游）：输入out_ready代表外部端口（下游）已经准备好接受数据；输出out_valid：该模块从机输出数据有效，可以被主机接收。完成输出端数据的握手。
    input  logic                  out_ready,
    output logic                  out_valid,
    output logic [DATA_WIDTH-1:0] out_data
);

// -------------------------------------------

logic reg_flag; //寄存器标志位，标识reg中是否存在数据
logic enable_to_nxt; //能不能，允不允许向下发送
logic pre_to_nxt; //有没有数据向下发送，prepare（data）to next or not？

assign in_ready = ~reg_flag; //内部寄存器为空时，才可接收上游新数据。
//assign enable_to_nxt = ~{&{~out_ready, out_valid}}; //当下游就绪(out_ready=1) 或 当前输出本就无效(out_valid=0)时，允许传递。
assign enable_to_nxt = |{out_ready, ~out_valid}; 
//可有可无
assign pre_to_nxt = &{|{in_valid, reg_flag}, enable_to_nxt}; //data+control combine。当“有数据要发(新数据有效1 或 寄存器有缓存1)” 且 “允许传递” 时，out_valid应为高。

//Part1:Control flow
always_ff@(posedge clk `ifdef ASYNC_RST or posedge rst `endif) begin
    //SystemVerilog 预处理指令，ASYNC_RST=always_ff @(posedge clk or posedge rst) 
    if(rst) begin
        reg_flag <= 1'b0;
        out_valid <= 1'b0;
    end else begin
        reg_flag <= (reg_flag) ? (~enable_to_nxt) : (&{in_valid, ~enable_to_nxt});
        //寄存器有数据（1），看能不能发送，能（1），则发送过后flag=0；如果不能（0）则flag=1。
        //寄存器无数据（0），只有“不允许向下发送”+“外部有数据输入”，代表数据存在寄存器级，flag=1。

        //out_valid <= (enable_to_nxt) ? (|{in_valid, reg_flag}) : out_valid;
        out_valid <= (enable_to_nxt) ? pre_to_nxt : out_valid;
        //如果能向下发送（1），+有数据发送（1），那么自然输出有效的。如果不能向下发送，则keep。
    end
end

//Part2:Data flow
logic [DATA_WIDTH-1:0] reg_data;

always_ff @ (posedge clk) begin
    reg_data <= (reg_flag) ? reg_data : in_data; //寄存器标志位1则keep，无数据0则接收上游模块外部输入
    out_data <= (~enable_to_nxt) ? out_data : ((reg_flag) ? reg_data : in_data); //没准备好，不enable则keep；ok了看传的是寄存器数据还是外部数据
end

// -------------------------------------------
   
endmodule