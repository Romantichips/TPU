`timescale 1ns/1ps

`include "top.svh"

// 3bits precison info 
// 3'b000 is int4, 3'b001 is int8, 3'b010 is fp16, 3'b011 is fp32, 3'b100 is int32

// 2bits matrix size info
// 2'b00 is (m=32,n=8), 2'b01 is (m=16,n=16), 2'b10 is (m=8,n=32)

module cfg_fetch #(
    parameter integer                DATA_WIDTH = 512
) (
    input  logic                     clk,
    input  logic                     rst_n,

    // CFG to TPU
    input  logic [31:0]              cfg_axil_awaddr ,
    input  logic [2:0]               cfg_axil_awprot ,
    output logic                     cfg_axil_awready,
    input  logic                     cfg_axil_awvalid,
    input  logic [31:0]              cfg_axil_wdata  ,
    output logic                     cfg_axil_wready ,
    input  logic [3:0]               cfg_axil_wstrb  ,
    input  logic                     cfg_axil_wvalid ,
    input  logic                     cfg_axil_bready ,
    output logic [1:0]               cfg_axil_bresp  ,
    output logic                     cfg_axil_bvalid ,

    output logic [2:0]               AB_precision,
    output logic [2:0]               C_precision,
    output logic [2:0]               D_precision,

    // 2'b00 is (m=32,n=8), 2'b01 is (m=16,n=16), 2'b10 is (m=8,n=32)
    output logic [1:0]               n_size,

    output logic [31:0]              D_start_address
);

//FSM version1
/*
// state machine definition
typedef enum logic [1:0] {
    IDLE        = 2'b00,   // idle state
    WRITE_ADDR  = 2'b01,   // address receive
    WRITE_DATA  = 2'b10,   // data receive
    RESPONSE    = 2'b11    // response state
} state_t;

state_t current_state, next_state;

// latch register for address and data
logic [31:0] awaddr_reg;
logic [31:0] wdata_reg;

// -------------------------- state machine control ------------------------
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
        awaddr_reg    <= '0;
        wdata_reg     <= '0;
    end else begin
        // 状态跳转
        current_state <= next_state;

        // 地址锁存：在 IDLE 状态且地址握手完成（awvalid && awready）
        if (current_state == IDLE && cfg_axil_awvalid && cfg_axil_awready) begin
            awaddr_reg <= cfg_axil_awaddr;
        end

        // 数据锁存：在 WRITE_ADDR 状态且数据握手完成（wvalid && wready）
        if (current_state == WRITE_ADDR && cfg_axil_wvalid && cfg_axil_wready) begin
            wdata_reg <= cfg_axil_wdata;
        end
    end
end

// -------------------------- state machine combinational logic --------------------------
always_comb begin
    next_state = current_state;
    case(current_state)
        IDLE: begin
            // 地址通道握手完成（awvalid && awready）后进入 WRITE_ADDR
            if (cfg_axil_awvalid && cfg_axil_awready) begin
                next_state = WRITE_ADDR;
            end else begin
                next_state = IDLE;
            end
        end
        WRITE_ADDR: begin
            // 数据通道握手完成（wvalid && wready）后进入 WRITE_DATA
            if (cfg_axil_wvalid && cfg_axil_wready) begin
                next_state = WRITE_DATA;
            end else begin
                next_state = WRITE_ADDR;
            end
        end
        WRITE_DATA: begin
            // 固定跳转到 RESPONSE（无需条件），AXI Lite规范
            next_state = RESPONSE;
        end
        RESPONSE: begin
            // 响应通道握手完成（bready && bvalid）后回到 IDLE
            if (cfg_axil_bready && cfg_axil_bvalid) begin
                next_state = IDLE;
            end else begin
                next_state = RESPONSE;
            end
        end
        default: next_state = IDLE;
    endcase
end

// -------------------------- handshake signal control --------------------------
// 地址通道：仅在 IDLE 状态允许地址接收
assign cfg_axil_awready = (current_state == IDLE) ? 1'b1 : 1'b0;

// 数据通道：仅在 WRITE_ADDR 状态允许数据接收
assign cfg_axil_wready = (current_state == WRITE_ADDR) ? 1'b1 : 1'b0;

// 响应通道
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cfg_axil_bvalid <= 1'b0;
        cfg_axil_bresp  <= 2'b00; // OKAY
    end else begin
        case(current_state)
            // 在 WRITE_DATA 状态触发响应（bvalid）
            WRITE_DATA: begin
                cfg_axil_bvalid <= 1'b1;
                cfg_axil_bresp  <= 2'b00; // OKAY
            end
            // 在 RESPONSE 状态等待 bready 完成握手
            RESPONSE: begin
                if (cfg_axil_bready) begin
                    cfg_axil_bvalid <= 1'b0; // 响应完成后清除
                end
            end
            default: begin
                cfg_axil_bvalid <= 1'b0;
                cfg_axil_bresp  <= 2'b00;
            end
        endcase
    end
end
*/

