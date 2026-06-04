// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math' show max;

import 'compound.dart';
import 'writer.dart';

/// A binding for C Struct.
///
/// For a C structure -
/// ```c
/// struct C {
///   int a;
///   double b;
///   int c;
/// };
/// ```
/// The generated dart code is -
/// ```dart
/// final class Struct extends Struct {
///  int a;
///
///  double b;
///
///  int c;
///
/// }
/// ```
class Struct extends Compound {
  Struct({
    super.usr,
    super.originalName,
    required super.name,
    super.isIncomplete,
    super.pack,
    super.dartDoc,
    super.members,
    super.isInternal,
    super.nativeType,
  }) : super(compoundType: CompoundType.struct);

  @override
  String get llvmType => '*';

  @override
  int get alignmentInBytes {
    int maxAlign = 1;
    for (final member in members) {
      maxAlign = max(maxAlign, member.type.alignmentInBytes);
    }
    return maxAlign;
  }

  @override
  int get sizeInBytes {
    int size = 0;
    int maxAlign = 1;
    for (final member in members) {
      final align = member.type.alignmentInBytes;
      maxAlign = max(maxAlign, align);
      // Pad to alignment before this field
      size = (size + align - 1) & ~(align - 1);
      size += member.type.sizeInBytes;
    }
    // Tail padding: struct size is a multiple of its largest member alignment
    size = (size + maxAlign - 1) & ~(maxAlign - 1);
    return size;
  }
}
