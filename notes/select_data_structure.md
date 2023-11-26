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
    
    




