/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

`default_nettype none

module dma_master(
    input wire clk,
    input wire reset,
    input wire trigger,  // Signal to start DMA transfer
    input wire [4:0] length,
    input wire [31:0] source_address,
    input wire [31:0] destination_address,
    output reg done,

    // Read address channel
    input wire ARREADY,
    output reg ARVALID,
    output reg [31:0] ARADDR,

    // Read data channel
    input wire RVALID,
    output reg RREADY,
    input wire [31:0] RDATA,

    // Write address channel
    input wire AWREADY,
    output reg AWVALID,
    output reg [31:0] AWADDR,

    // Write data channel
    input wire WREADY,
    output reg WVALID,
    output reg [31:0] WDATA,

    // Write response channel
    input wire BVALID,
    output reg BREADY
);

// Internal registers
reg [4:0] count;
reg state;  // Simple state machine

// State encoding
localparam IDLE = 0, TRANSFER = 1;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        ARVALID <= 0;
        RREADY  <= 0;
        AWVALID <= 0;
        WVALID  <= 0;
        BREADY  <= 0;
        count   <= 0;
        done    <= 0;
        state   <= IDLE;
    end else begin
        case (state)
            IDLE: begin
                if (trigger) begin
                    ARADDR  <= source_address;
                    ARVALID <= 1;
                    count   <= length;
                    done    <= 0;
                    state   <= TRANSFER;
                end
            end

            TRANSFER: begin
                if (ARREADY && ARVALID) begin
                    ARVALID <= 0;  // Address phase done
                    RREADY  <= 1;   // Ready for data
                end

                if (RVALID && RREADY) begin
                    WDATA  <= RDATA;   // Pass read data to write data
                    AWADDR <= destination_address;
                    AWVALID <= 1;
                    WVALID  <= 1;
                    RREADY  <= 0;  // Stop reading
                end

                if (AWREADY && AWVALID) begin
                    AWVALID <= 0;  // Write address phase done
                end

                if (WREADY && WVALID) begin
                    WVALID <= 0;  // Write data phase done
                    BREADY <= 1;  // Ready for response
                end

                if (BVALID && BREADY) begin
                    BREADY <= 0;  // Acknowledge write completion
                    if (count > 0) begin
                        count <= count - 1;
                        ARVALID <= 1;  // Start next transfer
                    end else begin
                        done <= 1;  // DMA complete
                        state <= IDLE;
                    end
                end
            end
        endcase
    end
end

endmodule
