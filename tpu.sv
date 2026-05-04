`timescale 1ns/1ps

`include "top.svh"

module tpu #(
    parameter integer                DATA_WIDTH = 512
) (
    input  logic                     clk,
    input  logic                     rst_n,

    // data to TPU
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
    
    // TPU to data
    output logic [7:0]               tpu2data_axi_awid  ,
    output logic [31:0]              tpu2data_axi_awaddr,
    output logic [7:0]               tpu2data_axi_awlen ,
    output logic [2:0]               tpu2data_axi_awsize,
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

logic [2:0]  AB_precision   ;
logic [2:0]  C_precision    ;
logic [2:0]  D_precision    ;
logic [1:0]  n_size         ;
logic [31:0] D_start_address;

cfg_fetch #(
    .DATA_WIDTH                      (DATA_WIDTH)
) cfg_fetch (
    .clk                             (clk  ),
    .rst_n                           (rst_n),

    // CFG to TPU
    .cfg_axil_awaddr                 (cfg_axil_awaddr ),
    .cfg_axil_awprot                 (cfg_axil_awprot ),
    .cfg_axil_awready                (cfg_axil_awready),
    .cfg_axil_awvalid                (cfg_axil_awvalid),
    .cfg_axil_wdata                  (cfg_axil_wdata  ),
    .cfg_axil_wready                 (cfg_axil_wready ),
    .cfg_axil_wstrb                  (cfg_axil_wstrb  ),
    .cfg_axil_wvalid                 (cfg_axil_wvalid ),
    .cfg_axil_bready                 (cfg_axil_bready ),
    .cfg_axil_bresp                  (cfg_axil_bresp  ),
    .cfg_axil_bvalid                 (cfg_axil_bvalid ),

    .AB_precision                    (AB_precision),
    .C_precision                     (C_precision ),
    .D_precision                     (D_precision ),

    // 2'b00 is (m=32,n=8), 2'b01 is (m=16,n=16), 2'b10 is (m=8,n=32)
    .n_size                          (n_size         ),
    .D_start_address                 (D_start_address)
);

// -------------------------------------------

logic                  data_valid   ;
logic                  is_first_data;
logic [DATA_WIDTH-1:0] data         ;
logic                  data_ready   ;
logic [1:0]            data_address ;

indata_bus_adapter #(
    .DATA_WIDTH                      (DATA_WIDTH)  
)indata_bus_adapter (
    .clk                             (clk),
    .rst_n                           (rst_n),

    .AB_precision                    (AB_precision),
    .C_precision                     (C_precision),

    .data2tpu_axi_awid               (data2tpu_axi_awid),
    .data2tpu_axi_awaddr             (data2tpu_axi_awaddr),
    .data2tpu_axi_awlen              (data2tpu_axi_awlen),
    .data2tpu_axi_awsize             (data2tpu_axi_awsize),
    .data2tpu_axi_awburst            (data2tpu_axi_awburst),
    .data2tpu_axi_awlock             (data2tpu_axi_awlock),
    .data2tpu_axi_awcache            (data2tpu_axi_awcache),
    .data2tpu_axi_awprot             (data2tpu_axi_awprot),
    .data2tpu_axi_awqos              (data2tpu_axi_awqos),
    .data2tpu_axi_awvalid            (data2tpu_axi_awvalid),
    .data2tpu_axi_awready            (data2tpu_axi_awready),
    .data2tpu_axi_wdata              (data2tpu_axi_wdata),
    .data2tpu_axi_wstrb              (data2tpu_axi_wstrb),
    .data2tpu_axi_wlast              (data2tpu_axi_wlast),
    .data2tpu_axi_wvalid             (data2tpu_axi_wvalid),
    .data2tpu_axi_wready             (data2tpu_axi_wready),
    .data2tpu_axi_bready             (data2tpu_axi_bready),
    .data2tpu_axi_bid                (data2tpu_axi_bid),
    .data2tpu_axi_bresp              (data2tpu_axi_bresp),
    .data2tpu_axi_bvalid             (data2tpu_axi_bvalid),
    
    .data_valid                      (data_valid),
    .data_address                    (data_address),
    .is_first_data                   (is_first_data),
    .data                            (data),
    .data_ready                      (data_ready)
);

