`timescale 1ns/1ps

`include "top.svh"

//logic [2:0] precision, 3'd0 is int4, 3'd1 is int8, 3'd2 is fp16, 3'd3 is fp32, 3'd4 is int32
function [2:0] get_precision;
    input [31:0] data;
    if(data == 4) begin
        get_precision = 3'b000;
    end else if(data == 8) begin
        get_precision = 3'b001;
    end else if(data == 32) begin
        get_precision = 3'b100;
    end else begin
        $display("*E, parameter error in %m");
        $finish();
    end
endfunction
//logic [1:0] n_size, 2'd0 is 8, 2'd1 is 16, 2'd2 is 32
function [1:0] get_n_size;
    input [31:0] data;
    if(data == 8) begin
        get_n_size = 2'b00;
    end else if(data == 16) begin
        get_n_size = 3'b01;
    end else if(data == 32) begin
        get_n_size = 3'b10;
    end else begin
        $display("*E, parameter error in %m");
        $finish();
    end
endfunction

module tpu_test #(
    parameter integer                DATA_WIDTH = 512
) (
    input  logic                     clk,
    input  logic                     rst_n,

    // data to TPU
    output logic  [7:0]              data2tpu_axi_awid   ,
    output logic  [31:0]             data2tpu_axi_awaddr ,
    output logic  [7:0]              data2tpu_axi_awlen  ,
    output logic  [2:0]              data2tpu_axi_awsize ,
    output logic  [1:0]              data2tpu_axi_awburst,
    output logic  [0:0]              data2tpu_axi_awlock ,
    output logic  [3:0]              data2tpu_axi_awcache,
    output logic  [2:0]              data2tpu_axi_awprot ,
    output logic  [3:0]              data2tpu_axi_awqos  ,
    output logic                     data2tpu_axi_awvalid,
    input  logic                     data2tpu_axi_awready,
    output logic  [DATA_WIDTH-1:0]   data2tpu_axi_wdata  ,
    output logic  [DATA_WIDTH/8-1:0] data2tpu_axi_wstrb  ,
    output logic                     data2tpu_axi_wlast  ,
    output logic                     data2tpu_axi_wvalid ,
    input  logic                     data2tpu_axi_wready ,
    output logic                     data2tpu_axi_bready ,
    input  logic  [7:0]              data2tpu_axi_bid    ,
    input  logic  [1:0]              data2tpu_axi_bresp  ,
    input  logic                     data2tpu_axi_bvalid ,

    // CFG to TPU
    output logic [31:0]              cfg_axil_awaddr ,
    output logic [2:0]               cfg_axil_awprot ,
    input  logic                     cfg_axil_awready,
    output logic                     cfg_axil_awvalid,
    output logic [31:0]              cfg_axil_wdata  ,
    input  logic                     cfg_axil_wready ,
    output logic [3:0]               cfg_axil_wstrb  ,
    output logic                     cfg_axil_wvalid ,
    output logic                     cfg_axil_bready ,
    input  logic [1:0]               cfg_axil_bresp  ,
    input  logic                     cfg_axil_bvalid ,
    
    // TPU to data
    input  logic [7:0]               tpu2data_axi_awid  ,
    input  logic [31:0]              tpu2data_axi_awaddr,
    input  logic [7:0]               tpu2data_axi_awlen ,
    input  logic [2:0]               tpu2data_axi_awsize,
    input  logic [1:0]               tpu2data_axi_awburst,
    input  logic [0:0]               tpu2data_axi_awlock ,
    input  logic [3:0]               tpu2data_axi_awcache,
    input  logic [2:0]               tpu2data_axi_awprot ,
    input  logic [3:0]               tpu2data_axi_awqos  ,
    input  logic                     tpu2data_axi_awvalid,
    output logic                     tpu2data_axi_awready,
    input  logic [DATA_WIDTH-1:0]    tpu2data_axi_wdata  ,
    input  logic [DATA_WIDTH/8-1:0]  tpu2data_axi_wstrb  ,
    input  logic                     tpu2data_axi_wlast  ,
    input  logic                     tpu2data_axi_wvalid ,
    output logic                     tpu2data_axi_wready ,
    input  logic                     tpu2data_axi_bready ,
    output logic [7:0]               tpu2data_axi_bid    ,
    output logic [1:0]               tpu2data_axi_bresp  ,
    output logic                     tpu2data_axi_bvalid 
);

//tip_delay=0.5个T，半个周期，稳定信号
localparam real tip_delay = 0.5;

// -------------------------------------------

