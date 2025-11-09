`include "axi/typedef.svh"

package ariane_axi_pkg;

  typedef enum logic {
    SINGLE_REQ,
    CACHE_LINE_REQ
  } ad_req_t;

  localparam int IdWidth = 4;
  localparam int AddrWidth = 64;
  localparam int DataWidth = 64;
  localparam int StrbWidth = DataWidth / 8;
  localparam int UserWidth = 1;

  `AXI_TYPEDEF_ALL(m, logic [AddrWidth-1:0], logic [IdWidth-1:0], logic [DataWidth-1:0],
                   logic [StrbWidth-1:0], logic [UserWidth-1:0])

endpackage
