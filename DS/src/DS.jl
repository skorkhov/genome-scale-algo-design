module DS

# Shared Types
abstract type AbstractNode end
abstract type AbstractTree end

include("binary_heap.jl")
include("binary_trees.jl")
include("balanced_binary_trees.jl")
include("graphs.jl")

end # module DS
