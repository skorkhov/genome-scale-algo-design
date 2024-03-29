# Theory from Genome-Scale Algorithm Design

v = BitVector, length(v) = n

General idea: subdivide v into chunks of 2 different sizes (l and s), 
and for each chunk store the rank relative to the beginning of the chunk. 

Chunk Sizes: width(l) and width(s)
- width(l) 
- width(k) = sqrt(width(l))

To compute the rank at i, identify the large and small chunks to which a bit at 
position i belongs, then extract the respecive ranck caches of the chunks and 
add them up. 

What remains is to comput the name within the small chunk relative to the 
beginninf of the chunk. There are two appraoches to this: 
(1) store a 2D tables of ranks at all possible position or all possible small 
    chunks; or
(2) use machine instructions (e.g. popcount and bit-shifts) to compute on the 
    fly in constant time, which can be done on machine word-sized blocks of 
    memory in constant time. 


# Relationships between block width, and the size/number of values it stores

The length of each type of block dictates the width of the entries that store 
the block's cached rank. Let's label each block level as 0th, 1st, 2nd, and 
consider the width and length of a each type of block, where
- width() = how many bites of the bitvector are in the block's scope
- holds() = the size of integer that stores the block-associated cache
- len() = how many of this type of blocks are needed for the DS

0th: the entire bitvector
width(0th) = n
holds(0th) = log2(n)
len(0th) = 1

1st: a large block within the bitvector
width(1st) = w1
holds(1st) = log2(n)
len(1st) = n / width(.) = n / w1

2nd: a small block within the bitvector
width(2nd) = w2
holds(2nd) = log2(width(1st)) = log2(w1)
len(2nd) = n / width(.) = n / w2

Note: the lookup tables store ranks relative to the start of the larger chunk to
which they belong. In particular, the start of every [lcm(w1, w2) / w2]th 
small chunk (or, w1 mod w2 = 0, every (w1/w2)th) will align with the start of 
a large chunk, and every large chunk will align with a small chunk. Meaning, the 
lookup table for the small chunk will store 0. We don't have to waste those bits
storing effectively no information, and can instead use them to increase the 
allowed container size of the first chunk as follows: 

effective size of bitvector = h'(1st) = holds(1st) + holds(2nd)

Because the integer size of 1st corresponds to the max length of the bitvector,
we can (the following two are equivalent) either achieve a given length by using
smaller integers in 1st and 2nd lookup tables, or extend the max size of the 
bitvector we can store.

# Practical Notes:

It makes sense to pick such intervals that holds(.) are powers of two. Pick the
smallest available integer size for holds(2nd): 8 bits (UInt8). Then, to 
accommodate a sufficiently large bitvector, holds(1st) = 32 bits (UInt32). With 
such choices, h'(1st) = 40 bits, allowing bitvector to be >100 GB.
