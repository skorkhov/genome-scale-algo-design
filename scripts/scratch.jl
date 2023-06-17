import DS as ds


# =======
# Binary Trees

# Self as a sentinel for nothing
# https://discourse.julialang.org/t/nullable-fields-current-recommendation/11258/7

root = ds.BSTNodeSelf(1, "a")
ds.push!(root, 2, "b")
ds.push!(root, 3, "c")
ds.push!(root, 4, "d")
ds.push!(root, 2, "B")

ds.get(root, 3)
n = ds.find_node(root, 3)
ds.find_parent(root, root)

pop!(root, 3)

# Node can be Nothing


# DONE: (self-end) non-recursive push!()
# DONE: (self-end) non-recursive pop!()
# DONE: (self-end) recursive pop!() - needs a wrapper to pass parent node around
# DONE: (nothing-end) recursive push!()
# DONE: (nothing-end) non-recursive push!()
# DONE: (nothing-end) recursive pop!() -- does not return popped value
# DONE: (nothing-end) non-recursive pop!()

# recursive approach:
root = ds.BSTNode(1, "a")
ds.pushrec!(root, 2, "b")
ds.pushrec!(root, 3, "c")
ds.pushrec!(root, 4, "d")
ds.pushrec!(root, 2, "B")

# non-recursive approach:
root = ds.BSTNode(1, "a")
ds.push!(root, 2, "b")
ds.push!(root, 3, "c")
ds.push!(root, 4, "d")
ds.push!(root, 2, "B")
ds.push!(root, -1, "A")
ds.push!(root, -2, "B")
ds.push!(root, -3, "C")

ds.get(root, -3)
ds.get(root, -2)
ds.poprec_min!(root)
ds.get(root, -3)
ds.get(root, -2)
ds.poprec_min!(root)
ds.get(root, -3)
ds.get(root, -2)

ds.get(root, -1)
ds.poprec!(root, -1)

ds.get(root, -1)
ds.pop!(root, -1)
ds.push!(root, -1, "A")

# Note: limitation of not storing nodes in a tree
# nodes are "dropped" by removing any connections to them;
# to drop root, reference to root needs to be dropped, 
# but that reference lived in the workspace, not in the object
# and hence cannot be dropped.
# To delete root, need a separate tree types that would store 
# the reference to first node.


# =======
# Red-Black Trees

import DS as ds

tree = ds.RBTreeNode(1, "a")
ds.pushr!(tree, 2, "b")
ds.pushr!(tree, 3, "c")
ds.pushr!(tree, 4, "d")
ds.pushr!(tree, 2, "B")
ds.pushr!(tree, -1, "A")
ds.pushr!(tree, -2, "B")
ds.pushr!(tree, -3, "C")

ds.getnode(tree, 1)
ds.get(tree, 1)
ds.get(tree, -99)


tree = ds.RBTreeNode(1, "a")
tree.right = ds.RBTreeNode(2, "b")
tree.left = ds.RBTreeNode(-1, "A")

tree_left = ds.rotate_left!(deepcopy(tree))
tree_right = ds.rotate_right!(deepcopy(tree))

ds.pushr!(tree, 3, "c")
ds.pushr!(tree, 4, "d")
ds.pushr!(tree, -2, "B")
ds.pushr!(tree, -3, "C")

tree = ds.RBTreeNode(1, "a")
ds.pushr!(tree, 3, "c")
ds.pushr!(tree, 4, "d")
ds.pushr!(tree, -2, "B")
ds.pushr!(tree, -3, "C")


# check color preservation for rotate_left!()
tree = ds.RBTreeNode(1, "a")
tree.right = ds.RBTreeNode(2, "b")
tree.right.color = true

nd = ds.rotate_left!(deepcopy(tree))
nd.color
nd.left.color


# check color preservation for rotate_left!()
tree = ds.RBTreeNode(1, "a")
tree.left = ds.RBTreeNode(2, "b")
tree.left.color = true

nd = ds.rotate_right!(deepcopy(tree))
nd.color  # false
nd.right.color  # true

# random input:
# append random pairs
using StatsBase
using Random
Random.seed!(1)
letters = Dict(i => ('A':'Z')[i] for i in sample(1:26, 26, replace = false))

# ordered input:
tree = ds.RBTreeNode(0, '_')
for (key, val) in Dict(i => ('a':'z')[i] for i in 1:3)
    tree = ds.pushr!(tree, key, val)
end
tree.color = false
nd = deepcopy(tree)

# random input:
tree = ds.RBTreeNode(0, '_')
for (key, val) in letters
    tree = ds.pushr!(tree, key, val)
end
tree.color = false


ds.valid_rbtree_node(tree)
ds.valid_rbtree(tree)
ds.compute_black_height(tree)

# create object copies: 
nd = deepcopy(tree)
node_bottom = deepcopy(nd.left.left)

# check removal of nodes: 
ds.get(nd, 0)
ds.get(nd, 1)
nd = ds.popmin!(nd)
ds.valid_rbtree(nd)
ds.compute_black_height(nd)
ds.get(nd, 0)
ds.get(nd, 1)
nd = ds.popmin!(nd)
ds.valid_rbtree(nd)
ds.compute_black_height(nd)
ds.get(nd, 0)
ds.get(nd, 1)
ds.get(nd, 2)
nd = ds.popmin!(nd)
ds.get(nd, 0)
ds.get(nd, 1)
ds.get(nd, 2)
nd = ds.popmin!(nd)
