
module fifo(clk,rst,data_in,wr_en,rd_en,data_out,full,empty);

  input clk,rst,wr_en,rd_en;

  parameter DEPTH = 16;
  parameter WIDTH = 8;
  parameter ADDR = $clog2(DEPTH);

  input [WIDTH-1:0] data_in;
  output reg [WIDTH-1:0] data_out;
  output full,empty;

  reg [ADDR-1:0] wr_ptr,rd_ptr;
  reg [WIDTH-1:0] mem [0:DEPTH-1];

  reg [ADDR+1:0] count;

  integer i;

  always @(posedge clk) begin
    if(rst) begin
      wr_ptr <= 0;

      for(i=0;i<DEPTH;i++) begin
        mem[i] <= 0;
      end
    end
    else begin
      if(wr_en && !full) begin
        mem[wr_ptr] <= data_in;

        if(wr_ptr == DEPTH-1)
          wr_ptr <= 0;
        else
          wr_ptr <= wr_ptr + 1'b1;
      end
    end
  end

  always @(posedge clk) begin
    if(rst) begin
      data_out <= 0;
      rd_ptr <= 0;
    end
    else begin
      if(rd_en && !empty) begin
        data_out <= mem[rd_ptr];

        if(rd_ptr == DEPTH-1)
          rd_ptr <= 0;
        else
          rd_ptr <= rd_ptr + 1'b1;
      end
    end
  end

  always @(posedge clk) begin
    if(rst)
      count <= 0;
    else begin
      case ({wr_en && !full, rd_en && !empty})

        2'b10: count <= count + 1'b1;

        2'b01: count <= count - 1'b1;

        default: count <= count;

      endcase
    end
  end

  assign full  = (count == DEPTH);
  assign empty = (count == 0);

endmodule
