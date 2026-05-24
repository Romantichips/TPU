`timescale 1ns/1ps

module data_merge #(
    parameter integer             DATA_WIDTH = 32
) (
    input  logic                    clk,
    input  logic                    rst,

    input  logic                    in_valid,
    input  logic [DATA_WIDTH-1:0]   in_data, 

    output logic                    out_valid,
    output logic [2*DATA_WIDTH-1:0] out_data
);

// -------------------------------------------

logic [DATA_WIDTH-1:0] reg_data;   
logic reg_flag;                           

// control flow
always_ff@(posedge clk `ifdef ASYNC_RST or posedge rst `endif) begin
    if (rst) begin
        reg_flag <= 1'b0;          
        out_valid <= 1'b0;         
    end else if (in_valid && !reg_flag) begin
            reg_flag <= 1'b1;     
            out_valid <= 1'b0; 
        end else if (in_valid && reg_flag) begin
            reg_flag <= 1'b0;   //clear 
            out_valid <= 1'b1;    
        end else begin
            out_valid <= 1'b0;     
        end
end

// data flow
always_ff @(posedge clk) 
    if (in_valid && reg_flag) begin
        reg_data <=  reg_data;
        out_data <= {in_data,reg_data};
    end else if (in_valid && !reg_flag) begin
        reg_data <= in_data; 
        out_data <= out_data;
    end

// -------------------------------------------
    
endmodule