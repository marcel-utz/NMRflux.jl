using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))   # activate the package's main Project.toml,
                                         # which has all of NMRflux's deps + Documenter
using Documenter, NMRflux

makedocs(sitename="NMRflux.jl")