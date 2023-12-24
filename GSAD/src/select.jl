# data structure for O(1)-time/O(n)-space select() operation on bit vectors

"""
    select(v::AbstractMappedBitVector, j::Integer)

Compute position of `j`-th 1-bit in `v`.
"""
function select(v::AbstractMappedBitVector, j::Integer)
    if j < 0 || sum(v) < j
        throw(BoundsError(v, j))
    end

    return select_unsafe(v, j)
end

index_in_interval(j) = Tuple(CartesianIndices((1:8, 1:512, 1:4096))[j])


#= SelectBitVector =#

# Implementation inspired by the idea of storing interval offsets and position 
# caches in ragged arrays (wrapped in resp types for Sparse, Dense-sparce, and 
# Dense-dense intervals).

struct SubSegmentDense
    offset::UInt32
end

struct SubSegmentSparse
    offset::UInt32
    cache::Vector{UInt32}
end

Base.getindex(A::SubSegmentSparse, jj) = A.cache[jj]

SubSegment = Union{SubSegmentDense, SubSegmentSparse}

struct SegmentDense
    start::UInt64
    subsegments::Vector{SubSegment}
end

Base.getindex(A::SegmentDense, isubseg) = A.subsegments[isubseg]

struct SegmentSparse
    start::UInt64
    cache::Vector{UInt64}
end

Base.getindex(A::SegmentSparse, jj) = A.cache[jj]
Base.getindex(A::SegmentSparse, isubseg, jj) = Base.getindex(A, (isubseg - 1) * 8 + jj)

Segment = Union{SegmentSparse, SegmentDense}

struct SelectBitVector <: AbstractMappedBitVector
    bits::BitVector
    population::UInt64
    # offset caches:
    intervals::Vector{Segment}

    function SelectBitVector(bits::T) where T <: AbstractVector{Bool}
        pop = sum(bits)
        intervals = Vector{Segment}(undef, cld(pop, 4096))
    
        pos = findall(bits) 
        segs = partition(pos, 4096)
        for iseg in eachindex(segs)
            seg = segs[iseg]
            segstart = seg[begin]
            if seg[end] - segstart >= 64^4
                intervals[iseg] = SegmentSparse(segstart, seg)
            else
                subsegments = Vector{SubSegment}(undef, 512)
                subsegs = partition(seg, 8)
                for isubseg in eachindex(subsegs)
                    subseg = subsegs[isubseg]
                    subsegstart = subseg[begin]
                    subsegend = subseg[end]
                    offset = subsegstart - segstart
                    if subsegend - subsegstart >= 32
                        subsegments[isubseg] = SubSegmentSparse(offset, subseg)
                    else
                        # Dd
                        subsegments[isubseg] = SubSegmentDense(offset)
                    end
                end
    
                intervals[iseg] = SegmentDense(segstart, subsegments)
    
            end
        end
    
        new(bits, pop, intervals)
    end
end

Base.sum(v::SelectBitVector) = v.population

function select_unsafe(v::SelectBitVector, j::Integer)
    jj, isubseg, iseg = index_in_interval(j)
    segment = v.intervals[iseg]
    # if j in Sparse segment, access directly in cache: 
    if typeof(segment) isa SegmentSparse
        return segment.start + segment[isubseg, jj]
    end

    subsegment = segment[isubseg]
    # if j in Dense-sparse sub-segment, access directly in cache: 
    if typeof(subsegment) isa SubSegmentSparse
        return segment.start + subsegment.offset + subsegment[jj]
    end

    # if j in Dense-dense sub-segment,
    # run a short loop to access it's position: 
    pos = segment.start + subsegment.offset - 1
    for _ in 1:jj
        pos = findnext(v.bits, pos + 1)
    end
    return pos
end

"""
    partition(v <: Vector)

Partitiion vector `v` into into vectors of len `n` plus tail `len(tail) < n`.
"""
function partition(v::Vector, n::Integer)
    l = length(v)
    idxs = [LinearIndices(v)[f:min(l, f + n - 1)] for f in 1:n:l]
    return [v[i] for i in idxs]
end


#= MappedBitVector =#

