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

# TODO: implement type stability for select(::MappedBitVector)
# TODO: support rank on MappedBitVector; rename BitVectorRSA
# TODO: document BitVectorRSA

"""
    MappedBitVector
    
Data Structure to support O(1)-time select() queries on bit vectors. 
"""
struct MappedBitVector <: AbstractMappedBitVector
    bits::BitVector
    population::UInt64

    # layout:
    segpos::Vector{UInt64}
    is_dense::RankedBitVector
    subsegpos::Vector{UInt32}
    is_ddense::RankedBitVector
    
    # cache tables:
    Ss::Matrix{UInt32}  # SEG_POPULATION x [nsegsparse]
    Ds::Matrix{UInt32}  # SUBSEG_POPULATION x [nsubsegsparse]

    function MappedBitVector(bits::T) where T <: AbstractVector{Bool}
        pos = findall(bits)
        pop = length(pos)
        
        # Segment data
        # layout: 
        nseg = cld(pop, SEG_POPULATION)
        segpos = Vector{UInt64}(undef, nseg)
        is_dense = falses(nseg)
        # cache:
        Ss = Matrix{UInt32}(undef, (SEG_POPULATION, nseg))

        segrank = 0
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
                @views Ss[1:(to - from + 1), iseg - segrank] = pos[from:to] .- pos[from]
            else
                # dense segment:
                is_dense[iseg] = true
                segrank += 1
            end
        end
    
        # Sub-segment data
        # layout:
        nsubseg = segrank * N_SUBSEG_PER_SEG
        subsegpos = Vector{UInt32}(undef, nsubseg)
        is_ddense = falses(nsubseg)
        # cache:
        Ds = Matrix{UInt32}(undef, (SUBSEG_POPULATION, nsubseg))
    
        segrank = 0
        subsegrank = 0
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
                        @views Ds[1:SUBSEG_POPULATION, isubseg - subsegrank] = pos[from:to] .- pos[from]
                    else 
                        # D-dense sub-segment:
                        is_ddense[isubseg] = true
                        subsegrank += 1
                    end
                end
            end
        end

        new(
            bits, pop,
            segpos, is_dense, subsegpos, is_ddense, 
            Ss[:, 1:(nseg - segrank)], 
            Ds[:, 1:(nsubseg - subsegrank)]
        )
    end

end

Base.sum(v::MappedBitVector) = v.population

function select_unsafe(v::AbstractMappedBitVector, j::Integer)
    # Bit in Sparse segment: 
    iseg, jj = index_in_interval(j, SEG_POPULATION)
    isegsparse = iseg - rank(v.is_dense, iseg)
    segstart = v.segpos[iseg]
    if !v.is_dense[iseg]
        offset = v.Ss[jj, isegsparse]
        return segstart + offset
    end
    
    # bit in Dense-sparse sub-segment:
    relsubseg, jj = index_in_interval(jj, SUBSEG_POPULATION)
    isubseg = isegsparse * N_SUBSEG_PER_SEG + relsubseg
    subsegoffset = v.subsegpos[isubseg]
    if !v.is_ddense[isubseg]
        isubseg = (isegsparse - 1) * N_SUBSEG_PER_SEG + isubseg
        isubsegsparse = isubseg - rank(v.is_ddense, isubseg)
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

