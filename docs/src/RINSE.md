# 1. Deep Learning Spectral Denoiser
`NMRflux.jl` includes Flux based deep learning tools for applying deep learning to the denoising of NMR spectra. These tools integrate with the `SpectData` structures of `NMRflux` and provide a flexible interface for loading datasets, building denoising models, training them, and applying inference to new FIDs or spectra.

## 1.1 Overview
Many NMR experiments, especially at low concentration or short acquisition times, produce spectra with poor signal-to-noise ratio and various artefacts (baseline distortions, phase errors, solvent residuals, etc.). Classical processing (apodisation, Fourier transform, phase and baseline correction, filtering) can improve the data, but often requires hand tuning and may either oversmooth peaks or leave structured noise. The deep learning spectral denoiser in `NMRflux.jl` addresses this problem by learning a non linear mapping from *artefact corrupted* spectra to their corresponding *clean* spectra. It uses a deep 1D convolutional autoencoder with residual connections, trained on pairs of clean/dirty spectra, to suppress noise and artefacts while preserving peak positions and line shapes. Once trained, the model can be applied to new spectra as an automated denoising step in larger NMR processing or analysis pipelines.

## 1.2 Data representation
The denoiser operates on **frequency-domain spectra** stored as `SpectData` objects and saved in `.jld2` files. Each `SpectData` used for training or validation is a 2D complex array where **odd-numbered rows contain clean spectra** and the corresponding **even-numbered rows contain the matching noisy/artefact corrupted spectra**. Internally, the training script normalizes each clean/dirty pair and converts them into `WHCN` tensors: the **input** to the model is the *dirty* spectrum with two channels (real and imaginary parts), and the **target** is the corresponding *clean* spectrum represented by a single channel (real part only). The model therefore learns to map `(W, 2, N)` dirty spectra to `(W, 1, N)` cleaned real spectra, where `W` is the number of frequency points and `N` is the batch size.

Training is controlled via a simple TOML configuration file (learning rate, batch size, number of epochs, etc.), and the script automatically writes model checkpoints (`.bson` files) during training so that runs can be resumed or warm started later.

## Dataset Format and Loaders
The training script expects a single `.jld2` file that contains *one* training split and *one or more* validation splits. Internally, the helper function

```@julia
load_multi_snr_loaders(path; batchsize=50, norm_mode=:max, seed=1234, send_to_gpu=true)
```

## Required keys in the .jld2 file
The dataset file must contain:

- A training split stored under the key "train"
- zero or more validation splits stored under keys of the form "val_snr_10", "val_snr_20", ...
The suffix (e.g. 10, 20) can be any SNR label you like; the loader sorts these by SNR and reports validation losses per split.

Each value at these keys must be a SpectData object.

## Shape and type of each SpectData
For each split (train, val_snr_XXX):

- `sd` is a `SpectData`
- `sd.dat` is a 2D array of type `ComplexF32` with shape (`2 * nbatch, W`) `2 * nbatch` rows, `W` frequency points per spectrum
- The row axis encodes clean/dirty pairs:
  - row 1 : clean spectrum 1
  - row 2 : dirty spectrum 1
  - row 3 : clean spectrum 2
  - row 4 : dirty spectrum 2
  - etc
- `length(sd.coord) == 2`
  - `sd.coord[1]` is a row index axis (e.g. `1:2*nbatch`)
  - `sd.coord[2]` is the frequency axis (in Hz, ppm, or arbitrary units)

The loader enforces:
  - `.jld2` extension only
  - `SpectData` with complex element type `ComplexF32`
  - 2D layout (rows x axis)
  - even number of rows (clean/dirty pairing)

## 1.3 TOML Configuration for Training
Training is configured via a `[Trainer]` table in a TOML file. A typical example is:

```toml
[Trainer]
batchSize      = 10
epochs         = 100000
timestamps     = 10
eta            = 2.0e-3
etaDecay       = 0.05
weightDecay    = 0.0e0
beta1          = 0.9
beta2          = 0.999
fname          = "Training"
breakCriterion = -0.1  
```

The script reads this `TOML` file, constructs a Trainer object, and uses it to control batch size, number of epochs, logging behaviour, and the optimiser (`AdamW` with `eta`, `beta1`, `beta2`, and weightDecay). The timestamps parameter controls how often detailed metrics are logged and checkpoints are written.

## 1.4 Running the training script & checkpoints
The training script is invoked from the command line:

```bash
julia spec_cleaner_train.jl <dataset_path.jld2> [config_path] [--restart path | --init path]
```

- `dataset_path.jld2`: Path to a `.jld2` file containing a `SpectData` object named "train" and one or more validation splits named "val_snr_XXX"
- `config_path` (optional): Path to the `TOML` configuration. If omitted, a default file `Trainer_repro.toml` is used
- `--restart path`: Resume a previous run from a full checkpoint (`.bson`) that stores both the model weights and optimiser / tracking state
- `--init path`: Warm start from an existing model checkpoint, but reset the optimiser and training history (useful when fine tuning on a new dataset)