"""
    MappedBitVectorLayout

Type to store segment layout for MappedBitVector supporting O(1)-time select().
"""
struct MappedBitVectorLayout
    pop::UInt64
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
    subsegpos::Vector{UInt32}

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
    maxrank = rank(bits, n)           # max number of set bits
    maxnseg = cld(maxrank, 64^2)
    maxnsubseg = 512  # div(64 ^ 2, 8) = log(2^64) ^ 2 / sqrt(log(2^64))
    
    # lengths separating dense and sparse: 
    threshold_seg = 64 ^ 4          # log(n)^4
    threshold_subseg = Int(64 / 2)  # log(n) / 2
    # 1-bit populations:
    pop_seg = 64 ^ 2                # log(n)^2
    pop_subseg = 8                  # sqrt(log(2^64))

    # keep track of num of sub/segs travered by loops:
    nseg = 0
    nsegD = 0
    nsubseg = 0

    # initialize empty containers: 
    segpos = Vector{UInt64}(undef, maxnseg)
    is_dense = falses(maxnseg)
    subsegpos = Vector{UInt32}(undef, maxnsubseg * maxnseg)
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
            nsegD += 1
        end

        # Idea: advance in increments of 64 if >= 64 bits remain to fill the seg
    end

    # second pass - specify subsegments:
    # for all Dense _segments_
    local subseg_start_i
    segD_idx = 0
    for _ in 1:nsegD
        segD_idx = findnext(is_dense, segD_idx + 1)
        segD_start_i = segpos[segD_idx]  # start of enclosing segment

        # for each subsegmet in a D segment:
        jj = 1
        i = segD_start_i - 1
        while (i !== nothing) && (jj <= 4096)
            i = findnext(bits, i + 1)  # position of j'th bit in subseg

            # if j is a subsegment start: 
            if jj % pop_subseg == 1
                nsubseg += 1
                subseg_start_i = i
                subsegpos[nsubseg] = i - segD_start_i
            end

            # If j is the end of Dd subsegment, set is_ddense; 
            # if an end of a subseg is never reached, 
            # the subseg will remain Ds (by is_ddense indialization).
            if (jj % pop_subseg == 0) && (i - subseg_start_i < threshold_subseg)
                is_ddense[nsubseg] = true
            end

            jj += 1
        end
    end

    # keep only the used capacity of layout arrayy:
    segpos = segpos[1:nseg]
    is_dense = is_dense[1:nseg]
    subsegpos = subsegpos[1:nsubseg]
    is_ddense = is_ddense[1:nsubseg]

    MappedBitVectorLayout(maxrank, segpos, is_dense, subsegpos, is_ddense)
end


"""
    InIntervalID

Container type describing a position (of a particular bit) relative to a 
`MappedBitVector` interval, where an interval can be Sparse (Ss), Dense-sparse 
(Ds), or Dense-dense (Dd)

See also [`MappedID`](@ref)

# Fields
-   i: interval index among intervals of the same generality
-   r: interval rank among intervals of the same type
-   j: rank of position relative to statrt of its enclising interval
-   start: start position of interval in bitvector
-   is_dense: is interval dense?
"""
struct InIntervalID
    i::UInt
    r::UInt
    j::UInt
    start::UInt  # parameterize
    is_dense::Bool
end

InIntervalID() = InIntervalID(0, 0, 0, 0, false)

"""
    MappedID

Container type describing a position relative to a layout in [an instance of] 
a `MappedBitVector` object.

# Fields
-   segment: bit position relative to the segment it is in;
-   subsegment: bit position relative to the sub-segment it is in;

The sub-segment ID `subsegment` will be initialized only if `segment.is_dense` 
is `false`, i.e. if the position is in a Dense segment. Otherwise, if the 
position is in a Sparse segment, the position description is complete without 
any sub-segment information.
"""
struct MappedID
    segment::InIntervalID
    subsegment::InIntervalID
end

