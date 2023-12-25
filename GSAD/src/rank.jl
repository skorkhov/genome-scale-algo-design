
"""
    RankedBitVector

Data structure to support O(1)-time rank() queries on bit vectors.
"""
struct RankedBitVector <: AbstractRankedBitVector
    bits::BitVector
    blocks::Vector{UInt32}
    chunks::Vector{UInt8}

    function RankedBitVector(bits::BitVector) 
        n = length(bits)
        n_chunks = cld(n, WIDTH_CHUNK)
        n_blocks = cld(n, WIDTH_BLOCK)
        # init lookup tables
        blocks = Vector{UInt32}(undef, n_blocks)
        chunks = Vector{UInt8}(undef, n_chunks)
    
        r_tot = 0 
        r_rel = 0
        for i_chunk in 1:n_chunks
            chunk_offset_in_block = (i_chunk - 1) % CHUNKS_PER_BLOCK
            bits_in_chunk = count_ones(bits.chunks[i_chunk])
            
            if chunk_offset_in_block == 0 
                i_block = cld(i_chunk, CHUNKS_PER_BLOCK)
                blocks[i_block] = r_tot & maskr(UInt64, 32)
                chunks[i_chunk] = (r_tot >>> 32) % UInt8
                r_rel = 0
            else 
                chunks[i_chunk] = r_rel
            end

            # increment rank counter:
            r_tot += bits_in_chunk
            r_rel += bits_in_chunk
        end
    
        new(bits, blocks, chunks)
    end
end

Base.length(x::AbstractRankedBitVector) = length(x.bits)
Base.size(x::AbstractRankedBitVector) = (length(x),)
Base.convert(::Type{BitVector}, x::AbstractRankedBitVector) = x.bits
Base.convert(::Type{T}, x::BitVector) where T <: AbstractRankedBitVector = RankedBitVector(x)

Base.getindex(A::AbstractRankedBitVector, i::Integer) = Base.getindex(A.bits, i)
Base.firstindex(A::AbstractRankedBitVector) = firstindex(A.bits)
Base.lastindex(A) = lastindex(A.bits)

Base.sum(v::AbstractRankedBitVector) = rank(v, length(v))

"""
    rank(v::RankedBitVector, i::Integer)

Compute the number of 1s in `v[1:i]` in O(1) time.
"""
function rank(v::AbstractRankedBitVector, i::Integer)
    if i < 0 || length(v) < i
        throw(BoundsError(v, i))
    end
    
    return rank_unsafe(v, i)
end

function rank_unsafe(v::AbstractRankedBitVector, i::Integer)
    i_block = cld(i, WIDTH_BLOCK)
    i_chunk = cld(i, WIDTH_CHUNK)
    chunk = v.bits.chunks[i_chunk]

    chunk_offset_in_block = (i_chunk - 1) % CHUNKS_PER_BLOCK
    @inbounds r = (
        convert(Int, v.chunks[i_chunk - chunk_offset_in_block]) << 32 +
        v.blocks[i_block] + 
        count_ones(chunk & maskr(typeof(chunk), (i - 1) % WIDTH_CHUNK + 1))
    )
    if chunk_offset_in_block != 0 
        @inbounds r += v.chunks[i_chunk]
    end

    return r
end


"""
    select(v::AbstractRankedBitVector, j)

Compute index of a 1-element of `v` with rank `j` in O(log(len(v))) time. 
"""
function select(v::AbstractRankedBitVector, j)
    hi = length(v)
    lo = 1
    r_max = rank(v, hi)
    if j <= 0 || j > r_max
        throw(DomainError(j, "cannot select(v, $j) if max-rank(v) < $j"))
    end

    mid = div(hi + lo, 2)
    while lo < hi || v.bits[mid] != 1
        mid = div(hi + lo, 2)
        r = rank(v, mid)
        # ensure correct index always stays in [lo, hi]
        if r >= j
            hi = mid
        else r < j
            lo = mid + 1
        end
    end

    lo
end
