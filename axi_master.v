module axi_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    // Clock and Reset
    input wire                      ACLK,
    input wire                      ARESETN,

    // AXI-Lite Slave Interface
    output reg [ADDR_WIDTH-1:0]     ARADDR,
    output reg                      ARVALID,
    input wire                      ARREADY,
    input wire [DATA_WIDTH-1:0]     RDATA,
    input wire                      RVALID,
    output reg                      RREADY,

    output reg [ADDR_WIDTH-1:0]     AWADDR,
    output reg                      AWVALID,
    input wire                      AWREADY,
    output reg [DATA_WIDTH-1:0]     WDATA,
    output reg                      WVALID,
    input wire                      WREADY,
    input wire [1:0]                BRESP,
    input wire                      BVALID,
    output reg                      BREADY,

    // Memory Interface
	
    output reg [ADDR_WIDTH-1:0]     MEM_ARADDR,
    output reg                      MEM_ARVALID,
    input wire                      MEM_ARREADY,
    input wire [7:0]                MEM_RDATA,
    input wire                      MEM_RVALID,
    output reg                      MEM_RREADY,

    output reg [ADDR_WIDTH-1:0]     MEM_AWADDR,
    output reg                      MEM_AWVALID,
    input wire                      MEM_AWREADY,
    output reg [7:0]                MEM_WDATA,
    output reg                      MEM_WVALID,
    input wire                      MEM_WREADY,
    input wire                      MEM_BVALID,
    output reg                      MEM_BREADY,

    // Dot Product Accelerator Interface
    output reg [7:0]                DP_A,
    output reg [7:0]                DP_B,
    input wire [31:0]               DP_RESULT,
    output reg                      DP_START,
    input wire                      DP_DONE,
	output reg						inputs_ready,
	
	// Start signal for AXI Master operations
	input							start_signal
);

    // Internal Registers
	reg [ADDR_WIDTH-1:0]            CONTROL_REG;
    reg [ADDR_WIDTH-1:0]            VECTOR_A_BASE;
    reg [ADDR_WIDTH-1:0]            VECTOR_B_BASE;
    reg [ADDR_WIDTH-1:0]            VECTOR_LENGTH;
    reg [ADDR_WIDTH-1:0]            OUTPUT_ADDR;

    // Local Parameters for Register Addresses
    localparam REG0_ADDR = 32'h0000_0000;
    localparam REG1_ADDR = 32'h0000_0004;
    localparam REG2_ADDR = 32'h0000_0008;
    localparam REG3_ADDR = 32'h0000_000C;
    localparam REG4_ADDR = 32'h0000_0010;
    localparam REG5_ADDR = 32'h0000_0014;

	// Done Flags for the Main FSM
	reg								config_read_done;
	reg								vector_read_done;
	reg								dot_product_done;
	reg								result_write_done;
	reg								config_write_done;








    // Main FSM States
    typedef enum logic [2:0] {
        IDLE,
        READ_CONFIG,
        READ_VECTORS,
        COMPUTE,
        WRITE_RESULT,
        UPDATE_STATUS
    } state_t;

    state_t current_state, next_state;

    // Vector Index
    integer vector_index;

    // Dot Product Accumulator
    reg [31:0] dot_product_result;

    // Main FSM Control Logic
    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Main FSM Next State Logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start_signal) begin
                    next_state = READ_CONFIG;
                end
            end
            READ_CONFIG: begin
                if (config_read_done) begin
                    next_state = READ_VECTORS;
                end
            end
            READ_VECTORS: begin
                if (vector_read_done) begin
                    next_state = COMPUTE;
                end
            end
            COMPUTE: begin
                if (dot_product_done) begin
                    next_state = WRITE_RESULT;
                end
            end
            WRITE_RESULT: begin
                if (result_write_done) begin
                    next_state = UPDATE_STATUS;
                end
            end
            UPDATE_STATUS: begin
                if (config_write_done) begin
                    next_state = IDLE;
                end
            end
        endcase
    end








