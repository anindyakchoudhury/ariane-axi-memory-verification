`ifndef COMMON_CELLS_REGISTERS_SVH_
`define COMMON_CELLS_REGISTERS_SVH_ 0

// Abridged Summary of available FF macros:
// `FF:      asynchronous active-low reset
// `FFAR:    asynchronous active-high reset
// `FFARN:   [deprecated] asynchronous active-low reset
// `FFSR:    synchronous active-high reset
// `FFSRN:   synchronous active-low reset
// `FFNR:    without reset
// `FFL:     load-enable and asynchronous active-low reset
// `FFLAR:   load-enable and asynchronous active-high reset
// `FFLARN:  [deprecated] load-enable and asynchronous active-low reset
// `FFLARNC: load-enable and asynchronous active-low reset and synchronous active-high clear
// `FFLSR:   load-enable and synchronous active-high reset
// `FFLSRN:  load-enable and synchronous active-low reset
// `FFLNR:   load-enable without reset

`define REG_DFLT_CLK clk_i
`define REG_DFLT_RST rst_ni

// Flip-Flop with asynchronous active-low reset
// __q: Q output of FF
// __d: D input of FF
// __reset_value: value assigned upon reset
// (__clk: clock input)
// (__arst_n: asynchronous reset, active-low)
`define FF(__q, __d, __reset_value, __clk = `REG_DFLT_CLK, __arst_n = `REG_DFLT_RST) \
  always_ff @(posedge (__clk) or negedge (__arst_n)) begin                           \
    if (!__arst_n) begin                                                             \
      __q <= (__reset_value);                                                        \
    end else begin                                                                   \
      __q <= (__d);                                                                  \
    end                                                                              \
  end

// Flip-Flop with asynchronous active-high reset
// __q: Q output of FF
// __d: D input of FF
// __reset_value: value assigned upon reset
// __clk: clock input
// __arst: asynchronous reset, active-high
`define FFAR(__q, __d, __reset_value, __clk, __arst)     \
  always_ff @(posedge (__clk) or posedge (__arst)) begin \
    if (__arst) begin                                    \
      __q <= (__reset_value);                            \
    end else begin                                       \
      __q <= (__d);                                      \
    end                                                  \
  end

// DEPRECATED - use `FF instead
// Flip-Flop with asynchronous active-low reset
// __q: Q output of FF
// __d: D input of FF
// __reset_value: value assigned upon reset
// __clk: clock input
// __arst_n: asynchronous reset, active-low
`define FFARN(__q, __d, __reset_value, __clk, __arst_n) \
  `FF(__q, __d, __reset_value, __clk, __arst_n)

// Flip-Flop with synchronous active-high reset
// __q: Q output of FF
// __d: D input of FF
// __reset_value: value assigned upon reset
// __clk: clock input
// __reset_clk: reset input, active-high
`define FFSR(__q, __d, __reset_value, __clk, __reset_clk) \
  always_ff @(posedge (__clk)) begin                      \
    __q <= (__reset_clk) ? (__reset_value) : (__d);       \
  end

// Flip-Flop with synchronous active-low reset
// __q: Q output of FF
// __d: D input of FF
// __reset_value: value assigned upon reset
// __clk: clock input
// __reset_n_clk: reset input, active-low
`define FFSRN(__q, __d, __reset_value, __clk, __reset_n_clk) \
  always_ff @(posedge (__clk)) begin                         \
    __q <= (!__reset_n_clk) ? (__reset_value) : (__d);       \
  end

// Always-enable Flip-Flop without reset
// __q: Q output of FF
// __d: D input of FF
// __clk: clock input
`define FFNR(__q, __d, __clk)        \
  always_ff @(posedge (__clk)) begin \
    __q <= (__d);                    \
  end

// Flip-Flop with load-enable and asynchronous active-low reset (implicit clock and reset)
// __q: Q output of FF
// __d: D input of FF
// __load: load d value into FF
// __reset_value: value assigned upon reset
// (__clk: clock input)
// (__arst_n: asynchronous reset, active-low)
`define FFL(__q, __d, __load, __reset_value, __clk = `REG_DFLT_CLK, __arst_n = `REG_DFLT_RST) \
  always_ff @(posedge (__clk) or negedge (__arst_n)) begin                                    \
    if (!__arst_n) begin                                                                      \
      __q <= (__reset_value);                                                                 \
    end else begin                                                                            \
      if (__load) begin                                                                       \
        __q <= (__d);                                                                         \
      end                                                                                     \
    end                                                                                       \
  end

