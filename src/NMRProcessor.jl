
@doc raw"""
    abstract type NMRProcessor <: Function end

Abstract data type for NMR processing routines. 
New processing tools should be declared as subtypes of
`NMRProcessor`.
"""
abstract type NMRProcessor <: Function end

@doc raw"""
    (m::NMRProcessor)(A::AbstractArray)

here is some fallback behaviour. NMR processors are defined
for SpectData objects. However, they can also be applied to
any AbstractArray, by promoting it to a SpectData, and then
extracting the data part.
"""
(m::NMRProcessor)(A::AbstractArray) = m(SpectData(A)).dat


@doc raw"""
    Chain(fs::Vararg{NMRProcessor}) 

returns a chain of processing tools, which will be
applied in order (the first in the argument list is 
applied first)
"""
Chain(fs::Vararg{Function}) = reduce(∘, reverse(fs))


import FFTW

struct FourierTransform <: NMRProcessor
    dims::Vector{Integer}
    SI::Vector{Integer}
    fftshift::Bool
    plan
end

@doc raw"""
    function FourierTransform(SI::Vector,dims::Vector; fftshift=true)

Fourier transform processor for data sets of size `SI`. `dims` is a Vector
of the dimensions along which a Fourier transform will be computed.
The corresponding coordinates are automatically replaced by frequencies,
based on the Nyqvist theorem. The zero frequency appears in the centre of the
spectrum. 

The function produces a FFTW plan for the Fourier transform, which is stored ^in
the returned `FourierTransform` object. This makes it more efficient to apply
the Fourier transform to multiple data sets of the same size. If the size of the
data set changes, a new `FourierTransform` object should be created.

"""
function FourierTransform(SI::Vector,dims::Vector; fftshift=true)
    dummy=zeros(ComplexF64,SI...)
    plan=FFTW.plan_fft(dummy,dims)
    return( FourierTransform(dims,SI,fftshift,plan))
end

function (ft::FourierTransform)(S::SpectData)
    ftdat = ft.plan*S.dat
    newcoord=[]
    for (k,d) in enumerate(S.coord)
        if k in ft.dims && d isa AbstractRange
            Δf = 1.0/step(d)
            push!(newcoord, range(-Δf/2,Δf/2,length=length(d)))
        else
            push!(newcoord,d)
        end
    end
    if ft.fftshift
        ftdat=FFTW.fftshift(ftdat,ft.dims)
    end
    return SpectData(ftdat,(newcoord...,))
end


struct ZeroFill <: NMRProcessor
    SI::Vector{Union{Integer,Colon}}
end

function (zf::ZeroFill)(A::SpectData{T,N}) where {T,N}
    oldsize = size(A)
    newsize = zf.SI
    newcoord=[]
    for (k,d) in enumerate(newsize)
        if d isa Colon
            newsize[k]=oldsize[k]
            push!(newcoord,A.coord[k])
        elseif A.coord[k] isa AbstractRange
            extrange = range(first(A.coord[k]),step=step(A.coord[k]),length=d)
            push!(newcoord,extrange)
        else
            push!(newcoord,A.coord[k])
        end
    end
    newA = zeros(T, newsize...)
    oldRange = map(x->1:x,oldsize)
    newA[oldRange...] = A
    return SpectData(newA,(newcoord...,)) 
end

struct Apodize <: NMRProcessor
    R::Vector{Union{Real,Colon}}
end

function (ap::Apodize)(A::SpectData)
    apo = A.dat
    for (k,r) in enumerate(ap.R)
        if !(r isa Colon)
            ix=ones(Int64,ndims(apo))
            ix[k] = length(A.coord[k])
            f = exp.(-ap.R[k] .* A.coord[k])
            apo .*= reshape(f,ix...)
        end
    end

    return(SpectData(apo,A.coord))
end


@doc raw"""
    abstract type NMRProcessor1D <: NMRProcessor

Data type for processing tools that apply to a single dimension, i.e., that are inherently
1D. They need to be defined as functors that act on a `AbstractVector{T}`. They must
contain a field `.dim` that indicates which dimension in a multidimensional array they
should be applied to.
"""
abstract type NMRProcessor1D <: NMRProcessor end

