
mutable struct RBTreeNode{T} <: AbstractNode
    color::Bool  # true=red
    left::Union{RBTreeNode{T}, Nothing}
    right::Union{RBTreeNode{T}, Nothing}
    key::T
    value

    RBTreeNode{T}(key, value) where T = new(false, nothing, nothing, key, value)
    RBTreeNode{T}(color, left, right, key, value) where T = new(color, left, right, key, value)
end

RBTreeNode(key::T, value) where T = RBTreeNode{T}(key, value)



# tree struct, allows to pop the root from the tree
mutable struct RBTree{T} <: AbstractTree
    root::Union{RBTreeNode{T}, Nothing}
end

# TODO: recursive pop!()
# DONE: get()
# DONE: recursive push!()

function getnode(node::RBTreeNode{T}, key::T) where T
    while node !== nothing && key != node.key
        node = key < node.key ? node.left : node.right
    end
    
    node
end

get(node::RBTreeNode{T}, key::T) where T = (node = getnode(node, key)) === nothing ? nothing : node.value

isred(node::Union{RBTreeNode, Nothing}) = node === nothing ? false : node.color
flip!(node::Union{RBTreeNode, Nothing}) = node !== nothing ? node.color = !node.color : nothing

function fliplinks!(node::RBTreeNode)
    flip!(node)
    flip!(node.left)
    flip!(node.right)
    node
end

function rotate_left!(node::RBTreeNode) 
    node.right === nothing && return node
    
    out = node.right
    node.right = node.right.left
    out.left = node

    # swap colors between out and node:
    out.color, out.left.color = out.left.color, out.color
    return out
end

function rotate_right!(node::RBTreeNode)
    node.left === nothing && return node

    out = node.left 
    node.left = node.left.right
    out.right = node

    # swao colors between out and node:
    out.color, out.right.color = out.right.color, out.color

    return out
end

function pushr!(node::Union{RBTreeNode{T}, Nothing}, key::T, value) where T
    if node === nothing
        out = RBTreeNode{T}(key, value)
        out.color = true
        return out
    end

    if key < node.key 
        node.left = pushr!(node.left, key, value)
    elseif key > node.key
        node.right = pushr!(node.right, key, value)
    else 
        node.value = value
        return node
    end

    # ordering matters: 
    # 
    # to pass link up the tree, the "passing" transform - color flip - 
    # should be last;
    !isred(node.left) && isred(node.right) && (node = rotate_left!(node))
    isred(node.left) && isred(node.left.left) && (node = rotate_right!(node))
    isred(node.left) && isred(node.right) && fliplinks!(node)

    node
end
