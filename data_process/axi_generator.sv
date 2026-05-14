`timescale 1ns/1ps

`include "top.svh"

//func:based on D precision and D address, generate AXI sequence
module axi_generator #(
    parameter integer                DATA_WIDTH = 512
) (
    input  logic                     clk,
    input  logic                     rst_n,

    //addr:D_start_address; write:in_data

    //logic [2:0] precision, 3'd0 is int4, 3'd1 is int8, 3'd2 is fp16, 3'd3 is fp32, 3'd4 is int32
    input  logic [2:0]               D_precision,
    input  logic [31:0]              D_start_address,

    //complete data
    input  logic [DATA_WIDTH-1:0]    in_data,
    input  logic                     in_data_valid,

    // TPU to data
    output logic [7:0]               tpu2data_axi_awid   ,
    output logic [31:0]              tpu2data_axi_awaddr ,
    output logic [7:0]               tpu2data_axi_awlen  ,
    output logic [2:0]               tpu2data_axi_awsize ,
    output logic [1:0]               tpu2data_axi_awburst,
    output logic [0:0]               tpu2data_axi_awlock ,
    output logic [3:0]               tpu2data_axi_awcache,
    output logic [2:0]               tpu2data_axi_awprot ,
    output logic [3:0]               tpu2data_axi_awqos  ,
    output logic                     tpu2data_axi_awvalid,
    input  logic                     tpu2data_axi_awready,
    output logic [DATA_WIDTH-1:0]    tpu2data_axi_wdata  ,
    output logic [DATA_WIDTH/8-1:0]  tpu2data_axi_wstrb  ,
    output logic                     tpu2data_axi_wlast  ,
    output logic                     tpu2data_axi_wvalid ,
    input  logic                     tpu2data_axi_wready ,
    output logic                     tpu2data_axi_bready ,
    input  logic [7:0]               tpu2data_axi_bid    ,
    input  logic [1:0]               tpu2data_axi_bresp  ,
    input  logic                     tpu2data_axi_bvalid 
);

// -------------------------------------------

//AXI：1-8bit, diff bit diff 事务，一次发射一个awid，多并发/乱序发射，B依靠awid相应，这里awid固定为0，单事务发射
assign tpu2data_axi_awid = '0;

//决定单次beat传输的字节数，awsize=6, 1 awsize 1 byte per beat, 6 size 64 byte per beat, 512 bit in one beat（对应512bit）∴fixed
assign tpu2data_axi_awsize = 3'b110;

//awburst: 2bit fix，00 is fixed（fixed fifo write data）, 01 is incr(addr increase), 10 is wrap(boundry back), 11 is reserved(forbbiden), 因为是连续传输数据，所以选择01 incr
assign tpu2data_axi_awburst = 2'b01;

//awlock: 1bit , 0 is normal（普通传输）, 1 is exclusive, 因为没有多master竞争，所以选择0 normal
assign tpu2data_axi_awlock = '0;

//4 bit, C3 Write Allocate；C2 Read Allocate；C1 Bufferable；C0 Cacheable, 这里固定为0，表示不使用cache
assign tpu2data_axi_awcache = '0;

//3 bit fixed, AWPROT[2:0] 三层定义：Bit2：0 = 非特权级 / 1 = 特权级、Bit1：0 = 安全访问 / 1 = 非安全访问、Bit0：0 = 数据访问 / 1 = 指令访问
assign tpu2data_axi_awprot = '0;

//4bit, value bigger more priority,多主机（GPU+TPU+CPU 抢总线）：给高优先级设备设大数值
assign tpu2data_axi_awqos = '0;

//bit of wstrb is DATA_WIDTH/8, 1 bit per byte, 512 bit data width has 64 byte, so 64 bit wstrb, all valid, fixed, bit(x)=1 means corresponding byte is valid, 0 means invalid
assign tpu2data_axi_wstrb = '1;

// -------------------------------------------


//m*n=256 const，if D=int8 , 1 beat contains 512/8=64 data, need 256/64=4 beats, and 2的（1+1）次幂-1=4-1，3+1=4，other precision same logic

