module NMRlab

    export SpectData,coords,load
    export NMRProcessor, Chain, FourierTransform, Apodize, ZeroFill, 
           PhaseCorrect, MedianBaselineCorrect, Derivative, Integral,
           AutoPhaseCorrectChen,PeakAlign
   
    export SpinSim
    export GISSMO

    include("DataSet.jl")
    include("Examples.jl")
    include("NMRProcessor.jl")
    include("FileIO.jl")
    include("SpinSim.jl")
    include("GISSMO.jl")

end
