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
Base.convert(::Type{T}, x::BitVector) where T <: AbstractRankedBitVector = RankedBitVector(x)

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


"Type to describe patially known container size/element."
struct ContainerLayout{N, T}
    dims::NTuple{N, Int}
    isknown::Vector{Bool}

    # TODO: implement initializer - could be needed for dynamically sized DS
    # TODO: fix operations on ContainerLayout
end

@inline bitwidth(x::ContainerLayout{N, T}) where {N, T} = sizeof(T) * 8
@inline size(x::ContainerLayout) = x.dims

init(x::ContainerLayout{N, T}) where {N, T} = Assay{T, N}(undef, size(x))

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

    # total number of subsegments at the start of each dense segment
    # equals rank(is_dense, seg_idx) * subsegments per segment
    # len(.) = [number of D segs] = same as nrow(subsegpos)
    # cumsubsegpos::Vector{UInt32}

    # is a given sub-segment dense (Ds)? 
    # rank of the sub-segment among sub-segments of the same kind? - 
    # use as a query index for Ds
    is_ddense::RankedBitVector
end

"Return new index of `i`th element in a vector split into `size`-long chunks."
@inline iloc(i::Integer, size::Integer) = (i - 1) % size + 1

function MappedBitVectorLayout(bits::T) where T <: AbstractVector{Bool}
    n = length(bits)
    # TODO: don't use rank on bits - don't need it
    maxrank = rank1(bits, n)           # max number of set bits
    maxnseg = cld(maxrank, 64^2)
    maxnsubseg = 512  # div(64 ^ 2, 8) = log(2^64) ^ 2 / sqrt(log(2^64))
    
    # lengths separating dense and sparse: 
    threshold_seg = 64 ^ 4          # log(n)^4
    threshold_subseg = Int(64 / 2)  # log(n) / 2
    # 1-bit populations:
    pop_seg = 64 ^ 2                # log(n)^2
    pop_subseg = 8                  # sqrt(log(2^64))

    # counters:
    nseg = 0
    nsubseg = 0

    # initialize empty containers: 
    segpos = Vector{UInt64}(undef, maxnseg)
    is_dense = falses(maxnseg)
    subsegpos = Matrix{UInt32}(undef, (maxnsubseg, maxnseg))
    is_ddense = falses(maxnsubseg)
    is_ddense = falses(maxnseg * maxnsubseg)
    
    # first pass - init segment boundaries:
    i = 0
    local seg_start_i
    for j in 1:maxrank
        # advance to next 1-bit
        i = findnext(bits, i + 1)  # position of j'th 1-bit

        # if j is a segment start:
        if j % pop_seg == 1
            nseg += 1
            seg_start_i = i
            segpos[nseg] = i
        end

        # If j is the end of D segment, set is_dense;
        # if a segment starts but the end is never reached, 
        # the segment remains indicated as Sparse (by is_dense initialization).
        if (j % pop_seg == 0) && (i - seg_start_i + 1 < threshold_seg)
            is_dense[nseg] = true
        end

        # Idea: advance in increments of 64 if >= 64 bits remain to fill the seg
    end

    # second pass - specify subsegments:
    # for all Dense _segments_
    local subseg_start_i
    nsegD = rank1(is_dense, nseg)  # TODO: should be replaced with a counter in previous pass
    segD_idx = 0
    for segD_rank in 1:nsegD
        segD_idx = findnext(is_dense, segD_idx + 1)
        segD_start_i = segpos[segD_idx]

        # for each subsegmet in a D segment:
        jj = 1
        i = segD_start_i - 1
        while (i !== nothing) && (jj <= 4096)
            i = findnext(bits, i + 1)  # position of j'th bit in subseg

            # if j is a subsegment start: 
            if jj % pop_subseg == 1
                nsubseg += 1
                subseg_start_i = i
                subsegpos[iloc(nsubseg, maxnsubseg), segD_rank] = i
            end

            # If j is the end of Dd subsegment, set is_ddense; 
            # if an end of a subseg is never reached, 
            # the subseg will remain Ds (by is_ddense indialization).
            if (jj % pop_subseg == 0) && (1 - subseg_start_i + 1 < threshold_subseg)
                is_ddense[nsubseg] = true
            end

            jj += 1
        end
    end

    # keep only the used capacity of layout arrayy:
    segpos = segpos[1:nseg]
    is_dense = is_dense[1:nseg]
    subsegpos = subsegpos[1:min(nsubseg, maxnsubseg), 1:nsegD]
    is_ddense = is_ddense[1:nsubseg]

    MappedBitVectorLayout(segpos, is_dense, subsegpos, is_ddense)
