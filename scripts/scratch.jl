import BookGSAD as bk
import DS as ds


# =======
# Binary Trees

root = ds.BSTNodeSelf(1, "a")
ds.push!(root, 2, "b")
ds.push!(root, 3, "c")
ds.push!(root, 4, "d")
ds.push!(root, 2, "B")

ds.get(root, 3)
n = ds.find_node(root, 3)
ds.find_parent(root, root)

pop!(root, 3)
