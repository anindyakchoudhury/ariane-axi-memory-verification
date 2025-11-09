module lzc #(

    parameter int unsigned WIDTH = 2,
    parameter int unsigned MODE  = 0
) (
    input  logic [        WIDTH-1:0] in_i,
    output logic [$clog2(WIDTH)-1:0] cnt_o,
    output logic                     empty_o
);

  localparam int NUM_LEVELS = $clog2(WIDTH);

  initial begin
    assert (WIDTH > 0)
    else $fatal(1, "input must be at least one bit wide");
  end

  logic [        WIDTH-1:0][NUM_LEVELS-1:0] index_lut;
  logic [2**NUM_LEVELS-1:0]                 sel_nodes;
  logic [2**NUM_LEVELS-1:0][NUM_LEVELS-1:0] index_nodes;

  logic [        WIDTH-1:0]                 in_tmp;

  assign in_tmp = MODE ? {<<{in_i}} : in_i;

  for (genvar j = 0; j < WIDTH; j++) begin : g_index_lut
    assign index_lut[j] = j;
  end

  for (genvar level = 0; level < NUM_LEVELS; level++) begin : g_levels
    if (level == NUM_LEVELS - 1) begin : g_last_level
      for (genvar k = 0; k < 2 ** level; k++) begin : g_level

        if (k * 2 < WIDTH - 1) begin
          assign sel_nodes[2**level-1+k] = in_tmp[k*2] | in_tmp[k*2+1];
          assign index_nodes[2**level-1+k] = (in_tmp[k*2] == 1'b1) ? index_lut[k*2] :
                                                                     index_lut[k*2+1];
        end

        if (k * 2 == WIDTH - 1) begin
          assign sel_nodes[2**level-1+k]   = in_tmp[k*2];
          assign index_nodes[2**level-1+k] = index_lut[k*2];
        end

        if (k * 2 > WIDTH - 1) begin
          assign sel_nodes[2**level-1+k]   = 1'b0;
          assign index_nodes[2**level-1+k] = '0;
        end
      end
    end else begin
      for (genvar l = 0; l < 2 ** level; l++) begin : g_level
        assign sel_nodes[2**level-1+l]   = sel_nodes[2**(level+1)-1+l*2] | sel_nodes[2**(level+1)-1+l*2+1];
        assign index_nodes[2**level-1+l] = (sel_nodes[2**(level+1)-1+l*2] == 1'b1) ? index_nodes[2**(level+1)-1+l*2] :
                                                                                     index_nodes[2**(level+1)-1+l*2+1];
      end
    end
  end

  assign cnt_o   = NUM_LEVELS > 0 ? index_nodes[0] : '0;
  assign empty_o = NUM_LEVELS > 0 ? ~sel_nodes[0] : ~(|in_i);

endmodule : lzc
