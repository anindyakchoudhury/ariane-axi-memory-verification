module spill_register #(
    parameter type T      = logic,
    parameter bit  Bypass = 1'b0
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic valid_i,
    output logic ready_o,
    input  T     data_i,
    output logic valid_o,
    input  logic ready_i,
    output T     data_o
);

  spill_register_flushable #(
      .T(T),
      .Bypass(Bypass)
  ) spill_register_flushable_i (
      .clk_i,
      .rst_ni,
      .valid_i,
      .flush_i(1'b0),
      .ready_o,
      .data_i,
      .valid_o,
      .ready_i,
      .data_o
  );

endmodule
