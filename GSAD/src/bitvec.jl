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
    from = (ith - 1) * WIDTH_CHUNK + 1
    to = ith * WIDTH_CHUNK
    sum(v[from:to])
end

struct RankedBitVector <: AbstractRankedBitVector
    bits::BitVector
    long::Vector{UInt32}
    short::Vector{UInt8}

    function RankedBitVector(bits::BitVector) 
        n = length(bits)
        # init lookup tables
        long = Vector{UInt32}(undef, div(n, WIDTH_BLOCK))
        short = Vector{UInt8}(undef, div(n, WIDTH_CHUNK))
    
        overall = 0 
        relative = 0
        for sth in eachindex(short)
            if sth % CHUNKS_PER_BLOCK == 0 
                # if at the end of a long block:
                lth = div(sth, CHUNKS_PER_BLOCK) 
                overall += sum_short_block(bits, sth)
                short[sth], long[lth] = split_bits_8plus32(overall)
                relative = 0
            else 
                inc = sum_short_block(bits, sth)
                overall += inc
                relative += inc
                short[sth] = relative
            end
        end
    
        new(bits, long, short)
    end
end

Base.length(v::RankedBitVector) = length(v.bits)
Base.size(v::RankedBitVector) = (length(v),)
Base.convert(::Type{BitVector}, v::RankedBitVector) = v.bits

Base.show(io::IO, x::RankedBitVector) = Base.show(io, x.bits)
# for some reason is necessary to make printing work in the terminal: 
Base.show(io::IO, ::MIME"text/plain", v::RankedBitVector) = print(io, "RankedBitVector: ", v.bits)

rank_within_uint64(i::UInt64, pos) = count_ones(i << (64 - pos))

function rank1(v::RankedBitVector, i)
    i = clamp(i, 0, length(v))
    ilong = div(i, WIDTH_BLOCK)
    ishort = div(i, WIDTH_CHUNK)

    # each cached rank of a long chunk is stored in two arrays: 
    # first 8 bits in the aligned short chunk table
    # last 32 bits in the long chunk table
    ishort_first8 = ilong * CHUNKS_PER_BLOCK
    rank_cache_long_first8 = ishort_first8 > 0 ? v.short[ishort_first8] : UInt8(0)
    rank_cache_long_last32 = ilong > 0 ? v.long[ilong] : 0
    rank_cache_long = UInt64(rank_cache_long_first8) << 32 + rank_cache_long_last32
    
    # every CHUNKS_PER_BLOCK'th short chunk stores long cache - ignore
    rank_cache_short = ishort % CHUNKS_PER_BLOCK == 0 ? 0 : v.short[ishort]
    rank_in_chunk = rank_within_uint64(v.bits.chunks[ishort + 1], i % 64)
    
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
    while lo < hi || v.bits[mid] != 1
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
