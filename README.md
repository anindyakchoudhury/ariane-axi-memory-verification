# AXI RAM Memory Verification - Front Door Testing

## Overview
Professional verification testbench for AXI4-compliant RAM module used in **Ariane RISC-V Core** (CVA6), implementing **pure front-door testing** through the complete AXI protocol stack. This project demonstrates production-grade verification methodology for memory subsystems in RISC-V SoC designs.

## What I Built

### Core Implementation
- **Full AXI4 Protocol Verification**: Complete testbench exercising all 5 AXI channels (AW, W, B, AR, R)
- **Independent Channel Handshakes**: Fork-join architecture allowing AW, W, and B channels to operate concurrently, mirroring real AXI behavior
- **Comprehensive Test Suite**: 9 test scenarios covering byte, halfword, word, and doubleword accesses with randomized patterns
- **Production-Ready Code**: Non-blocking assignments, proper handshake synchronization, timeout protection, and error detection

### Unique Technical Contributions

1. **True Independent Channel Implementation**
   - Fixed missing W_READY handshake that would cause real hardware failures
   - Concurrent channel operation using fork-join, not sequential
   - Demonstrates understanding of AXI protocol timing independence

2. **Randomized Verification Methodology**
   - All tests use randomized addresses and data patterns instead of fixed values
   - Dynamic address alignment enforcement based on transfer size
   - 150+ randomized transactions per test run

3. **Complete Stack Verification**
   - Tests propagate through 20+ RTL modules from Ariane ecosystem
   - Validates entire memory controller hierarchy: `axi_ram` → `axi_to_simple_if` → `axi_to_axi_lite` → `axi_burst_splitter` → `axi_fifo`
   - Uses `ariane_axi_pkg` types ensuring compatibility with CVA6 core

## Impact & Results

- ✅ **Zero Back-Door Access**: Pure protocol-based verification suitable for post-silicon validation
- ✅ **Full Data Width Coverage**: 8/16/32/64-bit accesses with proper alignment checking
- ✅ **Production Verification Quality**: Includes timeout watchdogs, comprehensive logging, and automated pass/fail reporting
- ✅ **Ariane Core Integration Ready**: Memory model verified and ready for RISC-V RV64G core integration

## Architecture Diagram
```
┌──────────────────────────────────────────────────────────────────┐
│                          TESTBENCH                               │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │  Test Generator (Randomized Patterns)                     │   │
│  │  • Address randomization with alignment                   │   │
│  │  • Data pattern randomization                             │   │
│  │  • Transfer size randomization (8/16/32/64-bit)           │   │
│  │  • Uses ariane_axi_pkg::m_req_t/m_resp_t types           │   │
│  └─────────────────┬─────────────────────────────────────────┘   │
│                    │ AXI4 Protocol (Pin 3: req_i)                │
│                    ▼                                              │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │            DUT: axi_ram (512MB)                           │   │
│  │            [From Ariane AXI Components]                   │   │
│  │  ┌─────────────────────────────────────────────────────┐  │   │
│  │  │  AXI Demux & Burst Splitter                         │  │   │
│  │  │  • axi_demux → axi_demux_simple                     │  │   │
│  │  │  • axi_burst_splitter (counters + ax_chan)          │  │   │
│  │  │  • axi_atop_filter → axi_fifo                       │  │   │
│  │  └────────┬────────────────────────────────────────────┘  │   │
│  │           │                                                │   │
│  │           ▼                                                │   │
│  │  ┌─────────────────────────────────────────────────────┐  │   │
│  │  │  AXI-to-AXI-Lite Converter                          │  │   │
│  │  │  • axi_to_axi_lite (protocol conversion)            │  │   │
│  │  │  • axi_to_axi_lite_id_reflect                       │  │   │
│  │  │  • axi_err_slv (error slave)                        │  │   │
│  │  └────────┬────────────────────────────────────────────┘  │   │
│  │           │                                                │   │
│  │           ▼                                                │   │
│  │  ┌─────────────────────────────────────────────────────┐  │   │
│  │  │  Simple Memory Interface                            │  │   │
│  │  │  • axi_to_simple_if (final conversion)              │  │   │
│  │  │  • Direct memory array access                       │  │   │
│  │  │  • Supporting modules: fifo_v3, id_queue,           │  │   │
│  │  │    spill_register, stream_register                  │  │   │
│  │  └─────────────────────────────────────────────────────┘  │   │
│  └───────────────────────────────────────────────────────────┘   │
│                    │ AXI4 Protocol (Pin 4: resp_o)               │
│                    ▼                                              │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │  Response Checker                                         │   │
│  │  • Handshake verification (all 5 channels)                │   │
│  │  • Data integrity checking                                │   │
│  │  • Error response validation (OKAY/SLVERR/DECERR)        │   │
│  │  • Timeout detection (100 cycle watchdog)                 │   │
│  └───────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘

Pin 1: clk_i (100MHz)          Pin 2: rst_ni (Active-low reset)
Pin 3: req_i (AXI4 M→S)        Pin 4: resp_o (AXI4 S→M)

RTL Components from Ariane/Pulp Platform:
- Core packages: axi_pkg, ariane_axi_pkg, cf_math_pkg
- Utility modules: lzc, onehot_to_bin, rr_arb_tree, counter, delta_counter
- Register/FIFO modules: spill_register, stream_register, fifo_v3, id_queue
- AXI infrastructure: Complete AXI subsystem from CVA6 ecosystem
```

