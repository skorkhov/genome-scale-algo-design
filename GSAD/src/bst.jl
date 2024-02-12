# Binary Search Trees

"""
    VectorRMQ{N, V}

Vector of N elements of type V supporting O(log(n))-time and RMQ queries.
"""
mutable struct VectorRMQ{N, V}
    tree::Vector{V}

    function VectorRMQ(::Type{V}, n::Integer) where V
        tree = Vector{V}(undef, 2n - 1)
        return new{n, V}(tree)
    end
end

function VectorRMQ(v::Vector{V}) where V
    n = length(v)
    A = VectorRMQ(V, n)
    
    # shift vector elements to ensure complete tree; 
    # get number of elements in the (incomplete) bottom-most layer: 
    overflow = 2n - leaf(n, 1)
    
    # create new reordered array
    vr = Vector{V}(undef, n)
    vr[1:end - overflow] = last(v, n - overflow)
    vr[end - overflow + 1:end] = first(v, overflow)
    A.tree[n:end] .= vr
    
    # construct by traversing up through non-leafs
    for i in n-1:-1:1
        A.tree[i] = min(A.tree[2i], A.tree[2i+1])
    end

    return A
end

function leaf(n::Integer, i::Integer)
    nt = 2n - 1
    offset = 1 << (sizeof(nt) * 8 - leading_zeros(nt) - 1) - 1
    i = i + offset
    return i > nt ? i - n : i
end

function Base.getindex(A::VectorRMQ{N}, i) where N
    1 <= i <= N || throw(BoundsError(A, i))
    return A.tree[leaf(N, i)]
end

function Base.setindex!(A::VectorRMQ{N, V}, v::V, i) where {N, V}
    i = leaf(N, i)
    A.tree[i] = v
    while i > 1
        i = i >> 1
        A.tree[i] = min(A.tree[2i], A.tree[2i + 1])
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
    l = leaf(N, i)
    r = leaf(N, j)
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
