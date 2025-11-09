module id_queue #(
    parameter int ID_WIDTH  = 0,
    parameter int CAPACITY  = 0,
    parameter bit FULL_BW   = 0,
    parameter bit CUT_OUP_POP_INP_GNT = 0,
    parameter int NUM_CMP_PORTS = 1,
    parameter type data_t   = logic[31:0],

    localparam type id_t    = logic[ID_WIDTH-1:0]
) (
    input  logic    clk_i,
    input  logic    rst_ni,

    input  id_t     inp_id_i,
    input  data_t   inp_data_i,
    input  logic    inp_req_i,
    output logic    inp_gnt_o,

    input  data_t [NUM_CMP_PORTS-1:0] exists_data_i,
    input  data_t [NUM_CMP_PORTS-1:0] exists_mask_i,
    input  logic  [NUM_CMP_PORTS-1:0] exists_req_i,
    output logic  [NUM_CMP_PORTS-1:0] exists_o,
    output logic  [NUM_CMP_PORTS-1:0] exists_gnt_o,

    input  id_t     oup_id_i,
    input  logic    oup_pop_i,
    input  logic    oup_req_i,
    output data_t   oup_data_o,
    output logic    oup_data_valid_o,
    output logic    oup_gnt_o
);

    localparam int NIds = 2**ID_WIDTH;
    localparam int HtCapacity = (NIds <= CAPACITY) ? NIds : CAPACITY;
    localparam int unsigned HtIdxWidth = cf_math_pkg::idx_width(HtCapacity);
    localparam int unsigned LdIdxWidth = cf_math_pkg::idx_width(CAPACITY);

    typedef logic [HtIdxWidth-1:0] ht_idx_t;

    typedef logic [LdIdxWidth-1:0] ld_idx_t;

    typedef struct packed {
        id_t        id;
        ld_idx_t    head,
                    tail;
        logic       free;
    } head_tail_t;

    typedef struct packed {
        data_t      data;
        ld_idx_t    next;
        logic       free;
    } linked_data_t;

    head_tail_t [HtCapacity-1:0]    head_tail_d,    head_tail_q;

    linked_data_t [CAPACITY-1:0]    linked_data_d,  linked_data_q;

    logic                           full,
                                    match_in_id_valid,
                                    match_out_id_valid,
                                    no_in_id_match,
                                    no_out_id_match;

    logic [HtCapacity-1:0]         head_tail_free,
                                    idx_matches_in_id,
                                    idx_matches_out_id;

    logic [NUM_CMP_PORTS-1:0][CAPACITY-1:0] exists_match;
    logic [CAPACITY-1:0]            linked_data_free;

    id_t                            match_in_id, match_out_id;

    ht_idx_t                        head_tail_free_idx,
                                    match_in_idx,
                                    match_out_idx;

    ld_idx_t                        linked_data_free_idx,
                                    oup_data_free_idx;

    logic                           oup_data_popped,
                                    oup_ht_popped;

    for (genvar i = 0; i < HtCapacity; i++) begin: gen_idx_match
        assign idx_matches_in_id[i] = match_in_id_valid && (head_tail_q[i].id == match_in_id) &&
                !head_tail_q[i].free;
        assign idx_matches_out_id[i] = match_out_id_valid && (head_tail_q[i].id == match_out_id) &&
                !head_tail_q[i].free;
    end
    assign no_in_id_match = !(|idx_matches_in_id);
    assign no_out_id_match = !(|idx_matches_out_id);
    onehot_to_bin #(
        .ONEHOT_WIDTH ( HtCapacity )
    ) i_id_ohb_in (
        .onehot ( idx_matches_in_id ),
        .bin    ( match_in_idx      )
    );
    onehot_to_bin #(
        .ONEHOT_WIDTH ( HtCapacity )
    ) i_id_ohb_out (
        .onehot ( idx_matches_out_id ),
        .bin    ( match_out_idx      )
    );

    for (genvar i = 0; i < HtCapacity; i++) begin: gen_head_tail_free
        assign head_tail_free[i] = head_tail_q[i].free;
    end
    lzc #(
        .WIDTH ( HtCapacity ),
        .MODE  ( 0          )
    ) i_ht_free_lzc (
        .in_i    ( head_tail_free     ),
        .cnt_o   ( head_tail_free_idx ),
        .empty_o (                    )
    );

    for (genvar i = 0; i < CAPACITY; i++) begin: gen_linked_data_free
        assign linked_data_free[i] = linked_data_q[i].free;
    end
    lzc #(
        .WIDTH ( CAPACITY ),
        .MODE  ( 0        )
    ) i_ld_free_lzc (
        .in_i    ( linked_data_free     ),
        .cnt_o   ( linked_data_free_idx ),
        .empty_o (                      )
    );

    assign full = !(|linked_data_free);

    assign oup_data_free_idx = head_tail_q[match_out_idx].head;

    assign inp_gnt_o = ~full || (oup_data_popped && FULL_BW && ~CUT_OUP_POP_INP_GNT);
    always_comb begin
        match_in_id         = '0;
        match_out_id        = '0;
        match_in_id_valid   = 1'b0;
        match_out_id_valid  = 1'b0;
        head_tail_d         = head_tail_q;
        linked_data_d       = linked_data_q;
        oup_gnt_o           = 1'b0;
        oup_data_o          = data_t'('0);
        oup_data_valid_o    = 1'b0;
        oup_data_popped     = 1'b0;
        oup_ht_popped       = 1'b0;

        if (!FULL_BW) begin
            if (inp_req_i && !full) begin
                match_in_id = inp_id_i;
                match_in_id_valid = 1'b1;

                if (no_in_id_match) begin
                    head_tail_d[head_tail_free_idx] = '{
                        id: inp_id_i,
                        head: linked_data_free_idx,
                        tail: linked_data_free_idx,
                        free: 1'b0
                    };

                end else begin
                    linked_data_d[head_tail_q[match_in_idx].tail].next = linked_data_free_idx;
                    head_tail_d[match_in_idx].tail = linked_data_free_idx;
                end
                linked_data_d[linked_data_free_idx] = '{
                    data: inp_data_i,
                    next: '0,
                    free: 1'b0
                };
            end else if (oup_req_i) begin
                match_in_id = oup_id_i;
                match_in_id_valid = 1'b1;
                if (!no_in_id_match) begin
                    oup_data_o = data_t'(linked_data_q[head_tail_q[match_in_idx].head].data);
                    oup_data_valid_o = 1'b1;
                    if (oup_pop_i) begin

                        linked_data_d[head_tail_q[match_in_idx].head]      = '0;
                        linked_data_d[head_tail_q[match_in_idx].head].free = 1'b1;
                        if (head_tail_q[match_in_idx].head == head_tail_q[match_in_idx].tail) begin
                            head_tail_d[match_in_idx] = '{free: 1'b1, default: '0};
                        end else begin
                            head_tail_d[match_in_idx].head =
                                    linked_data_q[head_tail_q[match_in_idx].head].next;
                        end
                    end
                end

                oup_gnt_o = 1'b1;
            end
        end else begin

            if (oup_req_i) begin
                match_out_id = oup_id_i;
                match_out_id_valid = 1'b1;
                if (!no_out_id_match) begin
                    oup_data_o = data_t'(linked_data_q[head_tail_q[match_out_idx].head].data);
                    oup_data_valid_o = 1'b1;
                    if (oup_pop_i) begin
                        oup_data_popped = 1'b1;

                        linked_data_d[head_tail_q[match_out_idx].head]      = '0;
                        linked_data_d[head_tail_q[match_out_idx].head].free = 1'b1;
                        if (head_tail_q[match_out_idx].head
                                          == head_tail_q[match_out_idx].tail) begin
                            oup_ht_popped = 1'b1;
                            head_tail_d[match_out_idx] = '{free: 1'b1, default: '0};
                        end else begin
                            head_tail_d[match_out_idx].head =
                                    linked_data_q[head_tail_q[match_out_idx].head].next;
                        end
                    end
                end

                oup_gnt_o = 1'b1;
            end
            if (inp_req_i && inp_gnt_o) begin
                match_in_id = inp_id_i;
                match_in_id_valid = 1'b1;

                if (oup_ht_popped && (oup_id_i==inp_id_i)) begin

                    head_tail_d[match_out_idx] = '{
                        id: inp_id_i,
                        head: oup_data_free_idx,
                        tail: oup_data_free_idx,
                        free: 1'b0
                    };
                    linked_data_d[oup_data_free_idx] = '{
                        data: inp_data_i,
                        next: '0,
                        free: 1'b0
                    };
                end else if (no_in_id_match) begin

                    if (oup_ht_popped) begin
                        head_tail_d[match_out_idx] = '{
                            id: inp_id_i,
                            head: oup_data_free_idx,
                            tail: oup_data_free_idx,
                            free: 1'b0
                        };
                        linked_data_d[oup_data_free_idx] = '{
                            data: inp_data_i,
                            next: '0,
                            free: 1'b0
                        };
                    end else begin
                        if (oup_data_popped) begin
                          head_tail_d[head_tail_free_idx] = '{
                            id: inp_id_i,
                            head: oup_data_free_idx,
                            tail: oup_data_free_idx,
                            free: 1'b0
                          };
                          linked_data_d[oup_data_free_idx] = '{
                              data: inp_data_i,
                              next: '0,
                              free: 1'b0
                          };
                        end else begin
                            head_tail_d[head_tail_free_idx] = '{
                              id: inp_id_i,
                              head: linked_data_free_idx,
                              tail: linked_data_free_idx,
                              free: 1'b0
                            };
                            linked_data_d[linked_data_free_idx] = '{
                                data: inp_data_i,
                                next: '0,
                                free: 1'b0
                            };
                        end
                    end
                end else begin

                    if (oup_data_popped) begin
                        linked_data_d[head_tail_q[match_in_idx].tail].next = oup_data_free_idx;
                        head_tail_d[match_in_idx].tail = oup_data_free_idx;
                        linked_data_d[oup_data_free_idx] = '{
                            data: inp_data_i,
                            next: '0,
                            free: 1'b0
                        };
                    end else begin
                        linked_data_d[head_tail_q[match_in_idx].tail].next = linked_data_free_idx;
                        head_tail_d[match_in_idx].tail = linked_data_free_idx;
                        linked_data_d[linked_data_free_idx] = '{
                            data: inp_data_i,
                            next: '0,
                            free: 1'b0
                        };
                    end
                end
            end
        end
    end

    for (genvar k = 0; k < NUM_CMP_PORTS; k++) begin: gen_lookup_port
        for (genvar i = 0; i < CAPACITY; i++) begin: gen_lookup
            data_t exists_match_bits;
            for (genvar j = 0; j < $bits(data_t); j++) begin: gen_mask
                always_comb begin
                    if (linked_data_q[i].free) begin
                        exists_match_bits[j] = 1'b0;
                    end else begin
                        if (!exists_mask_i[k][j]) begin
                            exists_match_bits[j] = 1'b1;
                        end else begin
                            exists_match_bits[j] =
                                (linked_data_q[i].data[j] == exists_data_i[k][j]);
                        end
                    end
                end
            end
            assign exists_match[k][i] = (&exists_match_bits);
        end
        always_comb begin
            exists_gnt_o[k] = 1'b0;
            exists_o[k] = '0;
            if (exists_req_i[k]) begin
                exists_gnt_o[k] = 1'b1;
                exists_o[k] = (|exists_match[k]);
            end
        end
    end

    for (genvar i = 0; i < HtCapacity; i++) begin: gen_ht_ffs
        always_ff @(posedge clk_i, negedge rst_ni) begin
            if (!rst_ni) begin
                head_tail_q[i] <= '{free: 1'b1, default: '0};
            end else begin
                head_tail_q[i] <= head_tail_d[i];
            end
        end
    end
    for (genvar i = 0; i < CAPACITY; i++) begin: gen_data_ffs
        always_ff @(posedge clk_i, negedge rst_ni) begin
            if (!rst_ni) begin

                linked_data_q[i]      <= '0;
                linked_data_q[i].free <= 1'b1;
            end else begin
                linked_data_q[i]    <= linked_data_d[i];
            end
        end
    end

endmodule
