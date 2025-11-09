module spill_register_flushable #(
    parameter type T      = logic,
    parameter bit  Bypass = 1'b0
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic valid_i,
    input  logic flush_i,
    output logic ready_o,
    input  T     data_i,
    output logic valid_o,
    input  logic ready_i,
    output T     data_o
);

  if (Bypass) begin : gen_bypass
    assign valid_o = valid_i;
    assign ready_o = ready_i;
    assign data_o  = data_i;
  end else begin : gen_spill_reg

    T a_data_q;
    logic a_full_q;
    logic a_fill, a_drain;

    always_ff @(posedge clk_i or negedge rst_ni) begin : ps_a_data
      if (!rst_ni) a_data_q <= T'('0);
      else if (a_fill) a_data_q <= data_i;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : ps_a_full
      if (!rst_ni) a_full_q <= 0;
      else if (a_fill || a_drain) a_full_q <= a_fill;
    end

    T b_data_q;
    logic b_full_q;
    logic b_fill, b_drain;

    always_ff @(posedge clk_i or negedge rst_ni) begin : ps_b_data
      if (!rst_ni) b_data_q <= T'('0);
      else if (b_fill) b_data_q <= a_data_q;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : ps_b_full
      if (!rst_ni) b_full_q <= 0;
      else if (b_fill || b_drain) b_full_q <= b_fill;
    end

    assign a_fill  = valid_i && ready_o && (!flush_i);
    assign a_drain = (a_full_q && !b_full_q) || flush_i;

    assign b_fill  = a_drain && (!ready_i) && (!flush_i);
    assign b_drain = (b_full_q && ready_i) || flush_i;

    assign ready_o = !a_full_q || !b_full_q;

    assign valid_o = a_full_q | b_full_q;

    assign data_o  = b_full_q ? b_data_q : a_data_q;

  end

endmodule
