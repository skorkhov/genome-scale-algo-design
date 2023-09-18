
# Implement a digraphs with weights

using DataStructures

abstract type AbstractEdge end
abstract type AbstractWDiGraph end

mutable struct WEdge <: AbstractEdge
    src::Int
    dst::Int
    w::Real
end


function empty_adjlist(n) 
    adjlist = Vector{Vector{WEdge}}(undef, n)
    for i in eachindex(adjlist)
        adjlist[i] = Vector{WEdge}[]
    end

    adjlist
end

mutable struct WDiGraph <: AbstractWDiGraph
    nV::Int
    nE::Int
    edges::Vector{WEdge}
    adjlist::Vector{Vector{WEdge}}

    WDiGraph(nV::Int) = new(nV, 0, WEdge[], empty_adjlist(nV))
    WDiGraph(nV::Int, nE::Int) = new(nV, nE, Vector{WEdge}(undef, nE), empty_adjlist(nV))
end


# digraph creation and modification: 

function add_edge!(G::WDiGraph, edge::Tuple{Int, Int, <:Real})
    to_add = WEdge(edge...)
    nE = G.nE
    to_add in G.edges[1:nE] && return nothing
    
    # not in graph yet:
    src = to_add.src
    # update graph obj:
    push!(G.edges, to_add)
    push!(G.adjlist[src], to_add)
    G.nE += 1

    to_add
end

function remove_edge!(G::WDiGraph, edge_idx::Int)
    to_remove = G.edges[edge_idx]  # can error here if e in out of bounds
    src = to_remove.src

    # update graph obj:
    deleteat!(G.edges, edge_idx)
    deleteat!(G.adjlist[src], G.adjlist[edge_idx] .== to_remove)
    G.nE -= 1

    to_remove
end

function remove_edge!(G::WDiGraph, e::WEdge)
    e in G.edges || return nothing
    edge_idx = findfirst(e .== G.edges)
    remove_edge!(G, edge_idx)
end


# Bellman-Ford Algorithm: from source verted s
# init distTo[s] = 0 and distTo[i != s] = Inf
# relax every _edge_ (in any order)
# pass over all edged V times
# return a shortest path tree obj: distTo=Real[], parents=Int[]

function relax_edge!(distTo, edgeTo, G::WDiGraph, edge_idx::Int)
    edge = G.edges[edge_idx]
    
    # if path to source hasn't been build, the edge cannot be relaxed yet: 
    distTo[edge.src] == -999 && return nothing
    
    print("relaxing $edge_idx: $edge\n")
    # if distTo[dst] not defined, edge will be relaxed: 
    distTo_candidate = edge.w + distTo[edge.src]
    if distTo[edge.dst] == -999 || distTo_candidate < distTo[edge.dst]
        distTo[edge.dst] = distTo_candidate
        edgeTo[edge.dst] = edge.src
    end

    return edge
end

function belleman_ford(G::WDiGraph, s::Int)
    # init vars: 
    distTo = fill(-999.0, G.nV)
    distTo[s] = 0
    edgeTo = fill(-999, G.nV)

    for iter in 1:G.nV
        print("Iteration $iter / $(G.nV)\n")
        for edge_idx in 1:G.nE
            relax_edge!(distTo, edgeTo, G, edge_idx)
        end
    end

    return distTo, edgeTo
end

function path_to(vert_idx::Int, distTo, edgeTo)
    cur = vert_idx
    path = Int[]
    i = 0
    while edgeTo[cur] != -999
        @show cur, edgeTo[cur]
        i == 20 && break
        i += 1
        push!(path, cur)
        cur = edgeTo[cur]
    end
    push!(path, cur)

    reverse!(path)
    print(join(path, " -> "), "\n")
    return path, distTo[vert_idx]
end

function graph_as_matrix(G::WDiGraph)
    mtx = fill(0, (G.nV, G.nV))
    for edge in G.edges
        mtx[edge.src, edge.dst] = 1
    end 

    mtx
end



# no negative cycle
# simple graph with two possible paths: 
# top - short path: even nodes except for 9 (source) and 1 (destination)
# bottom - long path: odd nodes

Gs2 = WDiGraph(9)
Gs2_edges = [
    (2, 1, 0.0),
    # edge to destination:
    (4, 2, 0.5), 
    (3, 2, 1.0),
    (6, 4, 0.5),
    (5, 3, 1.0), 
    (8, 6, 0.5), 
    (7, 5, 1.0), 
    (9, 7, 1.0),
    (9, 8, 0.5)
]
for e in Gs2_edges
    add_edge!(Gs2, e)
end
distTo, edgeTo = belleman_ford(Gs2, 9)
path_to(1, distTo, edgeTo)

using GraphRecipes, Plots
g = graph_as_matrix(Gs2)
graphplot(g)

# no negative cycle
# simple graph with two possible paths: 
Gs1 = WDiGraph(9)
Gs1_edges = [
    (2, 1, 0.0),
    # top path - short:
    (4, 2, 0.5), 
    (6, 4, 0.5),
    (8, 6, 0.5), 
    (9, 8, 0.5), 
    # bottom path - long: 
    (3, 2, 1.0),
    (5, 3, 1.0), 
    (7, 5, 1.0), 
    (9, 7, 1.0)
]



# no negative cycle:
G = WDiGraph(8)
G_edges = [
    (5, 6, 35), 
    (6, 5, 35), 
    (5, 8, 37),
    (6, 8, 28), 
    (8, 6, 28), 
    (6, 2, 32), 
    (1, 5, 38), 
    (1, 3, 26),
    (8, 4, 39), 
    (2, 4, 29), 
    (3, 8, 34), 
    (7, 3, -120),
    (4, 7, 52),
    (7, 1, -140), 
    (7, 5, -125)
]
for e in G_edges
    add_edge!(G, e)
end

distTo, edgeTo = belleman_ford(G, 1)
path_to(2, distTo, edgeTo)


# negative cycle: 
Gc = WDiGraph(8)
Gc_edges = [
    (5, 6, 35), 
    (6, 5, -66), 
    (5, 8, 37),
    (6, 8, 28), 
    (8, 6, 28), 
    (6, 2, 32), 
    (1, 5, 38), 
    (1, 3, 26),
    (8, 4, 39), 
    (2, 4, 29), 
    (3, 8, 34), 
    (7, 3, 40),
    (4, 7, 52),
    (7, 1, 58), 
    (7, 5, 93)
]
for e in Gc_edges
    add_edge!(Gc, e)
end
