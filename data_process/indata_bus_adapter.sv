`timescale 1ns/1ps //仿真时间单位为1ns，仿真时间精度为1ps

`include "top.svh"

// 3bits precison info 
// 3'b000 is int4, 3'b001 is int8, 3'b010 is fp16, 3'b011 is fp32, 3'b100 is int32

//1）based on address [17:16] and precision info, perform bit extension, (4,8,16,32) bit to 32bit for every TPU cell
//2）data2tpu_axi_awaddr[17:16] is 
module indata_bus_adapter #(
    parameter integer                DATA_WIDTH = 512
) (
    input  logic                     clk,
    input  logic                     rst_n,

    input  logic  [2:0]              AB_precision,
    input  logic  [2:0]              C_precision,

    input  logic  [7:0]              data2tpu_axi_awid   ,
    input  logic  [31:0]             data2tpu_axi_awaddr ,
    input  logic  [7:0]              data2tpu_axi_awlen  ,
    input  logic  [2:0]              data2tpu_axi_awsize ,
    input  logic  [1:0]              data2tpu_axi_awburst,
    input  logic  [0:0]              data2tpu_axi_awlock ,
    input  logic  [3:0]              data2tpu_axi_awcache,
    input  logic  [2:0]              data2tpu_axi_awprot ,
    input  logic  [3:0]              data2tpu_axi_awqos  ,
    input  logic                     data2tpu_axi_awvalid,
    output logic                     data2tpu_axi_awready,
    input  logic  [DATA_WIDTH-1:0]   data2tpu_axi_wdata  ,
    input  logic  [DATA_WIDTH/8-1:0] data2tpu_axi_wstrb  ,
    input  logic                     data2tpu_axi_wlast  ,
    input  logic                     data2tpu_axi_wvalid ,
    output logic                     data2tpu_axi_wready ,
    input  logic                     data2tpu_axi_bready ,
    output logic  [7:0]              data2tpu_axi_bid    ,
    output logic  [1:0]              data2tpu_axi_bresp  ,
    output logic                     data2tpu_axi_bvalid ,

    output logic                     data_valid   ,
    output logic  [1:0]              data_address ,
    output logic                     is_first_data,
    output logic  [DATA_WIDTH-1:0]   data         , //位宽拓展后的数据
    input  logic                     data_ready   
);

assign data2tpu_axi_bid = '0;
assign data2tpu_axi_bresp = '0;

// -------------------------------------------

/*always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data2tpu_axi_awready <= 1'b1;//默认就绪，可以接收地址
    end else begin
        if(data2tpu_axi_awready) begin
            if(data2tpu_axi_awvalid) begin
                data2tpu_axi_awready <= 1'b0;//已经接受地址，从机不可再接收地址
            end
        end else begin
            if(&{data2tpu_axi_bready, data2tpu_axi_bvalid}) begin
                data2tpu_axi_awready <= 1'b1;//本轮的写响应完成，准备接收下一个写地址
            end
        end
    end
end

logic bit_extend_ready;
logic data2tpu_axi_wready_pre;
//对于写入slave的data，扩展完毕后，data2tpu_axi_wready才能=1，接收下一批，否则背压
assign data2tpu_axi_wready = &{data2tpu_axi_wready_pre, bit_extend_ready};

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data2tpu_axi_wready_pre <= 1'b0;//不能随意就绪，等写地址完成才能开始写数据
    end else begin
        if(data2tpu_axi_wready_pre) begin
            if(&{data2tpu_axi_wvalid, data2tpu_axi_wready, data2tpu_axi_wlast}) begin
                data2tpu_axi_wready_pre <= 1'b0;//数据接收完毕，不再就绪
            end
        end else begin
            if(&{data2tpu_axi_awvalid, data2tpu_axi_awready}) begin
                data2tpu_axi_wready_pre <= 1'b1;
            end
        end
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data2tpu_axi_bvalid <= 1'b0;
    end else begin
        if(data2tpu_axi_bvalid) begin
            if(data2tpu_axi_bready) begin
                data2tpu_axi_bvalid <= 1'b0;//反压，相应已被接收
            end
        end else begin
            if(&{data2tpu_axi_wvalid, data2tpu_axi_wready, data2tpu_axi_wlast}) begin
                data2tpu_axi_bvalid <= 1'b1;
            end
        end
    end
end*/
// -------------------------------------------

