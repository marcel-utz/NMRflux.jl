# 1. Working with SpectData
`SpectData` is the central data structure in NMRflux.jl. It stores an N-dimensional numerical data array, and one coordinate vector for each dimension, and is defined as a subtype of `AbstractArray{T,N}`. This means that `SpectData` behaves like a regular Julia array in most contexts: it supports indexing, slicing, broadcasting, and can be passed to most numerical functions that expect an array.

For reference, the type is defined as:
```julia
struct SpectData{T,N} <: AbstractArray{T,N}
dat::AbstractArray{T,N}
coord::NTuple{N,AbstractVector}
end
```

## 1.1 Loading a simple JOEL dataset
```@example joelEg
using NMRflux
using NMRflux.Examples

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

The returned data from above is of type `SpectData`:
```@example joelEg
typeof(data_td_jeol)
```

## 1.2 Basic indexing
`SpectData` can be indexed just like a normal array. When you index with a range, you obtain a `SpectData` view with the corresponding subset of the data and coordinates:
```@example joelEg
data_td_jeol[1:5] # SpectData containing the first 5 complex points
```

To access the underlying numerical values directly, you can use the `dat` field or broadcasted operations:
```@example joelEg
data_td_jeol.dat[1:5]     # first 5 complex values as a plain array
real.(data_td_jeol)[1:5]  # real part of first 5 points
imag.(data_td_jeol)[1:5]  # imaginary part of first 5 points
```

Multi dimensional `SpectData` objects behave analogously, with size and indexing following standard Julia conventions.

## 1.3 Internal structure
For a 1D `SpectData` object such as `data_td_jeol`, the two fields are:
- `data_td_jeol.dat` the underlying AbstractArray{T,1} holding the numerical data values
(e.g. a complex FID or spectrum)
- `data_td_jeol.coord` a 1-tuple of coordinate vectors, one per dimension. For 1D data,
coord[1] is the time axis (for FIDs) or frequency axis (for spectra)

For a 1D time domain FID:
```@example joelEg
data_array = data_td_jeol.dat   # numerical array (complex FID)
t_axis = data_td_jeol.coord[1]  # time axis
(first(t_axis), last(t_axis))
```

In higher dimensions (e.g. 2D or 3D spectra), dat becomes an N-dimensional array, and coord[k] stores the coordinate vector (time, frequency, ppm, etc.) for the k-th dimension. Thus SpectData always keeps the numerical values and their physical axes together in a single coherent object. Conversion to frequency domain spectra (FFT, shifting, phasing, etc.) is handled by the processing tools described in the following sections.
