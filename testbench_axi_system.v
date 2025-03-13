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
		.REG0_val(32'h0000_0001), // Default value for REG0, program user defined value here
		.REG1_val(32'h0000_0000), // Default value for REG1, program user defined value here
		.REG2_val(32'h0000_0100), // Default value for REG2, program user defined value here
		.REG3_val(32'h0000_0003), // Default value for REG3, program user defined value here
		.REG4_val(32'h0001_0000), // Default value for REG4, program user defined value here
		.REG5_val(32'h0000_0000)  // Default value for REG5, program user defined value here
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
        $display("DP_A: %h, DP_B: %h, DP_RESULT: %h", DP_A, DP_B, DP_RESULT);

        // End simulation
        $finish;
    end

    // Dump all signals to a waveform file
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, testbench_axi_system); // Dump all signals in the testbench
    end

endmodule