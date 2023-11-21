using BenchmarkTools
using Random
import IndexableBitVectors as ibv

Random.seed!(1)

v_bool = rand(Bool, 1_000_000)
v_bit = BitArray(x);
# rank up to each chunk: 
t1 = accumulate(+, map(count_ones, y.chunks))


# reprocude findall from Julia Discort
@btime findall($v_bool);
@btime findall($v_bit);

# Experiment - benchmark count_ones()
# compare count_ones in different length integers 
# to determine the "computer word size" for the purposes or bitvector rank()
Random.seed!(1)
i128 = rand(UInt128, 1_000_000);
i64 = rand(UInt64, 1_000_000);
i16 = rand(UInt16, 1_000_000);
i8 = rand(UInt8, 1_000_000);

@btime count_ones.($i128);
@btime count_ones.($i64);
@btime count_ones.($i16);
@btime count_ones.($i8);

# Conclusion:
# time is roughly proportional to bits_in(i)/word_size; 
# it is slower for integers shorter than 64 bits 
# because there are additional operations to exclude the padding bits



# Experiment - benchmark code: 
mtx = BitArray(undef, (2, 3))
rand!(mtx)

arr = BitArray(rand(0:1,50))
@edit BitArray(rand(0:1,10))
@edit BitArray{1}(undef, 1)

reshape(rand(0:1,10), (2, 5))
BitArray(reshape(rand(0:1,10), (2, 5)))



# Experiment - step into a function with Debugger
# commands in docs: https://github.com/JuliaDebug/Debugger.jl
#   st = "state"
#   n = step to next line
#   ` = enter evaluation mode
#   [w / w add expr / w rm i] = show / add expr to / remove ith expr from watch list
#   o = show current line in source
#   q = quit and return nothing
using Debugger
Debugger.@enter BitArray{1}(undef, 1)
Debugger.@enter BitArray{1}(undef, 65)

# Conclusion: 
# for BitArrays of dim N=1, the `dims` slot in the type is never set to anything, 
# so it stays uninitialized; for higher values of dims N, dims are reported correctly
a = BitArray(undef, 1); a.dims
a = BitArray(undef, 1, 1); a.dims

# Questions Remaing: 
#   - why `dims` slots is never initialized for N=1
#   - why only the last chunk is initialized to 0: `nc > 0 && (chunks[end] = UInt64(0))`



# Experiment - bit layout in BitArray (N>1)
bits = Bool[1, 0, 1, 0, 1, 0]
shape = (2, 3)
bit_mtx = BitArray(reshape(bits, shape))
bit_vec = reshape(bit_mtx, reduce(*, shape))
# see chunks: 
bit_mtx.chunks == bit_vec.chunks
Int(bit_mtx.chunks[1])
Int(bit_vec.chunks[1])



# Experiment - set a breakpoint in a deep call of a function
# call an outer constructor with a breakpoint in an inner constructor
a = BitArray(rand(0:1, 10))

# set a breakpoint in all constructor methods: 
Debugger.@enter BitArray{1}(undef, 1)
# once in, set a breakpoint at some line of the source, 
# e.g. in inner cosntructor,
# then quit: 
# > bp add 31
# > q

# then enter another function to debug: 
Debugger.@enter BitArray(rand(0:1, 10))
# once done, remove all breakpoints:
# > bp rm



# Experiment - does BitVector store values flush-LEFT or RIGHT?
using Test

function first_chunk(v::BitArray)
    chunk = falses(64)
    chunk.chunks[1] = v.chunks[1]
    chunk
end

function last_chunk(v::BitArray)
    chunk = falses(64)
    chunk.chunks[1] = v.chunks[end]
    chunk
end

# define a BitArray with two chunks:
v = falses(70)
v[1:3] .= true
v[end] = true   

first_block(v)
last_block(v) 

# Conclusion: bitvector chunks are LEFT-justified
empty_chunk = falses(64)

first = copy(empty_chunk)
first[1:3] .= true
@test first_block(v) == first

last = copy(empty_chunk)
last[70 - 64] = true
@test last_block(v) == last



# Experiment - two ways to split an int into 8+32 bits
using BenchmarkTools
function f(n)
    first8 = UInt8(n >>> 32)
    last32 = UInt32(n << 32 >>> 32)

    first8, last32
end

function h(n)
    last32 = n % UInt32
    first8 = (n >>> 32) % UInt8

    first8, last32
end


ints_large = rand((2^32):(2^40), 1000);
@btime f.($ints_large);
@btime h.($ints_large);

ints_small = rand(0:(2^30), 1000);
@btime f.($ints_small);
@btime h.($ints_small);


# Experiment - compare my rank with one from IndexableBitVectors
using Random
using BenchmarkTools
using IndexableBitVectors, GSAD

Random.seed!(1)
bv = bitrand(1_000_000)
bv0 = convert(IndexableBitVectors.CompactBitVector, bv)
bv1 = SucVector(bv)
bv2 = RankedBitVector(bv)
bv3 = CachedBitVector(bv)

i = 9_000
@btime GSAD.rank1($bv, $i);
@btime IndexableBitVectors.rank1($bv0, $i);
@btime IndexableBitVectors.rank1($bv1, $i);
@btime GSAD.rank1($bv2, $i);
@btime GSAD.rank1($bv3, $i);

i = 90_000
@btime GSAD.rank1($bv, $i);
@btime IndexableBitVectors.rank1($bv0, $i);
@btime IndexableBitVectors.rank1($bv1, $i);
@btime GSAD.rank1($bv2, $i);
@btime GSAD.rank1($bv3, $i);

i = 900_000
@btime GSAD.rank1($bv, $i);
@btime IndexableBitVectors.rank1($bv1, $i);
@btime GSAD.rank1($bv2, $i);
@btime GSAD.rank1($bv3, $i);

# veery long vector:
Random.seed!(1)
len = 2^32 + 3
bv = bitrand(len)
bv1 = SucVector(bv)
bv2 = RankedBitVector(bv)

i = 2^32 + 1
@btime GSAD.rank1($bv, $i);
@btime IndexableBitVectors.rank1($bv1, $i);
@btime GSAD.rank1($bv2, $i);

# veery long vecctor of 1: 
len = 2^32 + 3
bv = trues(len)
bv0 = convert(IndexableBitVectors.CompactBitVector, bv)
bv1 = SucVector(bv)
bv2 = RankedBitVector(bv)

IndexableBitVectors.rank1(bv0, len)
IndexableBitVectors.rank1(bv1, len)
Int(GSAD.rank1(bv2, len))
