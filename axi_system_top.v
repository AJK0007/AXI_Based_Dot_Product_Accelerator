module axi_system_top #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
// Register Parameters for configuring the accelerator
	parameter REG0_val = 32'h0000_0001, // Default value for REG0 (Control Register)
	parameter REG1_val = 32'h0000_0000, // Default value for REG1 (Vector A Base Address)
	parameter REG2_val = 32'h0000_0100, // Default value for REG2 (Vector B Base Address)
	parameter REG3_val = 32'h0000_0003, // Default value for REG3 (Vector Length)
	parameter REG4_val = 32'h0000_1000, // Default value for REG4 (Output Address)
	parameter REG5_val = 32'h0000_0000  // Default value for REG5 (Status Register)
)(
    input wire ACLK,
    input wire ARESETN,
    input wire start_signal,
    output wire [7:0] DP_A,
    output wire [7:0] DP_B,
    output wire [DATA_WIDTH-1:0] DP_RESULT
);

    // Internal signals for AXI-Lite Slave
    wire [ADDR_WIDTH-1:0] AWADDR;
    wire AWVALID;
    wire AWREADY;
    wire [DATA_WIDTH-1:0] WDATA;
    wire WVALID;
    wire WREADY;
    wire [1:0] BRESP;
    wire BVALID;
    wire BREADY;

    wire [ADDR_WIDTH-1:0] ARADDR;
    wire ARVALID;
    wire ARREADY;
    wire [DATA_WIDTH-1:0] RDATA;
    wire RVALID;
    wire RREADY;

    // Internal signals for Memory
    wire [ADDR_WIDTH-1:0] MEM_AWADDR;
    wire MEM_AWVALID;
    wire MEM_AWREADY;
    wire [7:0] MEM_WDATA;
    wire MEM_WVALID;
    wire MEM_WREADY;
    wire MEM_BVALID;
    wire MEM_BREADY;

    wire [ADDR_WIDTH-1:0] MEM_ARADDR;
    wire MEM_ARVALID;
    wire MEM_ARREADY;
    wire [7:0] MEM_RDATA;
    wire MEM_RVALID;
    wire MEM_RREADY;

    // Internal signal to connect AXI Master to DP Accelerator
    //wire [7:0] dp_a_internal;
    //wire [7:0] dp_b_internal;
    //wire [DATA_WIDTH-1:0] dp_result_internal;
	wire inputs_ready;
	wire [DATA_WIDTH-1:0] VECTOR_LENGTH_DP;
	wire DP_START;
	wire DP_DONE;
	

    // Instantiate AXI Master
    axi_master u_axi_master (
        .ACLK(ACLK),
        .ARESETN(ARESETN),
        .ARADDR(ARADDR),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),
        .RDATA(RDATA),
        .RVALID(RVALID),
        .RREADY(RREADY),
        .AWADDR(AWADDR),
        .AWVALID(AWVALID),
        .AWREADY(AWREADY),
        .WDATA(WDATA),
        .WVALID(WVALID),
        .WREADY(WREADY),
        .BRESP(BRESP),
        .BVALID(BVALID),
        .BREADY(BREADY),
        .MEM_ARADDR(MEM_ARADDR),
        .MEM_ARVALID(MEM_ARVALID),
        .MEM_ARREADY(MEM_ARREADY),
        .MEM_RDATA(MEM_RDATA),
        .MEM_RVALID(MEM_RVALID),
        .MEM_RREADY(MEM_RREADY),
        .MEM_AWADDR(MEM_AWADDR),
        .MEM_AWVALID(MEM_AWVALID),
        .MEM_AWREADY(MEM_AWREADY),
        .MEM_WDATA(MEM_WDATA),
        .MEM_WVALID(MEM_WVALID),
        .MEM_WREADY(MEM_WREADY),
        .MEM_BVALID(MEM_BVALID),
        .MEM_BREADY(MEM_BREADY),
        .DP_A(DP_A),
        .DP_B(DP_B),
        .DP_RESULT(DP_RESULT),
        .DP_START(DP_START),
        .DP_DONE(DP_DONE),
        .inputs_ready(inputs_ready),
		.VECTOR_LENGTH_DP(VECTOR_LENGTH_DP),
        .start_signal(start_signal)
    );

    // Instantiate AXI-Lite Slave
    axi_lite_slave #(
		.REG0_val(REG0_val), // Connecting register parameter for configuring the accelerator
		.REG1_val(REG1_val), // Connecting register parameter for configuring the accelerator
		.REG2_val(REG2_val), // Connecting register parameter for configuring the accelerator
		.REG3_val(REG3_val), // Connecting register parameter for configuring the accelerator
		.REG4_val(REG4_val), // Connecting register parameter for configuring the accelerator
		.REG5_val(REG5_val)  // Connecting register parameter for configuring the accelerator
		
	) u_axi_lite_slave (
        .ACLK(ACLK),
        .ARESETN(ARESETN),
        .AWADDR(AWADDR),
        .AWVALID(AWVALID),
        .AWREADY(AWREADY),
        .WDATA(WDATA),
        .WVALID(WVALID),
        .WREADY(WREADY),
        .BRESP(BRESP),
        .BVALID(BVALID),
        .BREADY(BREADY),
        .ARADDR(ARADDR),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),
        .RDATA(RDATA),
        .RVALID(RVALID),
        .RREADY(RREADY)
    );

    // Instantiate Memory
    memory u_memory (
        .clk(ACLK),
        .rst_n(ARESETN),
        .awaddr(MEM_AWADDR),
        .awvalid(MEM_AWVALID),
        .awready(MEM_AWREADY),
        .wdata(MEM_WDATA),
        .wvalid(MEM_WVALID),
        .wready(MEM_WREADY),
        .bvalid(MEM_BVALID),
        .bready(MEM_BREADY),
        .araddr(MEM_ARADDR),
        .arvalid(MEM_ARVALID),
        .arready(MEM_ARREADY),
        .rdata(MEM_RDATA),
        .rvalid(MEM_RVALID),
        .rready(MEM_RREADY)
    );

    // Instantiate Dot Product Accelerator
    dot_product_accelerator u_dot_product_accelerator (
        .ACLK(ACLK),
        .ARESETN(ARESETN),
        .DP_A(DP_A),
        .DP_B(DP_B),
        .inputs_ready(inputs_ready),
		.VECTOR_LENGTH_DP(VECTOR_LENGTH_DP),
        .DP_START(DP_START),
        .DP_RESULT(DP_RESULT),
        .DP_DONE(DP_DONE)
    );

//    // Assign the output
	//assign DP_A = dp_a_internal;
	//assign DP_B = dp_b_internal;
    //assign DP_RESULT = dp_result_internal;

endmodule