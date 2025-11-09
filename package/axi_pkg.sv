
package axi_pkg;

  parameter int unsigned BurstWidth = 32'd2;
  parameter int unsigned RespWidth = 32'd2;
  parameter int unsigned CacheWidth = 32'd4;
  parameter int unsigned ProtWidth = 32'd3;
  parameter int unsigned QosWidth = 32'd4;
  parameter int unsigned RegionWidth = 32'd4;
  parameter int unsigned LenWidth = 32'd8;
  parameter int unsigned SizeWidth = 32'd3;
  parameter int unsigned LockWidth = 32'd1;
  parameter int unsigned AtopWidth = 32'd6;
  parameter int unsigned NsaidWidth = 32'd4;

  typedef logic [1:0] burst_t;
  typedef logic [1:0] resp_t;
  typedef logic [3:0] cache_t;
  typedef logic [2:0] prot_t;
  typedef logic [3:0] qos_t;
  typedef logic [3:0] region_t;
  typedef logic [7:0] len_t;
  typedef logic [2:0] size_t;
  typedef logic [5:0] atop_t;
  typedef logic [3:0] nsaid_t;

  localparam BURST_FIXED = 2'b00;
  localparam BURST_INCR = 2'b01;
  localparam BURST_WRAP = 2'b10;
  localparam RESP_OKAY = 2'b00;
  localparam RESP_EXOKAY = 2'b01;
  localparam RESP_SLVERR = 2'b10;
  localparam RESP_DECERR = 2'b11;
  localparam CACHE_BUFFERABLE = 4'b0001;
  localparam CACHE_MODIFIABLE = 4'b0010;
  localparam CACHE_RD_ALLOC = 4'b0100;
  localparam CACHE_WR_ALLOC = 4'b1000;



  function automatic shortint unsigned num_bytes(size_t size);
    return 1 << size;
  endfunction



  typedef logic [127:0] largest_addr_t;



  function automatic largest_addr_t aligned_addr(largest_addr_t addr, size_t size);
    return (addr >> size) << size;
  endfunction



  function automatic largest_addr_t wrap_boundary(largest_addr_t addr, size_t size, len_t len);
    largest_addr_t wrap_addr;

    unique case (len)
      4'b1: wrap_addr = (addr >> (unsigned'(size) + 1)) << (unsigned'(size) + 1);
      4'b11: wrap_addr = (addr >> (unsigned'(size) + 2)) << (unsigned'(size) + 2);
      4'b111: wrap_addr = (addr >> (unsigned'(size) + 3)) << (unsigned'(size) + 3);
      4'b1111: wrap_addr = (addr >> (unsigned'(size) + 4)) << (unsigned'(size) + 4);
      default: wrap_addr = '0;
    endcase
    return wrap_addr;
  endfunction



  function automatic largest_addr_t beat_addr(largest_addr_t addr, size_t size, len_t len,
                                              burst_t burst, shortint unsigned i_beat);
    largest_addr_t ret_addr = addr;
    largest_addr_t wrp_bond = '0;
    if (burst == BURST_WRAP) begin

      wrp_bond = wrap_boundary(addr, size, len);
    end
    if (i_beat != 0 && burst != BURST_FIXED) begin

      ret_addr = aligned_addr(addr, size) + i_beat * num_bytes(size);

      if (burst == BURST_WRAP && ret_addr >= wrp_bond + (num_bytes(size) * (len + 1))) begin
        ret_addr = ret_addr - (num_bytes(size) * (len + 1));
      end
    end
    return ret_addr;
  endfunction



  function automatic shortint unsigned beat_lower_byte(
      largest_addr_t addr, size_t size, len_t len, burst_t burst, shortint unsigned strobe_width,
      shortint unsigned i_beat);
    largest_addr_t _addr = beat_addr(addr, size, len, burst, i_beat);
    return shortint'(_addr - (_addr / strobe_width) * strobe_width);
  endfunction



  function automatic shortint unsigned beat_upper_byte(
      largest_addr_t addr, size_t size, len_t len, burst_t burst, shortint unsigned strobe_width,
      shortint unsigned i_beat);
    if (i_beat == 0) begin
      return aligned_addr(addr, size) + (num_bytes(size) - 1) -
          (addr / strobe_width) * strobe_width;
    end else begin
      return beat_lower_byte(addr, size, len, burst, strobe_width, i_beat) + num_bytes(size) - 1;
    end
  endfunction



  function automatic logic bufferable(cache_t cache);
    return |(cache & CACHE_BUFFERABLE);
  endfunction



  function automatic logic modifiable(cache_t cache);
    return |(cache & CACHE_MODIFIABLE);
  endfunction



  typedef enum logic [3:0] {
    DEVICE_NONBUFFERABLE,
    DEVICE_BUFFERABLE,
    NORMAL_NONCACHEABLE_NONBUFFERABLE,
    NORMAL_NONCACHEABLE_BUFFERABLE,
    WTHRU_NOALLOCATE,
    WTHRU_RALLOCATE,
    WTHRU_WALLOCATE,
    WTHRU_RWALLOCATE,
    WBACK_NOALLOCATE,
    WBACK_RALLOCATE,
    WBACK_WALLOCATE,
    WBACK_RWALLOCATE
  } mem_type_t;



  function automatic logic [3:0] get_arcache(mem_type_t mtype);
    unique case (mtype)
      DEVICE_NONBUFFERABLE:              return 4'b0000;
      DEVICE_BUFFERABLE:                 return 4'b0001;
      NORMAL_NONCACHEABLE_NONBUFFERABLE: return 4'b0010;
      NORMAL_NONCACHEABLE_BUFFERABLE:    return 4'b0011;
      WTHRU_NOALLOCATE:                  return 4'b1010;
      WTHRU_RALLOCATE:                   return 4'b1110;
      WTHRU_WALLOCATE:                   return 4'b1010;
      WTHRU_RWALLOCATE:                  return 4'b1110;
      WBACK_NOALLOCATE:                  return 4'b1011;
      WBACK_RALLOCATE:                   return 4'b1111;
      WBACK_WALLOCATE:                   return 4'b1011;
      WBACK_RWALLOCATE:                  return 4'b1111;
    endcase
  endfunction



  function automatic logic [3:0] get_awcache(mem_type_t mtype);
    unique case (mtype)
      DEVICE_NONBUFFERABLE:              return 4'b0000;
      DEVICE_BUFFERABLE:                 return 4'b0001;
      NORMAL_NONCACHEABLE_NONBUFFERABLE: return 4'b0010;
      NORMAL_NONCACHEABLE_BUFFERABLE:    return 4'b0011;
      WTHRU_NOALLOCATE:                  return 4'b0110;
      WTHRU_RALLOCATE:                   return 4'b0110;
      WTHRU_WALLOCATE:                   return 4'b1110;
      WTHRU_RWALLOCATE:                  return 4'b1110;
      WBACK_NOALLOCATE:                  return 4'b0111;
      WBACK_RALLOCATE:                   return 4'b0111;
      WBACK_WALLOCATE:                   return 4'b1111;
      WBACK_RWALLOCATE:                  return 4'b1111;
    endcase
  endfunction



  function automatic resp_t resp_precedence(resp_t resp_a, resp_t resp_b);
    unique case (resp_a)
      RESP_OKAY: begin

        if (resp_b == RESP_EXOKAY) begin
          return resp_a;
        end else begin
          return resp_b;
        end
      end
      RESP_EXOKAY: begin

        return resp_b;
      end
      RESP_SLVERR: begin

        if (resp_b == RESP_DECERR) begin
          return resp_b;
        end else begin
          return resp_a;
        end
      end
      RESP_DECERR: begin

        return resp_a;
      end
    endcase
  endfunction



  function automatic int unsigned aw_width(int unsigned addr_width, int unsigned id_width,
                                           int unsigned user_width);
    return (id_width + addr_width + LenWidth + SizeWidth + BurstWidth + LockWidth + CacheWidth +
            ProtWidth + QosWidth + RegionWidth + AtopWidth + user_width );
  endfunction



  function automatic int unsigned w_width(int unsigned data_width, int unsigned user_width);
    return (data_width + data_width / 32'd8 + 32'd1 + user_width);
  endfunction



  function automatic int unsigned b_width(int unsigned id_width, int unsigned user_width);
    return (id_width + RespWidth + user_width);
  endfunction



  function automatic int unsigned ar_width(int unsigned addr_width, int unsigned id_width,
                                           int unsigned user_width);
    return (id_width + addr_width + LenWidth + SizeWidth + BurstWidth + LockWidth + CacheWidth +
            ProtWidth + QosWidth + RegionWidth + user_width );
  endfunction



  function automatic int unsigned r_width(int unsigned data_width, int unsigned id_width,
                                          int unsigned user_width);
    return (id_width + data_width + RespWidth + 32'd1 + user_width);
  endfunction



  function automatic int unsigned req_width(int unsigned addr_width, int unsigned data_width,
                                            int unsigned id_width, int unsigned aw_user_width,
                                            int unsigned ar_user_width, int unsigned w_user_width);
    return (aw_width(addr_width, id_width, aw_user_width) +
            32'd1 + w_width(data_width, w_user_width) + 32'd1 +
            ar_width(addr_width, id_width, ar_user_width) + 32'd1 + 32'd1 + 32'd1);
  endfunction



  function automatic int unsigned rsp_width(int unsigned data_width, int unsigned id_width,
                                            int unsigned r_user_width, int unsigned b_user_width);
    return (r_width(data_width, id_width, r_user_width) + 32'd1 + b_width(id_width, b_user_width) +
            32'd1 + 32'd1 + 32'd1 + 32'd1);
  endfunction

  localparam ATOP_ATOMICSWAP = 6'b110000;
  localparam ATOP_ATOMICCMP = 6'b110001;
  localparam ATOP_NONE = 2'b00;
  localparam ATOP_ATOMICSTORE = 2'b01;
  localparam ATOP_ATOMICLOAD = 2'b10;
  localparam ATOP_LITTLE_END = 1'b0;
  localparam ATOP_BIG_END = 1'b1;
  localparam ATOP_ADD = 3'b000;
  localparam ATOP_CLR = 3'b001;
  localparam ATOP_EOR = 3'b010;
  localparam ATOP_SET = 3'b011;
  localparam ATOP_SMAX = 3'b100;
  localparam ATOP_SMIN = 3'b101;
  localparam ATOP_UMAX = 3'b110;
  localparam ATOP_UMIN = 3'b111;
  localparam ATOP_R_RESP = 32'd5;

  localparam bit [9:0] DemuxAw = (1 << 9);
  localparam bit [9:0] DemuxW = (1 << 8);
  localparam bit [9:0] DemuxB = (1 << 7);
  localparam bit [9:0] DemuxAr = (1 << 6);
  localparam bit [9:0] DemuxR = (1 << 5);
  localparam bit [9:0] MuxAw = (1 << 4);
  localparam bit [9:0] MuxW = (1 << 3);
  localparam bit [9:0] MuxB = (1 << 2);
  localparam bit [9:0] MuxAr = (1 << 1);
  localparam bit [9:0] MuxR = (1 << 0);

  typedef enum bit [9:0] {
    NO_LATENCY    = 10'b000_00_000_00,
    CUT_SLV_AX    = DemuxAw | DemuxAr,
    CUT_MST_AX    = MuxAw | MuxAr,
    CUT_ALL_AX    = DemuxAw | DemuxAr | MuxAw | MuxAr,
    CUT_SLV_PORTS = DemuxAw | DemuxW | DemuxB | DemuxAr | DemuxR,
    CUT_MST_PORTS = MuxAw | MuxW | MuxB | MuxAr | MuxR,
    CUT_ALL_PORTS = 10'b111_11_111_11
  } xbar_latency_e;

  typedef struct packed {
    int unsigned NoSlvPorts;
    int unsigned NoMstPorts;
    int unsigned MaxMstTrans;
    int unsigned MaxSlvTrans;
    bit FallThrough;
    bit [9:0] LatencyMode;
    int unsigned PipelineStages;
    int unsigned AxiIdWidthSlvPorts;
    int unsigned AxiIdUsedSlvPorts;
    bit UniqueIds;
    int unsigned AxiAddrWidth;
    int unsigned AxiDataWidth;
    int unsigned NoAddrRules;
  } xbar_cfg_t;

  typedef struct packed {
    int unsigned idx;
    logic [63:0] start_addr;
    logic [63:0] end_addr;
  } xbar_rule_64_t;

  typedef struct packed {
    int unsigned idx;
    logic [31:0] start_addr;
    logic [31:0] end_addr;
  } xbar_rule_32_t;

  function automatic integer unsigned iomsb(input integer unsigned width);
    return (width != 32'd0) ? unsigned'(width - 1) : 32'd0;
  endfunction

endpackage
