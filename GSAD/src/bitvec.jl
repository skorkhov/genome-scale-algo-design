abstract type AbstractRankedBitVector <: AbstractVector{Bool} end

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

Base.length(v::RankedBitVector) = length(v.bits)
Base.size(v::RankedBitVector) = (length(v),)
Base.convert(::Type{BitVector}, v::RankedBitVector) = v.bits

Base.show(io::IO, x::RankedBitVector) = Base.show(io, x.bits)
# for some reason is necessary to make printing work in the terminal: 
Base.show(io::IO, ::MIME"text/plain", v::RankedBitVector) = print(io, "RankedBitVector: ", v.bits)

"""
    rank1(v::RankedBitVector, i::Integer)

Compute the number of 1s in `v[1:i]` in O(1) time.
"""
function rank1(v::RankedBitVector, i::Integer)
    if i < 0 || length(v) < i
        throw(BoundsError("index `i` has to be in [0, length(v)]; given i=$i"))
    end
    
    return rank1_unsafe(v, i)
end

function rank1_unsafe(v::RankedBitVector, i::Integer)
    i_block = cld(i, WIDTH_BLOCK)
    i_chunk = cld(i, WIDTH_CHUNK)
    chunk = v.bits.chunks[i_chunk]

    chunk_offset_in_block = (i_chunk - 1) % CHUNKS_PER_BLOCK
    r = (
        convert(Int, v.chunks[i_chunk - chunk_offset_in_block]) << 32 +
        v.blocks[i_block] + 
        count_ones(chunk & maskr(typeof(chunk), i % WIDTH_CHUNK))
    )
    if chunk_offset_in_block != 0 
        r += v.chunks[i_chunk]
    end

    return r
end


"""
    select1(v::RankedBitVector, j)

Compute index of a 1-element of `v` with rank `j` in O(log(len(v))) time. 
"""
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