// 经典三段状态机写法
localparam IDLE     = 2'b00;
localparam AW_ADDR  = 2'b01;
localparam W_DATA   = 2'b10;
localparam B_RESP   = 2'b11;

reg [1:0] cur_state;
reg [1:0] nxt_state;

// 时序逻辑写cur_state
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) cur_state <= IDLE;
    else       cur_state <= nxt_state;
end

// 组合逻辑写nxt_state
always_comb  begin
    nxt_state = cur_state;
    case(cur_state)
        IDLE: begin
            if(cfg_axil_awvalid) 
                nxt_state = AW_ADDR;
        end
        AW_ADDR: begin
            if(cfg_axil_awvalid && cfg_axil_awready) 
                nxt_state = W_DATA;
        end
        W_DATA: begin
            if(cfg_axil_wvalid && cfg_axil_wready) 
                nxt_state = B_RESP;
        end
        B_RESP: begin
            if(cfg_axil_bvalid && cfg_axil_bready) 
                nxt_state = IDLE;
        end
        default: nxt_state = IDLE;
    endcase
end

// 时序逻辑写Output(控制流)
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cfg_axil_awready <= 1'b0;
        cfg_axil_wready  <= 1'b0;
        cfg_axil_bvalid  <= 1'b0;
        cfg_axil_bresp   <= 2'b00;
    end
    else begin
        case(cur_state)
            IDLE: begin
                cfg_axil_awready <= 1'b0;
                cfg_axil_wready  <= 1'b0;
                cfg_axil_bvalid  <= 1'b0;
                cfg_axil_bresp   <= 2'b00;
            end
            AW_ADDR: begin
                //cfg_axil_awready <= 1;   // Moore：仅依靠当前状态，不依靠外部输入
                cfg_axil_awready <= cfg_axil_awvalid;   // Mealy：输出依赖外部aw_valid
                cfg_axil_wready  <= 1'b0;
                cfg_axil_bvalid  <= 1'b0;
                cfg_axil_bresp   <= 2'b00;
            end
            W_DATA: begin
                //cfg_axil_wready  <= 1;    // Moore：仅依靠当前状态，不依靠外部输入
                cfg_axil_awready <= 1'b0;
                cfg_axil_wready  <= cfg_axil_wvalid;    // Mealy：输出依赖外部w_valid
                cfg_axil_bvalid  <= 1'b0;
                cfg_axil_bresp   <= 2'b00;
            end
            B_RESP: begin
                cfg_axil_awready <= 1'b0;
                cfg_axil_wready  <= 1'b0;
                //cfg_axil_bvalid  <= 1;    // Moore：仅依靠当前状态，不依靠外部输入
                cfg_axil_bvalid  <= cfg_axil_bready;     // Mealy：输出依赖外部b_ready
                cfg_axil_bresp   <= 2'b00;
            end
            default: begin
                cfg_axil_awready <= 1'b0;
                cfg_axil_wready  <= 1'b0;
                cfg_axil_bvalid  <= 1'b0;
                cfg_axil_bresp   <= 2'b00;
            end
        endcase
    end
end

// 时序逻辑写Output(数据流)

// latch register for address and data
logic [31:0] awaddr_reg;
logic [31:0] config_reg0; // Address 0x0000_0000
logic [31:0] config_reg4; // Address 0x0000_0004

// Ch1:AW addr reg
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        awaddr_reg <= '0;
    end
    else if( (cur_state == AW_ADDR) && cfg_axil_awvalid && cfg_axil_awready ) begin
        awaddr_reg <= cfg_axil_awaddr;  
    end
    else begin
        awaddr_reg <= awaddr_reg;   
    end
end

// Ch2:W data reg
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        config_reg0 <= '0;
        config_reg4 <= '0;
    end else 
        if ((cur_state == W_DATA) && cfg_axil_wready && cfg_axil_wvalid) begin
            case(awaddr_reg)
                32'h0000_0000: config_reg0 <= cfg_axil_wdata;
                32'h0000_0004: config_reg4 <= cfg_axil_wdata;
                default: ;                                  // ignore other addresses    
            endcase
    end else begin
        config_reg0 <= config_reg0;
        config_reg4 <= config_reg4;
    end
end

// output logic
assign D_precision     = config_reg0[10:8]; // 3 bits
assign C_precision     = config_reg0[7:5];  // 3 bits
assign AB_precision    = config_reg0[4:2];  // 3 bits
assign n_size          = config_reg0[1:0];  // 2 bits
assign D_start_address = config_reg4;

// data[10:0] in cfg_axil_awaddr 0x0000_0000 is {D_precision, C_precision, AB_precision, n_size}
// data[31:0] in cfg_axil_awaddr 0x0000_0004 is D_start_address

// -------------------------------------------

endmodule