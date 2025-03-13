module axi_lite_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
	
// Register Parameters for configuring the accelerator
	parameter REG0_val,// = 32'h0000_0001 Default value for REG0 from top module
	parameter REG1_val,// = 32'h0000_0000 Default value for REG1 from top module
	parameter REG2_val,// = 32'h0000_0100 Default value for REG2 from top module
	parameter REG3_val,// = 32'h0000_0003 Default value for REG3 from top module
	parameter REG4_val,// = 32'h0001_0000 Default value for REG4 from top module
	parameter REG5_val // = 32'h0000_0000 Default value for REG5 from top module
)(
    // AXI-Lite Interface Signals
    input wire                      ACLK,
    input wire                      ARESETN,

    // Write Address Channel
    input wire [ADDR_WIDTH-1:0]     AWADDR,
    input wire                      AWVALID,
    output reg                      AWREADY,

    // Write Data Channel
    input wire [DATA_WIDTH-1:0]     WDATA,
    input wire                      WVALID,
    output reg                      WREADY,

    // Write Response Channel
    output reg [1:0]                BRESP,
    output reg                      BVALID,
    input wire                      BREADY,

    // Read Address Channel
    input wire [ADDR_WIDTH-1:0]     ARADDR,
    input wire                      ARVALID,
    output reg                      ARREADY,

    // Read Data Channel
    output reg [DATA_WIDTH-1:0]     RDATA,
    output reg                      RVALID,
    input wire                      RREADY
);

    // Internal Registers
    reg [DATA_WIDTH-1:0]            REG0; // Control Register
    reg [DATA_WIDTH-1:0]            REG1; // Vector A Base Address
    reg [DATA_WIDTH-1:0]            REG2; // Vector B Base Address
    reg [DATA_WIDTH-1:0]            REG3; // Vector Length
    reg [DATA_WIDTH-1:0]            REG4; // Output Address
    reg [DATA_WIDTH-1:0]            REG5; // Status Register

    // Local Parameters for Register Addresses
    localparam REG0_ADDR = 32'h0000_0000;
    localparam REG1_ADDR = 32'h0000_0004;
    localparam REG2_ADDR = 32'h0000_0008;
    localparam REG3_ADDR = 32'h0000_000C;
    localparam REG4_ADDR = 32'h0000_0010;
    localparam REG5_ADDR = 32'h0000_0014;

    // Write FSM
    typedef enum logic [1:0] {WRITE_IDLE, WRITE_ADDR, WRITE_DATA, WRITE_RESP} write_state_t;
    write_state_t write_state;

    // Read FSM
    typedef enum logic [1:0] {READ_IDLE, READ_ADDR, READ_DATA} read_state_t;
    read_state_t read_state;

    // Write Logic
    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            write_state <= WRITE_IDLE;
            AWREADY <= 1'b0;
            WREADY <= 1'b0;
            BVALID <= 1'b0;
            BRESP <= 2'b00;
        end else begin
            case (write_state)
                WRITE_IDLE: begin
                    if (AWVALID) begin
                        AWREADY <= 1'b1;
                        write_state <= WRITE_ADDR;
                    end
                end

                WRITE_ADDR: begin
                    AWREADY <= 1'b0;
                    if (WVALID) begin
                        WREADY <= 1'b1;
                        write_state <= WRITE_DATA;
                    end
                end

                WRITE_DATA: begin
                    WREADY <= 1'b0;
                    case (AWADDR)
                        REG0_ADDR: REG0 <= WDATA;
                        REG1_ADDR: REG1 <= WDATA;
                        REG2_ADDR: REG2 <= WDATA;
                        REG3_ADDR: REG3 <= WDATA;
                        REG4_ADDR: REG4 <= WDATA;
                        REG5_ADDR: REG5 <= WDATA;
                        default: BRESP <= 2'b10; // SLVERR
                    endcase
                    write_state <= WRITE_RESP;
                end

                WRITE_RESP: begin
                    BVALID <= 1'b1;
                    if (BREADY) begin					//Checking if the Master is ready to receive a write response from Slave
                        BVALID <= 1'b0;
                        write_state <= WRITE_IDLE;
                    end
                end
            endcase
        end
    end

    // Read Logic
    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            read_state <= READ_IDLE;
            ARREADY <= 1'b0;
            RVALID <= 1'b0;
            RDATA <= 32'h0000_0000;
			REG0 <= REG0_val;
			REG1 <= REG1_val;
			REG2 <= REG2_val;
			REG3 <= REG3_val;
			REG4 <= REG4_val;
			REG5 <= REG5_val;
        end else begin
            case (read_state)
                READ_IDLE: begin
                    if (ARVALID) begin
                        ARREADY <= 1'b1;
                        read_state <= READ_ADDR;
                    end
                end

                READ_ADDR: begin
                    ARREADY <= 1'b0;
                    case (ARADDR)
                        REG0_ADDR: RDATA <= REG0;
                        REG1_ADDR: RDATA <= REG1;
                        REG2_ADDR: RDATA <= REG2;
                        REG3_ADDR: RDATA <= REG3;
                        REG4_ADDR: RDATA <= REG4;
                        REG5_ADDR: RDATA <= REG5;
                        default: RDATA <= 32'hDEAD_BEEF; // Invalid Address
                    endcase
                    RVALID <= 1'b1;
                    read_state <= READ_DATA;
                end

                READ_DATA: begin
                    if (RREADY) begin
                        RVALID <= 1'b0;
                        read_state <= READ_IDLE;
                    end
                end
            endcase
        end
    end

endmodule