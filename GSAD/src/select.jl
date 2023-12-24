# data structure for O(1)-time/O(n)-space select() operation on bit vectors

"""
    partition(v <: Vector)

Partitiion vector `v` into into sub-vectors of len n plus tail len(tail) < n.
"""
function partition(v::Vector, n::Integer)
    l = length(v)
    idxs = [LinearIndices(v)[f:min(l, f + n - 1)] for f in 1:n:l]
    return [v[i] for i in idxs]
end


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
end

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

    SelectBitVector(bits, pop, intervals)
end

function select1(v::SelectBitVector, j::Integer)
    if j < 0 || v.population < j
        throw(BoundsError(v, j))
    end

    return select1_unsafe(v, j)
end

function select1_unsafe(v::SelectBitVector, j::Integer)
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

index_in_interval(j) = Tuple(CartesianIndices((1:8, 1:512, 1:4096))[j])

