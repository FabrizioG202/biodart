# HiC Package

> [!NOTE]
> This package is still in development and some features may not be fully implemented. Good `dart` experience is recommended to use this package for now.

A pure-dart, zero-dependency* parser for the Hi-C file format. Currently it supports only V8 files ([format specification](https://github.com/aidenlab/hic-format/blob/master/HiCFormatV8.md), though support for V9 is being actively worked on. 

*The only dependencies are the `readers` package, which is used to streamline file reading, and the `genomics` package, which is used to provide a more general API for genomic data, and is part of this monorepo.

I developed this package to address some pain points with existing implementations, and mainly as the backbone to proprietary, closed source software. But the package itself is licensed (like the rest of the `biodart` project) as MIT, and it can be used as a standalone library to enable extremely fast parsing of Hi-C Contacts data. 

# Code Example

See a list of simple examples in the `example` folder. Although many of those are not yet implemented, they will be made available as soon as the underlying features are ready.

Once the package is more mature, I will provide examples and documentation for all the features. For now, here is a simple snippet that shows the basic usage including most of the features that are already implemented:

```dart

void main() {
  // Create a source to read the file.
  // For now, only the Version 8 of the format is supported.
  final source = SyncFileSource(File('../.data/v8.hic'))..open();

  // Create a HiC file object.
  // This is more of a container for the file, and does not
  // read the file itself.
  final file = HiCFile();

  // This is not optimal, I am working
  // on a way to make this better.
  // The funky syntax is due to the design of the library,
  // In particular, I am trying to make the library as
  // explicit as possible, so that the user knows what is
  // happening at each step, while also balancing the
  // verbosity of the code and performance.
  // and of the `readers` package, which is used to read the file.
  handleSync(
    (b) sync* {
      // Read the header and master index
      yield* file.readHeader(b).passthrough<void>();
      yield* file.readMasterIndex(b).passthrough<void>();

      // Stop the parser
      yield PartialParseResult.stop;
    },
    source,
    clearOnPassthrough: true,
  );

  // Now that the header is read, get chr1, using
  final chr1 = file.header.genome.getChromosome('1').asRange();

  // Read the contacts for chr1 at 50kb resolution
  // These are the observed counts, since normalization
  // is not ready yet.
  //
  // I am working on a way to make this better.
  final (
    Float32List data, //2D matrix, flattened to a 1D array (row-major order)
    (
      int width,
      int height,
    ) shape // Shape of the matrix,
  ) = handleSync(
    (b) => file.readContactsAsMatrix(
      b,
      chr1,
      chr1,
      const Resolution.bp(50000),
    ),
    source,
  );

  // Close the source.
  source.close();
}
```

# Performance
Throughout the code, there are performance pitfalls and bottlenecks, many of which I am aware of. The more obvious ones are marked as so and are being left in mainly due to ease of development and testing. They will be swiftly addressed as we move out of alpha.

# Credits
Particular praise goes to the [Aiden Lab](https://github.com/aidenlab) for developing the Hi-C format and for providing a detailed specification.