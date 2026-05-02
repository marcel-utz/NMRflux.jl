# 1. Loading NMR Data
`NMRflux.jl` provides:
Low level, vendor specific readers in the submodule `NMRflux.FileIO`. These work directly with Bruker and JEOL file formats and return raw time domain arrays and parameter dictionaries. High level processing tools that operate on `SpectData` objects created from these raw arrays. For convenience, `NMRflux.jl` comes with example datasets that can be used in the documentation and in interactive sessions.

## 1.1 Example datasets
The example data are stored in the dictionary `NMRflux.Examples.Data`.

```@example brukerEg
using NMRflux
using NMRflux.Examples

data_bruker = NMRflux.Examples.Data["HCC cell culture media spectra"]
```

```@example joelEg
using NMRflux
using NMRflux.Examples

data_joel = NMRflux.Examples.Data["Spheroid culture medium"]
```

## 1.2 Bruker Data High-level (recommended)
For most use cases, Bruker data can be loaded via the high-level `load` function, which returns both the acquisition parameters and a time domain
`SpectData` object:

```@example brukerEg
data_bruker = NMRflux.Examples.Data["HCC cell culture media spectra"]
params_bruker, data_td_bruker = NMRflux.load(joinpath(data_bruker["path"], "10"), :Bruker)

(params_bruker["SW_h"], size(data_td_bruker))
```
Here:
- `params_bruker` is a dictionary of acquisition parameters parsed from `acqus`.
- `data_td_bruker` is a `SpectData` object containing the time domain FID with an
  appropriate time axis.

Internally, `NMRflux.load(path, :Bruker)`:
- Reads acqus and fid using `NMRflux.FileIO`
- Applies the Bruker group-delay correction using the parameter `GRPDLY`
- Constructs the time axis from the sweep width `SW_h`.

This saves users from manually computing the dwell time and axis. The loaded FID can be inspected as:
```@example brukerEg
using Plots: plot, savefig

t = data_td_bruker.coord[1]
y = real.(data_td_bruker.dat)

plot(t, y, xlabel = "time / s", ylabel = "signal (a.u.)", title  = "Bruker FID (real part) - High level loading") # Plot the real part of the FID
savefig("bruker_fid_hl_plot.svg"); nothing # Save figure for Documenter
```
![](bruker_fid_hl_plot.svg)

## 1.3 Bruker Data (Low-level FileIO)
Power users can work with the low-level Bruker readers in `NMRflux.FileIO`. These functions operate directly on the raw Bruker files (fid, acqus, etc.)
and return:

- A complex FID as a Julia vector
- A dictionary of acquisition parameters

Using the same example dataset as above, we can read the FID as follows:

```@example brukerEg
using NMRflux.FileIO

fid_bruker = NMRflux.FileIO.readBrukerFID(joinpath(data_bruker["path"], "10", "fid"))
```

The `fid_bruker` is a `Vector{ComplexF64}` containing the complex time domain data points stored in the Bruker fid file. For older TopSpin 2.0 data, the FID is stored as 32-bit integers; in that case you can specify the format:
```@example brukerEg
#fid_bruker_old = NMRflux.FileIO.readBrukerFID("fid"; format = Int32) # Example call for TopSpin 2.0 data
nothing
```

The acquisition parameters are stored in Bruker JCAMP-DX files such as acqus. We can read them using:
```@example brukerEg
params_bruker = NMRflux.FileIO.readBrukerParameterFile(joinpath(data_bruker["path"], "10", "acqus"))
```

The `params_bruker` is a `Dict{String,Any}` in which:
- Numeric scalar values are automatically parsed as `Int64` or `Float64`
- Non-numeric scalars remain as `String`
- Array parameters (such as `D0`, `D1`, etc) are returned as Julia vectors whose elements 
are parsed in the same way (`integer`, `float`, or `string`)

Bruker array parameters such as `D0`, `D1`, etc are stored in a single vector `params_bruker["D"]`. Because Julia arrays are 1-based, `D0` corresponds to index `1`, `D1` to index `2`, and so on:
```@example brukerEg
(params_bruker["D"][1], params_bruker["D"][2])  # D0, D1
```

An important example is the sweep width in Hz, stored in the parameter `SW_h`. The dwell time (sampling interval) is its inverse, and can be used to construct a time axis:
```@example brukerEg
dwell     = 1 / params_bruker["SW_h"]                  # s per point
time_axis = (0:length(fid_bruker)-1) .* dwell          # explicit time vector
(dwell, length(time_axis))
```

