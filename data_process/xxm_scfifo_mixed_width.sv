// -------------------------------------------
// Author: 
// Version: 0.1
// Date:    2024-09-06
// -------------------------------------------

`include "top.svh"

module xxm_scfifo_mixed_width #(
    parameter                              MEMORY_TYPE = "auto", // "auto", "block", "distributed", "ultra"
    parameter integer                      WR_DATA_WIDTH = 32,
    parameter integer                      WR_FIFO_DEPTH = 32,
    parameter integer                      RD_DATA_WIDTH = 32,
    parameter integer                      PROG_FULL_THRESH = WR_FIFO_DEPTH-8
) (
    input  logic                           clk,
    input  logic                           rst,

    input  logic [WR_DATA_WIDTH-1:0]       in_data,
    input  logic                           wrreq,
    output logic [$clog2(WR_FIFO_DEPTH):0] usedw,
    output logic                           full,
    output logic                           prog_full,

    input  logic                           rdreq,
    output logic [RD_DATA_WIDTH-1:0]       out_data,
    output logic                           empty
);

// -------------------------------------------

logic rd_rst_busy; // rdreq
logic wr_rst_busy; // wrreq

`ifdef VCS

initial begin
    @(negedge clk);
    wait(0 == rst);
    forever begin
        @(negedge clk);
        if(&{rd_rst_busy, rdreq}) begin
            $display("*E, rdreq operation when rd_rst_busy in %m\n");
            $finish;
        end
        if(&{wr_rst_busy, wrreq}) begin
            $display("*E, wrreq operation when wr_rst_busy in %m\n");
            $finish;
        end
        if(&{empty, rdreq}) begin
            $display("*E, rdreq operation when empty in %m\n");
            $finish;
        end
        if(&{full, wrreq}) begin
            $display("*E, wrreq operation when full in %m\n");
            $finish;
        end
    end
end

`endif

// -------------------------------------------

xpm_fifo_sync # (
    .DOUT_RESET_VALUE("0"),                       // String
    .ECC_MODE("no_ecc"),                          // String
    .FIFO_MEMORY_TYPE(`ifdef VCS "block" `else MEMORY_TYPE `endif), // String
    .FIFO_READ_LATENCY(0),                        // DECIMAL
    .FIFO_WRITE_DEPTH(WR_FIFO_DEPTH),             // DECIMAL
    .FULL_RESET_VALUE(0),                         // DECIMAL
    .PROG_EMPTY_THRESH(10),                       // DECIMAL
    .PROG_FULL_THRESH(PROG_FULL_THRESH),          // DECIMAL
    .RD_DATA_COUNT_WIDTH(1),                      // DECIMAL
    .READ_DATA_WIDTH(RD_DATA_WIDTH),              // DECIMAL
    .READ_MODE("fwft"),                           // String
    .SIM_ASSERT_CHK(0),                           // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    .USE_ADV_FEATURES("0707"),                    // String
    .WAKEUP_TIME(0),                              // DECIMAL
    .WRITE_DATA_WIDTH(WR_DATA_WIDTH),             // DECIMAL
    .WR_DATA_COUNT_WIDTH($clog2(WR_FIFO_DEPTH)+1) // DECIMAL
) xpm_fifo_sync_inst (

    .wr_clk(clk),
    .rst(rst),

    .dout(out_data),
    .empty(empty),         // 1-bit output: Empty Flag: When asserted, this signal indicates that the
                           // FIFO is empty. Read requests are ignored when the FIFO is empty,
                           // initiating a read while empty is not destructive to the FIFO.
    .full(full),           // 1-bit output: Full Flag: When asserted, this signal indicates that the
                           // FIFO is full. Write requests are ignored when the FIFO is full,
                           // initiating a write when the FIFO is full is not destructive to the
                           // contents of the FIFO.
    .wr_data_count(usedw), // WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates
                           // the number of words written into the FIFO.
    .din(in_data),
    .rd_en(rdreq),         // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
                           // signal causes data (on dout) to be read from the FIFO. Must be held
                           // active-low when rd_rst_busy is active high.
    .wr_en(wrreq),         // 1-bit input: Write Enable: If the FIFO is not full, asserting this
                           // signal causes data (on din) to be written to the FIFO Must be held
                           // active-low when rst or wr_rst_busy or rd_rst_busy is active high

    .almost_empty(),       // 1-bit output: Almost Empty : When asserted, this signal indicates that
                           // only one more read can be performed before the FIFO goes to empty.
    .almost_full(),        // 1-bit output: Almost Full: When asserted, this signal indicates that
                           // only one more write can be performed before the FIFO is full.
    .data_valid(),         // 1-bit output: Read Data Valid: When asserted, this signal indicates
                           // that valid data is available on the output bus (dout).
    .overflow(),           // 1-bit output: Overflow: This signal indicates that a write request
                           // (wren) during the prior clock cycle was rejected, because the FIFO is
                           // full. Overflowing the FIFO is not destructive to the contents of the
                           // FIFO.
    .prog_empty(),         // 1-bit output: Programmable Empty: This signal is asserted when the
                           // number of words in the FIFO is less than or equal to the programmable
                           // empty threshold value. It is de-asserted when the number of words in
                           // the FIFO exceeds the programmable empty threshold value.
    .prog_full(prog_full), // 1-bit output: Programmable Full: This signal is asserted when the
                           // number of words in the FIFO is greater than or equal to the
                           // programmable full threshold value. It is de-asserted when the number of
                           // words in the FIFO is less than the programmable full threshold value.
    .rd_data_count(),      // RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the
                           // number of words read from the FIFO.
    .underflow(),          // 1-bit output: Underflow: Indicates that the read request (rd_en) during
                           // the previous clock cycle was rejected because the FIFO is empty. Under
                           // flowing the FIFO is not destructive to the FIFO.
    .wr_ack(),             // 1-bit output: Write Acknowledge: This signal indicates that a write
                           // request (wr_en) during the prior clock cycle is succeeded.

    .rd_rst_busy(rd_rst_busy), // 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read
                               // domain is currently in a reset state.
    .wr_rst_busy(wr_rst_busy), // 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
                               // write domain is currently in a reset state.

    .sbiterr(),
    .dbiterr(),
    .injectdbiterr(1'b0),
    .injectsbiterr(1'b0),
    .sleep(1'b0)          // 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo
                          // block is in power saving mode.
);

// -------------------------------------------

endmodule