//tip：不写状态机，没有idle态；3个态=3个reg，直接写控制流的输出
logic aw_reg;  
logic w_reg;   
logic b_reg;   

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        aw_reg <= 1'b1;
        w_reg  <= 1'b0;
        b_reg  <= 1'b0;
    end else begin
        if(data2tpu_axi_awvalid && data2tpu_axi_awready) begin
            aw_reg <= 1'b0;
            w_reg  <= 1'b1; 
        end
        else if(data2tpu_axi_wvalid && data2tpu_axi_wready && data2tpu_axi_wlast) begin
            w_reg  <= 1'b0;
            b_reg  <= 1'b1; 
        end
        else if(data2tpu_axi_bvalid && data2tpu_axi_bready) begin
            aw_reg <= 1'b1;
            b_reg  <= 1'b0; 
        end
    end
end

assign data2tpu_axi_awready = aw_reg; 

assign data2tpu_axi_wready = w_reg & bit_extend_ready;

assign data2tpu_axi_bvalid = b_reg;

// -------------------------------------------

//tip：显然精度有很多，但fp32和int32都是same bit，又lock_data_address只记录bit不care fp or int，∴需要归一化
// 2'b00 is A_address, 2'b01 is B_address, 2'b10 is C_address
logic [1:0] lock_data_address;

// 2'b00 is 4-bit, 2'b01 is 8bit, 2'b10 is 16-bit, 2'b11 is 32-bit
logic [1:0] lock_precision;

// 3bits precison info 
// 3'b000 is int4, 3'b001 is int8, 3'b010 is fp16, 3'b011 is fp32, 3'b100 is int32

//tip：top.svh里面存放了A,B,C的32bit地址。data2tpu_axi_awaddr传的就是这三个地址，又AB精度相同，C与AB可能不同，∴需要区分data2tpu_axi_awaddr到底是AB的地址 or C的地址范围？
//A addr[17:16]=00，B addr[17:16]=01，C addr[17:16]=10。确定了addr属于哪个地址范围再锁精度
//data2tpu_axi_awaddr[17:16]可以区分A,B,C ∵AB precison same bit ∴ for locking precision，only need recongnize AB and C
//lock_data_address&lock_precision：judge A/B/C, and precsion
always_ff @(posedge clk) begin
    if(&{data2tpu_axi_awvalid, data2tpu_axi_awready}) begin
        lock_data_address <= data2tpu_axi_awaddr[17:16];
        lock_precision <= (data2tpu_axi_awaddr[17]) ? ((C_precision[2]) ? 2'b11 : C_precision[1:0]) : ((AB_precision[2]) ? 2'b11 : AB_precision[1:0]);
    end
end

//lock_is_first_data：写数据的开始，每次burst第一个beat开始标志
logic lock_is_first_data;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        lock_is_first_data <= 1'b1;
    end else begin
        if(&{data2tpu_axi_wvalid, data2tpu_axi_wready}) begin
            if(data2tpu_axi_wlast) begin
                lock_is_first_data <= 1'b1;
            end else begin
                lock_is_first_data <= 1'b0;
            end
        end
    end
end

// -------------------------------------------

logic [1:0]            tmp_8bit_precision    ;
logic [1:0]            tmp_8bit_data_address ;
logic                  tmp_8bit_is_first_data;
logic [DATA_WIDTH-1:0] tmp_8bit_data         ;
logic                  tmp_8bit_valid        ;
logic                  tmp_8bit_ready        ;

