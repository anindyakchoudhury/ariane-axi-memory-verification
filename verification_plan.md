Author: Anindya Kishore Choudhury

Email: anindyakchoudhury@gmail.com

Date Last Updated: 28 October 2025

# AXI RAM Verification Plan and Test Report

## Overview
This document describes the verification strategy and test coverage for the AXI RAM module. All tests are performed using front-door access through the AXI protocol to verify the complete RTL stack.

## Verification Strategy

### Design Under Test (DUT)
- **Module:** `axi_ram`
- **Interface:** AXI4 protocol compliant
- **Access Method:** Front-door only (no back-door memory access)
- **Memory Size:** 512MB address space

### Key Improvements Implemented
1. **Independent Channel Handshakes:** AXI Write Address, Write Data, and Write Response channels operate independently using fork-join constructs
2. **Non-Blocking Assignments:** All signal driving uses non-blocking assignments to prevent race conditions
3. **Complete Handshake Protocol:** Added missing W_READY handshake that was previously absent
4. **Randomization:** All tests use randomized data patterns and addresses instead of fixed values

## Test Suite Description

### Test 1: Byte Access Test
**Purpose:** Verify single-byte read and write operations

**Description:** This test validates that the memory can correctly handle 8-bit data transfers. It performs 10 iterations with randomized addresses and data values to ensure byte-level access works correctly across different memory locations.

**Coverage:** 
- 8-bit data transfers
- Random address selection
- Write-read consistency for byte operations

---

### Test 2: Halfword Access Test
**Purpose:** Verify 16-bit read and write operations

**Description:** This test validates halfword (2-byte) data transfers with proper address alignment. It performs 10 iterations with randomized halfword-aligned addresses and 16-bit data values to ensure proper handling of 2-byte operations.

**Coverage:**
- 16-bit data transfers
- Halfword address alignment enforcement
- Write-read consistency for halfword operations

---

### Test 3: Word Access Test
**Purpose:** Verify 32-bit read and write operations

**Description:** This test validates word (4-byte) data transfers with proper address alignment. It performs 10 iterations with randomized word-aligned addresses and 32-bit data values to verify correct handling of standard word-sized operations.

**Coverage:**
- 32-bit data transfers
- Word address alignment enforcement
- Write-read consistency for word operations

---

### Test 4: Doubleword Access Test
**Purpose:** Verify 64-bit read and write operations

**Description:** This test validates doubleword (8-byte) data transfers using the full bus width. It performs 10 iterations with randomized doubleword-aligned addresses and 64-bit data values to ensure maximum-width transfers work correctly.

**Coverage:**
- 64-bit data transfers (full bus width)
- Doubleword address alignment enforcement
- Write-read consistency for doubleword operations

---

### Test 5: Write-Read Consistency Test
**Purpose:** Verify data retention and integrity

**Description:** This test focuses on verifying that data written to memory can be read back correctly without corruption. It performs 10 iterations of write-then-read operations using random 64-bit data at random doubleword-aligned addresses. Each iteration includes detailed logging of addresses and data values for debugging purposes.

**Coverage:**
- Memory data retention
- Write-to-read path verification
- Data integrity across write-read cycles

---

### Test 6: Sequential Operations Test
**Purpose:** Verify burst-like sequential access patterns

**Description:** This test validates the memory's ability to handle multiple consecutive transactions. It writes 64 doublewords to sequential memory locations (starting at base address 0x10000), then reads them back and verifies each value matches what was written. This simulates array or buffer operations commonly used in real systems.

**Coverage:**
- Sequential address generation
- Multiple back-to-back transactions (64 operations)
- Address calculation correctness
- Data integrity across 512 bytes of memory

---

### Test 7: Address Alignment Test
**Purpose:** Verify proper handling of aligned addresses

**Description:** This test validates that correctly-aligned addresses work properly for different data sizes. It tests three specific scenarios: 8-byte aligned access at address 0x5000, 4-byte aligned access at address 0x6000, and 2-byte aligned access at address 0x7000. Each uses randomized data to ensure alignment logic works correctly.

**Coverage:**
- 8-byte alignment verification
- 4-byte alignment verification
- 2-byte alignment verification
- Alignment requirement enforcement

---

### Test 8: Byte Strobe Patterns Test
**Purpose:** Verify selective byte writing capability

**Description:** This test validates the byte strobe mechanism that allows writing specific bytes within a larger data word. It tests two scenarios: full strobe pattern (all 8 bytes enabled) and partial strobe pattern (only lower 4 bytes enabled). This ensures the memory correctly handles partial updates.

**Coverage:**
- Full byte strobe (all bytes written)
- Partial byte strobe (selective byte writing)
- Strobe logic correctness

---

### Test 9: Comprehensive Random Transactions Test
**Purpose:** Verify mixed-size random operations

**Description:** This is the most comprehensive test that randomizes everything including transfer size, addresses, and data. It performs 50 iterations where each iteration randomly selects a transfer size (byte, halfword, word, or doubleword), generates appropriately-aligned addresses, and uses random data. This provides broader coverage across all data sizes in a single test.

