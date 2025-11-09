// Author : Anindya Kishore Choudhury
// Email : anindyakchoudhury@gmail.com

module real_axi_ram_test;

    // Clock and Reset (Pin 1 & 2)
    logic clk_i;
    logic rst_ni;

    // AXI Interface from/to SoC Core (Pin 3 & 4)
    ariane_axi_pkg::m_req_t  axi_req_from_core;   // Pin 3: Coming from core
    ariane_axi_pkg::m_resp_t axi_resp_to_core;    // Pin 4: Going to core

    //////////////////////////////////////////////////////////////////////////
    // DUT: Real RTL Memory Model from source/axi_ram.sv
    //////////////////////////////////////////////////////////////////////////
    axi_ram #(
        .MEM_BASE    (64'h0000_0000),
        .MEM_SIZE    (29),                          // 512MB address space
        .ALLOW_WRITES(1),
        .req_t       (ariane_axi_pkg::m_req_t),
        .resp_t      (ariane_axi_pkg::m_resp_t)
    ) u_axi_ram (
        .clk_i   (clk_i),                          // Pin 1: Clock input
        .arst_ni (rst_ni),                         // Pin 2: Reset input
        .req_i   (axi_req_from_core),              // Pin 3: AXI request from core
        .resp_o  (axi_resp_to_core)                // Pin 4: AXI response to core
    );

    //////////////////////////////////////////////////////////////////////////
    // Clock Generation (100 MHz)
    //////////////////////////////////////////////////////////////////////////
    initial begin
        clk_i = 0;
        forever #5ns clk_i = ~clk_i;  // 10ns period = 100MHz
    end

    //////////////////////////////////////////////////////////////////////////
    // FRONT DOOR ONLY: Generic AXI Transaction Tasks
    //////////////////////////////////////////////////////////////////////////

    // AXI Write Task - Front Door Access Only with Independent Handshakes
    task automatic axi_write(
        input logic [63:0] addr,
        input logic [63:0] data,
        input logic [2:0]  size,  // 0=1B, 1=2B, 2=4B, 3=8B
        input logic [7:0]  strb
    );
        automatic int aw_timeout, w_timeout, b_timeout;

        @(posedge clk_i);

        // Fork to handle AW, W, and B channels independently
        fork
            // Write Address Channel - Independent process

            // In AXI protocol, the Master can send:
            // - Address on AW channel
            // - Data on W channel

            // These two can happen in ANY ORDER. The slave might accept:
            // - Address first, then data (normal)
            // - Data first, then address (also valid!)
            // - Both at the same time (also valid!)
            begin
                // Drive Write Address Channel using NON-BLOCKING assignments
                axi_req_from_core.aw_valid   <= 1'b1;
                axi_req_from_core.aw.addr    <= addr;
                axi_req_from_core.aw.id      <= 4'h1;
                axi_req_from_core.aw.len     <= 8'h0;      // Single beat
                axi_req_from_core.aw.size    <= size;
                axi_req_from_core.aw.burst   <= 2'b01;     // INCR
                axi_req_from_core.aw.lock    <= 1'b0;
                axi_req_from_core.aw.cache   <= 4'b0000;
                axi_req_from_core.aw.prot    <= 3'b000;
                axi_req_from_core.aw.qos     <= 4'b0000;
                axi_req_from_core.aw.region  <= 4'b0000;
                axi_req_from_core.aw.atop    <= 6'b000000;
                axi_req_from_core.aw.user    <= 1'b0;

                // Wait for aw_ready handshake
                aw_timeout = 0;
                while (!axi_resp_to_core.aw_ready && aw_timeout < 100) begin
                    @(posedge clk_i);
                    aw_timeout = aw_timeout + 1;
                end
                if (aw_timeout >= 100) $fatal(1, "[FATAL] AXI write timeout on aw_ready");

                @(posedge clk_i);
                axi_req_from_core.aw_valid <= 1'b0;
            end

            // Write Data Channel - Independent process
            begin
                // Drive Write Data Channel using NON-BLOCKING assignments
                axi_req_from_core.w_valid <= 1'b1;
                axi_req_from_core.w.data  <= data;
                axi_req_from_core.w.strb  <= strb;
                axi_req_from_core.w.last  <= 1'b1;
                axi_req_from_core.w.user  <= 1'b0;

                // Wait for w_ready handshake (THIS WAS MISSING!)
                w_timeout = 0;
                while (!axi_resp_to_core.w_ready && w_timeout < 100) begin
                    @(posedge clk_i);
                    w_timeout = w_timeout + 1;
                end
                if (w_timeout >= 100) $fatal(1, "[FATAL] AXI write timeout on w_ready");

                @(posedge clk_i);
                axi_req_from_core.w_valid <= 1'b0;
            end

            // Write Response Channel - Independent process
            begin
                // Drive b_ready using NON-BLOCKING assignment
                axi_req_from_core.b_ready <= 1'b1;

                // Wait for b_valid (write response)
                b_timeout = 0;
                while (!axi_resp_to_core.b_valid && b_timeout < 100) begin
                    @(posedge clk_i);
                    b_timeout = b_timeout + 1;
                end
                if (b_timeout >= 100) $fatal(1, "[FATAL] AXI write timeout on b_valid");

                // Check response
                if (axi_resp_to_core.b.resp != 2'b00) begin //2'b00 = OKAY - Write succeeded
                    $fatal(1, "[FATAL] AXI write error response: 0x%h", axi_resp_to_core.b.resp);
                end

                @(posedge clk_i);
                axi_req_from_core.b_ready <= 1'b0;
            end
        join

        // Clear all signals after transaction completes
        axi_req_from_core <= '0;
    endtask

    // AXI Read Task - Front Door Access Only with Non-blocking Assignments
    task automatic axi_read(
        input  logic [63:0] addr,
        input  logic [2:0]  size,  // 0=1B, 1=2B, 2=4B, 3=8B
        output logic [63:0] data
    );
        automatic int ar_timeout, r_timeout;

        @(posedge clk_i);

        // Fork to handle AR and R channels independently
        fork
            begin
                // Drive Read Address Channel using NON-BLOCKING assignments
                axi_req_from_core.ar_valid   <= 1'b1;
                axi_req_from_core.ar.addr    <= addr;
                axi_req_from_core.ar.id      <= 4'h2;
                axi_req_from_core.ar.len     <= 8'h0;      // Single beat
                axi_req_from_core.ar.size    <= size;
                axi_req_from_core.ar.burst   <= 2'b01;     // INCR
                axi_req_from_core.ar.lock    <= 1'b0;
                axi_req_from_core.ar.cache   <= 4'b0000;
                axi_req_from_core.ar.prot    <= 3'b000;
                axi_req_from_core.ar.qos     <= 4'b0000;
                axi_req_from_core.ar.region  <= 4'b0000;
                axi_req_from_core.ar.user    <= 1'b0;

                // Wait for ar_ready handshake
                ar_timeout = 0;
                while (!axi_resp_to_core.ar_ready && ar_timeout < 100) begin
                    @(posedge clk_i);
                    ar_timeout = ar_timeout + 1;
                end
                if (ar_timeout >= 100) $fatal(1, "[FATAL] AXI read timeout on ar_ready");

                @(posedge clk_i);
                axi_req_from_core.ar_valid <= 1'b0;
            end

            // Read Data Channel - Independent process
            begin
                // Drive r_ready using NON-BLOCKING assignment
                axi_req_from_core.r_ready <= 1'b1;

                // Wait for r_valid (read data)
                r_timeout = 0;
                while (!axi_resp_to_core.r_valid && r_timeout < 100) begin
                    @(posedge clk_i);
                    r_timeout = r_timeout + 1;
                end
                if (r_timeout >= 100) $fatal(1, "[FATAL] AXI read timeout on r_valid");

                // Capture data
                data = axi_resp_to_core.r.data;

                // Check response
                if (axi_resp_to_core.r.resp != 2'b00) begin
                    $fatal(1, "[FATAL] AXI read error response: 0x%h", axi_resp_to_core.r.resp);
                end

                @(posedge clk_i);
                axi_req_from_core.r_ready <= 1'b0;
            end
        join

        // Clear all signals after transaction completes
        axi_req_from_core <= '0;
    endtask

    //////////////////////////////////////////////////////////////////////////
    // Test Stimulus - FRONT DOOR ONLY with RANDOMIZATION
    //////////////////////////////////////////////////////////////////////////
    initial begin
        $display("\033[7;38m----------- FRONT DOOR ONLY TEST STARTED -----------\033[0m");
        $display("[INFO] All memory access through AXI protocol (Pin 3 & 4)");
        $display("[INFO] No back door access - production verification");
        $display("[INFO] Using RANDOMIZED test patterns");

        // Initialize all signals
        rst_ni = 0;
        axi_req_from_core = '0;

        // Apply reset
        repeat(5) @(posedge clk_i);
        rst_ni = 1;
        repeat(2) @(posedge clk_i);

        $display("[%0t] Reset deasserted - Memory model ready", $time);

        // Run all tests using ONLY front door (AXI protocol) with RANDOMIZATION
        test_byte_access_frontdoor();
        test_halfword_access_frontdoor();
        test_word_access_frontdoor();
        test_doubleword_access_frontdoor();
        test_write_then_read_frontdoor();
        test_sequential_operations_frontdoor();
        test_address_alignment_frontdoor();
        test_strobe_patterns_frontdoor();
        test_random_transactions();

        repeat(10) @(posedge clk_i);

        $display("\033[7;32m[PASS] All front door tests passed!\033[0m");
        $display("[INFO] Complete AXI stack verified: axi_ram → axi_to_simple_if → axi_to_axi_lite → axi_fifo");
        $display("\033[7;38m------------ FRONT DOOR ONLY TEST ENDED ------------\033[0m");
        $finish;
    end

    //////////////////////////////////////////////////////////////////////////
    // Test Tasks - ALL USING FRONT DOOR (AXI PROTOCOL) with RANDOMIZATION
    //////////////////////////////////////////////////////////////////////////

    task test_byte_access_frontdoor();
        automatic logic [63:0] addr;
        automatic logic [63:0] wdata, rdata;
        automatic int i;

        $display("\n[TEST 1] Front Door Byte Access (8-bit via AXI) - RANDOMIZED");

        // RANDOMIZATION LOOP instead of fixed values
        for (i = 0; i < 10; i = i + 1) begin
            // Randomize address and data
            addr = {$random} & 64'h0000_FFFF;  // Random address in lower range (16 bits)
            wdata = {$random} & 64'h0000_00FF; // Random byte value (8 bits)

            // Write via AXI
            axi_write(addr, wdata, 3'b000, 8'h01);  // size=0 (1 byte), strb=bit 0

            // Read via AXI
            axi_read(addr, 3'b000, rdata);

            if (rdata[7:0] === wdata[7:0]) begin
                $display("  [PASS] Iteration %0d: Byte access at 0x%h - wrote 0x%02h, read 0x%02h",
                         i, addr, wdata[7:0], rdata[7:0]);
            end else begin
                $display("  [FAIL] Iteration %0d: Byte access at 0x%h - wrote 0x%02h, read 0x%02h",
                         i, addr, wdata[7:0], rdata[7:0]);
                $fatal(1, "Byte access test failed");
            end
        end
    endtask

    task test_halfword_access_frontdoor();
        automatic logic [63:0] addr;
        automatic logic [63:0] wdata, rdata;
        automatic int i;

        $display("\n[TEST 2] Front Door Halfword Access (16-bit via AXI) - RANDOMIZED");

        // RANDOMIZATION LOOP
        for (i = 0; i < 10; i = i + 1) begin
            // Randomize address (halfword aligned) and data
            addr = ({$random} & 64'h0000_FFFE);  // Ensure halfword alignment
            wdata = {$random} & 64'h0000_FFFF;   // Random halfword value
            /*Why the mask 0xFFFE?
            - Halfword = 2 bytes, must be aligned to 2-byte boundary
            - Address must be EVEN (last bit = 0)
            - 0xFFFE = 1111_1111_1111_1110 (bit 0 forced to 0)

            Examples:

            $random = 0x1234 & 0xFFFE = 0x1234  (even, aligned)
            $random = 0x1235 & 0xFFFE = 0x1234  (forced even)
            $random = 0xABCD & 0xFFFE = 0xABCC  (forced even)

            Why alignment matters?

            Valid halfword addresses:
            0x1000, 0x1002, 0x1004, 0x1006 ... (even addresses)

            Invalid halfword addresses:
            0x1001, 0x1003, 0x1005 ... (odd addresses - unaligned!) */

            // Write via AXI
            axi_write(addr, wdata, 3'b001, 8'h03);  // size=1 (2 bytes), strb=bits 0-1

            // Read via AXI
            axi_read(addr, 3'b001, rdata);

            if (rdata[15:0] === wdata[15:0]) begin
                $display("  [PASS] Iteration %0d: Halfword access at 0x%h - wrote 0x%04h, read 0x%04h",
                         i, addr, wdata[15:0], rdata[15:0]);
            end else begin
                $display("  [FAIL] Iteration %0d: Halfword access at 0x%h - wrote 0x%04h, read 0x%04h",
                         i, addr, wdata[15:0], rdata[15:0]);
                $fatal(1, "Halfword access test failed");
            end
        end
    endtask

    task test_word_access_frontdoor();
        automatic logic [63:0] addr;
        automatic logic [63:0] wdata, rdata;
        automatic int i;

        $display("\n[TEST 3] Front Door Word Access (32-bit via AXI) - RANDOMIZED");

        // RANDOMIZATION LOOP
        for (i = 0; i < 10; i = i + 1) begin
            // Randomize address (word aligned) and data
            addr = ({$random} & 64'h0000_FFFC);  // Ensure word alignment (last 2 bits = 0)
            wdata = $random;                      // Random word value, without bracket, so 32 bit value

            // Write via AXI protocol
            axi_write(addr, wdata, 3'b010, 8'h0F);  // size=2 (4 bytes), strb=bits 0-3

            // Read via AXI protocol
            axi_read(addr, 3'b010, rdata);

            if (rdata[31:0] === wdata[31:0]) begin
                $display("  [PASS] Iteration %0d: Word access at 0x%h - wrote 0x%08h, read 0x%08h",
                         i, addr, wdata[31:0], rdata[31:0]);
            end else begin
                $display("  [FAIL] Iteration %0d: Word access at 0x%h - wrote 0x%08h, read 0x%08h",
                         i, addr, wdata[31:0], rdata[31:0]);
                $fatal(1, "Word access test failed");
            end
        end
    endtask

    task test_doubleword_access_frontdoor();
        automatic logic [63:0] addr;
        automatic logic [63:0] wdata, rdata;
        automatic int i;

        $display("\n[TEST 4] Front Door Doubleword Access (64-bit via AXI) - RANDOMIZED");

        // RANDOMIZATION LOOP
        for (i = 0; i < 10; i = i + 1) begin
            // Randomize address (doubleword aligned) and data
            addr = ({$random} & 64'h0000_FFF8);  // 8-byte alignment (last 3 bits = 0)
            wdata = {$random, $random};           // Random 64-bit value

            // Write via AXI protocol
            axi_write(addr, wdata, 3'b011, 8'hFF);  // size=3 (2^3 = 8 bytes), strb=all bits

            // Read via AXI protocol
            axi_read(addr, 3'b011, rdata);

            if (rdata === wdata) begin
                $display("  [PASS] Iteration %0d: Doubleword access at 0x%h - wrote 0x%016h, read 0x%016h",
                         i, addr, wdata, rdata);
            end else begin
                $display("  [FAIL] Iteration %0d: Doubleword access at 0x%h - wrote 0x%016h, read 0x%016h",
                         i, addr, wdata, rdata);
                $fatal(1, "Doubleword access test failed");
            end
        end
    endtask

    task test_write_then_read_frontdoor();
        /*
        What it catches:
        - Data corruption in memory
        - Address decoding errors
        - Timing issues in write-read sequence
        */

        automatic logic [63:0] addr;
        automatic logic [63:0] wdata, rdata;
        automatic int i;

        $display("\n[TEST 5] Front Door Write-Read Consistency (via AXI) - RANDOMIZED");

        // RANDOMIZATION LOOP
        for (i = 0; i < 10; i = i + 1) begin
            // Randomize address and data
            addr = ({$random} & 64'h0000_FFF8);  // Doubleword aligned
            wdata = {$random, $random};

            $display("  [INFO] Iteration %0d: Writing 0x%h to address 0x%h via AXI", i, wdata, addr);
            axi_write(addr, wdata, 3'b011, 8'hFF);

            $display("  [INFO] Iteration %0d: Reading back from address 0x%h via AXI", i, addr);
            axi_read(addr, 3'b011, rdata);

            if (rdata === wdata) begin
                $display("  [PASS] Iteration %0d: Write-Read consistency verified: 0x%016h", i, rdata);
            end else begin
                $display("  [FAIL] Iteration %0d: Data mismatch: expected 0x%016h, got 0x%016h",
                         i, wdata, rdata);
                $fatal(1, "Write-Read consistency test failed");
            end
        end
    endtask

    task test_sequential_operations_frontdoor();
        automatic logic [63:0] base_addr;
        automatic logic [63:0] wdata, rdata;
        automatic logic [63:0] expected_data [0:63];  // Array to store written values
        automatic int i;

        $display("\n[TEST 6] Front Door Sequential Operations (64 transactions via AXI) - RANDOMIZED");
        base_addr = 64'h10000;

        $display("  [INFO] Writing 64 randomized doublewords via AXI protocol...");
        for (i = 0; i < 64; i = i + 1) begin
            wdata = {$random, $random};
            expected_data[i] = wdata;  // Store for later verification
            axi_write(base_addr + (i*8), wdata, 3'b011, 8'hFF);
        end

        $display("  [INFO] Reading and verifying 64 doublewords via AXI protocol...");
        for (i = 0; i < 64; i = i + 1) begin
            axi_read(base_addr + (i*8), 3'b011, rdata);
            if (rdata !== expected_data[i]) begin
                $display("  [FAIL] Sequential test failed at index %0d", i);
                $display("         Expected: 0x%016h, Got: 0x%016h", expected_data[i], rdata);
                $fatal(1, "Sequential operation test failed");
            end
        end

        $display("  [PASS] 64 sequential doubleword operations verified");
    endtask

    task test_address_alignment_frontdoor();

        // Tests that properly aligned addresses work correctly
        // Verifies different alignment requirements for different data sizes
        // Uses specific addresses that are known to be correctly aligned

        automatic logic [63:0] rdata;
        automatic logic [63:0] wdata;

        $display("\n[TEST 7] Front Door Address Alignment Tests (via AXI) - RANDOMIZED");

        // Aligned addresses with random data
        $display("  [INFO] Testing aligned accesses...");

        wdata = {$random, $random};
        axi_write(64'h5000, wdata, 3'b011, 8'hFF); // 8-byte aligned (last 3 bits = 000)
        axi_read(64'h5000, 3'b011, rdata);
        if (rdata === wdata)
            $display("  [PASS] 8-byte aligned access with random data 0x%016h", wdata);
        else
            $fatal(1, "8-byte aligned access failed");

        wdata = $random;
        axi_write(64'h6000, wdata, 3'b010, 8'h0F); // 4-byte aligned (last 2 bits = 00)
        axi_read(64'h6000, 3'b010, rdata);
        if (rdata[31:0] === wdata[31:0])
            $display("  [PASS] 4-byte aligned access with random data 0x%08h", wdata[31:0]);
        else
            $fatal(1, "4-byte aligned access failed");

        wdata = {$random} & 64'h0000_FFFF;
        axi_write(64'h7000, wdata, 3'b001, 8'h03); // 2-byte aligned (last 1 bit = 0)
        axi_read(64'h7000, 3'b001, rdata);
        if (rdata[15:0] === wdata[15:0])
            $display("  [PASS] 2-byte aligned access with random data 0x%04h", wdata[15:0]);
        else
            $fatal(1, "2-byte aligned access failed");
    endtask

    task test_strobe_patterns_frontdoor();
        automatic logic [63:0] addr;
        automatic logic [63:0] wdata, rdata;

        $display("\n[TEST 8] Front Door Byte Strobe Patterns (via AXI) - RANDOMIZED");
        addr = 64'h8000;

        // Write full word with all strobes
        wdata = {$random, $random};
        axi_write(addr, wdata, 3'b011, 8'hFF);
        axi_read(addr, 3'b011, rdata);
        if (rdata === wdata)
            $display("  [PASS] Full strobe (0xFF) with random data 0x%016h", wdata);
        else
            $fatal(1, "Full strobe test failed");

        // Write with partial strobes (lower 4 bytes only)
        addr = 64'h8010;
        wdata = {$random, $random};
        axi_write(addr, wdata, 3'b011, 8'h0F);  // Only lower 4 bytes
        axi_read(addr, 3'b011, rdata);
        if (rdata[31:0] === wdata[31:0])        // checking only the lower 4 bytes
            $display("  [PASS] Partial strobe (0x0F) - lower 4 bytes with random data 0x%08h", wdata[31:0]);
        else
            $fatal(1, "Partial strobe test failed");
    endtask

    // Comprehensive Random Transaction Test
    task test_random_transactions();
        automatic logic [63:0] addr;
        automatic logic [63:0] wdata, rdata;
        automatic logic [2:0] size;
        automatic logic [7:0] strb;
        automatic int i;

        $display("\n[TEST 9] Comprehensive Random Transactions - FULLY RANDOMIZED");

        for (i = 0; i < 50; i = i + 1) begin
            // Randomize size
            size = $random % 4;  // 0, 1, 2, or 3

            // Generate aligned address based on size
            case (size)
                3'b000: begin  // Byte
                    addr = {$random} & 64'h0000_FFFF;
                    strb = 8'h01;
                    wdata = {$random} & 64'h0000_00FF;
                end
                3'b001: begin  // Halfword
                    addr = ({$random} & 64'h0000_FFFE);
                    strb = 8'h03;
                    wdata = {$random} & 64'h0000_FFFF;
                end
                3'b010: begin  // Word
                    addr = ({$random} & 64'h0000_FFFC);
                    strb = 8'h0F;
                    wdata = $random;
                end
                3'b011: begin  // Doubleword
                    addr = ({$random} & 64'h0000_FFF8);
                    strb = 8'hFF;
                    wdata = {$random, $random};
                end
                default: begin
                    addr = 0;
                    strb = 0;
                    wdata = 0;
                end
            endcase

            // Write
            axi_write(addr, wdata, size, strb);

            // Read back
            axi_read(addr, size, rdata);

            // Verify based on size
            case (size)
                3'b000: if (rdata[7:0] !== wdata[7:0])
                           $fatal(1, "[FAIL] Random test %0d: Byte mismatch", i);
                3'b001: if (rdata[15:0] !== wdata[15:0])
                           $fatal(1, "[FAIL] Random test %0d: Halfword mismatch", i);
                3'b010: if (rdata[31:0] !== wdata[31:0])
                           $fatal(1, "[FAIL] Random test %0d: Word mismatch", i);
                3'b011: if (rdata !== wdata)
                           $fatal(1, "[FAIL] Random test %0d: Doubleword mismatch", i);
            endcase

            if (i % 10 == 0)
                $display("  [INFO] Completed %0d random transactions", i);
        end

        $display("  [PASS] All 50 random transactions passed");
    endtask

    //////////////////////////////////////////////////////////////////////////
    // Waveform Dump
    //////////////////////////////////////////////////////////////////////////
    initial begin
        $dumpfile("frontdoor_axi_ram_test.vcd");
        $dumpvars(0, real_axi_ram_test);
    end

    //////////////////////////////////////////////////////////////////////////
    // Timeout Watchdog
    //////////////////////////////////////////////////////////////////////////
    initial begin
        #10ms;
        $fatal(1, "[FATAL] Simulation timeout after 10ms");
    end

endmodule