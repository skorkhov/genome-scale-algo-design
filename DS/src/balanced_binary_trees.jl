
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


# true of valid, else false
function valid_rbtree_node(node::RBTreeNode{T}) where T
    (node === nothing || node.left === nothing || node.right === nothing) && return true
    isred(node.right) && return false
    isred(node) && isred(node.left) && return false

    true
end

function valid_rbtree(node::RBTreeNode{T}) where T
    isred(node) && flip!(node)
    queue = Union{Nothing, RBTreeNode{T}}[node]
    while length(queue) != 0
        # check current node
        node = pop!(queue)
        if node !== nothing
            push!(queue, node.right, node.left)
            !valid_rbtree_node(node) && return false
        end
    end

    true
end

function compute_black_height(node::RBTreeNode{T}) where T
    parents = Dict{T, T}()
    black_count = Dict{T, Int}()
    terminal_node = Dict{T, Bool}()

    # traverse the tree:
    queue = Union{Nothing, RBTreeNode{T}}[node]
    while length(queue) != 0
        node = pop!(queue)
        if node === nothing continue end 
        push!(queue, node.right, node.left)

        # add to terminal node: 
        if node.left === nothing || node.right === nothing 
            terminal_node[node.key] = true
        else 
            terminal_node[node.key] = false
        end

        # increment counter: 
        node_parent = get(parents, node.key, -99)
        black_count[node.key] = get(black_count, node_parent, 0) + !isred(node)
        
        # add child => parent to parent: 
        if node.left !== nothing parents[node.left.key] = node.key end
        if node.right !== nothing parents[node.right.key] = node.key end
    end

    terminal = [k for (k, v) in terminal_node if v]
    [key => black_count[key] for key in terminal]
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



# delete nodes by key

function find_min(node::RBTreeNode)
    while node.left !== nothing
        node = node.left
    end

    node
end

# descend down the left node making sure the current node is never a 3 node
function popmin!(node::RBTreeNode{T}) where T
    node.left === nothing && return nothing

    # if node == "red" -- at left end of 3 or 4-node:
    #   if should_balance == TRUE
    #       3-node sibling: transfer from sibling to make 3-node
    #       2-node sibling: drop from current to make 4-node
    #   if should_balance == FALSE -- next leftmost node is a 3-node
    #       advance            
    # if node == "black":
    #   if should_balance == TRUE -- can only happen at the root
        #   same procedures
    #   if should_balance == FALSE
    #       advance

    # on the way down the tree: 
    # by this point, left node exests, 
    # so isred() is defined for node.left and node.left.left
    if !isred(node.left) && !isred(node.left.left)
        # either at root, or at left end of 3- or 4-node
        # and next node 
        if node.right === nothing throw(ErrorException("invalid node: $(node.key)")) end
        # TODO: check if nothing condition is needed
        if node.right === nothing || !isred(node.right.left) 
            fliplinks!(node)
        else
            node.right = rotate_right!(node.right)
            node = rotate_left!(node)
            flip!(node.right)
            flip!(node.left.left)
        end
    end

    node.left = popmin!(node.left)

    # ordering matters: 
    isred(node.left) && isred(node.right) && fliplinks!(node)
    isred(node.right) && (node = rotate_left!(node))

    return node
end

function increase_node_order!(node::RBTreeNode)
    # either at root, or at left end of 3- or 4-node 
    # TODO: check if nothing condition is needed
    if node.right === nothing || !isred(node.right.left) 
        fliplinks!(node)
    else
        node.right = rotate_right!(node.right)
        node = rotate_left!(node)
        flip!(node.right)
        flip!(node.left.left)
    end

    node
end

function balance!(node::RBTreeNode)
    # balance up
    # ordering matters: 
    isred(node.left) && isred(node.right) && fliplinks!(node)
    isred(node.right) && (node = rotate_left!(node))

    node
end

function pop!(node::RBTreeNode{T}, key::T) where T
    get(node, key) === nothing && return node
    node === nothing && return nothing

    # balance-down
    if !isred(node.left) && !isred(node.left.left)
        # either at root, or at left end of 3- or 4-node 
        # TODO: check if nothing condition is needed
        if node.right === nothing || !isred(node.right.left) 
            fliplinks!(node)
        else
            node.right = rotate_right!(node.right)
            node = rotate_left!(node)
            flip!(node.right)
            flip!(node.left.left)
        end
    end

    # recurse
    if key < node.key 
        node.left = pop!(node.left, key)
    elseif key > node.key
        node.right = pop!(node.right, key)
    else
        # rearrange
        rightmin = deepcopy(find_min(node.right))
        rightmin.color = node.color
        rightmin.left = node.left
        rightmin.right = popmin!(node.right)
        node = rightmin
    end

    # balance up
    # ordering matters: 
    isred(node.left) && isred(node.right) && fliplinks!(node)
    isred(node.right) && (node = rotate_left!(node))

    return node
end
