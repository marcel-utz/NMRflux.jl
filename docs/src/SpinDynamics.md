# 1. Spin Dynamics Simulation and Synthetic FIDs (GenerateFIDs / SpinSim)
`NMRflux.jl` includes a lightweight spin dynamics engine (`SpinSim`) for simulating NMR spin evolution. `SpinSim` is designed for generic spin dynamics simulations in both the time and frequency domain, performing simulations in Hilbert space using the density operator formalism. Building on this physics core, `NMRflux.jl` provides a higher level helper module (`GenerateFIDs`) for generating realistic synthetic 1H NMR spectra and time domain FIDs that resemble experimental measurements of complex mixtures motivated by our group's main interest in analysing complex mixtures in biological contexts (metabolomics and metabolic analysis). Because the full pipeline is implemented in Julia and can generate paired clean/dirty data on demand, it provides an effectively unlimited source of training data for machine learning models, and it is also useful for stress testing and validating NMR processing pipelines.

The main entry point is `generateBatch`, which offers a unified, user friendly interface for producing synthetic datasets. It reads all simulation parameters from a TOML configuration file, automatically generates random spin Hamiltonians, computes the corresponding frequency domain spectra, converts them into realistic time domain FIDs, and applies artefacts (e.g. noise, phase errors, solvent peaks, and baseline distortions) to produce *dirty* FIDs. The output is returned as a `SpectData` object, fully compatible with downstream processing tools in `NMRflux.jl`, and can be written to disk in `.jld2` format.

Each batch follows a clean/dirty pairing convention: **odd-indexed** rows contain **clean** FIDs and the subsequent **even-indexed** rows contain the corresponding artefact-corrupted **dirty** FIDs (row 1 = clean, row 2 = dirty; row 3 = clean, row 4 = dirty; etc.). All simulation behaviour is controlled entirely through the TOML configuration file, ensuring reproducibility and easy tuning of SNR and artefact settings.

## 1.1 TOML configuration for synthetic FIDs
A typical configuration file has four sections: `[Hamiltonian]`, `[FID]`,
`[Artefacts]`, and `[Batch]`. For example:

```@text fidSimEg
[Hamiltonian]
nCouplings = 2            # average number of couplings per spin
shiftRange = [0.0,10.0]   # range of chemical shifts (ppm-like units)
Jstd = 12.0               # J-coupling std. dev. (Hz)
baseFreq = 700.0          # base frequency in MHz
shiftCtr = 4.76           # centre offset for shifts

[FID]
SWH = 5000                # spectral width in Hz
TD = 1024                 # number of complex points
LWmean = 2.0              # mean linewidth in Hz
LWstd = 5.0               # linewidth std. dev. in Hz

[Artefacts]
phase0error = 360.0       # max zero-order phase error (deg)
phase1error = 360.0       # max first-order phase error (deg over full width)
solventArtefact = 100.0   # solvent artefact intensity
solventWidth = 100.0      # solvent artefact width (Hz)
baselineArtefact = 10.0   # baseline distortion strength
baselineDuration = 0.0002 # baseline distortion duration (s)
SNR = 500.0               # signal/noise ratio

[Batch]
size = 250                # number of (clean, artefact) pairs
nFIDs = 3                 # number of basis FIDs to generate
alpha = 3                 # width of exponential concentration distribution
filename = "Batch16k"     # output filename prefix (without extension)
maxNspin = 4              # maximum number of spins in any system
```

Conceptually:
- `[Hamiltonian]`: controls the random spin systems (chemical shifts, J couplings, base frequency)
- `[FID]`: sets digitization parameters (spectral width SWH, number of points TD, linewidth statistics)
- `[Artefacts]`: controls phase errors, solvent peaks, baseline distortions, and noise level
- `[Batch]`: sets the number of samples and file output behaviour

## 1.2 Generating a batch of synthetic FIDs
The main entry point is `GenerateFIDs.generateBatch`, which reads the `TOML` file, builds the Hamiltonians, simulates the spectra using `SpinSim.Spectrum`, converts them to time domain FIDs, applies artefacts, and returns a `SpectData` object.

```@julia
using NMRflux
using NMRflux.GenerateFIDs

toml_file = joinpath(@DIR, "..", "examples", "synthetic", "Batch16k.toml") # Path to your TOML configuration file (adjust to your repository layout)
batch = GenerateFIDs.generateBatch(toml_file; saveFile = false)
```

The return value batch is a 2D SpectData object:
- `batch.dat` has size (`2 * nbatch, TD`)
  - Rows `1, 3, 5, ...` contain the clean FIDs
  - Rows `2, 4, 6, ...` contain the corresponding artefact-distorted FIDs
- `batch.coord[1]` is the row index (`1, 2, 3, ...`)
- `batch.coord[2]` is the time axis (seconds)
