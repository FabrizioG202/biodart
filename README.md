# BioDart
An effort to develop a Bioinformatics Toolkit in pure-dart. The goal of this project is to leverage the _performance_, _ease of use_ and especially _portability_ of Dart to create tools that can be used across multiple platforms with minimal to no dependency.


# ✨ TLDR: Features

- Pure Dart implementation for cross-platform compatibility
- Fully available on linux, macos, windows, web and mobile
- Minimal dependencies 
- Optimized for performance
- Type-safe implementations of common bioinformatics algorithms and data structures

# Rationale / Why?
Dart is a relatively modern language, with a strong type system, and a focus on performance. It is also a language that is easy to learn and use, and has a strong community backing it. This repo exists to try and ease the dependency hell that bioinformatics tools often face. 

> [!IMPORTANT]
> The contents of this repo are still in very early stages of development and are not yet ready for production use. Refer to the [Roadmap](#roadmap) for more information.

> [!Note] 
> This project is currently maintained only by me, mirroring the requirements of personal projects, but features can be requested and contributions are welcome. Feel free to get in contact if you would like to help development.

# Disclaimer:
In the spirit of the project, the only third party dependency this package has, is on the _readers_ package, which is required for ease of use. 
 
# 📦 Packages
## genomics
Main module containing common genomics data structures and algorithms.

## hic
Module for reading [Hi-C](https://en.wikipedia.org/wiki/Hi-C_(genomic_analysis_technique)) contact maps. This module is being actively worked on and will be the first (format/workflow) to be released. 

> [!NOTE]
> The hic package is now in a semi-usable state. Refer to the subdirectory for more information.


# 🚀 Roadmap
- [ ] Implement fundamental data structures
    - [x] GenomicRange, Strand, Chromosome
    - [x] GenomeReference
- [ ] Format readers
    - [ ] FASTA
    - [ ] FASTQ
    - [ ] SAM/BAM
    - [ ] VCF
    - [ ] GFF
    - [ ] BED
    - [x] Hi-C (V8 support is public), older versions and V9 support is being worked on.
- [ ] Implement common algorithms
    - [ ] Needleman-Wunsch
    - [ ] Smith-Waterman

- [ ] Add tests for all modules