// -------------------------------------------

logic [DATA_WIDTH-1:0] A_data           ;
logic                  A_data_valid     ;
logic                  A_data_ready     ; 
logic [DATA_WIDTH-1:0] B_data           ;
logic                  is_first_data_out;
logic                  B_data_valid     ;
logic                  B_data_ready     ;   
logic [DATA_WIDTH-1:0] C_data           ;
logic                  C_data_valid     ;
logic                  C_data_ready     ;

data_split #(
    .DATA_WIDTH             (DATA_WIDTH)
) data_split(
    .clk                     (clk), 
    .rst_n                   (rst_n) , 
    .data_valid              (data_valid),
    .data_address            (data_address),  
    .is_first_data_in        (is_first_data),   
    .data                    (data),      
    .data_ready              (data_ready) ,  

    .A_data                  (A_data), 
    .A_data_valid            (A_data_valid), 
    .A_data_ready            (A_data_ready), 

    .B_data                  (B_data),  
    .is_first_data_out       (is_first_data_out), 
    .B_data_valid            (B_data_valid ),
    .B_data_ready            (B_data_ready),

    .C_data                  (C_data),
    .C_data_valid            (C_data_valid),
    .C_data_ready            (C_data_ready)
);

// -------------------------------------------

logic [DATA_WIDTH-1:0] weight      ;                   
logic [4:0]            weight_addr ;                   
logic                  weight_valid;   

label_address #(
  .DATA_WIDTH                (DATA_WIDTH )
) label_address (
    .clk                     (clk),      
    .rst_n                   (rst_n),

    .data                    (B_data),
    .is_first_data           (is_first_data_out),
    .data_valid              (B_data_valid),
    .data_ready              (B_data_ready),

    .weight                  (weight),
    .weight_addr             (weight_addr),
    .weight_valid            (weight_valid)
);

// -------------------------------------------

logic [DATA_WIDTH-1:0] pre_in_data      ;
logic                  pre_in_data_valid;

data_copy #(
    .DATA_WIDTH              (DATA_WIDTH )
) data_copy (
    .clk                     (clk),      
    .rst_n                   (rst_n),
    
    .n_size                  (n_size),

    .in_data                 (A_data      ),
    .in_data_valid           (A_data_valid),
    .in_data_ready           (A_data_ready),

    .out_data                (pre_in_data      ),
    .out_data_valid          (pre_in_data_valid)
);

// -------------------------------------------

logic [`TPU_HEIGHT*`MAX_DATA_BIT-1:0] bias_data      ;
logic                                 bias_data_valid;

c_width_change c_width_change (
    .clk                     (clk),      
    .rst_n                   (rst_n),

    .in_data                 (C_data      ),
    .in_data_valid           (C_data_valid),
    .in_data_ready           (C_data_ready),

    .out_data                (bias_data      ),
    .out_data_valid          (bias_data_valid)
);

// -------------------------------------------