assign data2tpu_axi_awid = '0;
assign data2tpu_axi_awsize = '0;
assign data2tpu_axi_awburst = 2'b01;
assign data2tpu_axi_awlock = '0;
assign data2tpu_axi_awcache = '0;
assign data2tpu_axi_awprot = '0;
assign data2tpu_axi_awqos = '0;
assign data2tpu_axi_wstrb = '1;
assign data2tpu_axi_bready = 1'b1;

assign cfg_axil_awprot = '0;
assign cfg_axil_wstrb = '1;
assign cfg_axil_bready = 1'b1;

assign tpu2data_axi_bid = '0;
assign tpu2data_axi_bresp = '0;

// -------------------------------------------

// DATA_WIDTH parameter check
initial begin
    if(DATA_WIDTH != `TPU_WIDTH*`MAX_DATA_BIT) begin
        $display("*E, DATA_WIDTH in %m, is unexpected\n");
        $finish;
    end
end

// -------------------------------------------

logic [`M_DIM-1:0][`TPU_WIDTH-1:0][`AB_PRECISION-1:0] matrix_A;
logic [`TPU_WIDTH-1:0][`N_DIM-1:0][`AB_PRECISION-1:0] matrix_B;
logic [`M_DIM    -1:0][`N_DIM-1:0][`C_PRECISION -1:0] matrix_C;

logic [DATA_WIDTH-1:0] B_queue [$];
logic [DATA_WIDTH-1:0] C_queue [$];
logic [DATA_WIDTH-1:0] A_queue [$];
logic [DATA_WIDTH-1:0] D_ref_queue [$];

//initial验证专用，初始化信号，防止不定态X，只执行1次，不可综合
initial begin
    cfg_axil_awaddr = '0;
    cfg_axil_awvalid = 1'b0;
    cfg_axil_wdata = '0;
    cfg_axil_wvalid = 1'b0;
end

//----------------------------------------------

task data_to_queue ();
//tip:1)A,B,C,D data2queue 2）cfg2data，写入2个reg（addr0/addr4）
    integer i, j, k, order;
    logic [DATA_WIDTH-1:0] word_data;
    logic [31:0] tmp_data;

    //clk一直周期性波动；rst_n先=1，再=0（复位状态，不相应任何输入），再=1（释放复位，正常由clk驱动）
    // wait reset release
    @(posedge clk);
    #tip_delay;
    wait(1 == rst_n);
    #tip_delay;

    // prepare data
    for(i=0;i<`M_DIM;i=i+1) begin
        for(k=0;k<`TPU_WIDTH;k=k+1) begin
            //matrix_A[i][k] = 1;
            matrix_A[i][k] = $random;
        end
    end
    for(k=0;k<`TPU_WIDTH;k=k+1) begin
        for(j=0;j<`N_DIM;j=j+1) begin
            // matrix_B[k][j] = 1;
            matrix_B[k][j] = $random;
            //matrix_B[k][j] = k + j * `TPU_WIDTH;
        end
    end
    for(i=0;i<`M_DIM;i=i+1) begin
        for(j=0;j<`N_DIM;j=j+1) begin
            //matrix_C[i][j] = 2;
            matrix_C[i][j] = $random;
        end
    end

    //计算结果放到D，参考结果队列
    D_ref_queue = {};
    order = 0;
    for(i=0;i<`M_DIM;i=i+1) begin
        for(j=0;j<`N_DIM;j=j+1) begin
            tmp_data = matrix_C[i][j];
            for(k=0;k<`TPU_WIDTH;k=k+1) begin
                tmp_data = tmp_data + matrix_A[i][k] * matrix_B[k][j];
            end
            // improve truncation in the future
            //tmp_data被D精度截取后每次拼接到高位
            word_data = {tmp_data[`D_PRECISION-1:0], word_data[DATA_WIDTH-1:`D_PRECISION]};
            order = order + 1;
            if(order == (DATA_WIDTH/`D_PRECISION)) begin
                //word_data被截取后的tmp_data拼接满512bit放回D_ref_queue
                D_ref_queue.push_back(word_data);
                order = 0;
            end
        end
    end

    // cfg-addr0
    //tip:cfg_axil_valid由initial的0 -- 1（输出） -- 0（等待ready握手结束置零）

    @(posedge clk);
    #tip_delay;
    //cfg_axil_awvalid,cfg_axil_wvalid=1确保输出有效
    cfg_axil_awaddr = 32'd0;
    cfg_axil_awvalid = 1'b1;
    cfg_axil_wdata = {21'd0, get_precision(`D_PRECISION), get_precision(`C_PRECISION), get_precision(`AB_PRECISION), get_n_size(`N_DIM)};
    cfg_axil_wvalid = 1'b1;
    fork
        //2 AW/W task 同时进行
        begin
            //AW handshake
            do begin
                @(negedge clk);
                #tip_delay;
            end while(~cfg_axil_awready);
            //cfg_axil_awready=0，input awready没准好，一直等
            //等待cfg_axil_awready=1，AW握手结束，cfg_axil_awvalid = 1'b0
            @(posedge clk);
            #tip_delay;
            cfg_axil_awvalid = 1'b0;
        end
            //W handshake
        begin
            do begin
                @(negedge clk);
                #tip_delay;
            end while(~cfg_axil_wready);
            //cfg_axil_wready=0，input wready没准好，一直等
            //等待cfg_axil_wready=1，W握手结束，cfg_axil_wvalid = 1'b0
            @(posedge clk);
            #tip_delay;
            cfg_axil_wvalid = 1'b0;
        end
    join
    @(negedge clk);
    #tip_delay;
    //等待cfg_axil_bvalid=1，B握手结束，写响应完成
    wait(cfg_axil_bvalid);

    // cfg-addr4
    @(posedge clk);
    #tip_delay;
    cfg_axil_awaddr = 32'd4;
    cfg_axil_awvalid = 1'b1;
    cfg_axil_wdata = `D_START_ADDRESS;
    cfg_axil_wvalid = 1'b1;
    fork
        begin
            do begin
                @(negedge clk);
                #tip_delay;
            end while(~cfg_axil_awready);
            @(posedge clk);
            #tip_delay;
            cfg_axil_awvalid = 1'b0;
        end
        begin
            do begin
                @(negedge clk);
                #tip_delay;
            end while(~cfg_axil_wready);
            @(posedge clk);
            #tip_delay;
            cfg_axil_wvalid = 1'b0;
        end
    join
    @(negedge clk);
    #tip_delay;
    wait(cfg_axil_bvalid);

    // weight
    B_queue = {};
    order = 0;
    for(j=0;j<`N_DIM;j=j+1) begin
        for(k=0;k<`TPU_WIDTH;k=k+1) begin
            word_data = {matrix_B[k][j], word_data[DATA_WIDTH-1:`AB_PRECISION]};
            order = order + 1;
            if(order == (DATA_WIDTH/`AB_PRECISION)) begin
                B_queue.push_back(word_data);
                order = 0;
            end
        end
    end

    // bias
    C_queue = {};
    order = 0;
    for(i=0;i<`M_DIM;i=i+1) begin
        for(j=0;j<`N_DIM;j=j+1) begin
            word_data = {matrix_C[i][j], word_data[DATA_WIDTH-1:`C_PRECISION]};
            order = order + 1;
            if(order == (DATA_WIDTH/`C_PRECISION)) begin
                C_queue.push_back(word_data);
                order = 0;
            end
        end
    end

    // data
    A_queue = {};
    order = 0;
    for(i=0;i<`M_DIM;i=i+1) begin
        for(k=0;k<`TPU_WIDTH;k=k+1) begin
            word_data = {matrix_A[i][k], word_data[DATA_WIDTH-1:`AB_PRECISION]};
            order = order + 1;
            if(order == (DATA_WIDTH/`AB_PRECISION)) begin
                A_queue.push_back(word_data);
                order = 0;
            end
        end
    end

endtask

initial begin
    data2tpu_axi_awvalid = 1'b0;
    data2tpu_axi_awaddr = '0;
    data2tpu_axi_awlen = '0;
    data2tpu_axi_wvalid = 1'b0;
    data2tpu_axi_wdata = '0;
    data2tpu_axi_wlast = 1'b0;
end

task queue_to_bus ();
//data2tpu：写data给TPU（非发送配置）
    integer i, j;
    integer data_word_num;

    forever begin
        if(B_queue.size()) begin

            data2tpu_axi_awaddr = `B_START_ADDRESS;
            //计算1 burst 发送完B所有data需要的beat数
            data_word_num = 16*`N_DIM*`AB_PRECISION/DATA_WIDTH;
            data2tpu_axi_awlen = data_word_num - 1;

            // aw
            @(posedge clk);
            #tip_delay;
            data2tpu_axi_awvalid = 1;
            // aw ready
            do begin
                @(negedge clk);
                #tip_delay;
            end while(~data2tpu_axi_awready);
            // aw not valid
            @(posedge clk);
            #tip_delay;
            data2tpu_axi_awvalid = 0;

            // w
            i=0;
            repeat(data_word_num) begin
                i++;
                // w valid
                @(posedge clk);
                #tip_delay;
                data2tpu_axi_wvalid = 1;
                data2tpu_axi_wlast = (i == data_word_num);
                data2tpu_axi_wdata = B_queue.pop_front();
                // w ready
                do begin
                    @(negedge clk);
                    #tip_delay;
                end while(~data2tpu_axi_wready);
                end
                // w not valid
                @(posedge clk);
                #tip_delay;
                data2tpu_axi_wvalid = 0;

        end else if (C_queue.size()) begin

            data2tpu_axi_awaddr = `C_START_ADDRESS;
            data_word_num = `M_DIM*`N_DIM*`C_PRECISION/DATA_WIDTH;
            data2tpu_axi_awlen = data_word_num - 1;

            // aw
            @(posedge clk);
            #tip_delay;
            data2tpu_axi_awvalid = 1;
            // aw ready
            do begin
                @(negedge clk);
                #tip_delay;
            end while(~data2tpu_axi_awready);
            // aw not valid
            @(posedge clk);
            #tip_delay;
            data2tpu_axi_awvalid = 0;

            // w
            i=0;
            repeat(data_word_num) begin
                i++;
                // w valid
                @(posedge clk);
                #tip_delay;
                data2tpu_axi_wvalid = 1;
                data2tpu_axi_wlast = (i == data_word_num);
                data2tpu_axi_wdata = C_queue.pop_front();
                // w ready
                do begin
                    @(negedge clk);
                    #tip_delay;
                end while(~data2tpu_axi_wready);
            end
            // w not valid
            @(posedge clk);
            #tip_delay;
            data2tpu_axi_wvalid = 0;

        end else if (A_queue.size()) begin

            data2tpu_axi_awaddr = `A_START_ADDRESS;
            data_word_num = 16*`M_DIM*`AB_PRECISION/DATA_WIDTH;
            data2tpu_axi_awlen = data_word_num - 1;

            // aw
            @(posedge clk);
            #tip_delay;
            data2tpu_axi_awvalid = 1;
            // aw ready
            do begin
                @(negedge clk);
                #tip_delay;
            end while(~data2tpu_axi_awready);
            // aw not valid
            @(posedge clk);
            #tip_delay;
            data2tpu_axi_awvalid = 0;

            // w
            i=0;
            repeat(data_word_num) begin
                i++;
                // w valid
                @(posedge clk);
                #tip_delay;
                data2tpu_axi_wvalid = 1;
                data2tpu_axi_wlast = (i == data_word_num);
                data2tpu_axi_wdata = A_queue.pop_front();
                // w ready
                do begin
                    @(negedge clk);
                    #tip_delay;
                end while(~data2tpu_axi_wready);
                end
                // w not valid
                @(posedge clk);
                #tip_delay;
                data2tpu_axi_wvalid = 0;

        end else begin
            @(posedge clk);
        end
    end
endtask

initial begin
    fork
        data_to_queue();
        queue_to_bus();
    join
end

// -------------------------------------------

//ready=0，master初始状态不响应tpu的任何输入，不接收
initial begin
    tpu2data_axi_awready = 1'b0;
    tpu2data_axi_wready = 1'b0;
end

//tip：tpu2data：check
task bus_to_check ();
    logic [DATA_WIDTH-1:0] word_data;

    // wait reset release
    @(posedge clk);
    #tip_delay;
    wait(1 == rst_n);
    #tip_delay;

    @(posedge clk);
    //复位释放后，aw/w准备接收输入
    #tip_delay;
    tpu2data_axi_awready = 1'b1;
    tpu2data_axi_wready = 1'b1;
    forever begin
        @(posedge clk);
        #tip_delay;
        if(tpu2data_axi_wvalid) begin
            word_data = D_ref_queue.pop_front();
            if(word_data != tpu2data_axi_wdata) begin
            $display("*E, in %m, data is incorrect, ref data is 32'h%x, actual data is 32'h%x\n", word_data, tpu2data_axi_wdata);
            $finish;
            end
        end
    end

endtask

initial begin
    fork
        bus_to_check();
    join
end

always_ff@(posedge clk) begin
    if(!rst_n) begin
        tpu2data_axi_bvalid <= 1'b0;
    end else begin
        tpu2data_axi_bvalid <= (&{tpu2data_axi_wready, tpu2data_axi_wvalid, tpu2data_axi_wlast}) ? 1'b1 : ~tpu2data_axi_bready;
    end
end

// -------------------------------------------
    
endmodule