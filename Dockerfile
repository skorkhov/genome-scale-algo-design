FROM julia:1.8.5
LABEL Maintainer="skorkhov"

# use revise: 
RUN julia -e 'using Pkg; Pkg.add.(["Revise", "PkgTemplates"])'
RUN mkdir -p ~/.julia/config/ && echo "using Revise" >> ~/.julia/config/startup.jl
RUN julia -e 'using Pkg; Pkg.add.(["Debugger"])'

# install Julia libs
RUN julia -e 'using Pkg; Pkg.add.("Random")'
RUN julia -e 'using Pkg; Pkg.add.("StatsBase")'
RUN julia -e 'using Pkg; Pkg.add.("DataStructures")'
RUN julia -e 'using Pkg; Pkg.add.("Graphs")'
RUN julia -e 'using Pkg; Pkg.add.("SimpleWeightedGraphs")'

# plotting graphs: 
RUN julia -e 'using Pkg; Pkg.add.("Plots")'
RUN julia -e 'using Pkg; Pkg.add.("GraphRecipes")'

# RUN julia -e 'using Pkg; Pkg.add.("Bio")'

# push local package paths: 
RUN echo 'push!(LOAD_PATH, pwd() * "/BookGSAD")' >> ~/.julia/config/startup.jl 
RUN echo 'push!(LOAD_PATH, pwd() * "/DS")' >> ~/.julia/config/startup.jl