## Test Coverage

| Test | Description | Transactions |
|------|-------------|-------------|
| **Test 1:** Byte Access | 8-bit R/W with random addresses | 10 iterations |
| **Test 2:** Halfword Access | 16-bit R/W with alignment enforcement | 10 iterations |
| **Test 3:** Word Access | 32-bit R/W with alignment enforcement | 10 iterations |
| **Test 4:** Doubleword Access | 64-bit R/W (full AXI width) | 10 iterations |
| **Test 5:** Write-Read Consistency | Data retention verification | 10 iterations |
| **Test 6:** Sequential Operations | Burst-like 64-word access pattern | 128 transactions |
| **Test 7:** Address Alignment | Alignment requirement validation | Variable |
| **Test 8:** Strobe Patterns | Partial byte enables (full/partial) | Variable |
| **Test 9:** Random Comprehensive | Mixed sizes, addresses, strobes | 50 iterations |

**Total: 150+ randomized AXI transactions per run**

## Running the Tests
```bash
chmod +x test_real_mem.sh
./test_real_mem.sh
```

**Requirements:** 
- Xilinx Vivado (xvlog, xelab, xsim)
- SystemVerilog support
- Ariane AXI RTL components (included via flist)

**Expected Output:**
```
========================================
Front Door AXI RAM Memory Test
Testing via AXI Protocol Only
========================================
[1/3] Compiling RTL files...
✓ Compilation successful
[2/3] Elaborating design...
✓ Elaboration successful
[3/3] Running simulation...

----------- FRONT DOOR ONLY TEST STARTED -----------
[INFO] All memory access through AXI protocol (Pin 3 & 4)

[TEST 1] Front Door Byte Access (8-bit via AXI) - RANDOMIZED
  [PASS] Iteration 0: Byte access at 0x1234...
  ...

========================================
✓ SUCCESS: FRONT DOOR VERIFICATION COMPLETE
========================================
Memory model ready for RV64G core integration!
```

## Key Files

| File | Description |
|------|-------------|
| `real_axi_ram_test.sv` | Complete testbench with 9 test scenarios and randomization |
| `test_real_mem.sh` | Automated build and simulation script with colored output |
| `mem_model_test_readme.md` | Detailed verification plan, coverage analysis, and known limitations |

## RTL Dependencies (from Ariane/Pulp Platform)

The testbench exercises these RTL modules:

