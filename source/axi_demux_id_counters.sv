module axi_demux_id_counters #(
    parameter int unsigned AxiIdBits         = 2,
    parameter int unsigned CounterWidth      = 4,
    parameter type         mst_port_select_t = logic
) (
    input clk_i,
    input rst_ni,

    input logic [AxiIdBits-1:0] lookup_axi_id_i,
    output mst_port_select_t lookup_mst_select_o,
    output logic lookup_mst_select_occupied_o,

    output logic full_o,
    input logic [AxiIdBits-1:0] push_axi_id_i,
    input mst_port_select_t push_mst_select_i,
    input logic push_i,

    input logic [AxiIdBits-1:0] inject_axi_id_i,
    input logic inject_i,

    input logic [AxiIdBits-1:0] pop_axi_id_i,
    input logic pop_i
);
  localparam int unsigned NoCounters = 2 ** AxiIdBits;
  typedef logic [CounterWidth-1:0] cnt_t;
  mst_port_select_t [NoCounters-1:0] mst_select_q;
  logic [NoCounters-1:0] push_en, inject_en, pop_en, occupied, cnt_full;

  assign lookup_mst_select_o          = mst_select_q[lookup_axi_id_i];
  assign lookup_mst_select_occupied_o = occupied[lookup_axi_id_i];
  assign push_en                      = (push_i) ? (1 << push_axi_id_i) : '0;
  assign inject_en                    = (inject_i) ? (1 << inject_axi_id_i) : '0;
  assign pop_en                       = (pop_i) ? (1 << pop_axi_id_i) : '0;
  assign full_o                       = |cnt_full;

  for (genvar i = 0; i < NoCounters; i++) begin : gen_counters
    logic cnt_en, cnt_down, overflow;
    cnt_t cnt_delta, in_flight;
    always_comb begin
      unique case ({
        push_en[i], inject_en[i], pop_en[i]
      })
        3'b001: begin
          cnt_en    = 1'b1;
          cnt_down  = 1'b1;
          cnt_delta = cnt_t'(1);
        end
        3'b010: begin
          cnt_en    = 1'b1;
          cnt_down  = 1'b0;
          cnt_delta = cnt_t'(1);
        end

        3'b100: begin
          cnt_en    = 1'b1;
          cnt_down  = 1'b0;
          cnt_delta = cnt_t'(1);
        end

        3'b110: begin
          cnt_en    = 1'b1;
          cnt_down  = 1'b0;
          cnt_delta = cnt_t'(2);
        end
        3'b111: begin
          cnt_en    = 1'b1;
          cnt_down  = 1'b0;
          cnt_delta = cnt_t'(1);
        end
        default: begin
          cnt_en    = 1'b0;
          cnt_down  = 1'b0;
          cnt_delta = cnt_t'(0);
        end
      endcase
    end

    delta_counter #(
        .WIDTH          (CounterWidth),
        .STICKY_OVERFLOW(1'b0)
    ) i_in_flight_cnt (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),
        .clear_i   (1'b0),
        .en_i      (cnt_en),
        .load_i    (1'b0),
        .down_i    (cnt_down),
        .delta_i   (cnt_delta),
        .d_i       ('0),
        .q_o       (in_flight),
        .overflow_o(overflow)
    );
    assign occupied[i] = |in_flight;
    assign cnt_full[i] = overflow | (&in_flight);

    `FFLARN(mst_select_q[i], push_mst_select_i, push_en[i], '0, clk_i, rst_ni)

  end
endmodule

