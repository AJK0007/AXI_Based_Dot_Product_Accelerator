module testbench_axi_system;

    // Inputs to top
    reg ACLK;
    reg ARESETN;
    reg start_signal;

    // Outputs from top
    wire [7:0] DP_A;
    wire [7:0] DP_B;
    wire [31:0] DP_RESULT;

    // Instantiate top-level module
    axi_system_top #(
		.REG0_val(32'h0000_0001), // User defined value for REG0 (Control Register)
		.REG1_val(32'h0000_0000), // User defined value for REG1 (Vector A Base Address)
		.REG2_val(32'h0000_0100), // User defined value for REG2 (Vector B Base Address)
		.REG3_val(32'h0000_0003), // User defined value for REG3 (Vector Length) 
		.REG4_val(32'h0000_1000), // User defined value for REG4 (Output Address)
		.REG5_val(32'h0000_0000)  // User defined value for REG5 (Status Register)
	) u_axi_system (
        .ACLK(ACLK),
        .ARESETN(ARESETN),
        .start_signal(start_signal),
        .DP_A(DP_A),
        .DP_B(DP_B),
        .DP_RESULT(DP_RESULT)
    );

    // Clock generation
    initial begin
        ACLK = 0;
        forever #5 ACLK = ~ACLK; // 100 MHz clock
    end

    // Testbench logic
    initial begin
	
        $monitor("DP_A: %h, DP_B: %h, DP_RESULT: %h", DP_A, DP_B, DP_RESULT);
        // Initialize inputs
        ARESETN = 0;
        start_signal = 0;

        // Release reset
        #20;
        ARESETN = 1;

        // Start the AXI Master
        #10;
        start_signal = 1;
        #10;
        start_signal = 0;

        // Wait for computation to complete
        #1000;

        // Display results
		$display("Time: %0t | mem[0] = %h | mem[1] = %h | mem[2] = %h", $time, u_axi_system.u_memory.mem[0], u_axi_system.u_memory.mem[1], u_axi_system.u_memory.mem[2]);
        $display("Time: %0t | mem[256] = %h | mem[257] = %h | mem[258] = %h", $time, u_axi_system.u_memory.mem[256], u_axi_system.u_memory.mem[257], u_axi_system.u_memory.mem[258]);
        $display("Time: %0t | mem[4096] = %h | mem[4097] = %h | mem[4098] = %h | mem[4099] = %h", $time, u_axi_system.u_memory.mem[4096], u_axi_system.u_memory.mem[4097], u_axi_system.u_memory.mem[4098], u_axi_system.u_memory.mem[4099]);
        // End simulation
        $finish;
    end

    // Dump all signals to a waveform file
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, testbench_axi_system); // Dump all signals in the testbench
    end

endmodule