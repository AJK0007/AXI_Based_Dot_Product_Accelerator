module memory #(
    //parameter ADDR_WIDTH = 32, // 32-bit address for 2^32 locations - Enormous memory!
    parameter ADDR_WIDTH = 16, // 16-bit address for 2^16 locations
    parameter DATA_WIDTH = 8   // 8-bit data width
)(
    // Clock and Reset
    input wire                      clk,
    input wire                      rst_n,

    // Write Address Channel
    input wire [ADDR_WIDTH-1:0]     awaddr,
    input wire                      awvalid,
    output reg                      awready,

    // Write Data Channel
    input wire [DATA_WIDTH-1:0]     wdata,
    input wire                      wvalid,
    output reg                      wready,

    // Write Response Channel
    output reg                      bvalid,
    input wire                      bready,

    // Read Address Channel
    input wire [ADDR_WIDTH-1:0]     araddr,
    input wire                      arvalid,
    output reg                      arready,

    // Read Data Channel
    output reg [DATA_WIDTH-1:0]     rdata,
    output reg                      rvalid,
    input wire                      rready
);

    // Memory Array
    reg [DATA_WIDTH-1:0] mem [0:(1 << ADDR_WIDTH)-1];

    // State Machine for Write Transaction
    typedef enum logic [1:0] {WRITE_IDLE, WRITE_ADDR, WRITE_DATA, WRITE_RESP} write_state_t;
    write_state_t write_state;

    // State Machine for Read Transaction
    typedef enum logic [1:0] {READ_IDLE, READ_ADDR, READ_DATA} read_state_t;
    read_state_t read_state;

    // Write Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_state <= WRITE_IDLE;
            awready <= 1'b0;
            wready <= 1'b0;
            bvalid <= 1'b0;
        end else begin
            case (write_state)
                WRITE_IDLE: begin
                    if (awvalid) begin
                        awready <= 1'b1;
                        write_state <= WRITE_ADDR;
                    end
                end

                WRITE_ADDR: begin
                    awready <= 1'b0;
                    if (wvalid) begin
                        wready <= 1'b1;
                        write_state <= WRITE_DATA;
                    end
                end

                WRITE_DATA: begin
                    wready <= 1'b0;
                    mem[awaddr] <= wdata; // Write data to memory
                    bvalid <= 1'b1;
                    write_state <= WRITE_RESP;
                end

                WRITE_RESP: begin
                    if (bready) begin
                        bvalid <= 1'b0;
                        write_state <= WRITE_IDLE;
                    end
                end
            endcase
        end
    end

    // Read Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_state <= READ_IDLE;
            arready <= 1'b0;
            rvalid <= 1'b0;
            rdata <= {DATA_WIDTH{1'b0}};
        end else begin
            case (read_state)
                READ_IDLE: begin
                    if (arvalid) begin
                        arready <= 1'b1;
						rdata <= {DATA_WIDTH{1'b0}};
                        read_state <= READ_ADDR;
                    end
                end

                READ_ADDR: begin
                    arready <= 1'b0;
                    rdata <= mem[araddr]; // Fetch data from memory
                    rvalid <= 1'b1;
                    read_state <= READ_DATA;
                end

                READ_DATA: begin
                    if (rready) begin
                        rvalid <= 1'b0;
                        read_state <= READ_IDLE;
                    end
                end
            endcase
        end
    end

    // Initialize Memory (for simulation)
    initial begin
        // Initialize memory with zeros (optional)
        for (integer i = 0; i < (1 << ADDR_WIDTH); i = i + 1) begin
            mem[i] = {DATA_WIDTH{1'b0}};
        end

        // Example: Initialize vectors A and B (for testing)
        mem[0] = 8'h01; // Vector A, element 0
        mem[1] = 8'h02; // Vector A, element 1
        mem[2] = 8'h03; // Vector A, element 2

        mem[256] = 8'h04; // Vector B, element 0
        mem[257] = 8'h05; // Vector B, element 1
        mem[258] = 8'h06; // Vector B, element 2
    end

endmodule