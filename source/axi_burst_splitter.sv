`include "axi/typedef.svh"
`include "common_cells/registers.svh"

module axi_burst_splitter #(

    parameter int unsigned MaxReadTxns = 32'd0,

    parameter int unsigned MaxWriteTxns = 32'd0,

    parameter bit FullBW = 0,

    parameter int unsigned AddrWidth  = 32'd0,
    parameter int unsigned DataWidth  = 32'd0,
    parameter int unsigned IdWidth    = 32'd0,
    parameter int unsigned UserWidth  = 32'd0,
    parameter type         axi_req_t  = logic,
    parameter type         axi_resp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    input  axi_req_t  slv_req_i,
    output axi_resp_t slv_resp_o,

    output axi_req_t  mst_req_o,
    input  axi_resp_t mst_resp_i
);

  typedef logic [AddrWidth-1:0] addr_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [IdWidth-1:0] id_t;
  typedef logic [DataWidth/8-1:0] strb_t;
  typedef logic [UserWidth-1:0] user_t;
  `AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(b_chan_t, id_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(r_chan_t, data_t, id_t, user_t)

  axi_req_t act_req, unsupported_req;
  axi_resp_t act_resp, unsupported_resp;
  logic sel_aw_unsupported, sel_ar_unsupported;
  localparam int unsigned MaxTxns = (MaxReadTxns > MaxWriteTxns) ? MaxReadTxns : MaxWriteTxns;
  axi_demux #(
      .AxiIdWidth (IdWidth),
      .aw_chan_t  (aw_chan_t),
      .w_chan_t   (w_chan_t),
      .b_chan_t   (b_chan_t),
      .ar_chan_t  (ar_chan_t),
      .r_chan_t   (r_chan_t),
      .axi_req_t  (axi_req_t),
      .axi_resp_t (axi_resp_t),
      .NoMstPorts (2),
      .MaxTrans   (MaxTxns),
      .AxiLookBits(IdWidth),
      .SpillAw    (1'b0),
      .SpillW     (1'b0),
      .SpillB     (1'b0),
      .SpillAr    (1'b0),
      .SpillR     (1'b0)
  ) i_demux_supported_vs_unsupported (
      .clk_i,
      .rst_ni,
      .test_i         (1'b0),
      .slv_req_i,
      .slv_aw_select_i(sel_aw_unsupported),
      .slv_ar_select_i(sel_ar_unsupported),
      .slv_resp_o,
      .mst_reqs_o     ({unsupported_req, act_req}),
      .mst_resps_i    ({unsupported_resp, act_resp})
  );

  function bit txn_supported(axi_pkg::atop_t atop, axi_pkg::burst_t burst, axi_pkg::cache_t cache,
                             axi_pkg::len_t len);

    if (len == '0) return 1'b1;

    if (burst == axi_pkg::BURST_WRAP) return 1'b0;

    if (atop != '0) return 1'b0;

    // if (!axi_pkg::modifiable(cache)) begin
    //   return (burst == axi_pkg::BURST_INCR) & (len > 16);
    // end

    return 1'b1;
  endfunction

  always_comb
    sel_aw_unsupported =
        ~txn_supported(slv_req_i.aw.atop, slv_req_i.aw.burst, slv_req_i.aw.cache, slv_req_i.aw.len);
  always_comb
    sel_ar_unsupported =
        ~txn_supported('0, slv_req_i.ar.burst, slv_req_i.ar.cache, slv_req_i.ar.len);

  axi_err_slv #(
      .AxiIdWidth(IdWidth),
      .axi_req_t (axi_req_t),
      .axi_resp_t(axi_resp_t),
      .Resp      (axi_pkg::RESP_SLVERR),
      .ATOPs     (1'b0),
      .MaxTrans  (1)
  ) i_err_slv (
      .clk_i,
      .rst_ni,
      .test_i    (1'b0),
      .slv_req_i (unsupported_req),
      .slv_resp_o(unsupported_resp)
  );

  logic w_cnt_dec, w_cnt_req, w_cnt_gnt, w_cnt_err;
  axi_pkg::len_t w_cnt_len;
  axi_burst_splitter_ax_chan #(
      .chan_t (aw_chan_t),
      .IdWidth(IdWidth),
      .MaxTxns(MaxWriteTxns),
      .FullBW (FullBW)
  ) i_axi_burst_splitter_aw_chan (
      .clk_i,
      .rst_ni,
      .ax_i         (act_req.aw),
      .ax_valid_i   (act_req.aw_valid),
      .ax_ready_o   (act_resp.aw_ready),
      .ax_o         (mst_req_o.aw),
      .ax_valid_o   (mst_req_o.aw_valid),
      .ax_ready_i   (mst_resp_i.aw_ready),
      .cnt_id_i     (mst_resp_i.b.id),
      .cnt_len_o    (w_cnt_len),
      .cnt_set_err_i(mst_resp_i.b.resp[1]),
      .cnt_err_o    (w_cnt_err),
      .cnt_dec_i    (w_cnt_dec),
      .cnt_req_i    (w_cnt_req),
      .cnt_gnt_o    (w_cnt_gnt)
  );

  always_comb begin
    mst_req_o.w      = act_req.w;
    mst_req_o.w.last = 1'b1;
  end
  assign mst_req_o.w_valid = act_req.w_valid;
  assign act_resp.w_ready  = mst_resp_i.w_ready;

  enum logic {
    BReady,
    BWait
  }
      b_state_d, b_state_q;
  logic b_err_d, b_err_q;
  always_comb begin
    mst_req_o.b_ready = 1'b0;
    act_resp.b        = '0;
    act_resp.b_valid  = 1'b0;
    w_cnt_dec         = 1'b0;
    w_cnt_req         = 1'b0;
    b_err_d           = b_err_q;
    b_state_d         = b_state_q;

    unique case (b_state_q)
      BReady: begin
        if (mst_resp_i.b_valid) begin
          w_cnt_req = 1'b1;
          if (w_cnt_gnt) begin
            if (w_cnt_len == 8'd0) begin
              act_resp.b = mst_resp_i.b;
              if (w_cnt_err) begin
                act_resp.b.resp = axi_pkg::RESP_SLVERR;
              end
              act_resp.b_valid = 1'b1;
              w_cnt_dec        = 1'b1;
              if (act_req.b_ready) begin
                mst_req_o.b_ready = 1'b1;
              end else begin
                b_state_d = BWait;
                b_err_d   = w_cnt_err;
              end
            end else begin
              mst_req_o.b_ready = 1'b1;
              w_cnt_dec         = 1'b1;
            end
          end
        end
      end
      BWait: begin
        act_resp.b = mst_resp_i.b;
        if (b_err_q) begin
          act_resp.b.resp = axi_pkg::RESP_SLVERR;
        end
        act_resp.b_valid = 1'b1;
        if (mst_resp_i.b_valid && act_req.b_ready) begin
          mst_req_o.b_ready = 1'b1;
          b_state_d         = BReady;
        end
      end
      default:  /*do nothing*/;
    endcase
  end

  logic r_cnt_dec, r_cnt_req, r_cnt_gnt;
  axi_pkg::len_t r_cnt_len;
  axi_burst_splitter_ax_chan #(
      .chan_t (ar_chan_t),
      .IdWidth(IdWidth),
      .MaxTxns(MaxReadTxns),
      .FullBW (FullBW)
  ) i_axi_burst_splitter_ar_chan (
      .clk_i,
      .rst_ni,
      .ax_i         (act_req.ar),
      .ax_valid_i   (act_req.ar_valid),
      .ax_ready_o   (act_resp.ar_ready),
      .ax_o         (mst_req_o.ar),
      .ax_valid_o   (mst_req_o.ar_valid),
      .ax_ready_i   (mst_resp_i.ar_ready),
      .cnt_id_i     (mst_resp_i.r.id),
      .cnt_len_o    (r_cnt_len),
      .cnt_set_err_i(1'b0),
      .cnt_err_o    (),
      .cnt_dec_i    (r_cnt_dec),
      .cnt_req_i    (r_cnt_req),
      .cnt_gnt_o    (r_cnt_gnt)
  );

  logic r_last_d, r_last_q;
  enum logic {
    RFeedthrough,
    RWait
  }
      r_state_d, r_state_q;
  always_comb begin
    r_cnt_dec         = 1'b0;
    r_cnt_req         = 1'b0;
    r_last_d          = r_last_q;
    r_state_d         = r_state_q;
    mst_req_o.r_ready = 1'b0;
    act_resp.r        = mst_resp_i.r;
    act_resp.r.last   = 1'b0;
    act_resp.r_valid  = 1'b0;

    unique case (r_state_q)
      RFeedthrough: begin

        if (mst_resp_i.r_valid) begin
          r_cnt_req = 1'b1;
          if (r_cnt_gnt) begin
            r_last_d         = (r_cnt_len == 8'd0);
            act_resp.r.last  = r_last_d;

            r_cnt_dec        = 1'b1;

            act_resp.r_valid = 1'b1;
            if (act_req.r_ready) begin

              mst_req_o.r_ready = 1'b1;
            end else begin

              r_state_d = RWait;
            end
          end
        end
      end
      RWait: begin
        act_resp.r.last  = r_last_q;
        act_resp.r_valid = mst_resp_i.r_valid;
        if (mst_resp_i.r_valid && act_req.r_ready) begin
          mst_req_o.r_ready = 1'b1;
          r_state_d         = RFeedthrough;
        end
      end
      default:  /*do nothing*/;
    endcase
  end

  `FFARN(b_err_q, b_err_d, 1'b0, clk_i, rst_ni)
  `FFARN(b_state_q, b_state_d, BReady, clk_i, rst_ni)
  `FFARN(r_last_q, r_last_d, 1'b0, clk_i, rst_ni)
  `FFARN(r_state_q, r_state_d, RFeedthrough, clk_i, rst_ni)

endmodule

