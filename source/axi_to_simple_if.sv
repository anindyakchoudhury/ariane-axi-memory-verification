`include "axi/typedef.svh"

module axi_to_simple_if #(
    parameter type         axi_req_t  = ariane_axi_pkg::m_req_t,
    parameter type         axi_resp_t = ariane_axi_pkg::m_resp_t,
    parameter logic [63:0] MEM_BASE   = '0,
    parameter int          MEM_SIZE   = 32
) (
    input  logic      arst_ni,
    input  logic      clk_i,
    input  axi_req_t  req_i,
    output axi_resp_t resp_o,

    output logic                           mem_we_o,
    output logic [           MEM_SIZE-1:0] mem_waddr_o,
    output logic [$bits(req_i.w.data)-1:0] mem_wdata_o,
    output logic [$bits(req_i.w.strb)-1:0] mem_wstrb_o,
    input  logic [                    1:0] mem_wresp_i,

    output logic                           mem_re_o,
    output logic [           MEM_SIZE-1:0] mem_raddr_o,
    input  logic [$bits(req_i.w.data)-1:0] mem_rdata_i,
    input  logic [                    1:0] mem_rresp_i
);

  localparam int IW = $bits(req_i.aw.id);
  localparam int AW = $bits(req_i.aw.addr);
  localparam int UW = $bits(req_i.aw.user);
  localparam int DW = $bits(req_i.w.data);

  `AXI_LITE_TYPEDEF_ALL(axil, logic [AW-1:0], logic [DW-1:0], logic [DW/8-1:0])

  axil_req_t  l_req_fi;
  axil_resp_t l_resp_fi;
  axil_req_t  l_req_fo;
  axil_resp_t l_resp_fo;

  axi_to_axi_lite #(
      .AxiAddrWidth   (AW),
      .AxiDataWidth   (DW),
      .AxiIdWidth     (IW),
      .AxiUserWidth   (UW),
      .AxiMaxWriteTxns(2),
      .AxiMaxReadTxns (2),
      .FullBW         (0),
      .FallThrough    (0),
      .full_req_t     (axi_req_t),
      .full_resp_t    (axi_resp_t),
      .lite_req_t     (axil_req_t),
      .lite_resp_t    (axil_resp_t)
  ) u_axi_to_axi_lite (
      .clk_i     (clk_i),
      .rst_ni    (arst_ni),
      .test_i    ('0),
      .slv_req_i (req_i),
      .slv_resp_o(resp_o),
      .mst_req_o (l_req_fi),
      .mst_resp_i(l_resp_fi)
  );

  axi_fifo #(
      .Depth      (4),
      .FallThrough('0),
      .aw_chan_t  (axil_aw_chan_t),
      .w_chan_t   (axil_w_chan_t),
      .b_chan_t   (axil_b_chan_t),
      .ar_chan_t  (axil_ar_chan_t),
      .r_chan_t   (axil_r_chan_t),
      .axi_req_t  (axil_req_t),
      .axi_resp_t (axil_resp_t)
  ) u_axi_fifo (
      .clk_i     (clk_i),
      .rst_ni    (arst_ni),
      .test_i    ('0),
      .slv_req_i (l_req_fi),
      .slv_resp_o(l_resp_fi),
      .mst_req_o (l_req_fo),
      .mst_resp_i(l_resp_fo)
  );

  always_comb mem_we_o = l_req_fo.aw_valid & l_req_fo.w_valid & l_req_fo.b_ready;
  always_comb l_resp_fo.aw_ready = mem_we_o;
  always_comb l_resp_fo.w_ready = mem_we_o;
  always_comb l_resp_fo.b_valid = mem_we_o;

  always_comb mem_waddr_o = (l_req_fo.aw.addr - MEM_BASE);
  always_comb mem_wdata_o = l_req_fo.w.data;
  always_comb mem_wstrb_o = l_req_fo.w.strb;
  always_comb l_resp_fo.b.resp = mem_wresp_i;

  always_comb mem_re_o = l_req_fo.ar_valid & l_req_fo.r_ready;
  always_comb l_resp_fo.ar_ready = mem_re_o;
  always_comb l_resp_fo.r_valid = mem_re_o;

  always_comb mem_raddr_o = (l_req_fo.ar.addr - MEM_BASE);
  always_comb l_resp_fo.r.data = mem_rdata_i;
  always_comb l_resp_fo.r.resp = mem_rresp_i;

endmodule
