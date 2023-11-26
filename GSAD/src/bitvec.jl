"Supertype for one-dimensional arrays with fast rank()."
abstract type AbstractRankedBitVector <: AbstractVector{Bool} end

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

Base.show(io::IO, x::RankedBitVector) = Base.show(io, x.bits)
# for some reason is necessary to make printing work in the terminal: 
Base.show(io::IO, ::MIME"text/plain", x::RankedBitVector) = print(io, "RankedBitVector: ", x.bits)

Base.getindex(A::AbstractRankedBitVector, i::Integer) = getindex(A.bits, i)
Base.firstindex(A::AbstractRankedBitVector) = firstindex(A.bits)
Base.lastindex(A) = lastindex(A.bits)

"""
    rank1(v::RankedBitVector, i::Integer)

Compute the number of 1s in `v[1:i]` in O(1) time.
"""
function rank1(v::AbstractRankedBitVector, i::Integer)
    if i < 0 || length(v) < i
        throw(BoundsError(v, i))
    end
    
    return rank1_unsafe(v, i)
end

function rank1_unsafe(v::AbstractRankedBitVector, i::Integer)
    i_block = cld(i, WIDTH_BLOCK)
    i_chunk = cld(i, WIDTH_CHUNK)
    chunk = v.bits.chunks[i_chunk]

    chunk_offset_in_block = (i_chunk - 1) % CHUNKS_PER_BLOCK
    @inbounds r = (
        convert(Int, v.chunks[i_chunk - chunk_offset_in_block]) << 32 +
        v.blocks[i_block] + 
        count_ones(chunk & maskr(typeof(chunk), i % WIDTH_CHUNK))
    )
    if chunk_offset_in_block != 0 
        @inbounds r += v.chunks[i_chunk]
    end

    return r
end


"""
    select1(v::AbstractRankedBitVector, j)

Compute index of a 1-element of `v` with rank `j` in O(log(len(v))) time. 
"""
function select1(v::AbstractRankedBitVector, j)
    hi = length(v)
    lo = 1
    r_max = rank1(v, hi)
    if j <= 0 || j > r_max
        throw(DomainError(j, "cannot select(v, $j) if max-rank(v) < $j"))
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



"Supertype for one-dimensional arrays with fast select()."
abstract type AbstractMappedBitVector <: AbstractVector{Bool} end

"""
    MappedBitVectorLayout

Type to store segment layout for MappedBitVector supporting O(1)-time select().
"""
struct MappedBitVectorLayout
    segpos::Vector{UInt64}
    # need to know the rank of the dense chunk to undex into subsegpos
    is_dense::RankedBitVector

    # vector of sub-seg positions relative to start of Dense segment
    # len(.) = num of Dense segments
    # len(.[i]) = num of sub-segs in a seg = log(n)^2 / sqrt(log(n)) = 512
    # ragged 2D array indexed by rank(is_dense)
    # 
    # sub-segments only exist within Dense segments, 
    # where Dense segments are at most log(n)^4 bits long; 
    # hence, to represent relative start position of a sub-seg withing a seg,
    # need to store log(log(n)^4) bits per position; 
    # for n in 2^[32,64], 20-24 bits, or UInt32:
    # 
    # [number of D segs] x [512]
    subsegpos::Matrix{UInt32}
    # subsegpos::Vector{Vector{UInt32}}

    # total number of subsegments at the start of each dense segment
    # .[i] = sum(flatten(subsegpos[1:i]))
    cumsubsegpos::Vector{UInt32}  # same length as subsegpos

    # is a given sub-segment dense (Ds)? 
    # rank of the sub-segment among sub-segments of the same kind? - 
    # use as a query index for Ds
    is_ddense::RankedBitVector

    function MappedBitVectorLayout(bits::BitVector)
        # TODO: implement layout constructor
    end
end


# struct DdCache{T} where T <: Unsigned end
"""
    DdCache{T}

Type to represent positions by rank for all possible Dense-dense sub-segments.

Parameter T indicated the number of bits needed to represent max length of the 
bitvector use with the DdCache object. The type represent a lookup table and 
supports array-like behavior (provided by `size()` and `getindex()`), but with 
the following exceptions: 

- is indexed by bit sequences `bits` (1st idx) and 1-bit ranks `j` (2nd idx);
- "stores" positions of `j`th bit in `bits`, which are computed on-the-fly in 
  constant-boinded time.

The array behavior is inspired by the possibility of actually caching pos values
instead of computing them on demand. 
"""
struct DdCache{T} end
dd64 = DdCache{UInt64}()
dd32 = DdCache{UInt32}()

@inline function Base.size(x::DdCache{T}) where T <: Unsigned
    maxbits = sizeof(T) * 8
    pop = ceil(Int, sqrt(maxbits))
    # width = Int(2 ^ log2(maxbits / 2))
    width = ceil(Int, maxbits / 2)
    return pop, width
