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