**Coverage:**
- Random transfer size selection
- Size-appropriate address alignment
- Size-appropriate data masking
- Mixed operation patterns

---

## Current Test Coverage Summary

### What is Tested
- Single-beat transactions (read and write)
- All data sizes: byte, halfword, word, doubleword
- Proper address alignment for each size
- Write-read data consistency
- Byte strobe patterns (full and partial)
- Sequential memory access patterns
- Independent AXI channel handshakes
- Timeout protection for all handshakes
- Error detection for unexpected responses

### Test Statistics
- Total number of test tasks: 9
- Total transactions in full test run: Approximately 150+ individual AXI transactions
- Randomization: All tests use randomized data and most use randomized addresses
- Data sizes covered: 8-bit, 16-bit, 32-bit, 64-bit

---

## Plan Limitations and Weaknesses

### Critical Missing Features

#### 1. No Pipelined Transactions
**Issue:** The current testbench executes transactions sequentially. Each transaction (Address, Data, Response) fully completes before the next one starts.

**Impact:** Real AXI masters can send multiple address and data phases before receiving responses. This pipelining capability is completely untested. Any bugs in the DUT related to handling overlapped transactions will not be detected.

**Example:** Cannot test if the DUT correctly handles receiving a new Write Address while still processing data from a previous write.

#### 2. No Burst Transfers
**Issue:** All tests use single-beat transfers only. The length field is always set to 0, meaning only one data beat per address.

**Impact:** AXI burst transfers (multiple data beats for one address) are a fundamental feature of the protocol and are completely untested. The DUT's burst handling logic, address increment logic, and last-beat signaling are not verified.

**Example:** Cannot test a 4-beat burst write where the address increments automatically for each beat.

#### 3. No Multiple Outstanding Transactions
**Issue:** Only one transaction is in flight at any time, and transaction IDs are fixed (ID 1 for writes, ID 2 for reads).

**Impact:** AXI allows multiple transactions with different IDs to be outstanding simultaneously. The DUT's ability to track multiple pending requests and match responses to requests using IDs is untested.

**Example:** Cannot test if the DUT correctly handles three read requests with different IDs issued back-to-back.

#### 4. No Out-of-Order Response Testing
**Issue:** Since only one transaction occurs at a time, responses always arrive in order.

**Impact:** For read operations, AXI slaves are allowed to return data out of order. The DUT's ability to handle and tag out-of-order responses is untested.

**Example:** Cannot test if read responses for ID 3, ID 1, ID 2 arrive in that order when requests were issued as ID 1, ID 2, ID 3.

### Important Missing Features

#### 5. No Error Injection Testing
**Issue:** All tests assume successful operations. No tests attempt invalid operations that should generate error responses.

**Impact:** The DUT's error handling logic is completely untested. Cannot verify that the DUT correctly returns DECERR or SLVERR for out-of-range addresses or other protocol violations.

**Example:** Cannot test writing to address 0x80000000 (beyond memory range) and verifying an error response is returned.

**Additional Problem:** Current error checking code immediately terminates simulation on any error response, making it impossible to test error cases even if we wanted to.

#### 6. Limited Strobe Pattern Coverage
**Issue:** Only two strobe patterns are tested: all bytes enabled (0xFF) and lower 4 bytes enabled (0x0F).

**Impact:** Many valid strobe combinations are untested, such as writing only even bytes, only odd bytes, or sparse patterns like bytes 0 and 7 only.

**Example:** Cannot test strobe pattern 0xAA (alternating bytes) or 0x81 (first and last byte only).

#### 7. Limited Address Coverage
**Issue:** While addresses are randomized within a small range, the tests don't systematically cover memory boundaries, edge cases, or the full address space.

**Impact:** Boundary conditions and edge cases in address decoding may be missed.

**Example:** Not testing addresses near the top of memory range or at memory bank boundaries.

---

## Future Improvements Needed

### High Priority
1. Implement pipelined transaction testing where multiple address phases are issued before waiting for responses
2. Add burst transfer testing with various burst lengths (2, 4, 8, 16 beats)
3. Implement multiple outstanding transaction testing with different IDs
4. Add out-of-order read response handling tests

### Medium Priority
5. Add error injection tests for out-of-range addresses and verify correct error responses
6. Modify error checking to allow testing of error conditions instead of immediately terminating
7. Expand strobe pattern coverage to include sparse and alternating patterns
8. Add address boundary testing (first address, last address, bank boundaries)

### Low Priority
9. Add constrained-random verification for more sophisticated randomization
10. Implement functional coverage collection to track what scenarios have been tested
11. Add performance measurement (throughput, latency)
12. Test different burst types (FIXED, WRAP in addition to INCR)

---
## Simulation Results
- All Tests Passed

---

## Files Included
- `real_axi_ram_test_modified.sv` - Complete testbench with all tests
- `testplan/mem_model_test_readme.md` - This documentation file
- `test_real_mem.sh` - sh file to run the simulation