// Flip-Flop with load-enable and asynchronous active-high reset
// __q: Q output of FF
// __d: D input of FF
// __load: load d value into FF
// __reset_value: value assigned upon reset
// __clk: clock input
// __arst: asynchronous reset, active-high
`define FFLAR(__q, __d, __load, __reset_value, __clk, __arst) \
  always_ff @(posedge (__clk) or posedge (__arst)) begin      \
    if (__arst) begin                                         \
      __q <= (__reset_value);                                 \
    end else begin                                            \
      if (__load) begin                                       \
        __q <= (__d);                                         \
      end                                                     \
    end                                                       \
  end

// DEPRECATED - use `FFL instead
// Flip-Flop with load-enable and asynchronous active-low reset
// __q: Q output of FF
// __d: D input of FF
// __load: load d value into FF
// __reset_value: value assigned upon reset
// __clk: clock input
// __arst_n: asynchronous reset, active-low
`define FFLARN(__q, __d, __load, __reset_value, __clk, __arst_n) \
  `FFL(__q, __d, __load, __reset_value, __clk, __arst_n)

// Flip-Flop with load-enable and synchronous active-high reset
// __q: Q output of FF
// __d: D input of FF
// __load: load d value into FF
// __reset_value: value assigned upon reset
// __clk: clock input
// __reset_clk: reset input, active-high
`define FFLSR(__q, __d, __load, __reset_value, __clk, __reset_clk) \
  always_ff @(posedge (__clk)) begin                               \
    if (__reset_clk) begin                                         \
      __q <= (__reset_value);                                      \
    end else if (__load) begin                                     \
      __q <= (__d);                                                \
    end                                                            \
  end

// Flip-Flop with load-enable and synchronous active-low reset
// __q: Q output of FF
// __d: D input of FF
// __load: load d value into FF
// __reset_value: value assigned upon reset
// __clk: clock input
// __reset_n_clk: reset input, active-low
`define FFLSRN(__q, __d, __load, __reset_value, __clk, __reset_n_clk) \
  always_ff @(posedge (__clk)) begin                                  \
    if (!__reset_n_clk) begin                                         \
      __q <= (__reset_value);                                         \
    end else if (__load) begin                                        \
      __q <= (__d);                                                   \
    end                                                               \
  end

// Flip-Flop with load-enable and asynchronous active-low reset and synchronous clear
// __q: Q output of FF
// __d: D input of FF
// __load: load d value into FF
// __clear: assign reset value into FF
// __reset_value: value assigned upon reset
// __clk: clock input
// __arst_n: asynchronous reset, active-low
`define FFLARNC(__q, __d, __load, __clear, __reset_value, __clk, __arst_n) \
  always_ff @(posedge (__clk) or negedge (__arst_n)) begin                 \
    if (!__arst_n) begin                                                   \
      __q <= (__reset_value);                                              \
    end else begin                                                         \
      if (__clear) begin                                                   \
        __q <= (__reset_value);                                            \
      end else if (__load) begin                                           \
        __q <= (__d);                                                      \
      end                                                                  \
    end                                                                    \
  end

// Flip-Flop with asynchronous active-low reset and synchronous clear
// __q: Q output of FF
// __d: D input of FF
// __clear: assign reset value into FF
// __reset_value: value assigned upon reset
// __clk: clock input
// __arst_n: asynchronous reset, active-low
`define FFARNC(__q, __d, __clear, __reset_value, __clk, __arst_n) \
  always_ff @(posedge (__clk) or negedge (__arst_n)) begin        \
    if (!__arst_n) begin                                          \
      __q <= (__reset_value);                                     \
    end else begin                                                \
      if (__clear) begin                                          \
        __q <= (__reset_value);                                   \
      end else begin                                              \
        __q <= (__d);                                             \
      end                                                         \
    end                                                           \
  end

// Load-enable Flip-Flop without reset
// __q: Q output of FF
// __d: D input of FF
// __load: load d value into FF
// __clk: clock input
`define FFLNR(__q, __d, __load, __clk) \
  always_ff @(posedge (__clk)) begin   \
    if (__load) begin                  \
      __q <= (__d);                    \
    end                                \
  end

`endif
