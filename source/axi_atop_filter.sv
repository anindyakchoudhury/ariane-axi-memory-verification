module axi_atop_filter #(
    parameter int unsigned AxiIdWidth = 0,
    parameter int unsigned AxiMaxWriteTxns = 0,
    parameter type axi_req_t  = logic,
    parameter type axi_resp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,
    input axi_req_t slv_req_i,
    output axi_resp_t slv_resp_o,
    output axi_req_t mst_req_o,
    input axi_resp_t mst_resp_i
);

  localparam int unsigned COUNTER_WIDTH = (AxiMaxWriteTxns == 1) ? 2 : $clog2(AxiMaxWriteTxns + 1);
  typedef struct packed {
    logic                     underflow;
    logic [COUNTER_WIDTH-1:0] cnt;
  } cnt_t;
  cnt_t w_cnt_d, w_cnt_q;

  typedef enum logic [2:0] {
    W_RESET,
    W_FEEDTHROUGH,
    BLOCK_AW,
    ABSORB_W,
    HOLD_B,
    INJECT_B,
    WAIT_R
  } w_state_e;
  w_state_e w_state_d, w_state_q;

  typedef enum logic [1:0] {
    R_RESET,
    R_FEEDTHROUGH,
    INJECT_R,
    R_HOLD
  } r_state_e;
  r_state_e r_state_d, r_state_q;

  typedef logic [AxiIdWidth-1:0] id_t;
  id_t id_d, id_q;

  typedef logic [7:0] len_t;
  len_t r_beats_d, r_beats_q;

  typedef struct packed {len_t len;} r_resp_cmd_t;
  r_resp_cmd_t r_resp_cmd_push, r_resp_cmd_pop;

  logic
      aw_without_complete_w_downstream,
      complete_w_without_aw_downstream,
      r_resp_cmd_push_valid,
      r_resp_cmd_push_ready,
      r_resp_cmd_pop_valid,
      r_resp_cmd_pop_ready;

  assign aw_without_complete_w_downstream = !w_cnt_q.underflow && (w_cnt_q.cnt > 0);

  assign complete_w_without_aw_downstream = w_cnt_q.underflow && &(w_cnt_q.cnt);

  always_comb begin

    mst_req_o.aw_valid    = 1'b0;
    slv_resp_o.aw_ready   = 1'b0;
    mst_req_o.w_valid     = 1'b0;
    slv_resp_o.w_ready    = 1'b0;

    mst_req_o.b_ready     = slv_req_i.b_ready;
    slv_resp_o.b_valid    = mst_resp_i.b_valid;
    slv_resp_o.b          = mst_resp_i.b;

    id_d                  = id_q;

    r_resp_cmd_push_valid = 1'b0;

    w_state_d             = w_state_q;

    unique case (w_state_q)
      W_RESET: w_state_d = W_FEEDTHROUGH;

      W_FEEDTHROUGH: begin

        if (complete_w_without_aw_downstream || (w_cnt_q.cnt < AxiMaxWriteTxns)) begin
          mst_req_o.aw_valid  = slv_req_i.aw_valid;
          slv_resp_o.aw_ready = mst_resp_i.aw_ready;
        end

        if (aw_without_complete_w_downstream

            || ((slv_req_i.aw_valid && slv_req_i.aw.atop[5:4] == axi_pkg::ATOP_NONE)
                && !complete_w_without_aw_downstream)
        ) begin
          mst_req_o.w_valid  = slv_req_i.w_valid;
          slv_resp_o.w_ready = mst_resp_i.w_ready;
        end

        if (slv_req_i.aw_valid && slv_req_i.aw.atop[5:4] != axi_pkg::ATOP_NONE) begin
          mst_req_o.aw_valid = 1'b0;
          slv_resp_o.aw_ready = 1'b1;
          id_d = slv_req_i.aw.id;

          if (slv_req_i.aw.atop[axi_pkg::ATOP_R_RESP]) begin

            r_resp_cmd_push_valid = 1'b1;
          end

          if (aw_without_complete_w_downstream) begin
            w_state_d = BLOCK_AW;

          end else begin
            mst_req_o.w_valid  = 1'b0;
            slv_resp_o.w_ready = 1'b1;
            if (slv_req_i.w_valid && slv_req_i.w.last) begin

              if (slv_resp_o.b_valid && !slv_req_i.b_ready) begin
                w_state_d = HOLD_B;
              end else begin
                w_state_d = INJECT_B;
              end
            end else begin

              w_state_d = ABSORB_W;
            end
          end
        end
      end

      BLOCK_AW: begin

        if (aw_without_complete_w_downstream) begin
          mst_req_o.w_valid  = slv_req_i.w_valid;
          slv_resp_o.w_ready = mst_resp_i.w_ready;
        end else begin

          slv_resp_o.w_ready = 1'b1;
          if (slv_req_i.w_valid && slv_req_i.w.last) begin

            if (slv_resp_o.b_valid && !slv_req_i.b_ready) begin
              w_state_d = HOLD_B;
            end else begin
              w_state_d = INJECT_B;
            end
          end else begin

            w_state_d = ABSORB_W;
          end
        end
      end

      ABSORB_W: begin

        slv_resp_o.w_ready = 1'b1;
        if (slv_req_i.w_valid && slv_req_i.w.last) begin
          if (slv_resp_o.b_valid && !slv_req_i.b_ready) begin
            w_state_d = HOLD_B;
          end else begin
            w_state_d = INJECT_B;
          end
        end
      end

      HOLD_B: begin

        if (slv_resp_o.b_valid && slv_req_i.b_ready) begin
          w_state_d = INJECT_B;
        end
      end

      INJECT_B: begin

        mst_req_o.b_ready = 1'b0;

        slv_resp_o.b = '0;
        slv_resp_o.b.id = id_q;
        slv_resp_o.b.resp = axi_pkg::RESP_SLVERR;
        slv_resp_o.b_valid = 1'b1;
        if (slv_req_i.b_ready) begin

          if (r_resp_cmd_pop_valid && !r_resp_cmd_pop_ready) begin
            w_state_d = WAIT_R;
          end else begin
            w_state_d = W_FEEDTHROUGH;
          end
        end
      end

      WAIT_R: begin

        if (!r_resp_cmd_pop_valid) begin
          w_state_d = W_FEEDTHROUGH;
        end
      end

      default: w_state_d = W_RESET;
    endcase
  end

  always_comb begin

    mst_req_o.aw      = slv_req_i.aw;
    mst_req_o.aw.atop = '0;
  end
  assign mst_req_o.w = slv_req_i.w;

  always_comb begin

    slv_resp_o.r         = mst_resp_i.r;
    slv_resp_o.r_valid   = mst_resp_i.r_valid;
    mst_req_o.r_ready    = slv_req_i.r_ready;

    r_resp_cmd_pop_ready = 1'b0;

    r_beats_d            = r_beats_q;

    r_state_d            = r_state_q;

    unique case (r_state_q)
      R_RESET: r_state_d = R_FEEDTHROUGH;

      R_FEEDTHROUGH: begin
        if (mst_resp_i.r_valid && !slv_req_i.r_ready) begin
          r_state_d = R_HOLD;
        end else if (r_resp_cmd_pop_valid) begin

          r_beats_d = r_resp_cmd_pop.len;
          r_state_d = INJECT_R;
        end
      end

      INJECT_R: begin
        mst_req_o.r_ready  = 1'b0;
        slv_resp_o.r       = '0;
        slv_resp_o.r.id    = id_q;
        slv_resp_o.r.resp  = axi_pkg::RESP_SLVERR;
        slv_resp_o.r.last  = (r_beats_q == '0);
        slv_resp_o.r_valid = 1'b1;
        if (slv_req_i.r_ready) begin
          if (slv_resp_o.r.last) begin
            r_resp_cmd_pop_ready = 1'b1;
            r_state_d = R_FEEDTHROUGH;
          end else begin
            r_beats_d -= 1;
          end
        end
      end

      R_HOLD: begin
        if (mst_resp_i.r_valid && slv_req_i.r_ready) begin
          r_state_d = R_FEEDTHROUGH;
        end
      end

      default: r_state_d = R_RESET;
    endcase
  end

  assign mst_req_o.ar        = slv_req_i.ar;
  assign mst_req_o.ar_valid  = slv_req_i.ar_valid;
  assign slv_resp_o.ar_ready = mst_resp_i.ar_ready;

  always_comb begin
    w_cnt_d = w_cnt_q;
    if (mst_req_o.aw_valid && mst_resp_i.aw_ready) begin
      w_cnt_d.cnt += 1;
    end
    if (mst_req_o.w_valid && mst_resp_i.w_ready && mst_req_o.w.last) begin
      w_cnt_d.cnt -= 1;
    end
    if (w_cnt_q.underflow && (w_cnt_d.cnt == '0)) begin
      w_cnt_d.underflow = 1'b0;
    end else if (w_cnt_q.cnt == '0 && &(w_cnt_d.cnt)) begin
      w_cnt_d.underflow = 1'b1;
    end
  end

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      id_q <= '0;
      r_beats_q <= '0;
      r_state_q <= R_RESET;
      w_cnt_q <= '{default: '0};
      w_state_q <= W_RESET;
    end else begin
      id_q <= id_d;
      r_beats_q <= r_beats_d;
      r_state_q <= r_state_d;
      w_cnt_q <= w_cnt_d;
      w_state_q <= w_state_d;
    end
  end

  stream_register #(
      .T(r_resp_cmd_t)
  ) r_resp_cmd (
      .clk_i     (clk_i),
      .rst_ni    (rst_ni),
      .clr_i     (1'b0),
      .testmode_i(1'b0),
      .valid_i   (r_resp_cmd_push_valid),
      .ready_o   (r_resp_cmd_push_ready),
      .data_i    (r_resp_cmd_push),
      .valid_o   (r_resp_cmd_pop_valid),
      .ready_i   (r_resp_cmd_pop_ready),
      .data_o    (r_resp_cmd_pop)
  );
  assign r_resp_cmd_push.len = slv_req_i.aw.len;

endmodule
