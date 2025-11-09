module axi_burst_splitter_ax_chan #(
  parameter type         chan_t  = logic,
  parameter int unsigned IdWidth = 0,
  parameter int unsigned MaxTxns = 0,
  parameter bit          FullBW  = 0,
  parameter type         id_t    = logic[IdWidth-1:0]
) (
  input  logic          clk_i,
  input  logic          rst_ni,

  input  chan_t         ax_i,
  input  logic          ax_valid_i,
  output logic          ax_ready_o,
  output chan_t         ax_o,
  output logic          ax_valid_o,
  input  logic          ax_ready_i,

  input  id_t           cnt_id_i,
  output axi_pkg::len_t cnt_len_o,
  input  logic          cnt_set_err_i,
  output logic          cnt_err_o,
  input  logic          cnt_dec_i,
  input  logic          cnt_req_i,
  output logic          cnt_gnt_o
);
  typedef logic[IdWidth-1:0] cnt_id_t;

  logic cnt_alloc_req, cnt_alloc_gnt;
  axi_burst_splitter_counters #(
    .MaxTxns ( MaxTxns  ),
    .FullBW  ( FullBW   ),
    .IdWidth ( IdWidth  )
  ) i_axi_burst_splitter_counters (
    .clk_i,
    .rst_ni,
    .alloc_id_i     ( ax_i.id       ),
    .alloc_len_i    ( ax_i.len      ),
    .alloc_req_i    ( cnt_alloc_req ),
    .alloc_gnt_o    ( cnt_alloc_gnt ),
    .cnt_id_i       ( cnt_id_i      ),
    .cnt_len_o      ( cnt_len_o     ),
    .cnt_set_err_i  ( cnt_set_err_i ),
    .cnt_err_o      ( cnt_err_o     ),
    .cnt_dec_i      ( cnt_dec_i     ),
    .cnt_req_i      ( cnt_req_i     ),
    .cnt_gnt_o      ( cnt_gnt_o     )
  );

  chan_t ax_d, ax_q;

  enum logic {Idle, Busy} state_d, state_q;
  always_comb begin
    cnt_alloc_req = 1'b0;
    ax_d          = ax_q;
    state_d       = state_q;
    ax_o          = '0;
    ax_valid_o    = 1'b0;
    ax_ready_o    = 1'b0;
    unique case (state_q)
      Idle: begin
        if (ax_valid_i && cnt_alloc_gnt) begin
          if (ax_i.len == '0) begin
            ax_o       = ax_i;
            ax_valid_o = 1'b1;

            if (ax_ready_i) begin
              cnt_alloc_req = 1'b1;
              ax_ready_o    = 1'b1;
            end
          end else begin

            ax_d          = ax_i;
            cnt_alloc_req = 1'b1;
            ax_ready_o    = 1'b1;

            ax_o       = ax_d;
            ax_o.len   = '0;
            ax_valid_o = 1'b1;
            if (ax_ready_i) begin

              ax_d.len--;
              if (ax_d.burst == axi_pkg::BURST_INCR) begin
                ax_d.addr += (1 << ax_d.size);
              end
            end
            state_d = Busy;
          end
        end
      end
      Busy: begin

        ax_o       = ax_q;
        ax_o.len   = '0;
        ax_valid_o = 1'b1;
        if (ax_ready_i) begin
          if (ax_q.len == '0) begin

            state_d = Idle;
          end else begin

            ax_d.len--;
            if (ax_q.burst == axi_pkg::BURST_INCR) begin
              ax_d.addr += (1 << ax_q.size);
            end
          end
        end
      end
      default: /*do nothing*/;
    endcase
  end

  `FFARN(ax_q, ax_d, '0, clk_i, rst_ni)
  `FFARN(state_q, state_d, Idle, clk_i, rst_ni)

endmodule

