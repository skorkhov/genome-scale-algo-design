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

"Return new index of `i`th element in a vector split into `size`-long chunks."
@inline iloc(i::Integer, size::Integer) = (i - 1) % size + 1

@inline function index_in_interval(i, size)
    interval = cld(i, size)
    i_rel = (i - 1) % size + 1
    return interval, i_rel
end

function index_in_layout(j)
    iseg, jj = index_in_interval(j, SEG_POPULATION)
    isubseg, jj = index_in_interval(jj, SUBSEG_POPULATION)
    return iseg, isubseg, jj
end

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
    iseg, isubseg, jj = index_in_layout(j)
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


#= LayoutIntRank =#

struct SegmentIntRank
    start::UInt32
    rank::UInt32
    dense::Bool
end

struct SubsegmentIntRank
    offset::UInt32
    rank::UInt32
    dense::Bool
end

struct LayoutIntRank
    segments::Vector{SegmentIntRank}
    subsegments::Vector{SubsegmentIntRank}
end

function LayoutIntRank(bits::T) where T <: AbstractVector{Bool}
    pos = findall(bits)
    pop = length(pos)

    nseg = cld(pop, SEG_POPULATION)
    segments = Vector{SegmentIntRank}(undef, nseg)
    segrank = 0
    for iseg in 1:nseg
        from = (iseg - 1) * SEG_POPULATION + 1
        to = min(from + SEG_POPULATION - 1, pop)
        if (to - from < SEG_POPULATION - 1) || 
            (pos[to] - pos[from] >= SEG_DENSE_MAXWIDTH - 1)
            # sparse segment:
            segments[iseg] = SegmentIntRank(pos[from], segrank, false)
        else
            # dense segment:
            segrank += 1
            segments[iseg] = SegmentIntRank(pos[from], segrank, true)
        end
    end

    nsubseg = segrank * N_SUBSEG_PER_SEG
    subsegments = Vector{SubsegmentIntRank}(undef, nsubseg)
    subsegrank = 0
    for iseg in 1:nseg
        if segments[iseg].dense
            segstart = segments[iseg].start
            n_in_prev_sparse_seg = (iseg - segments[iseg].rank) * SEG_POPULATION
            
            # subseg indexes to assign:
            from_subseg = (segments[iseg].rank - 1) * N_SUBSEG_PER_SEG + 1
            to_subseg = min(from_subseg + N_SUBSEG_PER_SEG - 1, nsubseg)
            for isubseg in from_subseg:to_subseg
                # select position array indexes to consider: 
                from = n_in_prev_sparse_seg + (isubseg - 1) * SUBSEG_POPULATION + 1
                to = min(from + SUBSEG_POPULATION - 1, pop)
                offset = pos[from] - segstart
                if pos[to] - pos[from] >= SUBSEG_DENSE_MAXWIDTH - 1
                    # D-sparse sub-segment:
                    subsegments[isubseg] = SubsegmentIntRank(offset, subsegrank, false)
                else 
                    # D-dense sub-segment:
                    subsegrank += 1
                    subsegments[isubseg] = SubsegmentIntRank(offset, subsegrank, true)
                end
            end
        end
    end

    LayoutIntRank(segments, subsegments)
end


#= MappedBitVector =#

# TODO: MappedBitVectorLayout --> Layout
# TODO: construct MappedBitVector in one step, without Layout
# TODO: in tests, remove namespace references in non-exported methods

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
    # Vector: [number of D segs] x [512]
    subsegpos::Vector{UInt32}

    # is a given sub-segment dense (Ds)? 
    # rank of the sub-segment among sub-segments of the same kind? - 
    # use as a query index for Ds
    is_ddense::RankedBitVector
end

function MappedBitVectorLayout(pos::Vector{T}) where T <: Integer
    pop = length(pos)
    nseg = cld(pop, SEG_POPULATION)

    # segment layout:
    segpos = Vector{UInt64}(undef, nseg)
    is_dense = falses(nseg)

    for iseg in 1:nseg
        from = (iseg - 1) * SEG_POPULATION + 1
        to = min(from + SEG_POPULATION - 1, pop)
        segpos[iseg] = pos[from]

        # segment is Sparse when either:
        # - it has fewer 1-bits than SEG_POPULATION; or
        # - it is longer than/equal to the SEG_DENSE_MAXWIDTH threshold
        is_shorter_than_cutoff = pos[to] - pos[from] + 1 >= SEG_DENSE_MAXWIDTH
        if is_shorter_than_cutoff || (to - from + 1 < SEG_POPULATION)
            # sparse segment:
            is_dense[iseg] = false
        else
            # dense segment:
            is_dense[iseg] = true
        end
    end

    # subsegment layout:
    nsubseg = sum(is_dense) * N_SUBSEG_PER_SEG
    subsegpos = Vector{UInt32}(undef, nsubseg)
    is_ddense = falses(nsubseg)

    segrank = 0
    for iseg in 1:nseg
        if is_dense[iseg]
            segrank += 1
            segstart = segpos[iseg]
            
            n_from_sparse = (iseg - segrank) * SEG_POPULATION
            
            # subseg indexes to consider for the given (dense) segment: 
            from_subseg = (segrank - 1) * N_SUBSEG_PER_SEG + 1
            to_subseg = segrank * N_SUBSEG_PER_SEG

            for isubseg in from_subseg:to_subseg
                # consider the following position array indexes:
                from = n_from_sparse + (isubseg - 1) * SUBSEG_POPULATION + 1
                to = from + SUBSEG_POPULATION - 1
                subsegpos[isubseg] = pos[from] - segstart
                if pos[to] - pos[from] + 1 >= SUBSEG_DENSE_MAXWIDTH
                    # D-sparse sub-segment:
                    is_ddense[isubseg] = false
                else 
                    # D-dense sub-segment:
                    is_ddense[isubseg] = true
                end
            end
        end
    end

    MappedBitVectorLayout(segpos, is_dense, subsegpos, is_ddense)
