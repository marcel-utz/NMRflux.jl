# Roadmap to NMRflux.jl 1.0

`NMRflux.jl` intends to become the main entry point for general, vendor neutral NMR data representation, processing, simulation, and machine learning ready workflows. In its current state, `NMRflux.jl` brings together several strands of standard NMR infrastructure, ranging from data containers and spectral processing to spin dynamics simulation. These components form a domain agnostic toolbox that can be applied to a wide range of NMR problems.

In addition to this core functionality, the repository contains project specific example modules demonstrating how the toolbox can be applied to concrete research problems (e.g. metabolomics and microfluidic NMR). These examples build on the core infrastructure but are not required for general use of `NMRflux.jl`, and users interested only in generic NMR processing and simulation can safely ignore them.

To make `NMRflux.jl` suitable for long term, professional use (both inside and outside the group), we aim for the following goals.

## Completed Features (Core Toolbox)

These features constitute the general `NMRflux.jl` infrastructure and are designed to be applicable to a broad range of NMR applications.
- **User-Oriented Documentation**
    - A user friendly "Getting Started" page.
    - A complete manual with clear, guided examples.
    - Tutorials for data loading, processing, simulation, and ML workflows.

- **Well-Structured Data Types**
    - Fully implemented `SpectData` type.
    - Subtypes `AbstractArray` for natural integration with the Julia ecosystem.
    - Supports consistent indexing, axes, units, and metadata.
    - Designed for seamless interoperability with processing, simulation, and ML workflows.

- **Tight Integration with the Julia Ecosystem**
    - `SpectData` behaves like a native Julia array.
    - Supports broadcasting, slicing, and generic array operations.
    - Works in IJulia / Pluto notebooks.
    - Compatible with plotting packages.
    - Provides stable foundations for downstream packages and extensions.

- **Unified Processing and Simulation Tools**
    - Classical processing tools: Fourier transform, apodization, baseline and phase correction.
    - Spin-dynamics simulation framework implemented in `SpinSim.jl`.
    - All operations built around the unified `SpectData` interface.

- **Vendor-Neutral Data Access**
    - Loaders for multiple NMR vendor formats (e.g., Bruker, JEOL).
    - Robust parsing of acquisition parameters and metadata.
    - Uniform conversion into `SpectData` objects.

- **ML-Ready Interfaces**
    - Flux-compatible data representations and batching helpers.
    - Support for WHCN, Cartesian, and FFT-domain representations.
    - Designed to integrate cleanly with external ML pipelines.

***

## Applied Examples and Illustrative Workflows

This section documents example workflows that build on `NMRflux.jl`, but are not part of the core toolbox. These examples are intended to demonstrate how the infrastructure can be applied to specific research problems and may evolve independently of the core API. In addition to the core, domain agnostic toolbox, the documentation includes illustrative workflows that demonstrate how `NMRflux.jl` can be applied to concrete research problems. These examples are provided for guidance and do not define or constrain the scope of the core API.

**Synthetic FID generation (illustrative example)**: An example workflow demonstrating how to generate physically plausible synthetic FIDs using the spin-dynamics simulation framework. This example is documented in `SpinDynamics.md`, Section 1.2 - [Generating a batch of synthetic FIDs](SpinDynamics.md#1-2-generating-a-batch-of-synthetic-fids) and serves as an illustration of how the core simulation tools can be used for benchmarking and data generation.

These examples illustrate one way in which the toolbox can be used and may evolve independently of the core library.

## In Progress / To Be Finalized
These features are implemented at the code level but require documentation, examples, or interface polishing for the 1.0 release.

- **Example Datasets**
    - Downloadable datasets.
    - Curated FID and spectrum datasets for reproducible tutorials.
    
- **Final API Polishing**
    - Review of exported functions and naming conventions.
    - Ensuring consistent module interfaces across:
        - NMRProcessor.jl
        - SpinSim.jl
        - FileIO.jl
        - ML modules
    - Additional doctests and unit tests for interface stability.

- **Planned Release Timeline**
The roadmap below outlines the planned progression toward a stable 1.0 release. Dates are approximate and may evolve as the codebase matures.

|   Version | Planned Features                                                                  | Target Release |
| --------: | --------------------------------------------------------------------------------- | -------------- |
| **0.1.0** | Cleanup of core modules; basic documentation; simple spectral processing examples | Q1 2026        |
| **0.2.0** | Refined `SpectData` and related types; improved transforms and plotting           | Q2 2026        |
| **0.3.0** | Extended vendor and metadata support; example datasets; loading helpers           | Q3 2026        |
| **0.4.0** | Integration of ML based processing (spectral/FID cleaners) with example scripts   | Q4 2026        |
| **1.0.0** | Complete user manual and API reference; stable public interfaces                  | TBD            |
