`timescale 1ns / 1ps

module dma_master(
    input clk,
    input reset,
    input trigger,
    input [4:0] length,
    input [31:0] source_address,
    input [31:0] destination_address,
    output reg done,
    
    // Read Address Channel
    input ARREADY,
    output reg ARVALID,
    output reg [31:0] ARADDR,
    
    // Read Data Channel    
    input RVALID,
    output reg RREADY,
    input [31:0] RDATA,
    
    // Write Address Channel
    input AWREADY,
    output reg AWVALID,
    output reg [31:0] AWADDR,
    
    // Write Data Channel    
    input WREADY,
    output reg WVALID,
    output [31:0] WDATA,
    
    // Write Response Channel
    input BVALID,
    output reg BREADY
);        

// Internal Registers
reg RD_EN, WR_EN;
wire FIFO_FULL, FIFO_EMPTY;
reg [2:0] read_index, write_index;
reg transfer_start;
reg transfer_complete, transfer_complete_prev;

// FIFO Instantiation     
sync_fifo fifo_1 (
    .clk(clk), .rst(reset),
    .d_in(RDATA), .d_out(WDATA),
    .RD_EN(RD_EN), .WR_EN(WR_EN),
    .FULL(FIFO_FULL), .EMPTY(FIFO_EMPTY)
);

// Transfer Start Logic
always @(posedge clk) begin
    if (reset)
        transfer_start <= 1'b0;
    else if (trigger)
        transfer_start <= 1'b1;
    else if (done)
        transfer_start <= 1'b0;
end

// Read State Machine
reg [1:0] r_state;
parameter READ_ADDR = 2'b00,
          READ_DATA = 2'b01,
          READ_WAIT = 2'b10;

always @(posedge clk) begin
    if (reset) begin
        ARVALID <= 0;
        ARADDR  <= 32'd0;
        RREADY  <= 0;
        WR_EN   <= 0;
    end
    else if (transfer_start) begin
        case (r_state)
            READ_ADDR: begin
                if (!FIFO_FULL) begin
                    ARADDR  <= source_address + (read_index << 2);
                    ARVALID <= 1;
                    RREADY  <= 1;
                    if (ARREADY) begin
                        ARVALID <= 0;
                        r_state <= READ_DATA;
                    end
                end
            end 
            READ_DATA: begin
                if (RVALID) begin
                    WR_EN  <= 1;
                    RREADY <= 0;
                    r_state <= READ_WAIT;
                end
            end
            READ_WAIT: begin
                WR_EN <= 0;
                if (!FIFO_FULL) begin
                    if (read_index < ((length >> 2)-1)) begin
                        read_index <= read_index + 1;
                        r_state <= READ_ADDR;
                        RREADY <= 1;
                    end
                end
            end
        endcase
    end
end

// Write State Machine
reg [1:0] w_state;
parameter WRITE_ADDR = 2'b00,
          WRITE_DATA = 2'b01,
          WRITE_RESP = 2'b10;

always @(posedge clk) begin
    if (reset) begin
        AWVALID <= 0;
        AWADDR  <= 32'd0;
        WVALID  <= 0;
        BREADY  <= 0;
        RD_EN   <= 0;  
    end
    else if (transfer_start) begin
        case (w_state)
            WRITE_ADDR: begin
                if (!FIFO_EMPTY && !AWVALID) begin       
                    AWADDR  <= destination_address + (write_index << 2);
                    AWVALID <= 1;
                end
                if (AWREADY && AWVALID) begin
                    AWVALID <= 0;
                    RD_EN   <= 1;
                    w_state <= WRITE_DATA;
                end 
            end
            WRITE_DATA: begin
                RD_EN  <= 0;
                WVALID <= 1;
                if (WREADY && WVALID) begin
                    WVALID  <= 0;
                    w_state <= WRITE_RESP;
                end
            end
            WRITE_RESP: begin
                BREADY <= BVALID;
                if (BVALID && BREADY) begin
                    BREADY <= 0;
                    if (write_index < ((length >>2)-1)) begin
                        write_index <= write_index