//计算传输的beats（beat=awlen+1), 1 beat 1 512 bit in_data
always_ff @(posedge clk) begin
    tpu2data_axi_awaddr <= D_start_address;
    if(D_precision > 3'd3) begin
    //2 << D_precision = 2的（D_precision（demical）+1）次幂
        tpu2data_axi_awlen <= (2 << 3'd3) - 1'b1;
    end else begin
        tpu2data_axi_awlen <= (2 << D_precision) - 1'b1;
    end
end

//----------------------------------------------
//special state machine writing
localparam IDLE_STATE  = 3'b000;
localparam AW_STATE    = 3'b001;
localparam W_STATE     = 3'b010;
localparam B_STATE     = 3'b100;

logic tpu2data_axi_wvalid_pre;

logic [2:0] state;
logic [2:0] next_state;
assign {tpu2data_axi_bready, tpu2data_axi_wvalid_pre, tpu2data_axi_awvalid} = state;

wire [3:0] input_vector;
assign input_vector = {tpu2data_axi_bvalid, &{tpu2data_axi_wlast, tpu2data_axi_wready}, tpu2data_axi_awready, in_data_valid};

always_comb begin
    casex ({state, input_vector})
        {IDLE_STATE, 4'bXXX1}: begin next_state = AW_STATE  ; end
        {AW_STATE  , 4'bXX1X}: begin next_state = W_STATE   ; end
        {W_STATE   , 4'bX1XX}: begin next_state = B_STATE   ; end
        {B_STATE   , 4'b1XXX}: begin next_state = IDLE_STATE; end
        default:               begin next_state = state     ; end
    endcase
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE_STATE;
    else
        state <= next_state;
end

// -------------------------------------------

//cnt: cnt max = awlen+1,传输的总beat数，beat计数器
logic [3:0] cnt;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tpu2data_axi_wlast <= 1'b0;
        cnt <= 4'd0;
    end else begin
        if(&{tpu2data_axi_wvalid, tpu2data_axi_wready}) begin
            //in macro, D is 32bit , 1 beat contains 512/32=16 data, need 256/16=16 beats, 0-e =16 beats, max cnt is 15, e
            //if(cnt == 4'h(tpu2data_axi_awlen)) begin
            if(cnt == 4'hf) begin
                tpu2data_axi_wlast <= 1'b1;
                cnt <= 4'd0;
            end else begin
                tpu2data_axi_wlast <= 1'b0;
                cnt <= cnt + 1'b1;
            end
        end else tpu2data_axi_wlast <= 1'b0;
                 cnt <= 4'd0;
        /*else if(&{tpu2data_axi_bvalid, tpu2data_axi_bready}) begin
            tpu2data_axi_wlast <= 1'b0;
            cnt <= 4'd0;
        end*/
    end
end

logic [DATA_WIDTH-1:0] tmp_data;

// data and valid of W stage align, 2 pipe, could be more if need more frequency, but more could waste more area
//关键路径延时太长。直接输出：组合逻辑路径长，建立时间违例 → 跑不高频率。多拍打拍：切割长路径为短路径，每一级寄存器只需要驱动一小段逻辑 → 时序裕量提升，跑高频
always_ff @(posedge clk) begin
    tmp_data <= in_data;
    tpu2data_axi_wdata <= tmp_data;
end

logic tmp_tpu2data_axi_wvalid;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tmp_tpu2data_axi_wvalid <= 1'b0;
        tpu2data_axi_wvalid <= 1'b0;
    end else begin
        tmp_tpu2data_axi_wvalid <= in_data_valid;
        tpu2data_axi_wvalid <= tmp_tpu2data_axi_wvalid;
    end
end

// -------------------------------------------

//1)尽管IDLE_STATE时当in_data_valid=1时过2拍到W_STATE，但若想要高频，data和valid同步打多拍，显然state里是不能放tpu2data_axi_wvalid的，因为描述的组合逻辑只有两拍，而data和valid必须同步
//2）data和valid必须同步
//3）master先发valid,slave才能ready；不能反过来，否则一直等不到ready,valid一直=0，死锁

endmodule