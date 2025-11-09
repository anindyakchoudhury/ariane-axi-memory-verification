`include "axi/typedef.svh"

module axi_ram #(
    parameter logic [63:0] MEM_BASE     = 'h1000,
    parameter int          MEM_SIZE     = 18,
    parameter bit          ALLOW_WRITES = 1,
    parameter type         req_t        = ariane_axi_pkg::m_req_t,
    parameter type         resp_t       = ariane_axi_pkg::m_resp_t
) (
    input  logic  clk_i,
    input  logic  arst_ni,
    input  req_t  req_i,
    output resp_t resp_o
);

  localparam int MEM_AW = MEM_SIZE;
  localparam int MEM_DW = $bits(req_i.w.data);

  logic                     mem_we_o;
  logic [MEM_SIZE-1:0]      mem_waddr_o;
  logic [MEM_DW/8-1:0][7:0] mem_wdata_o;
  logic [MEM_DW/8-1:0]      mem_wstrb_o;
  logic [         1:0]      mem_wresp_i;

  logic                     mem_re_o;
  logic [MEM_SIZE-1:0]      mem_raddr_o;
  logic [MEM_DW/8-1:0][7:0] mem_rdata_i;
  logic [         1:0]      mem_rresp_i;

  bit   [         7:0]      mem         [longint];

  axi_to_simple_if #(
      .axi_req_t (req_t),
      .axi_resp_t(resp_t),
      .MEM_BASE  (MEM_BASE),
      .MEM_SIZE  (MEM_SIZE)
  ) u_cvt (
      .arst_ni,
      .clk_i,
      .req_i,
      .resp_o,
      .mem_we_o,
      .mem_waddr_o,
      .mem_wdata_o,
      .mem_wstrb_o,
      .mem_wresp_i,
      .mem_re_o,
      .mem_raddr_o,
      .mem_rdata_i,
      .mem_rresp_i
  );

  always @(posedge clk_i) begin
    logic [MEM_SIZE-1:0]      mem_waddr_;
    logic [MEM_DW/8-1:0][7:0] mem_wdata_;
    logic [MEM_DW/8-1:0]      mem_wstrb_;
    mem_wresp_i = '0;
    mem_waddr_ = mem_waddr_o;
    mem_waddr_[$clog2(MEM_DW/8)-1:0] = '0;
    mem_wdata_ = mem_wdata_o;
    mem_wstrb_ = mem_wstrb_o;
    if (arst_ni & mem_we_o) begin
      #1ps;
      foreach (mem_wstrb_[i]) begin
        if (mem_wstrb_[i]) begin
          mem[mem_waddr_+i] = mem_wdata_[i];
        end
      end
    end
  end

  always @(clk_i) begin
    logic [MEM_SIZE-1:0] mem_raddr_;
    mem_rresp_i = '0;
    mem_raddr_ = mem_raddr_o;
    mem_raddr_[$clog2(MEM_DW/8)-1:0] = '0;
    if (arst_ni & mem_re_o) begin
      #1ps;
      foreach (mem_rdata_i[i]) begin
        mem_rdata_i[i] = mem[mem_raddr_+i];
      end
    end
  end

  function automatic void write_mem_b(input logic [63:0] addr, input logic [7:0] data);
    mem[addr-MEM_BASE] = data;
  endfunction

  function automatic logic [7:0] read_mem_b(input logic [63:0] addr);
    return mem[addr-MEM_BASE];
  endfunction

  function automatic void write_mem_h(input logic [63:0] addr, input logic [15:0] data);
    mem[addr-MEM_BASE+1] = data[15:8];
    mem[addr-MEM_BASE+0] = data[7:0];
  endfunction

  function automatic logic [15:0] read_mem_h(input logic [63:0] addr);
    return {mem[addr-MEM_BASE+1], mem[addr-MEM_BASE+0]};
  endfunction

  function automatic void write_mem_w(input logic [63:0] addr, input logic [31:0] data);
    mem[addr-MEM_BASE+3] = data[31:24];
    mem[addr-MEM_BASE+2] = data[23:16];
    mem[addr-MEM_BASE+1] = data[15:8];
    mem[addr-MEM_BASE+0] = data[7:0];
  endfunction

  function automatic logic [31:0] read_mem_w(input logic [63:0] addr);
    return {mem[addr-MEM_BASE+3], mem[addr-MEM_BASE+2], mem[addr-MEM_BASE+1], mem[addr-MEM_BASE+0]};
  endfunction

  function automatic void write_mem_d(input logic [63:0] addr, input logic [63:0] data);
    mem[addr-MEM_BASE+7] = data[63:56];
    mem[addr-MEM_BASE+6] = data[55:48];
    mem[addr-MEM_BASE+5] = data[47:40];
    mem[addr-MEM_BASE+4] = data[39:32];
    mem[addr-MEM_BASE+3] = data[31:24];
    mem[addr-MEM_BASE+2] = data[23:16];
    mem[addr-MEM_BASE+1] = data[15:8];
    mem[addr-MEM_BASE+0] = data[7:0];
  endfunction

  function automatic logic [63:0] read_mem_d(input logic [63:0] addr);
    return {
      mem[addr-MEM_BASE+7],
      mem[addr-MEM_BASE+6],
      mem[addr-MEM_BASE+5],
      mem[addr-MEM_BASE+4],
      mem[addr-MEM_BASE+3],
      mem[addr-MEM_BASE+2],
      mem[addr-MEM_BASE+1],
      mem[addr-MEM_BASE+0]
    };
  endfunction

endmodule
