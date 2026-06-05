// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math' show max;

import 'compound.dart';

/// A binding for a C union -
///
/// ```c
/// union C {
///   int a;
///   double b;
///   float c;
/// };
/// ```
/// The generated dart code is -
/// ```dart
/// final class Union extends ffi.Union{
///  @ffi.Int32()
///  int a;
///
///  @ffi.Double()
///  double b;
///
///  @ffi.Float()
///  float c;
///
/// }
/// ```
class Union extends Compound {
  Union({
    super.usr,
    super.originalName,
    required super.name,
    super.isIncomplete,
    super.pack,
    super.dartDoc,
    super.members,
    super.nativeType,
  }) : super(compoundType: CompoundType.union);

  @override
  String get llvmType => '*';

  @override
  int get sizeInBytes {
    int maxSize = 0;
    int maxAlign = 1;
    for (final member in members) {
      maxSize = max(maxSize, member.type.sizeInBytes);
      maxAlign = max(maxAlign, member.type.alignmentInBytes);
    }
    return (maxSize + maxAlign - 1) & ~(maxAlign - 1);
  }

  @override
  int get alignmentInBytes {
    int maxAlign = 1;
    for (final member in members) {
      maxAlign = max(maxAlign, member.type.alignmentInBytes);
    }
    return maxAlign;
  }
}
