#!/bin/bash

# Author : Anindya Kishore Choudhury
# Email : anindyakchoudhury@gmail.com

RED='\033[1;31m'
GREEN='\033[1;32m'
MAGENTA='\033[3;35m'
BLUE='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${MAGENTA}========================================${NC}"
echo -e "${MAGENTA}Front Door AXI RAM Memory Test${NC}"
echo -e "${MAGENTA}Testing via AXI Protocol Only${NC}"
echo -e "${MAGENTA}========================================${NC}"

mkdir -p build_real_test
mkdir -p log

rm -rf build_real_test/xsim.dir
rm -rf build_real_test/.Xil
rm -rf build_real_test/work

cd build_real_test

cat > flist << EOF
-i ../include
../include/common_cells/registers.svh
../package/axi_pkg.sv
../package/cf_math_pkg.sv
../package/ariane_axi_pkg.sv
../source/lzc.sv
../source/onehot_to_bin.sv
../source/rr_arb_tree.sv
../source/counter.sv
../source/delta_counter.sv
../source/spill_register_flushable.sv
../source/spill_register.sv
../source/stream_register.sv
../source/fifo_v3.sv
../source/id_queue.sv
../source/axi_demux_simple.sv
../source/axi_demux_id_counters.sv
../source/axi_burst_splitter_counters.sv
../source/axi_burst_splitter_ax_chan.sv
../source/axi_burst_splitter.sv
../source/axi_atop_filter.sv
../source/axi_demux.sv
../source/axi_err_slv.sv
../source/axi_to_axi_lite_id_reflect.sv
../source/axi_to_axi_lite.sv
../source/axi_fifo.sv
../source/axi_to_simple_if.sv
../source/axi_ram.sv
../testbench/real_axi_ram_test.sv
EOF

echo -e "${BLUE}[1/3] Compiling RTL files...${NC}"
xvlog -sv -f flist --nolog -d SIMULATION 2>&1 | tee compile.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}COMPILATION FAILED!${NC}"
    echo -e "${RED}========================================${NC}"
    tail -50 compile.log
    cd ..
    exit 1
fi
echo -e "${GREEN}✓ Compilation successful${NC}"

echo -e "${BLUE}[2/3] Elaborating design...${NC}"
xelab real_axi_ram_test --timescale 1ns/1ps --debug wave --log ../log/elab_real.txt 2>&1 | tee elab.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}ELABORATION FAILED!${NC}"
    echo -e "${RED}========================================${NC}"
    tail -50 elab.log
    cd ..
    exit 1
fi
echo -e "${GREEN}✓ Elaboration successful${NC}"

echo -e "${BLUE}[3/3] Running simulation...${NC}"
xsim real_axi_ram_test -runall -log ../log/real_axi_ram_test.txt 2>&1 | tee sim.log

cd ..

echo -e "\n${MAGENTA}========================================${NC}"
echo -e "${MAGENTA}SIMULATION RESULTS${NC}"
echo -e "${MAGENTA}========================================${NC}"

if [ -f log/real_axi_ram_test.txt ]; then
    # Extract and display test results
    cat log/real_axi_ram_test.txt | grep -E "\[TEST|\[PASS\]|\[FAIL\]|\[INFO\]|TEST STARTED|TEST ENDED|FRONT DOOR" --color=always

    # Check for success
    if grep -q "All front door tests passed" log/real_axi_ram_test.txt; then
        echo -e "\n${GREEN}========================================${NC}"
        echo -e "${GREEN}✓ SUCCESS: FRONT DOOR VERIFICATION COMPLETE${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}AXI RAM Memory Model Verified Through:${NC}"
        echo -e "${GREEN}  • Complete AXI Protocol Stack${NC}"
        echo -e "${GREEN}  • All 4 Interface Pins${NC}"
        echo -e "${GREEN}  • 20+ RTL Modules${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo -e "${YELLOW}Verified Components:${NC}"
        echo -e "  Pin 1: clk_i (100MHz clock)"
        echo -e "  Pin 2: rst_ni (async reset)"
        echo -e "  Pin 3: req_i (AXI4 request from core)"
        echo -e "  Pin 4: resp_o (AXI4 response to core)"
        echo -e "${YELLOW}RTL Stack Exercised:${NC}"
        echo -e "  axi_ram → axi_to_simple_if → axi_to_axi_lite"
        echo -e "  → axi_burst_splitter → axi_atop_filter → axi_fifo"
        echo -e "  + 15 supporting modules (counters, arbiters, etc.)"
        echo -e "${YELLOW}Test Coverage:${NC}"
        echo -e "  ✓ Byte access (8-bit)"
        echo -e "  ✓ Halfword access (16-bit)"
        echo -e "  ✓ Word access (32-bit)"
        echo -e "  ✓ Doubleword access (64-bit)"
        echo -e "  ✓ Sequential operations (64 transactions)"
        echo -e "  ✓ Address alignment"
        echo -e "  ✓ Byte strobe patterns"
        echo -e "  ✓ Write-read consistency"
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}Memory model ready for RV64G core integration!${NC}"
        echo -e "${GREEN}========================================${NC}"
        exit 0
    elif grep -q "FAIL" log/real_axi_ram_test.txt; then
        echo -e "\n${RED}========================================${NC}"
        echo -e "${RED}✗ TEST FAILURES DETECTED${NC}"
        echo -e "${RED}========================================${NC}"
        echo -e "${YELLOW}Failed tests:${NC}"
        grep "\[FAIL\]" log/real_axi_ram_test.txt --color=always
        echo -e "${RED}========================================${NC}"
        exit 1
    else
        echo -e "\n${YELLOW}========================================${NC}"
        echo -e "${YELLOW}⚠ INCOMPLETE TEST RUN${NC}"
        echo -e "${YELLOW}========================================${NC}"
        echo -e "Tests may have terminated early. Check log for details."
        exit 1
    fi
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}✗ LOG FILE NOT FOUND${NC}"
    echo -e "${RED}========================================${NC}"
    echo -e "Expected: log/real_axi_ram_test.txt"
    echo -e "Simulation may not have run successfully."
    exit 1
fi