logic [`TPU_WIDTH*`MAX_DATA_BIT-1:0] post_in_data      ;
logic [`TPU_WIDTH-1:0]               post_in_data_valid;

 data_tilt #(
    .DATA_WIDTH (DATA_WIDTH)
 ) data_tilt (
    .clk                       (clk  ),  
    .rst_n                     (rst_n),
    
    .in_data                   (pre_in_data       ),          
    .in_data_valid             (pre_in_data_valid ),          
    .out_data                  (post_in_data      ),     
    .out_data_valid            (post_in_data_valid)           
);

// -------------------------------------------

logic [`TPU_HEIGHT-1:0][`MAX_DATA_BIT-1:0] tpu_out_data;

tpu_array tpu_array (
    .clk                     (clk),      
    .rst_n                   (rst_n),

    .n_size                  (n_size      ),
    .AB_precision            (AB_precision),
    
    .in_data                 (post_in_data      ),
    .in_data_valid           (post_in_data_valid),

    .in_weight               (weight      ),
    .in_weight_addr          (weight_addr ),
    .in_weight_valid         (weight_valid),

    .in_c                    (bias_data      ),
    .in_c_valid              (bias_data_valid),

    .tpu_out_data            (tpu_out_data)
);

// -------------------------------------------

logic aligned_tpu_out_data_valid;

delay #(
    .DELAY_NUM(`TPU_HEIGHT-1+`MUL_DELAY+`ADD_DELAY)
) delay_inst (
    .clk(clk),
    .data_in (post_in_data_valid[`TPU_WIDTH-1]),
    .data_out(aligned_tpu_out_data_valid)
);

logic [`TPU_HEIGHT-1:0][`MAX_DATA_BIT-1:0] aligned_tpu_out_data;

data_align data_align (
    .clk                     (clk),      
    .rst_n                   (rst_n),

    .tpu_in_data             (tpu_out_data),
    .tpu_out_data            (aligned_tpu_out_data)
);

// -------------------------------------------

logic [DATA_WIDTH-1:0] cut_data      ;
logic                  cut_data_valid;

bit_cut #(
    .DATA_WIDTH              (DATA_WIDTH)
) bit_cut (
    .clk                     (clk),      
    .rst_n                   (rst_n),

    .D_precision             (D_precision),

    .in_data                 (aligned_tpu_out_data      ),
    .in_data_valid           (aligned_tpu_out_data_valid),

    .out_data                (cut_data      ),
    .out_data_valid          (cut_data_valid)
);

// -------------------------------------------

axi_generator #(
    .DATA_WIDTH                      (DATA_WIDTH)
) axi_generator (
    .clk                             (clk),      
    .rst_n                           (rst_n),

    .D_precision                     (D_precision    ),
    .D_start_address                 (D_start_address),

    .in_data                         (cut_data      ),
    .in_data_valid                   (cut_data_valid),

    // TPU to data
    .tpu2data_axi_awid               (tpu2data_axi_awid   ),
    .tpu2data_axi_awaddr             (tpu2data_axi_awaddr ),
    .tpu2data_axi_awlen              (tpu2data_axi_awlen  ),
    .tpu2data_axi_awsize             (tpu2data_axi_awsize ),
    .tpu2data_axi_awburst            (tpu2data_axi_awburst),
    .tpu2data_axi_awlock             (tpu2data_axi_awlock ),
    .tpu2data_axi_awcache            (tpu2data_axi_awcache),
    .tpu2data_axi_awprot             (tpu2data_axi_awprot ),
    .tpu2data_axi_awqos              (tpu2data_axi_awqos  ),
    .tpu2data_axi_awvalid            (tpu2data_axi_awvalid),
    .tpu2data_axi_awready            (tpu2data_axi_awready),
    .tpu2data_axi_wdata              (tpu2data_axi_wdata  ),
    .tpu2data_axi_wstrb              (tpu2data_axi_wstrb  ),
    .tpu2data_axi_wlast              (tpu2data_axi_wlast  ),
    .tpu2data_axi_wvalid             (tpu2data_axi_wvalid ),
    .tpu2data_axi_wready             (tpu2data_axi_wready ),
    .tpu2data_axi_bready             (tpu2data_axi_bready ),
    .tpu2data_axi_bid                (tpu2data_axi_bid    ),
    .tpu2data_axi_bresp              (tpu2data_axi_bresp  ),
    .tpu2data_axi_bvalid             (tpu2data_axi_bvalid )
);

// -------------------------------------------

endmodule