// State Machine for AXI Slave Read Transaction
typedef enum logic [1:0] {
    SLV_READ_IDLE,
    SLV_READ_ADDR,
    SLV_READ_DATA,
	SLV_UPDATE_ADDR
} read_state_axi_slave;

read_state_axi_slave current_state_slave_read;

// AXI Master <-> AXI-Lite Read Slave Configuration Registers Logic
always @(posedge ACLK or negedge ARESETN) begin
    if (!ARESETN) begin
        ARADDR <= 0;
        ARVALID <= 0;
        RREADY <= 0;
		CONTROL_REG <= 0;
        VECTOR_A_BASE <= 0;
        VECTOR_B_BASE <= 0;
        VECTOR_LENGTH <= 0;
        OUTPUT_ADDR <= 0;
        config_read_done <= 0;
        current_state_slave_read <= SLV_READ_IDLE;
    end else begin
        case (current_state_slave_read)
            SLV_READ_IDLE: begin
                if (current_state == READ_CONFIG && !config_read_done) begin
                    ARADDR <= REG0_ADDR; // Start with REG1
                    ARVALID <= 1;
                    current_state_slave_read <= SLV_READ_ADDR;
                end
            end

            SLV_READ_ADDR: begin
                if (ARREADY) begin
                    ARVALID <= 0; // Address accepted
                    RREADY <= 1;  // Assert RREADY to accept the data
                    current_state_slave_read <= SLV_READ_DATA;
                end
            end

            SLV_READ_DATA: begin
                if (RVALID) begin
                    case (ARADDR)
						REG0_ADDR: CONTROL_REG <= RDATA;
                        REG1_ADDR: VECTOR_A_BASE <= RDATA;
                        REG2_ADDR: VECTOR_B_BASE <= RDATA;
                        REG3_ADDR: VECTOR_LENGTH <= RDATA;
                        REG4_ADDR: OUTPUT_ADDR <= RDATA;
                    endcase
                    RREADY <= 0; // Data captured
                    current_state_slave_read <= SLV_UPDATE_ADDR;
				end
            end

            SLV_UPDATE_ADDR: begin
                if (ARADDR == REG4_ADDR) begin
                    config_read_done <= 1; // All registers read
                    current_state_slave_read <= SLV_READ_IDLE;
                end else begin
					if (CONTROL_REG == 32'h0000_0001) begin // Proceed only if start bit in REG0/CONTROL_REG is set
						ARADDR <= ARADDR + 4; // Move to the next register (assuming 32-bit registers)
						ARVALID <= 1;
						current_state_slave_read <= SLV_READ_ADDR;
					end
                end
            end
        endcase
    end
end








// State Machine for AXI Memory Read Transaction
typedef enum logic [2:0] {
    MEM_READ_IDLE,
    MEM_READ_ADDR_A,
    MEM_READ_DATA_A,
    MEM_READ_ADDR_B,
    MEM_READ_DATA_B
} read_state_axi_mem;

read_state_axi_mem current_state_mem_read;

// AXI Master <-> Memory Read Logic
always @(posedge ACLK or negedge ARESETN) begin
    if (!ARESETN) begin
        MEM_ARADDR <= 0;
        MEM_ARVALID <= 0;
        MEM_RREADY <= 0;
        vector_index <= 0;
        DP_A <= 0;
        DP_B <= 0;
		inputs_ready <= 0;
		vector_read_done <= 0;
        current_state_mem_read <= MEM_READ_IDLE;
    end else begin
        case (current_state_mem_read)
            MEM_READ_IDLE: begin
                if (current_state == READ_VECTORS && vector_index < VECTOR_LENGTH && !vector_read_done) begin
					inputs_ready <= 0;
                    MEM_ARADDR <= VECTOR_A_BASE + vector_index;
                    MEM_ARVALID <= 1; // Assert read address valid
                    current_state_mem_read <= MEM_READ_ADDR_A;
                end
				else if (vector_index == VECTOR_LENGTH) begin
					vector_read_done <= 1;
					current_state_mem_read <= MEM_READ_IDLE;
				end
            end

            MEM_READ_ADDR_A: begin
                if (MEM_ARREADY) begin
                    MEM_ARVALID <= 0; // Address accepted
                    MEM_RREADY <= 1; // Ready to accept read data
                    current_state_mem_read <= MEM_READ_DATA_A;
                end
            end

            MEM_READ_DATA_A: begin
                if (MEM_RVALID && MEM_RREADY) begin
                    DP_A <= MEM_RDATA; // Capture data for vector A
                    MEM_RREADY <= 0; // Data captured
                    MEM_ARADDR <= VECTOR_B_BASE + vector_index;
                    MEM_ARVALID <= 1; // Request next read
                    current_state_mem_read <= MEM_READ_ADDR_B;
                end
            end

            MEM_READ_ADDR_B: begin
                if (MEM_ARREADY) begin
                    MEM_ARVALID <= 0; // Address accepted
                    MEM_RREADY <= 1; // Ready to accept read data
                    current_state_mem_read <= MEM_READ_DATA_B;
                end
            end

            MEM_READ_DATA_B: begin
                if (MEM_RVALID && MEM_RREADY) begin
                    DP_B <= MEM_RDATA; // Capture data for vector B
                    MEM_RREADY <= 0; // Data captured
					inputs_ready <= 1;
					vector_index <= vector_index + 1; // Move to next element
                    current_state_mem_read <= MEM_READ_IDLE;
                end
            end
        endcase
    end
end








// Instantiating dot_product_accelerator module
//dot_product_accelerator dp_accelerator (
//    .ACLK(ACLK),
//    .ARESETN(ARESETN),
//    .DP_A(DP_A),
//    .DP_B(DP_B),
//	.inputs_ready(inputs_ready),
//    .DP_START(DP_START),
//    .DP_RESULT(DP_RESULT),
//    .DP_DONE(DP_DONE)
//);

    // Dot Product Computation Logic
    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            DP_START <= 0;
            dot_product_result <= 0;
			dot_product_done <= 0;
        end else if (current_state == COMPUTE && !dot_product_done) begin
            DP_START <= 1;
            if (DP_DONE) begin
                dot_product_result <= DP_RESULT;
                DP_START <= 0;
				dot_product_done <= 1;
            end
        end
    end








// State Machine for AXI Memory Write Transaction
typedef enum logic [1:0] {
    MEM_WRITE_IDLE,
    MEM_WRITE_ADDR,
    MEM_WRITE_DATA,
    MEM_WRITE_RESP
} write_state_axi_mem;

write_state_axi_mem current_state_mem_write;

integer byte_counter;

// AXI Master <-> Memory Write Logic
always @(posedge ACLK or negedge ARESETN) begin
    if (!ARESETN) begin
        MEM_AWADDR  <= 0;
        MEM_AWVALID <= 0;
        MEM_WDATA   <= 0;
        MEM_WVALID  <= 0;
        MEM_BREADY  <= 0;
        current_state_mem_write <= MEM_WRITE_IDLE;
        result_write_done <= 0;
        byte_counter <= 0; // Counter to track which byte of dot_product_result is being written
    end else begin
        case (current_state_mem_write)
            // 1. Write Address Phase
            MEM_WRITE_IDLE: begin
                if (current_state == WRITE_RESULT && byte_counter < 4 && !result_write_done) begin
                    MEM_AWADDR  <= OUTPUT_ADDR + byte_counter; // Increment address for each byte
                    MEM_AWVALID <= 1;
                    current_state_mem_write <= MEM_WRITE_ADDR;
                end else if (byte_counter == 4) begin
                    result_write_done <= 1; // All bytes written
                    current_state_mem_write <= MEM_WRITE_IDLE;
                end
            end

            MEM_WRITE_ADDR: begin
                if (MEM_AWREADY) begin
                    MEM_AWVALID <= 0;  // Address accepted
                    case (byte_counter)
                        0: MEM_WDATA <= dot_product_result[7:0];
                        1: MEM_WDATA <= dot_product_result[15:8];
                        2: MEM_WDATA <= dot_product_result[23:16];
                        3: MEM_WDATA <= dot_product_result[31:24];
                    endcase
                    MEM_WVALID  <= 1;
                    current_state_mem_write <= MEM_WRITE_DATA;
                end
            end

            // 2. Write Data Phase
            MEM_WRITE_DATA: begin
                if (MEM_WREADY) begin
                    MEM_WVALID <= 0; // Data accepted
                    MEM_BREADY <= 1; // Ready to accept write response
                    current_state_mem_write <= MEM_WRITE_RESP;
                end
            end

            // 3. Write Response Phase
            MEM_WRITE_RESP: begin
                if (MEM_BVALID) begin
                    MEM_BREADY <= 0; // Response accepted
                    byte_counter <= byte_counter + 1; // Move to the next byte
                    current_state_mem_write <= MEM_WRITE_IDLE; // Return to IDLE to start the next write
                end
            end
        endcase
    end
end








// State Machine for AXI Slave Write Transaction
typedef enum logic [2:0] {
    SLV_WRITE_IDLE,
    SLV_WRITE_ADDR_REG4,
    SLV_WRITE_REG4,
    SLV_WRITE_RESP_REG4,
    SLV_WRITE_ADDR_REG5,
    SLV_WRITE_REG5,
    SLV_WRITE_RESP_REG5
} write_state_axi_slave;

write_state_axi_slave current_state_slave_write;

// AXI Master <-> AXI-Lite Write Slave Configuration Registers Logic
always @(posedge ACLK or negedge ARESETN) begin
    if (!ARESETN) begin
        AWADDR  <= 0;
        AWVALID <= 0;
        WDATA   <= 0;
        WVALID  <= 0;
        BREADY  <= 0;
        config_write_done <= 0;
        current_state_slave_write <= SLV_WRITE_IDLE;
    end else begin
        case (current_state_slave_write)
            SLV_WRITE_IDLE: begin
                if (current_state == UPDATE_STATUS && !config_write_done) begin
                    AWADDR  <= REG4_ADDR; // Write to REG4 (Output Register)
                    AWVALID <= 1;
                    current_state_slave_write <= SLV_WRITE_ADDR_REG4;
                end
            end

            SLV_WRITE_ADDR_REG4: begin
                if (AWREADY) begin
                    AWVALID <= 0;  // Address accepted
                    WDATA <= dot_product_result; // Write the dot product result to REG4
                    WVALID  <= 1;
                    current_state_slave_write <= SLV_WRITE_REG4;
                end
            end

            SLV_WRITE_REG4: begin
                if (WREADY) begin
                    WVALID <= 0; // Data accepted
                    BREADY <= 1; // Ready to accept write response
                    current_state_slave_write <= SLV_WRITE_RESP_REG4;
                end
            end

            SLV_WRITE_RESP_REG4: begin
                if (BVALID) begin
                    BREADY <= 0; // Response accepted
                    AWADDR  <= REG5_ADDR; // Write to REG5 (Status Register)
                    AWVALID <= 1;
                    current_state_slave_write <= SLV_WRITE_ADDR_REG5;
                end
			end

            SLV_WRITE_ADDR_REG5: begin
                if (AWREADY) begin
                    AWVALID <= 0;  // Address accepted
                    WDATA <= 32'h0000_0001; // Set "done" flag
                    WVALID  <= 1;
                    current_state_slave_write <= SLV_WRITE_REG5;
                end
			end

            SLV_WRITE_REG5: begin
                if (WREADY) begin
                    WVALID <= 0; // Data accepted
                    BREADY <= 1; // Ready to accept write response
                    current_state_slave_write <= SLV_WRITE_RESP_REG5;
                end
			end

            SLV_WRITE_RESP_REG5: begin
                if (BVALID) begin
                    BREADY <= 0; // Response accepted
					config_write_done <= 1;
                    current_state_slave_write <= SLV_WRITE_IDLE; // Return to IDLE to start the next write
				end
            end
			
        endcase
    end
end


endmodule