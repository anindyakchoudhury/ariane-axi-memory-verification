`include "common_cells/registers.svh"
`include "axi/assign.svh"

module axi_demux_simple #(
    parameter int unsigned AxiIdWidth  = 32'd0,
    parameter bit          AtopSupport = 1'b1,
    parameter type         axi_req_t   = logic,
    parameter type         axi_resp_t  = logic,
    parameter int unsigned NoMstPorts  = 32'd0,
    parameter int unsigned MaxTrans    = 32'd8,
    parameter int unsigned AxiLookBits = 32'd3,
    parameter bit          UniqueIds   = 1'b0,

    parameter int unsigned SelectWidth = (NoMstPorts > 32'd1) ? $clog2(NoMstPorts) : 32'd1,
    parameter type select_t = logic [SelectWidth-1:0]
) (
    input logic clk_i,
    input logic rst_ni,
    input logic test_i,

    input  axi_req_t  slv_req_i,
    input  select_t   slv_aw_select_i,
    input  select_t   slv_ar_select_i,
    output axi_resp_t slv_resp_o,

    output axi_req_t  [NoMstPorts-1:0] mst_reqs_o,
    input  axi_resp_t [NoMstPorts-1:0] mst_resps_i
);

  localparam int unsigned IdCounterWidth = cf_math_pkg::idx_width(MaxTrans);
  typedef logic [IdCounterWidth-1:0] id_cnt_t;

  if (NoMstPorts == 32'h1) begin : gen_no_demux
    `AXI_ASSIGN_REQ_STRUCT(mst_reqs_o[0], slv_req_i)
    `AXI_ASSIGN_RESP_STRUCT(slv_resp_o, mst_resps_i[0])
  end else begin

    logic lock_aw_valid_d, lock_aw_valid_q, load_aw_lock;
    logic aw_valid, aw_ready;

    select_t lookup_aw_select;
    logic aw_select_occupied, aw_id_cnt_full;

    logic atop_inject;

    select_t w_select, w_select_q;
    logic    w_select_valid;
    id_cnt_t w_open;
    logic w_cnt_up, w_cnt_down;

    logic [NoMstPorts-1:0] mst_b_valids, mst_b_readies;

    select_t lookup_ar_select;
    logic ar_select_occupied, ar_id_cnt_full;
    logic ar_push;

    logic lock_ar_valid_d, lock_ar_valid_q, load_ar_lock;
    logic ar_valid, ar_ready;

    logic [NoMstPorts-1:0] mst_r_valids, mst_r_readies;

    always_comb begin

      slv_resp_o.aw_ready = 1'b0;
      aw_valid            = 1'b0;

      lock_aw_valid_d     = lock_aw_valid_q;
      load_aw_lock        = 1'b0;

      w_cnt_up            = 1'b0;

      atop_inject         = 1'b0;

      if (lock_aw_valid_q) begin
        aw_valid = 1'b1;

        if (aw_ready) begin
          slv_resp_o.aw_ready = 1'b1;
          lock_aw_valid_d     = 1'b0;
          load_aw_lock        = 1'b1;

          atop_inject         = slv_req_i.aw.atop[axi_pkg::ATOP_R_RESP] & AtopSupport;
        end
      end else begin

        if (!aw_id_cnt_full && (w_open != {IdCounterWidth{1'b1}}) &&
            (!(ar_id_cnt_full && slv_req_i.aw.atop[axi_pkg::ATOP_R_RESP]) ||
             !AtopSupport)) begin

          if (slv_req_i.aw_valid &&
                ((w_open == '0) || (w_select == slv_aw_select_i)) &&
                (!aw_select_occupied || (slv_aw_select_i == lookup_aw_select))) begin

            aw_valid = 1'b1;

            w_cnt_up = 1'b1;

            if (aw_ready) begin
              slv_resp_o.aw_ready = 1'b1;
              atop_inject = slv_req_i.aw.atop[axi_pkg::ATOP_R_RESP] & AtopSupport;

            end else begin
              lock_aw_valid_d = 1'b1;
              load_aw_lock    = 1'b1;
            end
          end
        end
      end
    end

    `FFLARN(lock_aw_valid_q, lock_aw_valid_d, load_aw_lock, '0, clk_i, rst_ni)

    if (UniqueIds) begin : gen_unique_ids_aw

      assign lookup_aw_select = slv_aw_select_i;
      assign aw_select_occupied = 1'b0;
      assign aw_id_cnt_full = 1'b0;
    end else begin : gen_aw_id_counter
      axi_demux_id_counters #(
          .AxiIdBits        (AxiLookBits),
          .CounterWidth     (IdCounterWidth),
          .mst_port_select_t(select_t)
      ) i_aw_id_counter (
          .clk_i                       (clk_i),
          .rst_ni                      (rst_ni),
          .lookup_axi_id_i             (slv_req_i.aw.id[0+:AxiLookBits]),
          .lookup_mst_select_o         (lookup_aw_select),
          .lookup_mst_select_occupied_o(aw_select_occupied),
          .full_o                      (aw_id_cnt_full),
          .inject_axi_id_i             ('0),
          .inject_i                    (1'b0),
          .push_axi_id_i               (slv_req_i.aw.id[0+:AxiLookBits]),
          .push_mst_select_i           (slv_aw_select_i),
          .push_i                      (w_cnt_up),
          .pop_axi_id_i                (slv_resp_o.b.id[0+:AxiLookBits]),
          .pop_i                       (slv_resp_o.b_valid & slv_req_i.b_ready)
      );

    end

    counter #(
        .WIDTH          (IdCounterWidth),
        .STICKY_OVERFLOW(1'b0)
    ) i_counter_open_w (
        .clk_i,
        .rst_ni,
        .clear_i   (1'b0),
        .en_i      (w_cnt_up ^ w_cnt_down),
        .load_i    (1'b0),
        .down_i    (w_cnt_down),
        .d_i       ('0),
        .q_o       (w_open),
        .overflow_o()
    );

    `FFLARN(w_select_q, slv_aw_select_i, w_cnt_up, select_t'(0), clk_i, rst_ni)
    assign w_select       = (|w_open) ? w_select_q : slv_aw_select_i;
    assign w_select_valid = w_cnt_up | (|w_open);

    logic [cf_math_pkg::idx_width(NoMstPorts)-1:0] b_idx;

    rr_arb_tree #(
        .NumIn    (NoMstPorts),
        .DataType (logic),
        .AxiVldRdy(1'b1),
        .LockIn   (1'b1)
    ) i_b_mux (
        .clk_i  (clk_i),
        .rst_ni (rst_ni),
        .flush_i(1'b0),
        .rr_i   ('0),
        .req_i  (mst_b_valids),
        .gnt_o  (mst_b_readies),
        .data_i ('0),
        .gnt_i  (slv_req_i.b_ready),
        .req_o  (slv_resp_o.b_valid),
        .data_o (),
        .idx_o  (b_idx)
    );

    always_comb begin
      if (slv_resp_o.b_valid) begin
        `AXI_SET_B_STRUCT(slv_resp_o.b, mst_resps_i[b_idx].b)
      end else begin
        slv_resp_o.b = '0;
      end
    end

    always_comb begin

      slv_resp_o.ar_ready = 1'b0;
      ar_valid            = 1'b0;

      lock_ar_valid_d     = lock_ar_valid_q;
      load_ar_lock        = 1'b0;

      ar_push             = 1'b0;

      if (lock_ar_valid_q) begin
        ar_valid = 1'b1;

        if (ar_ready) begin
          slv_resp_o.ar_ready = 1'b1;
          ar_push             = 1'b1;
          lock_ar_valid_d     = 1'b0;
          load_ar_lock        = 1'b1;
        end
      end else begin

        if (!ar_id_cnt_full) begin

          if (slv_req_i.ar_valid && (!ar_select_occupied ||
             (slv_ar_select_i == lookup_ar_select))) begin

            ar_valid = 1'b1;

            if (ar_ready) begin
              slv_resp_o.ar_ready = 1'b1;
              ar_push             = 1'b1;

            end else begin
              lock_ar_valid_d = 1'b1;
              load_ar_lock    = 1'b1;
            end
          end
        end
      end
    end

    `FFLARN(lock_ar_valid_q, lock_ar_valid_d, load_ar_lock, '0, clk_i, rst_ni)

    if (UniqueIds) begin : gen_unique_ids_ar

      assign lookup_ar_select = slv_ar_select_i;
      assign ar_select_occupied = 1'b0;
      assign ar_id_cnt_full = 1'b0;
    end else begin : gen_ar_id_counter
      axi_demux_id_counters #(
          .AxiIdBits        (AxiLookBits),
          .CounterWidth     (IdCounterWidth),
          .mst_port_select_t(select_t)
      ) i_ar_id_counter (
          .clk_i                       (clk_i),
          .rst_ni                      (rst_ni),
          .lookup_axi_id_i             (slv_req_i.ar.id[0+:AxiLookBits]),
          .lookup_mst_select_o         (lookup_ar_select),
          .lookup_mst_select_occupied_o(ar_select_occupied),
          .full_o                      (ar_id_cnt_full),
          .inject_axi_id_i             (slv_req_i.aw.id[0+:AxiLookBits]),
          .inject_i                    (atop_inject),
          .push_axi_id_i               (slv_req_i.ar.id[0+:AxiLookBits]),
          .push_mst_select_i           (slv_ar_select_i),
          .push_i                      (ar_push),
          .pop_axi_id_i                (slv_resp_o.r.id[0+:AxiLookBits]),
          .pop_i                       (slv_resp_o.r_valid & slv_req_i.r_ready & slv_resp_o.r.last)
      );
    end

    logic [cf_math_pkg::idx_width(NoMstPorts)-1:0] r_idx;

    rr_arb_tree #(
        .NumIn    (NoMstPorts),
        .DataType (logic),
        .AxiVldRdy(1'b1),
        .LockIn   (1'b1)
    ) i_r_mux (
        .clk_i  (clk_i),
        .rst_ni (rst_ni),
        .flush_i(1'b0),
        .rr_i   ('0),
        .req_i  (mst_r_valids),
        .gnt_o  (mst_r_readies),
        .data_i ('0),
        .gnt_i  (slv_req_i.r_ready),
        .req_o  (slv_resp_o.r_valid),
        .data_o (),
        .idx_o  (r_idx)
    );

    always_comb begin
      if (slv_resp_o.r_valid) begin
        `AXI_SET_R_STRUCT(slv_resp_o.r, mst_resps_i[r_idx].r)
      end else begin
        slv_resp_o.r = '0;
      end
    end

    assign ar_ready = ar_valid & mst_resps_i[slv_ar_select_i].ar_ready;
    assign aw_ready = aw_valid & mst_resps_i[slv_aw_select_i].aw_ready;

    always_comb begin

      mst_reqs_o = '0;
      slv_resp_o.w_ready = 1'b0;
      w_cnt_down = 1'b0;

      for (int unsigned i = 0; i < NoMstPorts; i++) begin

        mst_reqs_o[i].aw       = slv_req_i.aw;
        mst_reqs_o[i].aw_valid = 1'b0;
        if (aw_valid && (slv_aw_select_i == i)) begin
          mst_reqs_o[i].aw_valid = 1'b1;
        end

        mst_reqs_o[i].w       = slv_req_i.w;
        mst_reqs_o[i].w_valid = 1'b0;
        if (w_select_valid && (w_select == i)) begin
          mst_reqs_o[i].w_valid = slv_req_i.w_valid;
          slv_resp_o.w_ready    = mst_resps_i[i].w_ready;
          w_cnt_down            = slv_req_i.w_valid & mst_resps_i[i].w_ready & slv_req_i.w.last;
        end

        mst_reqs_o[i].b_ready  = mst_b_readies[i];

        mst_reqs_o[i].ar       = slv_req_i.ar;
        mst_reqs_o[i].ar_valid = 1'b0;
        if (ar_valid && (slv_ar_select_i == i)) begin
          mst_reqs_o[i].ar_valid = 1'b1;
        end

        mst_reqs_o[i].r_ready = mst_r_readies[i];
      end
    end

    for (genvar i = 0; i < NoMstPorts; i++) begin : gen_b_channels

      assign mst_b_valids[i] = mst_resps_i[i].b_valid;

      assign mst_r_valids[i] = mst_resps_i[i].r_valid;
    end

  end
endmodule
