module axi_to_axi_lite_id_reflect #(
  parameter int unsigned AxiIdWidth      = 32'd0,
  parameter int unsigned AxiMaxWriteTxns = 32'd0,
  parameter int unsigned AxiMaxReadTxns  = 32'd0,
  parameter bit          FallThrough     = 1'b1,
  parameter type         full_req_t      = logic,
  parameter type         full_resp_t     = logic,
  parameter type         lite_req_t      = logic,
  parameter type         lite_resp_t     = logic
) (
  input  logic       clk_i,
  input  logic       rst_ni,
  input  logic       test_i,

  input  full_req_t  slv_req_i,
  output full_resp_t slv_resp_o,

  output lite_req_t  mst_req_o,
  input  lite_resp_t mst_resp_i
);
  typedef logic [AxiIdWidth-1:0] id_t;

  logic aw_full, aw_empty, aw_push, aw_pop, ar_full, ar_empty, ar_push, ar_pop;
  id_t  aw_reflect_id, ar_reflect_id;

  assign slv_resp_o = '{
    aw_ready: mst_resp_i.aw_ready & ~aw_full,
    w_ready:  mst_resp_i.w_ready,
    b: '{
      id:       aw_reflect_id,
      resp:     mst_resp_i.b.resp,
      default:  '0
    },
    b_valid:  mst_resp_i.b_valid  & ~aw_empty,
    ar_ready: mst_resp_i.ar_ready & ~ar_full,
    r: '{
      id:       ar_reflect_id,
      data:     mst_resp_i.r.data,
      resp:     mst_resp_i.r.resp,
      last:     1'b1,
      default:  '0
    },
    r_valid: mst_resp_i.r_valid & ~ar_empty,
    default: '0
  };

  assign aw_push = mst_req_o.aw_valid & slv_resp_o.aw_ready;
  assign aw_pop  = slv_resp_o.b_valid & mst_req_o.b_ready;
  fifo_v3 #(
    .FALL_THROUGH ( FallThrough     ),
    .DEPTH        ( AxiMaxWriteTxns ),
    .dtype        ( id_t            )
  ) i_aw_id_fifo (
    .clk_i     ( clk_i           ),
    .rst_ni    ( rst_ni          ),
    .flush_i   ( 1'b0            ),
    .testmode_i( test_i          ),
    .full_o    ( aw_full         ),
    .empty_o   ( aw_empty        ),
    .usage_o   ( /*not used*/    ),
    .data_i    ( slv_req_i.aw.id ),
    .push_i    ( aw_push         ),
    .data_o    ( aw_reflect_id   ),
    .pop_i     ( aw_pop          )
  );

  assign ar_push = mst_req_o.ar_valid & slv_resp_o.ar_ready;
  assign ar_pop  = slv_resp_o.r_valid & mst_req_o.r_ready;
  fifo_v3 #(
    .FALL_THROUGH ( FallThrough    ),
    .DEPTH        ( AxiMaxReadTxns ),
    .dtype        ( id_t           )
  ) i_ar_id_fifo (
    .clk_i     ( clk_i           ),
    .rst_ni    ( rst_ni          ),
    .flush_i   ( 1'b0            ),
    .testmode_i( test_i          ),
    .full_o    ( ar_full         ),
    .empty_o   ( ar_empty        ),
    .usage_o   ( /*not used*/    ),
    .data_i    ( slv_req_i.ar.id ),
    .push_i    ( ar_push         ),
    .data_o    ( ar_reflect_id   ),
    .pop_i     ( ar_pop          )
  );

  assign mst_req_o = '{
    aw: '{
      addr: slv_req_i.aw.addr,
      prot: slv_req_i.aw.prot
    },
    aw_valid: slv_req_i.aw_valid & ~aw_full,
    w: '{
      data: slv_req_i.w.data,
      strb: slv_req_i.w.strb
    },
    w_valid:  slv_req_i.w_valid,
    b_ready:  slv_req_i.b_ready & ~aw_empty,
    ar: '{
      addr: slv_req_i.ar.addr,
      prot: slv_req_i.ar.prot
    },
    ar_valid: slv_req_i.ar_valid & ~ar_full,
    r_ready:  slv_req_i.r_ready  & ~ar_empty,
    default:  '0
  };

endmodule