end

function Base.show(io::IO, ::MIME"text/plain", x::DdCache{T}) where T
    s = size(x)
    print(io, "$(s[1])-in-$(s[2]) DdCache{$T}")
end


"""
    Base.getindex(::DdCache, bits::Unsigned, j::Integer)

Get position of `j`th 1-bit in bit sequence `bits`.
"""
function Base.getindex(::DdCache, bits::Unsigned, j::Integer)
    # check that j is in the bit vector:
    jmax = count_ones(bits)
    j > jmax && throw(DomainError)

    # relies on sizeof(T) <= sizeof(BitVector chunk) = 64 bits
    bv = falses(64)
    bv.chunks[1] = bits

    pos = 0
    for _ in 1:j
        pos += 1
        pos = findnext(bv, pos)
    end
    
    pos
end

Base.getindex(A::DdCache, bits::Integer, j::Integer) = getindex(A, convert(Unsigned, bits), j)


"""
    MappedBitVector
    
Data Structure to support O(1)-time select() queries on bit vectors. 
"""
struct MappedBitVector <: AbstractMappedBitVector
    bits::BitVector
    layout::MappedBitVectorLayout
    
    # cache tables: 

    # Sparse: stores position of each 1 bit
    # size(elem) = log(n)
    # [log(n) ^ 2] x [count(S)] for 2^32 input
    # [count(S)] x [2 ^ 10]
    Ss::Matrix{UInt32}

    # Dense-sparse: stores pos of each 1-bit (relative to start of D)
    # len(.) = log(n)^4 (at most),
    # hence, each position can take up to:
    # size(.) = log(len(.)) = log(log(n)^4) = 24 bits ==> UInt32.
    # 
    # Each Ds sub-segment has exactly sqrt(log(n)) bits, or 
    # count(.) = sqrt(log(n)) = 8 positions to store
    # Ds: [count(Ds)] x [8]
    Ds::Matrix{UInt32}
    
    # Dense-dense: 
    # stores look up table of jth 1-bit positions 
    # for all possible Dd sub-segments
    #
    # Each Dd sub-seg is
    # len(.) = (1/2) log(n) = 32 bits (at most, but can be as little as 8);
    # size(.) = log(len(.)) = 5 bits => UInt8 (+ 3 extra bits)
    # count(.) = 8 positions to store (exactly)
    # Dd: [binomial(32, 8)] x [8]

    # define this as a singleton type
    # TODO: fix type of Dd cache... do we even need it?
    Dd::DdCache{UInt64}

    function MappedBitVector(bits::BitVector)
        # TODO: implement MappedBitVector constructor
    end
end


"""
    select1(v::AbstractMappedBitVector, j::Integer)

Compute position of 1-bit with rank k in O(1) time.
"""
function select1(v::AbstractMappedBitVector, j::Integer)
    # check: j < rank(v, length(v))
    # cannot be checked in constant time without using a ranked bit vector
    
    return select1_unsafe(v, j)
end

@inline iloc(i::Integer, size::Integer) = (i - 1) % size + 1

function select1_unsafe(v::AbstractMappedBitVector, j::Integer)
    seg_idx = cld(j, 4096)                      # segment index
    seg_start_i = v.layout.segpos[seg_idx]      # segment start pos
    segD_rank = rank(layout.is_dense, seg_idx)  # rank among dense segments
    jj = iloc(i, 4096)                          # j relative to segment start
    
    is_dense = v.layout.is_dense[seg_idx]
    # if sparse chunk, query directly from sparse lookup table
    if !is_dense
        return seg_start_i + v.Ss[seg_idx - segD_rank, jj]
    end

    subseg_idx_rel = cld(jj, 8)
    subseg_start_i = seg_start_i + v.layout.subsegpos[segD_rank, subseg_idx_rel]

    # get subsegment type:
    subseg_idx = v.layout.cumsubsegpos[segD_rank] + subseg_idx_rel
    is_ddense = v.layout.is_ddense[subseg_idx]
    jj = iloc(jj, 8)

    if is_ddense
        # for Dd, look for jj'th 1-bit starting from beginning of subseg;
        # not constant time,
        # but bounded by population(subseg_Dd)
        pos = _pos = subseg_start_i
        for _ in 1:jj  # not constant time but bounded by 8
            pos = findnext(v.bits, _pos)
            _pos += 1
        end
    else 
        # query dirctly in Ds
        subsegDd_rank = rank1(v.layout.is_ddense, subseg_idx)
        which_subseg_sparse = subseg_idx - subsegDd_rank
        pos = v.Ds[which_subseg_sparse, jj]
    end

    return subseg_start_i + pos
end
