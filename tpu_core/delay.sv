`timescale 1ns / 1ps

module delay # (
    parameter WIDTH_NUM = 1,
    parameter DELAY_NUM = 2
) (
    input  wire                 clk,
    input  wire [WIDTH_NUM-1:0] data_in,
    output wire [WIDTH_NUM-1:0] data_out
);

genvar i;

generate
    if(0 == DELAY_NUM) begin //0 dealy, direct connection
        assign data_out = data_in;
    end else begin
        reg [DELAY_NUM-1:0] [WIDTH_NUM-1:0] tmp_data;
        for(i=0;i<DELAY_NUM;i=i+1) begin
            if(0 == i) begin
                always @(posedge clk) begin
                    tmp_data[0] <= data_in;
                end
            end else begin
                always @(posedge clk) begin
                    //i max is DELAY_NUM-1, so tmp_data[i] valid const
                    tmp_data[i] <= tmp_data[i-1];
                end
            end
        end
        assign data_out = tmp_data[DELAY_NUM-1];
    end
endgenerate
    
endmodule