# (c)2024 Marcel Utz

module GenerateFIDs

    using NMRlab
    using NMRlab.SpinSim
    using CSV
    using LinearAlgebra
    using TOML
    using DataFrames
    using Random

    export version, HamiltonianGenerator, complexToWHCN, WHCNtoComplex, complexToWN, WNtoComplex
    export complexCartToWHCN, WHCNtoComplexCart
    export complexRealToWHCN

    function version()
        return(v"0.0.2")
    end

    struct HamiltonianGenerator
        shiftRange::Vector{Float64}
        Jstd::Float64
        nCouplings::Int64
        baseFreq::Float64    
        shiftCtr::Float64


        function HamiltonianGenerator(toml_file::String)
            params = TOML.parsefile(toml_file)["Hamiltonian"]
            
            new(
                get(params,"shiftRange",[0.0,10.0]),
                get(params,"Jstd",5.0),
                get(params,"nCouplings",1),
                get(params,"baseFreq",600.0),
                get(params,"shiftCtr",4.76),
            )
        end
    end

    function (c::HamiltonianGenerator)(nspin::Integer)
    # Example callable behavior based on the parameters from the .toml file
    # Customize this function according to your needs

        # For illustration, let's assume the .toml file has a key "factor"

       # function randomHamiltonian(nspin::Integer,freq=600.,ctr=4.76,Jstd=10,shiftMax=10.0)
        # select some random chemical shifts
        
        chem_shifts = (c.shiftRange[2]-c.shiftRange[1]) .* rand(nspin) .+ c.shiftRange[1]
        H=sum(j->2pi*c.baseFreq*(chem_shifts[j]-c.shiftCtr)*SpinOp(nspin,Sz,j),1:nspin)

        # and some random couplings
        for j=1:rand(1:c.nCouplings*nspin*(nspin-1))
            k=rand(1:nspin)
            l=rand(1:nspin)
            if k==l continue end
            if k>l f=l; l=k; k=f; end
            J=c.Jstd*randn() # we use a normal distribution with sigma=10 Hz
            H.+=2pi*J*OpJstrong(nspin,k,l)
        end
        H
    end

    struct FidGenerator
        t::LinRange{Float64, Int64}
        R2mu::Float64
        R2sigma::Float64

        function FidGenerator(toml_file::String)
            params = TOML.parsefile(toml_file)["FID"]
            muX=pi*get(params,"LWmean",1.0)
            sigmaX2 = (pi*get(params,"R2std",0.2))^2
            
            new(
                LinRange(get(params,"start",0.0), 
                         get(params,"TD",4096)/get(params,"SWH",10000.0),
                         get(params,"TD",4096)
                ),
                log(muX^2/sqrt(muX^2+sigmaX2)),
                sqrt(log(1+sigmaX2/(muX^2)))
            )
        end
    end
   
    function (c::FidGenerator)(freqs,ints)
        n=length(freqs)
        # relaxation rates for each line are taken from a log-normal distribution
        rrates=exp.(c.R2sigma.*randn(n).+c.R2mu)
        fid=zeros(ComplexF64,length(c.t))
        for k=1:n
            fid .+= ints[k].*exp.(-(rrates[k]+im*freqs[k]).*c.t)
        end
        return fid
    end

    struct ArtefactGenerator
        t::LinRange{Float64, Int64}
        solventArtefact::Float64
        solventWidth::Float64
        phase0error::Float64
        phase1error::Float64
        baselineArtefact::Float64
        baselineDuration::Float64
        SNR::Float64

        function ArtefactGenerator(toml_file::String)
            tparams = TOML.parsefile(toml_file)["FID"]
            aparams = TOML.parsefile(toml_file)["Artefacts"]

            new(
                LinRange(get(tparams,"start",0.0), 
                         get(tparams,"TD",4096)/get(tparams,"SWH",10000.0),
                         get(tparams,"TD",4096)
                    ),
                get(aparams,"solventArtefact",0.0),
                get(aparams,"solventWidth",1.0),
                get(aparams,"phase0error",0.0),
                get(aparams,"phase1error",0.0),
                get(aparams,"baselineArtefact",0.0),
                get(aparams,"baselineDuration",0.0),
                get(aparams,"SNR",100.0)
           )
        end
    end

    """
        function randcomp(n::Integer, alpha::Real)

    returns a vector of ``n`` random concentrations ``c_k`` with the property ``\\sum c_k = 1``. The returned concentrations
    are a random permutations of a exponentially decaying sequence of concentrations ``c_m = S_n \\tilde x_m \\exp(-\\frac{m}{\\alpha})``,
    where ``S_n``is the normalisation constant, and ``\\tilde x_m`` is a random number between 0 and 1. ``\\alpha`` represents the decay number, and roughly indicates the 
    number of concentrations
    that remain significantly above zero.
    """
    function randcomp(n::Integer, alpha::Real)
        S=exp.(- (1:n)./(alpha)).*rand(n)
        return (Random.shuffle(S)./sum(S))
    end

    function (c::ArtefactGenerator)(f::Vector{T}) where T <: Number
        
        # carrier / solvent suppression artefact
        d = f + c.solventArtefact * rand() * exp.(-rand()*pi*c.solventWidth.*c.t)

        # first order phase error
        # we compute the number of data points to apply a circular shift of the time origin
        maxShift = round(Int64,c.phase1error/180.0)
        d=circshift(d,-rand(0:maxShift))

        # mess up the base line
        maxBaselineTime = round(Int64,c.baselineDuration / step(c.t))
        for k=1:maxBaselineTime
            d[k] *= c.baselineArtefact * randn()
        end
    
        # noise
        d .+=  abs(f[1])/c.SNR * randn(length(f))
    
        return exp(im*pi/180.0*c.phase0error*rand())*d
    end

    struct LineshapeGenerator
        a::Vector{Float64}

        function Lorentzian(fname::String)
            tparams=TOML.parsefile(fname)["FID"]
            lparams=TOML.parsefile(fname)["Lineshape"]
        end
    
    end

    function generateBatch(toml_file::String; saveFile=true)
        params = TOML.parsefile(toml_file)["Batch"]
        nbatch =        get(params,"size",1000)
        nfid =          get(params,"nFIDs",100)
        maxNspin =      get(params,"maxNspin",10)
        alpha =         get(params,"alpha",5)
        filetype =      get(params,"fileType","NPZ")
        gtNSR =         get(params,"GroundTruthNSR",0.0)
        output_file =   get(params,"filename","batch")
        # of = open(output_file,"w")

        findex=1
        while (isfile(output_file*lpad(findex,4,"0")*".npz"))
            findex=findex+1
        end
    
        hgen=HamiltonianGenerator(toml_file)
        fidgen=FidGenerator(toml_file)
        art=ArtefactGenerator(toml_file)

        fidCollection =     [
            begin
                n=rand(2:maxNspin)
                Fx=sum(j->SpinOp(n,Sx,j),1:n)
                Fy=sum(j->SpinOp(n,Sy,j),1:n)
                H=hgen(n)        
                freqs,ints=Spectrum(Fx,H,Fx-im*Fy)
                fidgen(freqs,ints)
            end
            for k=1:nfid
        ] ;
        BFID=(hcat(fidCollection...)) 

        fidpts = length(fidgen.t)
    
        batch=Array{ComplexF64,2}(undef,2*nbatch,fidpts)
    
        Threads.@threads for k=1:2:2*nbatch
            f=BFID*randcomp(nfid,alpha)
            noise = f[1]*gtNSR.*randn(ComplexF64,fidpts)
            f .+= noise
            af= f |> art
            batch[k,:] = f
            batch[k+1,:] = af    
        end

        if (saveFile)
         #   npzwrite(output_file*lpad(findex,4,"0")*".npz",ComplexF32.(batch))
        end
        
        # close(of)

        return batch
        
    end


    """
    function complexToWHCN(x)


    convert complex signals in the `n x w` array of numbers into a `2w x 1 x n` array
    of real numbers, with the absolute value and phase angle in separate channels.
    The function uses Float32 numbers exclusively.
    """

    function complexToWHCN(x)
        (n,w)=size(x)
        WHCN=Array{Float32,3}(undef,2*w,1,n)

        for k=1:n 
           WHCN[1:2:2w,1,k] = 2pi*abs.(x[k,:]).-pi
           WHCN[2:2:2w,1,k] = angle.(x[k,:])     
        end
        return WHCN
    end

    function complexCartToWHCN(x)
        (n,w)=size(x)
        WHCN=Array{Float32,3}(undef,w,2,n)

        for k=1:n 
           WHCN[:,1,k] = real.(x[k,:])
           WHCN[:,2,k] = imag.(x[k,:])     
        end
        return WHCN
    end

    function complexRealToWHCN(x)
        (n,w)=size(x)
        WHCN=Array{Float32,3}(undef,w,1,n)

        for k=1:n 
           WHCN[:,1,k] = real.(x[k,:])
        end
        return WHCN
    end

    function WHCNtoComplex(x)
        (w,c,n) = size(x)
        data = Array{ComplexF32,2}(undef,n,w>>1)
    
        for k=1:n
            data[k,:] = (x[1:2:w,1,k].+pi)./(2*pi) .* exp.(im*x[2:2:w,1,k])
        end
        return data
    end

    function WHCNtoComplexCart(x)
        (w,c,n) = size(x)
        data = Array{ComplexF32,2}(undef,n,w)
    
        for k=1:n
            data[k,:] .= x[:,1,k].+im.*x[:,2,k]
        end
        return data
    end


    function complexToWN(x)
        (n,w)=size(x)
        WN = Array{Float32,2}(undef,2*w,n)
       for k=1:n 
           WN[1:2:2w,k] = 2pi*abs.(x[k,:]).-pi
           WN[2:2:2w,k] = angle.(x[k,:])     
        end
        return WN
    end

    function WNtoComplex(x)
        (w,n) = size(x)
        data = Array{ComplexF32,2}(undef,n,w>>1)
    
        for k=1:n
            data[k,:] = (x[1:2:w,k].+pi)./(2*pi) .* exp.(im*x[2:2:w,k])
        end
        return data
    end


end










