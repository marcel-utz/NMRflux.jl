*A Julia framework for processing, simulating, and denoising NMR data*

# NMRflux.jl - Overview

## Package Features

- Vendor-neutral loading of NMR data (e.g. Bruker, JEOL) into a unified `SpectData` format.
- Well-structured `SpectData` type that subtypes `AbstractArray` and carries axes and metadata.
- Classical NMR processing tools: Fourier transform, apodization, baseline and phase correction, slicing, etc.
- Spin dynamics simulations based on sparse matrix representations of the spin Hamiltonian and density operator (`SpinSim.jl`).
- Synthetic FID generation pipeline for method development and machine learning.
- Integrated machine learning workflows for spectral denoising using Flux based models.

## Contents

```@contents
```

`NMRflux.jl` is a library for the processing, simulation, and interpretation of NMR
data. It is the successor of an earlier toolkit (`NMR.jl`) developed in
the Utz group and is intended to provide a more coherent, extensible, and
well-documented framework.

The package grew out of concrete research needs in NMR spectroscopy, including
robust data handling, flexible processing pipelines, spin simulations, and
Deep learning based denoising. It is designed as a general NMR framework that
can serve as a foundation for higher-level workflows, including applications
where NMR data are used in quantitative studies. Many of these tools have 
already been used in ongoing projects, and the goal of NMRflux.jl is to collect 
them in a single, consistent interface that can be used both inside and outside the group.

!!! note "Scope and applications"
    NMRflux.jl is designed to be applicable to a wide range of NMR experiments.
    It aims to support standard NMR data processing workflows, spin dynamics
    simulations, synthetic data generation, and automated spectra cleaning. The
    package is intended as a flexible foundation that can be integrated into
    larger analysis pipelines, including applications where NMR data contribute
    to quantitative or multivariate studies.Everyday tasks should be straightforward 
    with sensible defaults, while power users can access lower-level routines for 
    fine-grained control.


## Manual Outline

If you would like to get started quickly, begin with the **Getting Started**
section in the Manual, which explains how to install the package, load data,
and perform basic processing steps.

For a more complete description of the available tools, refer to the **Manual**
and the **Roadmap to 1.0**, which describe the design of the data structures,
processing and simulation modules, and the planned evolution towards a stable
1.0 release.

A complete list of functions, types, and modules - together with their
docstrings - can be found in the **API Reference**.

## Feedback

`NMRflux.jl` is under active development, and feedback is very welcome.  
Bug reports, feature requests, and suggestions can be submitted via the
project's GitHub repository or contact `marcel.utz@kit.edu` by email.

## Citing NMRflux.jl

If you use `NMRflux.jl` in published work, we would appreciate an acknowledge this by citing our work. 
A formal reference for `NMRflux.jl` is planned and will be added here once available.
