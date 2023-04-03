
import Base: push!, pop!, length, size, isempty, sizehint!

mutable struct BinaryHeap{T}
    heap::Vector{T}

    BinaryHeap{T}(vec::Vector{T}) where T = new(heapify(vec))
end

BinaryHeap(vec::Vector{T}) where T = BinaryHeap{T}(vec)

# priority API using binary heap: 

# not specifying element type T: 
# Base.push! already knows how to handle type differences
# the rest should be handled by swim!() 
# (which errors for types not comparable with isless())
function Base.push!(h::BinaryHeap, value)
    push!(h.heap, value)
    swim!(h.heap, length(h.heap))
end

function Base.pop!(h::BinaryHeap)
    x = first(h.heap)
    
    # set first to last, drop last, and sink:
    h.heap[1] = h.heap[end]
    h.heap = h.heap[1:end-1]
    sink!(h.heap, 1)
    
    return x
end

Base.length(h::BinaryHeap) = Base.length(h.heap)
Base.size(h::BinaryHeap) = Base.size(h.heap)
Base.isempty(h::BinaryHeap) = Base.isempty(h.heap)
Base.first(h::BinaryHeap) = Base.first(h.heap)

# can improve performance 
function Base.sizehint!(h::BinaryHeap, n::Integer)
    Base.sizehint!(h.heap, n)
    return h
end

# functions to operate on array underlying the heap

function heapify!(vec::Vector)
    for i in parentidx(length(vec)):-1:1
        sink!(vec, i)
    end

    return vec
end

heapify(vec::Vector) = heapify!(copyto!(similar(vec), vec))

leftidx(i::Integer) = 2i
rightidx(i::Integer) = 2i + 1
parentidx(i::Integer) = div(i, 2)

function sink!(vec::Vector, idx::Int)
    len = length(vec)
    x = vec[idx]
    
    l = leftidx(idx)
    while l <= len
        r = rightidx(idx)
        i = r > len || isless(vec[r], vec[l]) ? l : r
        isless(x, vec[i]) || break
        # if current < (bigger child @ i)
        # assign biggen child to current
        vec[idx] = vec[i]
        idx = i
        l = leftidx(idx)
    end
    vec[idx] = x
end


function swim!(vec::Vector, idx::Int)
    x = vec[idx]

    p = parentidx(idx)
    while (p >= 1)
        isless(vec[p], x) || break
        # if parent < idx: assign parent to current
        vec[idx] = vec[p]
        # set current index to parent
        idx = p 
        # compute new parent to continue loop iteration
        p = parentidx(idx)
    end
    vec[idx] = x
end
