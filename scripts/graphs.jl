
import DS: WDiGraph, add_edge!, belleman_ford, path_to, graph_as_matrix
using GraphRecipes, Plots

# no negative cycle
# simple graph with two possible paths: 
# top - short path: even nodes except for 9 (source) and 1 (destination)
# bottom - long path: odd nodes

Gs = WDiGraph(9)
Gs_edges = [
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
for e in Gs_edges
    add_edge!(Gs, e)
end
distTo, edgeTo = belleman_ford(Gs, 9)
path_to(1, distTo, edgeTo)

# plot: 
# needs GraphRecipes, Plots
g = graph_as_matrix(Gs)
graphplot(g)



# no negative cycles:
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

# plot: 
g = graph_as_matrix(G)
graphplot(g)

distTo, edgeTo = belleman_ford(G, 1)
path_to(2, distTo, edgeTo)


# one negative cycle reachable from anywhere: 
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

# plot: 
g = graph_as_matrix(Gc)
graphplot(g)
