module dot_product_accelerator #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input wire ACLK,
    input wire ARESETN,
    input wire [7:0] DP_A,
    input wire [7:0] DP_B,
    input wire inputs_ready,
	input wire [DATA_WIDTH-1:0] VECTOR_LENGTH_DP,
	input wire DP_START,
    output reg [DATA_WIDTH-1:0] DP_RESULT,
    output reg DP_DONE
);

    reg [31:0] accumulated_result;
    reg inputs_ready_d;
    wire inputs_ready_posedge;
	integer vector_length_counter;
    
    assign inputs_ready_posedge = inputs_ready & ~inputs_ready_d;
    
    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            accumulated_result <= 0;
            DP_RESULT <= 0;
            DP_DONE <= 0;
            inputs_ready_d <= 0;
			vector_length_counter <=0;
        end else begin
            inputs_ready_d <= inputs_ready;
            if (inputs_ready_posedge) begin
                accumulated_result <= accumulated_result + (DP_A * DP_B);
				vector_length_counter <= vector_length_counter + 1;
            end
            else if (vector_length_counter == VECTOR_LENGTH_DP && VECTOR_LENGTH_DP != 0 && DP_START) begin
				DP_DONE <= 1;
				DP_RESULT <= accumulated_result;
			end
        end
    end
    
//    always @(posedge ACLK or negedge ARESETN) begin
//        if (!ARESETN) begin
//            DP_RESULT <= 0;
//        end else if (DP_START && DP_DONE) begin
//            DP_RESULT <= accumulated_result;
//        end
//    end
    
endmodule