end

function MappedBitVectorLayout(bits::T) where T <: AbstractVector{Bool}
    MappedBitVectorLayout(findall(bits))
end

nseg(layout::MappedBitVectorLayout) = length(layout.segpos)
nsegdense(layout::MappedBitVectorLayout) = sum(layout.is_dense)
nsegsparse(layout::MappedBitVectorLayout) = length(layout.is_dense) - sum(layout.is_dense)

nsubseg(layout::MappedBitVectorLayout) = length(layout.subsegpos)
nsubsegdense(layout::MappedBitVectorLayout) = sum(layout.is_ddense)
nsubsegsparse(layout::MappedBitVectorLayout) = length(layout.is_ddense) - sum(layout.is_ddense)

"""
    MappedBitVector
    
Data Structure to support O(1)-time select() queries on bit vectors. 
"""
struct MappedBitVector <: AbstractMappedBitVector
    bits::BitVector
    population::UInt64
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
        pos = findall(bits)
        layout = MappedBitVectorLayout(pos)
        pop = length(pos)
        Ss = Matrix{UInt32}(undef, (SEG_POPULATION, nsegsparse(layout)))
        Ds = Matrix{UInt32}(undef, (SUBSEG_POPULATION, nsubsegsparse(layout)))

        pop == 0 && return new(bits, layout, Ss, Ds)

        for iseg in 1:nseg(layout)
            segrank = rank(layout.is_dense, iseg)
            nsegsparse = iseg - segrank
            segstart = layout.segpos[iseg]
            if layout.is_dense[iseg]
                # Dense segment - store Dense-sparse cache:
                n_from_sparse = nsegsparse * SEG_POPULATION
                from_subseg = (segrank - 1) * N_SUBSEG_PER_SEG + 1
                to_subseg = segrank * N_SUBSEG_PER_SEG

                for isubseg in from_subseg:to_subseg
                    if !layout.is_ddense[isubseg]
                        nsubsegsparse = isubseg - rank(layout.is_ddense, isubseg)
                        subsegstart = layout.subsegpos[isubseg]
                        from = n_from_sparse + (isubseg - 1) * SUBSEG_POPULATION + 1
                        to = from + SUBSEG_POPULATION - 1
                        @views Ds[1:SUBSEG_POPULATION, nsubsegsparse] = pos[from:to] .- (segstart + subsegstart)
                    end
                end
            else
                # Sparse segment - store Sparse cache
                from = (iseg - 1) * SEG_POPULATION + 1
                to = min(from + SEG_POPULATION - 1, pop)
                @views Ss[1:(to - from + 1), nsegsparse] = pos[from:to] .- segstart
            end
        end

        new(bits, pop, layout, Ss, Ds)
    end

end

Base.sum(v::MappedBitVector) = v.population

function select_unsafe(v::AbstractMappedBitVector, j::Integer)
    # Bit in Sparse segment: 
    iseg, jj = index_in_interval(j, SEG_POPULATION)
    isegsparse = iseg - rank(v.layout.is_dense, iseg)
    segstart = v.layout.segpos[iseg]
    if !v.layout.is_dense[iseg]
        offset = v.Ss[jj, isegsparse]
        return segstart + offset
    end
    
    # bit in Dense-sparse sub-segment:
    relsubseg, jj = index_in_interval(jj, SUBSEG_POPULATION)
    isubseg = isegsparse * N_SUBSEG_PER_SEG + relsubseg
    subsegoffset = v.layout.subsegpos[isubseg]
    if !v.layout.is_ddense[isubseg]
        isubseg = (isegsparse - 1) * N_SUBSEG_PER_SEG + isubseg
        isubsegsparse = isubseg - rank(v.layout.is_ddense, isubseg)
        offset = v.Ds[jj, isubsegsparse]
        return segstart + subsegoffset + offset
    end

    # bit in Dense-dense subsegment: 
    pos = segstart + subsegoffset - 1
    for _ in 1:jj
        pos = findnext(v.bits, pos + 1)
    end
    return pos
end

