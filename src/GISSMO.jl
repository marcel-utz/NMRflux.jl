"""
module **GISSMO**

Interface routines with GISSMO database.

Hesam Dashti, Jonathan R. Wedell, William M. Westler, Marco Tonelli, David Aceti, Gaya K. Amarasinghe, John L. Markley, and Hamid R. Eghbalnia, Applications of Parametrized NMR Spin Systems of Small Molecules, *Anal. Chem.*, 2018, **90** (18), pp 10646–10649, DOI: 10.1021/acs.analchem.8b02660
Hesam Dashti, William M. Westler, Marco Tonelli, Jonathan R. Wedell, John L. Markley, and Hamid R. Eghbalnia, Spin System Modeling of Nuclear Magnetic Resonance Spectra for Applications in Metabolomics and Small Molecule Screening, *Analytical Chemistry*, 2017, **89** (22), pp 12201–12208, doi: 10.1021/acs.analchem.7b02884
""" 
module GISSMO

using HTTP
using LightXML
import JSON
import LinearAlgebra
using  NMRlab.SpinSim


export Hamiltonian, search


"""
    function Hamiltonian(fn::String;freq=600.0,ctr=4.8)
    function Hamiltonian(system::XMLElement;freq=600.0,ctr=4.8)
    function Hamiltonian(SpM::AbstractMatrix{T};freq=600.0,ctr=4.8) where {T<:Number}

computes the Hamiltonian of an entry in the GISSMO database and returns it in the natural basis as a sparse matrix.
`fn` is the GISSMO reference name of the compound. Keyword parameters are used to indicate spectrometer
base frequency (in MHz) and the spectral zero point (carrier position) in ppm. 
`maxSpin` represents the maximum size of the spin system that will be simulated.
If the spin system size exceeds `maxSpin`, the function returns `(-1,nothing)`.
"""
function Hamiltonian(id::String;freq=600.0,ctr=4.8)
    xs=String(HTTP.request("GET","https://gissmo.bmrb.io/entry/$(id)/simulation_1/spin_simulation.xml").body)
    xdoc=parse_string(xs)
    nspin,H = Hamiltonian(root(xdoc);freq=freq,ctr=ctr)
end

function Hamiltonian(system::XMLElement;freq=600.0,ctr=4.8,maxSpin=25)
    compound = system["name"][1]
    xspin = system["coupling_matrix"][1]
    chem_shifts = Array{Float64,1}([])
    xcs = xspin["chemical_shifts_ppm"][1]["cs"]
    chem_shifts = [parse(Float64,attribute(c,"ppm")) for c in xcs]
    nspin=length(chem_shifts)
    
    if nspin>maxSpin
        return (-1,nothing)
    end
    
    H=sum(j->2pi*freq*(chem_shifts[j]-ctr)*SpinOp(nspin,Sz,j),1:nspin)
    
    xJs=xspin["couplings_Hz"][1]["coupling"]
    for c in xJs
        k=parse(Int64,attribute(c,"from_index"))
        l=parse(Int64,attribute(c,"to_index"))
        J=parse(Float64,attribute(c,"value"))
        
        H.+=2pi*J*OpJstrong(nspin,k,l)
    end
    nspin,H
end

function Hamiltonian(SpM::AbstractMatrix{T};freq=600.0,ctr=4.8) where {T<:Number}
    n,m=size(SpM)
    if n!=m
        error("Spin matrix must be square.")
    end
    chem_shifts = LinearAlgebra.diag(SpM)
    H=sum(j->2pi*freq*(chem_shifts[j]-ctr)*SpinOp(n,Sz,j),1:n)
    for k in 1:(n-1)
        for l in (k+1):n
            J=SpM[k,l]
            H.+=2pi*J*OpJstrong(n,k,l)
        end
    end
    n,H
end

@doc """
    function SpinMatrix(id::String)

returns the spin matrix, with chemical shifts (on the diagonal) and J-couplings (on the off-diagonal elements)
for the GISSMO entry specified by the identifier `id`.
"""
function SpinMatrix(id::String)
    xs=String(HTTP.request("GET","https://gissmo.bmrb.io/entry/$(id)/simulation_1/spin_simulation.xml").body)
    xdoc=parse_string(xs)
    system=root(xdoc)
    xspin = system["coupling_matrix"][1]
    chem_shifts = Array{Float64,1}([])
    xcs = xspin["chemical_shifts_ppm"][1]["cs"]
    chem_shifts = [parse(Float64,attribute(c,"ppm")) for c in xcs]
    nspin=length(chem_shifts)

    S = zeros(nspin,nspin)
    for k in 1:nspin
        S[k,k]=chem_shifts[k]
    end    
    
    xJs=xspin["couplings_Hz"][1]["coupling"]
    for c in xJs
        k=parse(Int64,attribute(c,"from_index"))
        l=parse(Int64,attribute(c,"to_index"))
        J=parse(Float64,attribute(c,"value"))
        
        S[k,l] = J
        S[l,k] = J

    end 
    return S
end

"""
    function search(term::String)

searches the online GISSMO database for `term` and returns a `JSON` object
with the search result.
"""
function search(term::String)
    res=String(HTTP.request("GET","https://gissmo.bmrb.io/search?term=$(term)").body)
    return JSON.parse(res)
end

@doc"""
    function block_diagonal_reorder(SpM::AbstractMatrix{T};threshold=1e-6) where {T<:Number}

Reorders the spin matrix `SpM` to block diagonal form by finding connected
components of the graph defined by the nonzero entries of `SpM`.  Returns the
reordered matrix and the block structure as a vector of vectors of indices. The
`threshold` parameter is used to determine which entries are considered nonzero.
"""
function block_diagonal_reorder(SpM::AbstractMatrix{T};threshold=1e-6) where {T<:Number}
    A_bool = abs.(SpM) .> threshold
    blocks = connected_components(A_bool)
    perm = vcat(blocks...)
    return SpM[perm, perm], blocks
end

@doc"""
    function connected_components(A_bool)

Finds the connected components of a graph represented by a boolean adjacency matrix `A_bool`.
"""
function connected_components(A_bool::AbstractMatrix{Bool})
    n = size(A_bool, 1)
    visited = falses(n)
    components = Vector{Vector{Int}}()
    for start in 1:n
        if !visited[start]
            # BFS
            comp = Int[]
            queue = [start]
            visited[start] = true
            while !isempty(queue)
                node = popfirst!(queue)
                push!(comp, node)
                for neighbor in 1:n
                    if A_bool[node, neighbor] && !visited[neighbor]
                        visited[neighbor] = true
                        push!(queue, neighbor)
                    end
                end
            end
            push!(components, comp)
        end
    end
    return components
end


function fiedler_split(indices, A; tol=1e-10)
    n = length(indices)
    if n <= 1
        return [indices]
    end
    
    A_sub = abs.(A[indices, indices])
    A_sub = A_sub - Diagonal(A_sub)  # absolute values, zero diagonal
    
    D = Diagonal(vec(sum(A_sub, dims=2)))
    L = D - A_sub
    
    vals, vecs = eigen(Symmetric(L))
    
    if n < 2 || vals[2] > tol
        return [indices]
    end
    
    fiedler = vecs[:, 2]
    group1 = indices[fiedler .< 0]
    group2 = indices[fiedler .>= 0]
    
    if isempty(group1) || isempty(group2)
        return [indices]
    end
    
    return [fiedler_split(group1, A; tol=tol);
            fiedler_split(group2, A; tol=tol)]
end


end