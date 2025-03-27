module NMRlab

    export SpectData,coords,load
    export NMRProcessor, Chain, FourierTransform, Apodize, ZeroFill, PhaseCorrect
    export SpinSim
    export GISSMO
    export GenerateFIDs

    include("DataSet.jl")
    include("Examples.jl")
    include("NMRProcessor.jl")
    include("FileIO.jl")
    include("SpinSim.jl")
    include("GISSMO.jl")
    include("GenerateFIDs.jl")

end
