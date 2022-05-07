`timescale 1 ns / 1 ps

module AXI_INT_TEST #(
    /* Do not modify the parameters beyond this line. */

    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 7
) (
    output reg INTERRUPT,

    /* Do not modify the ports beyond this line. */

    /* global AXI signals */
    input wire S_AXI_ACLK,
    input wire S_AXI_ARESETN,

    /* write address channel */
    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input wire [2:0] S_AXI_AWPROT, /* unused */
    input wire S_AXI_AWVALID,
    output reg S_AXI_AWREADY,

    /* write data channel */
    input wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB, /* unused */
    input wire S_AXI_WVALID,
    output reg S_AXI_WREADY,

    /* write response channel */
    output reg [1:0] S_AXI_BRESP,
    output reg S_AXI_BVALID,
    input wire S_AXI_BREADY,

    /* read address channel */
    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input wire [2:0] S_AXI_ARPROT, /* unused */
    input wire S_AXI_ARVALID,
    output reg S_AXI_ARREADY,

    /* read data channel */
    output reg [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output reg [1:0] S_AXI_RRESP,
    output reg S_AXI_RVALID,
    input wire S_AXI_RREADY
);

localparam integer ADDRESS_WIDTH = 3;
localparam integer ADDRESS_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
localparam integer ADDRESS_MSB = ADDRESS_LSB + ADDRESS_WIDTH;

reg SET_INTERRUPT;
reg CLEAR_INTERRUPT;

/*
 * Device behaviour.
 */

reg START_COUNTING;
reg [31:0] COUNTER1;
reg [31:0] COUNTER2;

always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 0 || START_COUNTING == 0) begin
        COUNTER1      <= 0;
        COUNTER2      <= 0;
        SET_INTERRUPT <= 0;
    end else begin
        /* assumes a 50 MHz clock */
        if (COUNTER1 < 250000000) begin
            COUNTER1      <= COUNTER1 + 1;
            SET_INTERRUPT <= 0;
        end else begin
            COUNTER1      <= 0;
            COUNTER2      <= COUNTER2 + 1;
            SET_INTERRUPT <= 1;
        end
    end
end

/*
 * Write state machine.
 */

reg [3:0] WRITE_STATE;
localparam WRITE_STATE_WAIT     = 0;
localparam WRITE_STATE_EXECUTE  = 1;
localparam WRITE_STATE_RESPONSE = 2;
localparam WRITE_STATE_DONE     = 3;

reg [C_S_AXI_ADDR_WIDTH-1:0] AXI_AWADDR;
reg [C_S_AXI_ADDR_WIDTH-1:0] AXI_WDATA;

wire [ADDRESS_WIDTH-1:0] SELECTED_WRITE_REGISTER;
assign SELECTED_WRITE_REGISTER  = AXI_AWADDR[ADDRESS_MSB:ADDRESS_LSB];

always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 0) begin
        WRITE_STATE = WRITE_STATE_WAIT;

        S_AXI_AWREADY <= 0;
        S_AXI_WREADY  <= 0;
        S_AXI_BRESP   <= 0;
        S_AXI_BVALID  <= 0;
    end else begin
        case (WRITE_STATE)
        WRITE_STATE_WAIT: begin
            if (S_AXI_AWVALID == 1 && S_AXI_WVALID == 1) begin
                AXI_AWADDR <= S_AXI_AWADDR;
                AXI_WDATA  <= S_AXI_WDATA;

                S_AXI_AWREADY <= 1;
                S_AXI_WREADY  <= 1;

                WRITE_STATE <= WRITE_STATE_EXECUTE;
            end
        end

        WRITE_STATE_EXECUTE: begin
            S_AXI_AWREADY <= 0;
            S_AXI_WREADY  <= 0;

            case (SELECTED_WRITE_REGISTER)
            0: begin
                START_COUNTING <= S_AXI_WDATA[0];

                WRITE_STATE <= WRITE_STATE_RESPONSE;
            end

            1: begin
                START_COUNTING <= 0;

                WRITE_STATE <= WRITE_STATE_RESPONSE;
            end

            2: begin
                START_COUNTING <= 0;

                WRITE_STATE <= WRITE_STATE_RESPONSE;
            end

            3: begin
                CLEAR_INTERRUPT <= S_AXI_WDATA[0];

                WRITE_STATE <= WRITE_STATE_RESPONSE;
            end
            

            default: begin
                WRITE_STATE <= WRITE_STATE_RESPONSE;
            end
            endcase
        end

        WRITE_STATE_RESPONSE: begin
            CLEAR_INTERRUPT <= 0;

            if (S_AXI_BREADY == 1) begin
                S_AXI_BRESP  <= 0;
                S_AXI_BVALID <= 1;

                WRITE_STATE <= WRITE_STATE_DONE;
            end
        end

        WRITE_STATE_DONE: begin
            S_AXI_BRESP  <= 0;
            S_AXI_BVALID <= 0;

            WRITE_STATE <= WRITE_STATE_WAIT;
        end
        endcase
    end
end

/*
 * Read state machine.
 */

reg [3:0] READ_STATE;
localparam READ_STATE_WAIT     = 0;
localparam READ_STATE_EXECUTE  = 1;
localparam READ_STATE_RESPONSE = 2;
localparam READ_STATE_DONE     = 3;

reg [C_S_AXI_ADDR_WIDTH-1:0] AXI_ARADDR;

wire [ADDRESS_WIDTH-1:0] SELECTED_READ_REGISTER;
assign SELECTED_READ_REGISTER  = AXI_ARADDR[ADDRESS_MSB:ADDRESS_LSB];

always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 0) begin
        READ_STATE = READ_STATE_WAIT;

        S_AXI_ARREADY <= 0;
        S_AXI_RDATA   <= 0;
        S_AXI_RRESP   <= 0;
        S_AXI_RVALID  <= 0;
    end else begin
        case (READ_STATE)
        READ_STATE_WAIT: begin
            if (S_AXI_ARVALID == 1) begin
                AXI_ARADDR <= S_AXI_ARADDR;

                S_AXI_ARREADY <= 1;

                READ_STATE <= READ_STATE_EXECUTE;
            end
        end

        READ_STATE_EXECUTE: begin
            S_AXI_ARREADY <= 0;

            case (SELECTED_READ_REGISTER)
            0: begin
                S_AXI_RDATA <= {{30{1'b0}}, INTERRUPT, START_COUNTING};

                READ_STATE <= READ_STATE_RESPONSE;
            end

            1: begin
                S_AXI_RDATA <= COUNTER1;

                READ_STATE <= READ_STATE_RESPONSE;
            end

            2: begin
                S_AXI_RDATA <= COUNTER2;

                READ_STATE <= READ_STATE_RESPONSE;
            end

            3: begin
                S_AXI_RDATA <= 0;

                READ_STATE <= READ_STATE_RESPONSE;
            end

            default: begin
                S_AXI_RDATA <= 0;

                READ_STATE <= READ_STATE_RESPONSE;
            end
            endcase
        end

        READ_STATE_RESPONSE: begin
            if (S_AXI_RREADY == 1) begin
                S_AXI_RVALID <= 1;

                READ_STATE <= READ_STATE_DONE;
            end
        end

        READ_STATE_DONE: begin
            S_AXI_RDATA   <= 0;
            S_AXI_RRESP   <= 0;
            S_AXI_RVALID  <= 0;

            READ_STATE <= READ_STATE_WAIT;
        end
        endcase
    end
end

/*
 * Interrupt handling.
 */

always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 0) begin
        INTERRUPT = 0;
    end else begin
        if (INTERRUPT == 0) begin
            if (SET_INTERRUPT == 1) begin
                INTERRUPT <= 1;
            end
        end else begin
            if (CLEAR_INTERRUPT == 1) begin
                INTERRUPT <= 0;
            end
        end
    end
end
    
endmodule
