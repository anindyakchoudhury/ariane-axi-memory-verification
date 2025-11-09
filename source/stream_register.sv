`include "common_cells/registers.svh"

module stream_register #(
    parameter type T = logic
) (
    input  logic    clk_i,
    input  logic    rst_ni,
    input  logic    clr_i,
    input  logic    testmode_i,

    input  logic    valid_i,
    output logic    ready_o,
    input  T        data_i,

    output logic    valid_o,
    input  logic    ready_i,
    output T        data_o
);

    logic reg_ena;
    assign ready_o = ready_i | ~valid_o;
    assign reg_ena = valid_i & ready_o;

    `FFLARNC(valid_o, valid_i, ready_o, clr_i, 1'b0  , clk_i, rst_ni)
    `FFLARNC(data_o,   data_i, reg_ena, clr_i, T'('0), clk_i, rst_ni)

endmodule
