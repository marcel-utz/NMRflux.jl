#!/usr/bin/env julia
# -*- coding: utf-8 -*-

###########################################################################
# File:                make.jl
# Project:             NMRflux.jl - NMR Processing, Simulation, and ML Tools
# Author:              Manaz Kaleel
# Created:             2025-11-24
# Last Modified:       2026-01-12
#
# Description:
#   This script builds the NMRflux.jl documentation using Documenter.jl.
#   It collects all docstrings, renders the manual, generates the API
#   reference, and produces a complete HTML documentation site.
###########################################################################

push!(LOAD_PATH, "../src/")

using NMRflux
using Documenter
using Documenter.Remotes

# -------------------------------------------------------------------------
# Configuration: define project metadata and documentation settings
# -------------------------------------------------------------------------

makedocs(
    sitename = "NMRflux.jl",
    authors  = "Manaz Kaleel & Marcel Utz",
    clean    = true,

    repo = Remotes.GitHub("marcel-utz", "NMRflux.jl"),

    modules = [NMRflux],

    format = Documenter.HTML(
        prettyurls   = false,   # set to true later for GitHub Pages
        collapselevel = 2,
        assets       = String[],
    ),

    pages = [
        "Home" => "index.md",

        "Manual" => [
            "Getting Started" => "QuickStart.md",
        ],

        "Advanced topics" => [
            "Data Loading" => "DataLoading.md",
            "SpectData" => "SpectData.md",
            "Data Processing" => "DataProcessing.md",
            "Spin Dynamics and FID generation" => "SpinDynamics.md",
            "RINSE" => "RINSE.md",
        ],

        "Development" => [
            "Roadmap to 1.0" => "NMRflux-1.0.md",
        ],

        "Reference" => [
            "API" => "Reference.md",
        ],
    ],

    # For now, don't fail if some docstrings are not yet included in the manual
    checkdocs = :none,
)

# ------------------------------------------------------------------------------
# Deploy docs needed when pushing to GitHub Pages
# Uncomment when GitHub CI is set up:
# deploydocs(
#     repo   = "https://github.com/marcel-utz/NMRflux.jl.git",
#     target = "build",
# )
# ------------------------------------------------------------------------------
