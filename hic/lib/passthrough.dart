// Copyright (c) 2024 Fabrizio Guidotti
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import 'package:readers/readers.dart';

/// This is simply an alternative implementation of the passthrough system used in
/// the `readers` package. This might become a part of the package in the future.
/// It works pretty much the same way as the readers passthrough system, but it
/// is easier to use in this context.
///
/// We will eventually replace this with the official readers passthrough system.
extension PassthroughExt<T> on ParseIterator<T> {
  ParseIterator<Y> passthrough<Y>({
    void Function(T)? onComplete,
  }) sync* {
    for (final PartialParseResult<T> partial in this) {
      switch (partial) {
        case CompleteParseResult<T>(:final value):
          onComplete?.call(value);
          yield const PassthroughRequest();

        default:
          // This should be safe cast, since any other request should be a
          // subclass of PartialParseResult<Never>, hence the type parameter
          // will be inferred as Never.
          yield partial as PartialParseResult<Y>;
      }
    }
  }
}