end



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
    # [count(S)] x [32^2 = 2 ^ 10] for 2^32-length input
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
    # Dd::DdCache{UInt64}

    function MappedBitVector(bits::T) where T <: AbstractVector{Bool}
        layout = MappedBitVectorLayout(bits)
        Ss = Matrix{UInt32}(undef, ())
        Ds = Matrix{UInt32}(undef, ())

        new(bits, layout, Ss, Ds)
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

function select1_unsafe(v::AbstractMappedBitVector, j::Integer)
    seg_idx = cld(j, 4096)                         # segment index
    seg_start_i = v.layout.segpos[seg_idx]         # segment start pos
    segD_rank = rank1(v.layout.is_dense, seg_idx)  # rank among dense segments
    jj = iloc(i, 4096)                             # j relative to segment start
    
    is_dense = v.layout.is_dense[seg_idx]
    # if sparse chunk, query directly from sparse lookup table
    if !is_dense
        return seg_start_i + v.Ss[seg_idx - segD_rank, jj]
    end

    subseg_idx_rel = cld(jj, 8)
    subseg_start_i = seg_start_i + v.layout.subsegpos[segD_rank, subseg_idx_rel]
    jj = iloc(jj, 8)  # j relative to subsegment start
    
    # get subsegment type:
    subseg_idx::Int = segD_rank * div(4096, 8) + subseg_idx_rel
    is_ddense = v.layout.is_ddense[subseg_idx]

    if is_ddense
        # for Dd, look for jj'th 1-bit starting from beginning of subseg;
        # not constant time,
        # but bounded by pop(subseg_Dd)
        pos = subseg_start_i - 1
        for _ in 1:jj  # not constant time but bounded by 8
            pos = findnext(v.bits, pos + 1)
        end
    else 
        # query dirctly in Ds
        subsegDd_rank = rank1(v.layout.is_ddense, subseg_idx)
        which_subseg_sparse = subseg_idx - subsegDd_rank
        pos = v.Ds[which_subseg_sparse, jj]
    end

    return subseg_start_i + pos
end

"""
    locate_in_segment(layout::MappedBitVectorLayout, j::Integer)::Tuple{Bool, Bool, Int, Int, Int}

Locate `j`th 1-bit in the `layout`; return a 5-tuple with location coordinates:
-   `is_dense::Bool`: is in Dense segment? 
-   `is_ddense::Bool`: is in Dense-dense subsegment? 
-   `i_start::UInt`: start position of the sub-segment `j`th 1-bit is in
-   `rank::UInt`: rank of the sub-segments `j`th bit is in among subsegments of
    the same kind
-   `jj::UInt`: position of the `j` bit relative to start of subsegment
"""
function locate_in_segment(layout::MappedBitVectorLayout, j::Integer)::Tuple{Bool, Bool, Int, Int, Int}
    # is jth 1-bit in a Dense segment? 
    seg_idx = cld(j, 4096)
    is_dense = layout.is_dense[seg_idx]
    
    # rank among segments of the same type: 
    segD_rank = rank1(layout.is_dense, seg_idx)
    seg_rank = is_dense ? segD_rank : seg_idx - segD_rank
    
    i_start = layout.segpos[seg_idx]  # segment start pos
    jj = iloc(j, 4096)                # j relative to segment start
    
    # if segment is Sparse
    if ~ is_dense
        return is_dense, false, i_start, seg_rank, jj
    end
    
    # segment is Dense:

    # is jth 1-bit in a Dd segment?
    # (segD_rank - 1) = num of D segments priot to this one, each with 512 subsegs
    subseg_idx = (segD_rank - 1) * div(4096, 8) + cld(jj, 8)
    is_ddense = layout.is_ddense[subseg_idx]

    i_start = layout.subsegpos[subseg_idx]
    subsegDd_rank = rank1(layout.is_ddense, subseg_idx)
    seg_rank = is_ddense ? subsegDd_rank : subseg_idx - subsegDd_rank
    jj = iloc(jj, 8)

    # TODO: use the result in select1() to infer offsets and query the cache
    # return: tuple (is_dense::Bool, is_ddense::Bool, start_i::Int, seg_rank::Int, jj::Int)
    return is_dense, is_ddense, i_start, seg_rank, jj
end
