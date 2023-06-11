import Base: push!, get, pop!

abstract type AbstractNode end

# =======
# BST Node using Self as a sentinel for nothing

mutable struct BSTNodeSelf{T} <: AbstractNode
    left::BSTNodeSelf{T}
    right::BSTNodeSelf{T}
    key::T 
    value

    # an empty node references itself and has undefined key and value
    function BSTNodeSelf{T}(key, value) where T
        node = new()
        node.key = key
        node.value = value
        
        # point to itself: 
        node.left = node
        node.right = node

        node
    end

    BSTNodeSelf{T}(left, right, key, val) where T = new(left, right, key, val)
end

BSTNodeSelf(key::T, value) where T = BSTNodeSelf{T}(key, value)

is_leaf(current::BSTNodeSelf, next::BSTNodeSelf) = next === current

function find_node(node::AbstractNode, key)
    while node.key != key
        next = key < node.key ? node.left : node.right
        if is_leaf(node, next) return node end
        node = next 
    end

    node
end

function get(node::BSTNodeSelf, key)
    node = find_node(node, key)
    node.key == key ? node.value : nothing
end

function push!(root::BSTNodeSelf{T}, key::T, value) where T
    node = find_node(root, key)
    if key == node.key
        node.value = value
        return root
    end
    
    leaf = BSTNodeSelf(key, value)

    if key < node.key 
        node.left = leaf 
    else 
        node.right = leaf
    end

    root
end

"""
function pop_recursive!(node::BSTNodeSelf, key)
    if key < node.key
        if is_leaf(node, node.left) 
            return node.right
        else 
            node.left = pop_recursive(node.left, key)
        end
    elseif key > node.key
        if is_leaf(node, node.right) 
            return node.left
        else 
            node.right = pop_recursive(node.right, key)
        end
    else
        # found node to delete: key == node.key
        # need to be able to link node.parent to a new node, 
        # which needs parent access;
        # not possible without access to parent
        # hence the naive recursive approach wont work. 
        # Need a function with a different signature that will keep track of 
        # the parent as well
        
    end
end
"""

function find_parent(root, node) 
    key = node.key
    node_exists = find_node(root, key) === node
    node_exists || throw(ErrorException("node does not exist in tree at root"))
    # parent of root is nothing: 
    key == root.key && return nothing
    
    curr = root
    next = key < curr.key ? curr.left : curr.right
    while next !== node
        curr = next
        next = key < curr.key ? curr.left : curr.right
    end

    curr
end

function find_min(root::BSTNodeSelf)
    while !is_leaf(root, root.left)
        root = root.left
    end

    root
end

function popmin!(root::BSTNodeSelf)
    toremove = find_min(root)
    toreset = find_parent(root, toremove)

    toreset.left = is_leaf(toremove, toremove.right) ? toreset : toremove.right
    
    root
end

# Returns value associated with the key and removes it from the tree
function pop!(node::BSTNodeSelf, key) 
    toremove = find_node(node, key)
    toremove.key == key || return nothing

    toreset = find_parent(node, toremove)
    which = toreset.left === toremove ? :left : :right
    if is_leaf(toremove, toremove.left) & is_leaf(toremove, toremove.right)
        setfield!(toreset, which, toreset)
    elseif is_leaf(toremove, toremove.right)
        setfield!(toreset, which, toremove.left)
    elseif is_leaf(toremove, toremove.left)
        setfield!(toreset, which, toremove.right)
    else
        # set link from parent to min in the right subtree:
        rightmin = find_min(toremove.right)
        rightmin.right = popmin!(toremove.right)
        rightmin.left = toremove.left
        setfield!(toreset, which, rightmin)
    end

    toremove.value
end



# =======
# BST Node with nothing links

mutable struct BSTNode{T} <: AbstractNode
    left::Union{Nothing, BSTNode{T}}
    right::Union{Nothing, BSTNode{T}}
    key::T 
    value

    BSTNode{T}(key, value) where T = new{T}(nothing, nothing, key, value)
    BSTNode{T}(left, right, key, val) where T = new{T}(left, right, key, val)
end

BSTNode(key::T, value) where T = BSTNode{T}(key, value)

is_leaf(current::BSTNode, next) = next === nothing

function get(node::BSTNode, key)
    candidate = find_node(node, key)
    candidate.key === key ? candidate.value : nothing
end

function find_min(node::BSTNode) 
    while node.left !== nothing
        node = node.left
    end 
    node
end

# recursive push
function pushrec!(node::Union{BSTNode{T}, Nothing}, key::T, value) where T
    node === nothing && return BSTNode(key, value)
    if key < node.key 
        node.left = pushrec!(node.left, key, value)
    elseif key > node.key
        node.right = pushrec!(node.right, key, value)
    else 
        node.value = value
    end

    node
end

# non-recursive push
# uses find_node() generic
function push!(node::BSTNode{T}, key::T, value) where T
    current = find_node(node, key)
    if key == current.key
        current.value = value
        return node
    end

    new = BSTNode(key, value)
    key < current.key ? current.left = new : current.right = new

    node
end

# return the whole subtree with popped minimum node: 
function popmin!(node::BSTNode) 
    parent = node
    current = node.left
    current === nothing && throw(ErrorException("mis is root; cannot remove root"))

    # while current !== nothing && current.left !== nothing
    while current.left !== nothing
        parent = current
        current = current.left
    end
    parent.left = current.right
    
    current
end

# non-recursive pop
function pop!(node::BSTNode{T}, key::T) where T
    node.key == key && throw(ErrorException("cannot pop root"))
    parent = next = node
    # look for node that needs to be removed
    while next !== nothing && next.key != key
        parent = next
        next = key < next.key ? next.left : next.right
    end
    next === nothing && return nothing

    # found node to delete: next.key == key
    which_remove_in_parent = parent.left === next ? :left : :right
    if next.right === nothing 
        setfield!(parent, which_remove_in_parent, next.left)
    elseif next.left === nothing
        setfield!(parent, which_remove_in_parent, next.right)
    else 
        # TODO: fix popmin! to return whole subtree:
        rightmin = popmin!(next.right)
        rightmin.right = next.right
        rightmin.left = next.left
        setfield!(parent, which_remove_in_parent, rightmin)
    end

    next.value
end


# recursive pop
# needs a separate function to return the popped node, 
# and a high-lvl function to unwrap the value associated with the node

function poprec_min!(node::BSTNode) 
    # node.left === nothing && return node.right 
    if node.left === nothing
        @show node.value  # printing is the only option to see val in recursion
        return node.right
    end
    node.left = poprec_min!(node.left)

    # why is this necessary?
    # because otherwise returns Nothing, 
    # and all left nodes are set to nothing all the way up the tree:
    return node
end

function poprec!(node::BSTNode{T}, key::T) where T
    node === nothing && return nothing
    
    @show node.value
    if key < node.key 
        node.left = poprec!(node.left, key) 
    elseif key > node.key
        node.right = poprec!(node.right, key)
    else 
        # key == node.key
        # return a new subtree in place of the node: 
        
        # if only one child, simply return it: 
        node.right === nothing && return node.left
        node.left === nothing && return node.right
        
        # if noth children exist
        # construct a new node: 
        rightmin = find_min(node.right)
        @show rightmin.value, rightmin
        rightmin.right = poprec_min!(node.right)
        rightmin.left = node.left
        node = rightmin
    end

    return node
end 