The same example can be used to quickly inspect the loaded FID:
```@example brukerEg
plot(time_axis, real(fid_bruker), xlabel = "time / s", ylabel = "signal (a.u.)", title  = "Bruker FID (real part) - Low level loading") # Plot the real part of the FID
savefig("bruker_fid_plot.svg"); nothing # Save figure for Documenter
```
![](bruker_fid_plot.svg)

With the FID and time axis defined, a time domain `SpectData` object can be constructed as:
```@example brukerEg
data_td_bruker = SpectData(fid_bruker, (time_axis,))
```

## 1.4 JEOL Data High-level loading (recommended)
JEOL `.jdf` files contain acquisition parameters and binary data in a single file. JEOL datasets can be loaded using the unified high level loader NMRflux.load, which returns both the acquisition parameters and a time domain `SpectData` object. Most users can load JEOL data using:

```@example joelEg
using Plots

data_jeol = NMRflux.Examples.Data["Spheroid culture medium"]
jdf_file  = joinpath(data_jeol["path"], "yp-5-fu-2.5-100.jdf")

params_jeol, data_td_jeol = NMRflux.load(jdf_file, :JEOL)

t_jeol = data_td_jeol.coord[1]    # time axis (s)
y_jeol = real.(data_td_jeol.dat)  # real part

plot(t_jeol, y_jeol;
xlabel = "time / s",
ylabel = "signal (a.u.)",
title = "JEOL FID (real part)")

savefig("jeol_fid_plot.svg"); nothing
```
![](jeol_fid_plot.svg)

The returned values are:
- `params_jeol` :: `Dict{String,Any}`. A dictionary of JEOL acquisition parameters where each entry is stored as a tuple (scaler, units, value)
- `data_td_jeol` :: `SpectData{ComplexF64,1}` (or `SpectData{ComplexF32,1}` depending on the file). A `SpectData` object containing the reconstructed complex FID and its time axis

The high level loader performs all low level steps automatically:
- Reads the JEOL header and parameter blocks
- Reconstructs complex time domain data from the stored real/imaginary vectors
- Constructs the correct time axis from the digitization rate in `X_SWEEP`
- Returns a ready-to-use `SpectData` for downstream processing

```@example joelEg
params_jeol, data_td_jeol = NMRflux.load(jdf_file, :JEOL)
(size(data_td_jeol), params_jeol["X_SWEEP"][3])
```

## 1.5 JEOL data (low-level FileIO)
For advanced use, the low-level JEOL reader in `NMRflux.FileIO` provides direct access to all parts of the .jdf file:

```@example joelEg
header_jeol, params_jeol, data_jeol = NMRflux.FileIO.readJEOL(open(jdf_file))
```

This function returns:
- `header_jeol`: a dictionary with file-level metadata (axes, units, base frequencies, etc.)
- `params_jeol`: a dictionary of JEOL acquisition parameters where each entry is a (scaler, units, value) tuple
- `data_jeol`: a 1-D vector of `Vector{Float32}` or `Vector{Float64}` containing the stored data (real part followed by imaginary part) with the layout:

```markdown markdownEg
[ Re1, Re2, Re3, ..., ReN,  Im1, Im2, Im3, ..., ImN ]
```

Some of the metadata fields available in the `JEOL` header include:
```@example joelEg
# header_jeol["dataAxisStart"]
# header_jeol["dataAxisStop"]
# header_jeol["dataPoints"]
# header_jeol["baseFreq"]
header_jeol["zeroPoint"]
```

## 1.6 Reconstructing complex FID data
To reconstruct complex FID values, we split this vector into real and imaginary halves and combine them:
```@example joelEg
n     = length(data_jeol)
cdata = data_jeol[1:n>>1] - im * data_jeol[n>>1+1:end]
```

The `cdata` is now a complex vector containing the time domain JEOL FID.

## 1.7 Constructing a time axis
JEOL digitization information is stored in the `X_SWEEP` parameter. The sweep width is typically in the third element:
```@example joelEg
dwell     = 1.0 / params_jeol["X_SWEEP"][3]
time_axis = range(0.0, step = dwell, length = length(cdata))
```

## 1.8 Constructing a SpectData object
```@example joelEg
data_td_jeol = SpectData(cdata, (time_axis,))
```

The acquisition parameters (`params_jeol`) and header information (`header_jeol`) may be stored alongside the `SpectData` object to keep all metadata available for processing.
