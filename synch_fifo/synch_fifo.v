module synch_fifo(clk, reset, wr_en, wr_data, wr_ptr, rd_en, rd_data, rd_ptr, empty, full);
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;

    input clk, reset, wr_en, rd_en;
    input [DATA_WIDTH-1:0] wr_data;
    output reg [DATA_WIDTH-1:0] rd_data;
    output reg [ADDR_WIDTH:0] wr_ptr, rd_ptr;
    output empty, full;

    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    wire [ADDR_WIDTH-1:0] wr_addr = wr_ptr[ADDR_WIDTH-1:0];
    wire [ADDR_WIDTH-1:0] rd_addr = rd_ptr[ADDR_WIDTH-1:0];

    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) && (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);

    always @(posedge clk) begin
        if (reset) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
        end else begin
            if (wr_en && !full) begin
                mem[wr_addr] <= wr_data;
                wr_ptr <= wr_ptr + 1;
            end

            if (rd_en && !empty) begin
                rd_data <= mem[rd_addr];
                rd_ptr <= rd_ptr + 1;
            end
        end
    end
endmodule