**Packages:**
- `axi_pkg.sv` - AXI4 protocol definitions
- `ariane_axi_pkg.sv` - Ariane-specific AXI types
- `cf_math_pkg.sv` - Common functions

**Core AXI Modules:**
- `axi_ram.sv` - Main memory module under test
- `axi_to_simple_if.sv` - AXI to simple memory interface converter
- `axi_to_axi_lite.sv` - AXI4 to AXI-Lite protocol converter
- `axi_burst_splitter.sv` - Burst transaction handler
- `axi_atop_filter.sv` - Atomic operation filter
- `axi_demux.sv` - AXI demultiplexer
- `axi_fifo.sv` - AXI channel FIFOs

**Supporting Infrastructure:**
- FIFOs: `fifo_v3.sv`, `id_queue.sv`
- Registers: `spill_register.sv`, `stream_register.sv`
- Arbitration: `rr_arb_tree.sv`
- Counters: `counter.sv`, `delta_counter.sv`
- Utilities: `lzc.sv`, `onehot_to_bin.sv`

## Technical Highlights

### Protocol Compliance
- Proper AXI4 handshaking with valid/ready signaling on all 5 channels
- Independent channel operation (AW, W, B, AR, R can overlap)
- Correct burst type (INCR), size encoding, and length fields
- Transaction ID management for request/response matching

### Verification Rigor
- **Timeout Detection:** 100-cycle watchdog on all handshakes
- **Race Condition Prevention:** Non-blocking assignments throughout
- **Comprehensive Error Checking:** Response code validation (OKAY/SLVERR/DECERR)
- **Data Integrity:** Write-read verification on every transaction
- **Alignment Enforcement:** Size-dependent address alignment checking

### Industry Practices
- **Front-door only methodology:** No DPI, no backdoor memory access
- **Randomized stimulus generation:** Addresses, data, and transfer sizes
- **Automated pass/fail determination:** With detailed colored logging
- **Modular test structure:** Each test scenario in separate task
- **Production-ready comments:** Extensive documentation of AXI protocol behavior

## Known Limitations (Documented in Verification Plan)

This testbench currently does **not** test:
- Pipelined transactions (multiple outstanding requests)
- Burst transfers (len > 0)
- Multiple transaction IDs simultaneously
- Out-of-order responses
- Error injection scenarios

See `mem_model_test_readme.md` for complete limitation analysis and future improvement roadmap.

## Sample Test Output
```systemverilog
[TEST 3] Front Door Word Access (32-bit via AXI) - RANDOMIZED
  [PASS] Iteration 0: Word access at 0x4000 - wrote 0x12345678, read 0x12345678
  [PASS] Iteration 1: Word access at 0x8004 - wrote 0xabcdef90, read 0xabcdef90
  ...
  [PASS] Iteration 9: Word access at 0xc00c - wrote 0x5a5a5a5a, read 0x5a5a5a5a

[TEST 6] Front Door Sequential Operations (64 transactions via AXI) - RANDOMIZED
  [INFO] Writing 64 randomized doublewords via AXI protocol...
  [INFO] Reading and verifying 64 doublewords via AXI protocol...
  [PASS] 64 sequential doubleword operations verified
```

## Why This Matters

1. **Real-World Verification**: Uses actual Ariane core AXI types and RTL components
2. **Industry-Standard Practices**: Front-door testing methodology used in tape-out flows
3. **Comprehensive Coverage**: Tests data path, control path, and protocol compliance
4. **Production Quality**: Timeout protection, error handling, and extensive logging
5. **Integration Ready**: Verified memory subsystem ready for CVA6/Ariane core connection

---

**Author:** Anindya Kishore Choudhury  
**Contact:** anindyakchoudhury@gmail.com  
**Date:** October 2025  
**Purpose:** Demonstrating memory subsystem verification expertise for ASIC/FPGA design roles

**Acknowledgments:**  
RTL components from Pulp Platform's Ariane (CVA6) RISC-V core ecosystem  
AXI infrastructure from OpenHW Group's CVA6 project