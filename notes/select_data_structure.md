# Overall

Idea: `select(v, j)` returns the _position_ of a 1-bit with rank j. Hence, we 
will split the original vector up into segments and store intermediate positions
of elements with known ranks (and what those ranks are). Because we are 
considering ranks, our measure of how far we are from the start of the vector 
has to do with how many 1-bits we "passed" on the way, not simply how many 
positions. The lengths of segments will be governed by the number of 1-bits in 
them.

Note: remember, we are looking for a _position_, so we will store intermediate 
positions to later quickly query it given an input rank. For rank data 
structure, we stored intermediate ranks because the output we needed was a rank. 


# Details: Types and Sizes

- segments with `pop(.) = log(n) ^ 2`; can be _dense_ or _sparse_:
    - store `offsets`: position of the start of each segment
        - `count(.)`: can be computed using max rank
        - `size(.) = log(n)`

    - _sparse_ `S` (high 1-bit packing) = `len(S) > log(n) ^ 4`
        - `count(.)` has to be compited after all chunks are classified
        - pre-calculate the position of each 1-bit in a sparse chunk; 
        - for each sparse chunk
            - vector of positions, indexed by rank of 1 at each position
            - `size(.) = log(n)` (a sparse chunk can be as long as input)
            - `count(.) = log(n) ^ 2` (max count, but we can afford)
            - if 2^32 input length: `Vector{UInt32}` of length `log(n) ^ 2`

    - _dense_ `D` (high 1-bit packing) = `len(D) <= log(n) ^ 4`
        - store: `offsets_relative`: 
            - `count(.)`: 
            - `size(.) = log(log(n) ^ 4) = 4log(log(n))`
        - _dense-dense_ `Dd`: segments with `pop(.) = sqrt(log(n))` 
            - store lookup table for each possible vector 
        - _dense-sparse_ `Ds`: segment with `pop(.) = sqrt(log(n))`
            - pre-calculate the position of each 1-bit in a `Ds` chunk; 
            - for each `Ds` chunk: 
                - vector of positions, indexed by rank of 1 at each postion
                - `size(.) = log(log(n) ^ 4)`  (<24 or 5-bit number)
                - `Vector{IntSize(log(log(n) ^ 4))} `of length `sqrt(log(n))`


# Static vs Dynamic n-dependent DS sizing

**Example:**

For an up to `64^4`-bit-long vector with less than 4096 1-bits, and no
Dense-dense chunk (a chunk with at least 8 1-bits within a 32-bit wide span),
all 1-bit positions will be cached.[^ex] The max size of such data structure would 
assume 7 1-bits for every 32, or `7n/32` positions, each taking up 32 bits of 
storage, or `32 * 7n/32  >  log(n) * 7n/32` bits to store the positions; and
`32 * n/8 > log(n)` bits to store sub-segment offsets. 

[^ex] This is a bit vector with 1 Dense segment full of Dense-sparse 
sub-segments; the example is valid for n up to `64^4`.

**Conclusion:**
<!-- TODO: fix conclusion -->

Statically sized data structure for `select()` operations is O(n), but is worse 
than that for smaller sequences since the sizes/densities of different kinds of 
caches (Sparse, Dense-sparse, and Dense-dense) are anchored to the max allowed 
bitvector length of 2^64 (very large bitvector length).