function (np1d::NMRProcessor1D)(A::SpectData{T,N}) where {T,N}
    return SpectData(mapslices(np1d,A,dims=np1d.dim),A.coord)
end

struct PhaseCorrect <: NMRProcessor1D
    ph0::Float64
    ph1::Float64
    dim::Int32
end

function (pc::PhaseCorrect)(x::SpectData{T,1}) where {T<:Number}
    c = exp(im*pc.ph0).* exp.(im*pc.ph1.*coords(x,1))
    return x.*c
end

struct MedianBaselineCorrect <: NMRProcessor1D
    dim::Int64
    wdw::Int64
    stp::Int64
    gauss::Vector{Float64}
end

function MedianBaselineCorrect(dim::Integer;wdw=4096, stp=32)
    g=exp.(-25*((-wdw:wdw)./wdw).^2)
    g=g/sum(g)
    return MedianBaselineCorrect(dim,wdw,stp,g)
end

@doc """
    function extrema(X::AbstractArray{T,N}, dim::Integer) 

returns an array of booleans indicating all extremal values of `X` along the dimension `dim`.
"""
function extrema(X::AbstractArray{T,N}, dim::Integer) where {T,N} 
    shifter=zeros(Int64,ndims(X))
    shifter[dim]=1
    left=circshift(X,-shifter)
    right=circshift(X,shifter)

    minmaxima = (X .> left .&& X .> right) .|| (X .< left .&& X .< right)
    return minmaxima
end

wrap(n,l)=[mod(k,l) for k in n]


@doc"""
    function conv(X::AbstractArray{T1,N}, y::AbstractVector{T2},dim::Integer) where {N>1,T1,T2}

computes the convolution of the array `X` with the vector `y` along the dimension `dim`.
The ends of `X` are zero-padded such that the result is guaranteed to have the same size as `X`.
`NMRlab.conv()` uses a direct algorithm for the convolution, not fft. It is therefore efficient
when the length of `y` is much less than the corresponding dimension of `X`. If this is not
the case and performance is critical, a different algorithm should be used.
"""
function conv(X::AbstractArray{T1,N}, y::AbstractVector{T2},dim::Integer) where {N,T1,T2}
    return mapslices(a->conv(a,y), X, dims=dim)
end

function conv(x::AbstractVector{T1}, y::AbstractVector{T2} ) where {T1,T2}
    N=length(x)
    M=length(y)>>1
    lrange = isodd(length(y)) ? (-M:M) : (-M:(M-1))
    b = [ sum( ((k+l>0 && k+l<=N) ? x[k+l] : last(x) ) * y[l+M+1] for l=lrange)   for k=1:N]
end

import Statistics

@doc raw"""
    function (mb::MedianBaselineCorrect)(s::SpectData)

subtract baseline for the real part of `s` by the algorithm of M. S. Friedrichs,
*Journal of Biomolecular NMR*,  **5** (1995) 147  153.
"""
function (mb::MedianBaselineCorrect)(s::SpectData{T,1}) where {T<:Number}
    r=real.(s.dat)
    xtr = extrema(r,1)
    xind = findall(xtr)  # find the indices of all extrema in the spectrum
    bl=[Statistics.median(r[filter(x-> (x>=k-mb.wdw) && (x<=k+mb.wdw), xind)]) for k in 1:length(s.dat)] # find the index of the extremum closest to the 32500th point (the artifact)
    c=conv(bl,mb.gauss,1)
    return SpectData(r.-c, s.coord)
end


@doc raw"""
    function Derivative(dim::Integer)

returns a processor that computes the first derivative of a spectrum along the dimension `dim`.
"""
struct Derivative <: NMRProcessor1D 
    dim::Int64
end

function (der::Derivative)(spect::SpectData{T,1}) where {T<:Number}
    s=spect.dat
    inc=step(spect.coord[1])
    d = 1.0/12*(8*[s[2:end];0]-8*[0;s[1:(end-1)]] + [s[3:end];0;0] - [0;0;s[1:(end-2)]] )/inc
    return SpectData(d, spect.coord)
end


@doc raw"""
    function Integral(dim::Integer)

returns a processor that computes the integral of a spectrum along the dimension `dim`.
"""
struct Integral <: NMRProcessor1D
    dim::Int64