During training, the script writes:
- `model_last.bson`: The most recent model state (updated regularly)
- `model_best.bson`: The model with the best overall validation loss so far
- `model_E-k_...bson`: Additional checkpoints saved whenever the validation loss has improved by an order of magnitude relative to the previous baseline (E-1, E-2, etc.)

All training progress (loss curves, per-SNR validation metrics, and messages about checkpoints) is logged to a timestamped log file whose name starts with `fname` from the `TOML` configuration (e.g. `Training-2025-11-17_10-35-22.log`).

Typical example:
```@julia
julia spec_cleaner_train.jl spec_dataset.jld2 Trainer.toml
```

To run training in the background on a server:
```@bash
nohup julia spec_cleaner_train.jl spec_dataset.jld2 Trainer.toml > out.log 2>&1 &
```

## 1.5 Inference and Plotting
After training, the `spec_cleaner_inference.jl` script applies a saved model to new datasets and optionally produces plots. It supports two modes:

- Simulated datasets: clean + dirty rows (paired)
- Experimental datasets: dirty only rows (no ground truth)

## 1.5.1 Simulated datasets (paired clean/dirty)
Input format (simulated): rows are interleaved
```markdown markdownEg
[clean1, dirty1, clean2, dirty2, ...]
```

Inference and plotting:
```@julia
# Run inference on a simulated dataset
julia spec_cleaner_inference.jl infer-simulated <model_checkpoint.bson> <dataset.jld2>

# Plot a single example from the result file (clean, cleaned, dirty)
julia spec_cleaner_inference.jl plot-simulated <result_file.jld2> <index> [ppm_config.toml]

# Plot all pairs to a directory
julia spec_cleaner_inference.jl plot-simulated-all <result_file.jld2> [outdir] [ppm_config.toml]
```
- The inference step writes a new `.jld2` file where spectra are stored in triplets as `[clean, cleaned, dirty]` repeated for each pair
- The plotting commands overlay clean, cleaned, and dirty spectra (in ppm if a `ppm_config.toml` is provided, otherwise in bin/frequency index)

## 1.5.2 Optional PPM configuration
The plotting functions (plot-simulated, plot-simulated-all, plot-experimental, etc.) can display spectra on a ppm axis if a small TOML configuration file is provided. This configuration defines the Larmor frequency and spectral width needed to convert FFT bin indices into ppm.

A typical ppm_config.toml file looks like:
```toml
# ppm_config_simulated.toml

[Hamiltonian]
baseFreq = 700.0         # MHz (e.g. 1H at 16.4 T)
shiftCtr = 4.76          # ppm (reference peak, e.g. water or TMS)

[FID]
SWH = 10000.0            # Hz spectral width
```
Fields:
- `baseFreq`: The transmitter frequency in MHz (e.g. 600, 700, 900 ...). This sets the overall ppm scale
- `shiftCtr`: Reference position in ppm

Examples:
  - 4.76 for water at high field
  - 0.00 for TMS
  - 2.01 for NAA in MRS, etc
- `SWH`: Spectral width (in Hz) used to compute the frequency axis before ppm conversion

If no ppm config is supplied, plots fall back to a bin index axis, which is still useful but not physically calibrated.

## 1.6 Key Features
- **Configurable synthetic data generation:**  
  Users can generate arbitrarily large synthetic datasets using `GenerateFIDs`, with full control over noise level, SNR, phase errors, baseline distortions, solvent artefacts, and linewidths. This enables "infinite" training data tailored to the characteristics of any experimental setup.

- **Learned clean-dirty mapping:**  
  The training pipeline automatically extracts paired clean/dirty spectra from `.jld2` datasets and normalises each pair using a norm derived from the *dirty* spectrum (default: `:max` amplitude). This ensures that training is numerically stable and reproducible.

- **Multi-SNR evaluation:**  
  The loader automatically detects validation splits named `val_snr_XXX`, sorts them by SNR, and reports validation losses per SNR level as well as an overall average. This provides detailed insight into model robustness across noise conditions.

- **GPU acceleration and reproducibility:**  
  All tensors and model weights are moved to the GPU (`gpu(...)`) for fast training.  
  The script sets a global random seed for both Julia's RNG and CUDA (`GLOBAL_SEED`) to ensure fully reproducible training runs.

## 1.7 Building train/validation sets from synthetic FIDs (convenience script)
For user convenience, `NMRflux.jl` provides a script `make_train_val_multi_snr_from_synthetic_dir.jl` that scans a directory of synthetic FID batches (from GenerateFIDs) and builds one unified training file with:
- A single mixed SNR training set
- Separate validation sets for each SNR value

It expects `.jld2` files whose names look like `FIDs_16384_SNR-1000_0001.jld2` and that each file contains a `SpectData` under the key "batch" with rows ordered as `[clean1, dirty1, clean2, dirty2, ...]`.

