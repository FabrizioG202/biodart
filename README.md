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
In the spirit of the project, the only ~(third party) dependency this package has, is on the _readers_ package, required to provide a source and format-agnostic IO framework. 
 
# 📦 Packages
## genomics
Main module containing common genomics data structures and algorithms.

## hic
Module for reading [Hi-C](https://en.wikipedia.org/wiki/Hi-C_(genomic_analysis_technique)) contact maps. This module is being actively worked on and will be the first (format/workflow) to be released. 

> [!NOTE]
> The hic package is now in a semi-usable state. Refer to the subdirectory for more information.


# 🚀 Roadmap
- [ ] Fundamental data structures
    - [x] GenomicRange, Strand, Chromosome implementations
    - [x] GenomeReference implementation
- [ ] Format readers
    - [ ] FASTA
        - [ ] Header and sequence identifier parsing
        - [ ] Nucleotide sequence reading
        - [ ] Multiline sequence handling
        - [ ] Sequence validation
        - [ ] Full Unit Tests.
    - [ ] FASTQ
        - [ ] Header and sequence identifier parsing
        - [ ] Nucleotide sequence reading
        - [ ] Quality score parsing
        - [ ] Quality score validation
        - [ ] Full Unit Tests.
    - [ ] SAM/BAM: *Roadmap not yet created*
    - [ ] VCF: *Roadmap not yet created*
    - [ ] GFF: *Roadmap not yet created*
    - [ ] BED: *Roadmap not yet created*
    - [x] Hi-C formats
        - [x] V8 format support
        - [ ] Legacy version support
        - [ ] V9 format implementation
- [ ] Common algorithms
    - [ ] Sequence alignment: *Roadmap not yet created*

- [ ] Testing
    - [ ] Unit test coverage
    - [ ] Integration testing
    - [ ] Performance benchmarks