end

function (int::Integral)(spect::SpectData{T,1}) where {T<:Number}
    s=spect.dat
    inc=step(spect.coord[1])
    d = cumsum(s)*inc
    return SpectData(d, spect.coord)
end 


ent(x) = x*log(x)

import Optim

@doc raw"""
    function `entropy(s::SpectData{T,1})` 
        
computes the entropy of the first derivative
in the real part of an
NMR spectrum as defined by Chen et al. in
*Journal of Magnetic Resonance* **158** (2002) 164–168.
This quantity can be optimised with respect to zero- and first-order
phase correction for automatic (unsupervised) phase correction.
"""
function entropy(s::SpectData{T,1}) where {T<:Number}
    h= s.dat .|> real  .|> abs
    h/=sum(h)
    return -sum(ent.(h))/length(h)
end



struct AutoPhaseCorrectChen <: NMRProcessor1D
    dim::Int64
    verbose::Bool
    γ::Float64
end

@doc raw"""
    function AutoPhaseCorrectChen(dim::Integer;verbose=false,γ=0.0)

returns a processor that performs automatic phase correction of a spectrum along
the dimension `dim` using the minimum entropy algorithm by Chen et al. in
*Journal of Magnetic Resonance* **158** (2002) 164–168. The parameter `γ` can be
used to add a penalty term to the optimisation target, which penalises negative
peaks in the spectrum. This can be useful to avoid overcorrection in noisy
spectra.
"""
function AutoPhaseCorrectChen(dim::Integer;verbose=false,γ=1.0e-5)
    return AutoPhaseCorrectChen(dim,verbose,γ)
end

# penalty(x) computes the sum of squares of all negative points in x
function penalty(x)
    # x /= sum(abs.(x))
    return sum(k<0.0 ? k*k : 0.0 for k in x)
end

# this is the minimisation target for automatic phase correction
function goalfun(x,spect,γ)
    pc = PhaseCorrect(x[1],x[2]/1000,1)
    c = pc(spect) 
    return entropy(c)+γ*penalty(real.(c.dat));
end

function (apc::AutoPhaseCorrectChen)(spect::SpectData{T,1}) where {T<:Number}
    dspect = Derivative(1)(spect)
    # do a 1D optimisation of the zero-order pc first 
    res0  = Optim.optimize(x->goalfun([x[1],0.0],dspect,apc.γ),-pi,pi,Optim.Brent());
    
    if apc.verbose print(res0) end;        
    p0 = Optim.minimizer(res0)[1]

    # then a 2D optimisation of zero- and first-order pc
    result=Optim.optimize(x->goalfun(x,dspect,apc.γ),[p0,0.0],
            Optim.BFGS(),
            Optim.Options(show_trace=false,
                          f_calls_limit=500,
                          time_limit=2.0,
                          g_tol=1.0e-8)
        );
    if apc.verbose print(result) end;
    pc=PhaseCorrect( Optim.minimizer(result)[1], Optim.minimizer(result)[2]/1000,1);
    scorr = pc(spect);
  return scorr ;
end


@doc raw"""
    function PeakAlign(dim::Integer, readpos::Float64, wdw::Integer)

returns a processor that aligns a spectrum along the dimension `dim` to a
specific position `readpos`.  It works by finding a maximum in the spectrum within a window `wdw`
that
is closest to `readpos`, and then shifting the spectrum such that this maximum
is exactly at `readpos`. This can be useful to align spectra to a reference
peak, e.g., TMS.
"""
struct PeakAlign <: NMRProcessor1D
    dim::Int64
    readpos::Float64
    wdw::Int64
end

function (pa::PeakAlign)(spect::SpectData{T,1}) where {T<:Number}
    # find the index of the point closest to readpos
    idx = findmin(abs.(spect.coord[1] .- pa.readpos))[2]
    # find a maximum in the spectrum that is closest to readpos
    maxidx = findmax(abs.(spect.dat[idx-pa.wdw:idx+pa.wdw]))[2] + idx - pa.wdw
    newdat = circshift(spect.dat, idx-maxidx)
    return SpectData(newdat, (spect.coord[1],))
end