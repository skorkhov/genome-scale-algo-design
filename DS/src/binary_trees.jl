import Base: push!, get

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

is_leaf(current::BSTNodeSelf, next) = next === current

function find_node(node::BSTNodeSelf, key)
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
function pop_recursive(node::BSTNodeSelf, key)
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
