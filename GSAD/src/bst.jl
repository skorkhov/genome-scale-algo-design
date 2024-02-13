# Binary Search Trees

"""
    VectorRMQ{N, V}

Vector of N elements of type V supporting O(log(n))-time and RMQ queries.
"""
mutable struct VectorRMQ{N, V}
    tree::Vector{Tuple{V, Int}}
    ntree::Int
    ntail::Int

    function VectorRMQ(::Type{V}, n::Integer) where V
        ntree = 2n - 1
        ntail = 2n - (1 << (sizeof(ntree) * 8 - leading_zeros(ntree) - 1))
        tree = Vector{Tuple{V, Int}}(undef, ntree)

        return new{n, V}(tree, ntree, ntail)
    end
end

function VectorRMQ(v::Vector{V}) where V
    n = length(v)
    A = VectorRMQ(V, n)
    
    # create new reordered array
    vr = similar(A.tree, n)
    vr[1:end - A.ntail] .= zip(last(v, n - A.ntail), A.ntail + 1:n)
    vr[end - A.ntail + 1:end] .= zip(first(v, A.ntail), 1:A.ntail)
    
    # assign to tree:
    A.tree[n:end] .= vr
    
    # construct by traversing up through non-leafs
    for i in n-1:-1:1
        A.tree[i] = min(A.tree[2i], A.tree[2i+1])
    end

    return A
end

function leaf(A::VectorRMQ{N}, i::Integer) where N
    i = i + A.ntree - A.ntail
    return i > A.ntree ? i - N : i
end

function Base.getindex(A::VectorRMQ{N}, i) where N
    1 <= i <= N || throw(BoundsError(A, i))
    return A.tree[leaf(A, i)][1]
end

function Base.setindex!(A::VectorRMQ{N, V}, v::V, i) where {N, V}
    ileaf = leaf(A, i)
    A.tree[ileaf] = (v, i)
    while ileaf > 1
        ileaf = ileaf >> 1
        A.tree[ileaf] = min(A.tree[2ileaf], A.tree[2ileaf + 1])
    end
end

Base.firstindex(A::VectorRMQ{N}) where N = N
Base.lastindex(A::VectorRMQ{N}) where N = 2N - 1
size(A::VectorRMQ{N}) where N = N isa Integer ? N : throw(MethodError(size, A))

"""
    rmq(A::VectorRMQ{N}, i::Integer, j::Integer) where N

Compute index of the smallest value in sub-array A[i:j]
"""
function rmq(A::VectorRMQ{N}, i::Integer, j::Integer) where N
    l = leaf(A, i)
    r = leaf(A, j)
    m = min(A.tree[l], A.tree[r])

    # compare initial depths of l and r; 
    # it will either be the same or l (nor r!) will be deeper by one
    # because the start of the array is at the deepest level;
    # if the latter, advance l one level up: 
    if leading_zeros(l) != leading_zeros(r)
        # if r is a right child, min with left sibling:
        if l % 2 == 0
            m = min(m, A.tree[l + 1])
        end
        l = l >> 1
    end

    # proceed until l and r are sibling children of their lca
    # without including the lca itself;
    # happens when l is even and r == l + 1: 
    while xor(l, r) != 1
        if l % 2 == 0
            # min with right sibling
            m = min(m, A.tree[l + 1])
        end
        if r % 2 == 1
            # min with left sibling
            m = min(m, A.tree[r - 1])
        end
        l = l >> 1
        r = r >> 1
    end

    return m
end

rmqv(A::VectorRMQ{N}, i::Integer, j::Integer) where N = rmq(A, i, j)[1]
rmqi(A::VectorRMQ{N}, i::Integer, j::Integer) where N = rmq(A, i, j)[2]

"""
    TreeRMQ

Data structure supporting O(log(n)) RMQs on key-value pairs of comparable items.
"""
mutable struct TreeRMQ{N, K, V}
    tree::VectorRMQ{N, Tuple{K, V}}
end

function index_right_of(A::TreeRMQ{N, K}, i::K) where {N, K}

end

function index_left_of(A::TreeRMQ{N, K}, i::K) where {N, K}
    
end

function rmq(A::TreeRMQ{N, K}, i::K, j::K) where {N, K}
    l = index_left_of(A, i)
    r = index_right_of(A, j)

    return rmq(A.tree, l, r)
end

"""
    StaticTreeRMQ

Segment tree for O(log(n)) Range Min Queries.
"""
struct StaticTreeRMQ{N <: Integer, K, V}
    tree::Vector{K}    # implicit tree of keys
    values::Vector{V}  # vector ov values corresponding to keys in tree
end

function StaticTreeRMQ(keys::K, vals::V) where {K, V}
    N = length(keys)
    
    tree = Vector{K}(undef, 2 * N - 1)
    tree[N:end] = keys
    values = Vector{V}(undef, 2 * N - 1)
    values[N:end] = vals

    StaticTreeRMQ{N, K, V}(tree, values) 
end
