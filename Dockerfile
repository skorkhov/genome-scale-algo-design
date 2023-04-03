FROM julia:1.8.5
LABEL Maintainer="skorkhov"

# use revise: 
RUN julia -e 'using Pkg; Pkg.add.(["Revise", "PkgTemplates"])'
RUN mkdir -p ~/.julia/config/ && echo "using Revise" >> ~/.julia/config/startup.jl

# install Julia libs
RUN julia -e 'using Pkg; Pkg.add.(["Random", "StatsBase"])'
RUN julia -e 'using Pkg; Pkg.add.(["Debugger"])'

# push local package paths: 
RUN echo 'push!(LOAD_PATH, pwd() * "/BookGSAD")' >> ~/.julia/config/startup.jl