function MappedID(layout::MappedBitVectorLayout, j::Integer)
    # is jth 1-bit in a Dense segment? 
    i = cld(j, 4096)
    r = rank(layout.is_dense, i)
    jj = iloc(j, 4096)
    start = layout.segpos[i]
    is_dense = layout.is_dense[i]
    
    segment = InIntervalID(i, r, jj, start, is_dense)
    if !is_dense
        return MappedID(segment, InIntervalID())
    end

    # segment is Dense:
    i = (r - 1) * div(4096, 8) + cld(jj, 8)
    r = rank(layout.is_ddense, i)
    jj = iloc(jj, 8)
    start = layout.subsegpos[i]
    is_ddense = layout.is_ddense[i]

    subsegment = InIntervalID(i, r, jj, start, is_ddense)
    return MappedID(segment, subsegment)
end

"Return start position of MappedID"
function start_of(id::MappedID)
    start = id.segment.start
    !id.segment.is_dense && return start
    
    return start + id.subsegment.start
end

"""
    iterate(layout::MappedBitVectorLayout [, id::MappedID])

Return coordinates, as a MappedID, of the next interval's start position.
"""
function iterate(layout::MappedBitVectorLayout, id::MappedID)
    pop = layout.pop
    j = (id.segment.i - 1) * 4096 + id.segment.j
    if !id.segment.is_dense
        # if in Sparse (Ss) segment:
        jj = cld(j, 4096) * 4096 + 1
    else
        # if in Dense (Ds or Dd) sunsegment: 
        jj = cld(j, 8) * 8 + 1
    end
    
    return jj > pop ? nothing : MappedID(layout, jj)
end

iterate(layout::MappedBitVectorLayout, id::Integer) = iterate(layout, MappedID(layout, id))
iterate(layout::MappedBitVectorLayout) = layout.pop == 0 ? nothing : MappedID(layout, 1)

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
    # 
    # In practice, Dd "cache" values are computed on the fly in a loop that's at
    # most 8 iterations long. Hence, no slot needed for Dd cache.
    # Dd::DdCache{UInt64}

    function MappedBitVector(bits::T) where T <: AbstractVector{Bool}
        layout = MappedBitVectorLayout(bits)
        Ss, Ds = initialize_caches(layout)
        layout.pop == 0 && return new(bits, layout, Ss, Ds)
        n = length(bits)

        current = iterate(layout)
        while current !== nothing
            next = iterate(layout, current)
            from = start_of(current)
            to = next === nothing ? n : start_of(next) - 1
            
            # store withing-(sub)segment positions;
            # note: cache-1 adjust from index to offset 
            # relative to the start of enclosing interval
            if !current.segment.is_dense
                # Ss segment
                r = current.segment.i - current.segment.r
                cache = findall(view(bits, from:to)) .- 1
                Ss[1:length(cache), r] .= cache
            else
                if !current.subsegment.is_dense
                    # Ds segment
                    r = current.subsegment.i - current.subsegment.r
                    cache = findall(view(bits, from:to)) .- 1
                    Ds[1:length(cache), r] .= cache
                end
            end

            current = next
        end
        
        new(bits, layout, Ss, Ds)
    end
end

Base.sum(v::MappedBitVector) = v.layout.pop

function initialize_caches(layout)
    # num of Ss segments: 
    nseg = length(layout.is_dense)
    nsegD = sum(layout.is_dense)
    # number of Ds subsegments
    nsubseg = length(layout.is_ddense)
    nsubsegDd = sum(layout.is_ddense)

    Ss = Matrix{UInt32}(undef, (4096, nseg - nsegD))
    Ds = Matrix{UInt32}(undef, (8, nsubseg - nsubsegDd))
    
    return Ss, Ds
end

function select_unsafe(v::AbstractMappedBitVector, j::Integer)
    id = MappedID(v.layout, j)
    start = id.segment.start

    # j in Ss segment:
    if !id.segment.is_dense
        r = id.segment.i - id.segment.r
        return start + v.Ss[id.segment.j, r]
    end

    start += id.subsegment.start
    
    # j in Ds sub-segment
    if !id.subsegment.is_dense
        r = id.subsegment.i - id.subsegment.r
        return start + v.Ds[id.subsegment.j, r]
    end
    
    # j in Dd sub-segment:
    pos = start - 1
    for _ in 1:id.subsegment.j
        pos = findnext(v.bits, pos + 1)
    end

    return pos
end