Given such a directory, the script:
- Loads all FID batches from input_dir
- Zero fills, apodizes, and Fourier transforms them to `Spec64k`
- Crops each spectrum into 4k tiles with 50% overlap (preserving clean/dirty pairing)
- Groups all crops by SNR (parsed from the filenames)

For each SNR:
- Concatenates all crops for that SNR
- Splits by clean/dirty pair into train/val (default 80% / 20%, no shuffle)

Builds one combined dataset with:
- `"train"` :: `SpectData{ComplexF32,2}`: all SNRs mixed together
- `"val_snr_XXX"` :: `SpectData{ComplexF32,2}`: one validation set per SNR
- `"meta"` :: `Dict{String,Any}`: parameters, counts, per SNR information

This format matches the expectations of the deep learning loader `load_multi_snr_loaders` and is meant to be the main entry point for training.

Basic usage:
```@text trainValMultiEg
julia make_train_val_multi_snr_from_synthetic_dir.jl ../examples/synthetic/
```

This will:
- Scan synthetic for `FIDs_*SNR*.jld2`
- Process all of them with default settings

Write a single file such as `TrainVal_multiSNR_crops4096_h2048.jld2` back into the same directory.

You can then point the training script directly to this file as:
```@text trainValMultiEg
julia spec_cleaner_train.jl TrainVal_multiSNR_crops4096_h2048.jld2
```

Custom output and parameters. All arguments except `input_dir` are optional:
```@text trainValMultiEg
julia make_train_val_multi_snr_from_synthetic_dir.jl <input_dir> [output_dir] [zf_pow2] [apod] [cropN] [hop] [frac_train]
```
- `input_dir`: directory with FID `.jld2` files (each with "batch" :: `SpectData`)
- `output_dir`: directory for the combined train/val file (default: `input_dir`)
- `zf_pow2`: zero fill length as power of two (default: 16 -> 65536 points)
- `apod`: exponential apodization constant in time domain (default: 0.5`pi`)
- `cropN`: crop length in points (default: 4096)
- `hop`: hop length between crops (default: cropN/2 -> 50% overlap)
- `frac_train`: fraction of clean/dirty pairs used for training in each SNR group (default: 0.8)

Example with custom settings:
```@text trainValMultiEg
# No overlap and 75% of pairs used for training
julia make_train_val_multi_snr_from_synthetic_dir.jl ../examples/synthetic/ ../out_multi 16 1.57 4096 4096 0.75
```

The resulting `TrainVal_multiSNR_*.jld2` file is ready to be used with `load_multi_snr_loaders`, which will create a shuffled "train" loader with mixed SNRs and non shuffled "val_snr_XXX" loaders for each SNR, for monitoring validation loss by noise level.

## 1.8 Building test only sets from synthetic FIDs (convenience script)
For user convenience, `NMRflux.jl` also provides a standalone script `make_test_from_synthetic_dir.jl` that builds test only datasets from synthetic FIDs generated by GenerateFIDs. Given an input directory of `.jld2` files with names starting with `FIDs_` and having `SpectData` stored under the key "batch" and rows ordered as `[clean1, dirty1, clean2, dirty2, ...]` and SNR encoded in the filename (e.g. `FIDs_16384_SNR-1000_0001.jld2`), the script:

- Loads all FID batches in the directory
- Zero fills, apodizes, and Fourier transforms them
- Crops each spectrum into 4k tiles with 50% overlap (preserving clean/dirty pairing)
- Groups all crops by SNR (parsed from the filenames)
- Concatenates all crops per SNR without any train/val splitting
- Writes one JLD2 file per SNR with:
  - "test" :: `SpectData{ComplexF32,2}`
  - "batch" :: `SpectData{ComplexF32,2}` (alias so inference scripts expecting "batch" work directly)
  - "meta" :: `Dict{String,Any}` with parameters, counts, and input file list

This is intended for final evaluation or for stress testing a trained model on large synthetic test sets.

Basic usage
```@text testSetEg
julia make_test_from_synthetic_dir.jl ../examples/synthetic/
```
Custom output and parameters. All arguments except `input_dir` are optional:
```@text testSetEg
julia make_test_from_synthetic_dir.jl <input_dir> [output_dir] [zf_pow2] [apod] [cropN] [hop]
```

- `input_dir`: directory with synthetic FID .jld2 files (each with "batch" :: SpectData)
- `output_dir`: directory for the test files (default: input_dir)
- `zf_pow2`: zero-fill length as power of two (default: 16 -> 65536 points)
- `apod`: exponential apodization constant in time domain (default: 0.5pi)
- `cropN`: crop length in points (default: 4096)
- `hop`: hop length between crops (default: cropN/2 -> 50% overlap)

Example with custom settings:
```@text testSetEg

# No overlap and custom apodization
julia make_test_from_synthetic_dir.jl ./synthetic_FIDs_test ./out_test 16 1.57 4096 4096
```

The resulting `Test_SNR-XXX_*.jld2` files can be used directly with the inference script for evaluating a trained denoiser across different SNR levels.