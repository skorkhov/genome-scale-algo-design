abstract type AbstractRankedBitVector <: AbstractVector{Bool} end

function split_bits_8plus32(n)
    try
        n = UInt64(n)
    catch 
        throw(DomainError("only Unsigned ints can be split"))
    end

    n > 2^40 && throw(ArgumentError("Integer n should be below n^40: log2(n)=$(log2(n))"))
    last32 = n % UInt32
    first8 = (n >>> 32) % UInt8

    first8, last32
end

function sum_short_block(v::BitVector, ith::Integer)
    from = (ith - 1) * BLOCK_WIDTH_SHORT + 1
    to = ith * BLOCK_WIDTH_SHORT
    sum(v[from:to])
end

struct RankedBitVector <: AbstractRankedBitVector
    v::BitVector
    long::Vector{UInt32}
    short::Vector{UInt8}

    function RankedBitVector(v::BitVector) 
        n = length(v)
        # init lookup tables
        long = Vector{UInt32}(undef, div(n, BLOCK_WIDTH_LONG))
        short = Vector{UInt8}(undef, div(n, BLOCK_WIDTH_SHORT))
    
        overall = 0 
        relative = 0
        for sth in eachindex(short)
            if sth % N_SHORT_PER_LONG == 0 
                # if at the end of a long block:
                lth = div(sth, N_SHORT_PER_LONG) 
                overall += sum_short_block(v, sth)
                short[sth], long[lth] = split_bits_8plus32(overall)
                relative = 0
            else 
                inc = sum_short_block(v, sth)
                overall += inc
                relative += inc
                short[sth] = relative
            end
        end
    
        new(v, long, short)
    end
end

Base.length(v::RankedBitVector) = length(v.v)
Base.size(v::RankedBitVector) = (length(v),)
Base.convert(::Type{BitVector}, x::RankedBitVector) = x.v

Base.show(io::IO, x::RankedBitVector) = Base.show(io, x.v)
# for some reason is necessary to make printing work in the terminal: 
Base.show(io::IO, ::MIME"text/plain", z::RankedBitVector) = print(io, "RankedBitVector: ", z.v)

rank_within_uint64(i::UInt64, pos) = count_ones(i << (64 - pos))

function rank1(v::RankedBitVector, i)
    i = clamp(i, 0, length(v))
    ilong = div(i, BLOCK_WIDTH_LONG)
    ishort = div(i, BLOCK_WIDTH_SHORT)

    # each cached rank of a long chunk is stored in two arrays: 
    # first 8 bits in the aligned short chunk table
    # last 32 bits in the long chunk table
    ishort_first8 = ilong * N_SHORT_PER_LONG
    rank_cache_long_first8 = ishort_first8 > 0 ? v.short[ishort_first8] : UInt8(0)
    rank_cache_long_last32 = ilong > 0 ? v.long[ilong] : 0
    rank_cache_long = UInt64(rank_cache_long_first8) << 32 + rank_cache_long_last32
    
    # every N_SHORT_PER_LONG'th short chunk stores long cache - ignore
    rank_cache_short = ishort % N_SHORT_PER_LONG == 0 ? 0 : v.short[ishort]
    rank_in_chunk = rank_within_uint64(v.v.chunks[ishort + 1], i % 64)
    
    rank_cache_long + rank_cache_short + rank_in_chunk
end


# "slow" select with binary search using rank1: log(n) time
function select1(v::RankedBitVector, j)
    hi = length(v)
    lo = 1
    r_max = rank1(v, hi)
    if j <= 0 || j > r_max
        throw(BoundsError("rank(v, length(v))=$r_max; attempting to access $j"))
    end

    mid = div(hi + lo, 2)
    while lo < hi || v.v[mid] != 1
        mid = div(hi + lo, 2)
        r = rank1(v, mid)
        # ensure correct index always stays in [lo, hi]
        if r >= j
            hi = mid
        else r < j
            lo = mid + 1
        end
    end

    lo
end