data_expand #(
    .DATA_WIDTH                      (DATA_WIDTH),
    .VALID_BIT_WIDTH                 (4)
) data_expand_4bit_to_8bit (
    .clk                             (clk),
    .rst_n                           (rst_n),

    .in_precision                    (lock_precision),
    .in_data_address                 (lock_data_address),
    .in_is_first_data                (lock_is_first_data),
    .in_data                         (data2tpu_axi_wdata),
    //W handshake，really start to expand data
    .in_valid                        (&{data2tpu_axi_wvalid, data2tpu_axi_wready}),
    //output signal of inner module data_expand, in_ready=1 represent ready to expand new, in_ready=0 represent not ready, keep same data, backpressure
    .in_ready                        (bit_extend_ready),

    .condition_extend                (lock_precision == 2'b00),

    .out_precision                   (tmp_8bit_precision    ),
    .out_data_address                (tmp_8bit_data_address ),
    .out_is_first_data               (tmp_8bit_is_first_data),
    .out_data                        (tmp_8bit_data         ),
    .out_valid                       (tmp_8bit_valid        ),
    .out_ready                       (tmp_8bit_ready        )
);

// -------------------------------------------

logic [1:0]            tmp_16bit_precision    ;
logic [1:0]            tmp_16bit_data_address ;
logic                  tmp_16bit_is_first_data;
logic [DATA_WIDTH-1:0] tmp_16bit_data         ;
logic                  tmp_16bit_valid        ;
logic                  tmp_16bit_ready        ;

data_expand #(
    .DATA_WIDTH                      (DATA_WIDTH),
    .VALID_BIT_WIDTH                 (8)
) data_expand_8bit_to_16bit (
    .clk                             (clk),
    .rst_n                           (rst_n),

    .in_precision                    (tmp_8bit_precision    ),
    .in_data_address                 (tmp_8bit_data_address ),
    .in_is_first_data                (tmp_8bit_is_first_data),
    .in_data                         (tmp_8bit_data         ),
    .in_valid                        (tmp_8bit_valid        ),
    .in_ready                        (tmp_8bit_ready        ),

    //tmp_8bit_precision == 2'b00 represent orginal 4bit to 8bit, tmp_8bit_precision == 2'b01 represent original 8bit。不论4or8都经过上一级，同channel输出，只不过是否扩展的区别
    .condition_extend                (|{tmp_8bit_precision == 2'b00, tmp_8bit_precision == 2'b01}),

    .out_precision                   (tmp_16bit_precision    ),
    .out_data_address                (tmp_16bit_data_address ),
    .out_is_first_data               (tmp_16bit_is_first_data),
    .out_data                        (tmp_16bit_data         ),
    .out_valid                       (tmp_16bit_valid        ),
    .out_ready                       (tmp_16bit_ready        )
);

// -------------------------------------------

data_expand #(
    .DATA_WIDTH                      (DATA_WIDTH),
    .VALID_BIT_WIDTH                 (16)
) data_expand_16bit_to_32bit (
    .clk                             (clk),
    .rst_n                           (rst_n),

    .in_precision                    (tmp_16bit_precision    ),
    .in_data_address                 (tmp_16bit_data_address ),
    .in_is_first_data                (tmp_16bit_is_first_data),
    .in_data                         (tmp_16bit_data         ),
    .in_valid                        (tmp_16bit_valid        ),
    .in_ready                        (tmp_16bit_ready        ),

    .condition_extend                (|{tmp_16bit_precision == 2'b00, tmp_16bit_precision == 2'b01, tmp_16bit_precision == 2'b10}),

    .out_precision                   (),
    .out_data_address                (data_address),
    .out_is_first_data               (is_first_data),
    .out_data                        (data),
    .out_valid                       (data_valid),
    .out_ready                       (data_ready)
);

// -------------------------------------------

endmodule