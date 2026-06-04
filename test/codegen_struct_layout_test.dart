import 'package:test/test.dart';

import 'package:ffigen_js/src/jsgen/code_generator.dart';
import 'package:ffigen_js/src/jsgen/code_generator/writer.dart';

/// Helper to build a [Struct] with the given [members] for layout testing.
Struct _struct(String name, List<Member> members) {
  return Struct(name: name, members: members);
}

Member _member(String name, Type type) {
  return Member(name: name, type: type);
}

NativeType get _double => NativeType(SupportedNativeType.double);
NativeType get _int32 => NativeType(SupportedNativeType.int32);
NativeType get _int8 => NativeType(SupportedNativeType.int8);
NativeType get _intPtr => NativeType(SupportedNativeType.intPtr);

void main() {
  group('NativeType sizes and alignment', () {
    test('double is 8 bytes with 8-byte alignment', () {
      final t = NativeType(SupportedNativeType.double);
      expect(t.sizeInBytes, 8);
      expect(t.alignmentInBytes, 8);
    });

    test('int32 is 4 bytes with 4-byte alignment', () {
      final t = NativeType(SupportedNativeType.int32);
      expect(t.sizeInBytes, 4);
      expect(t.alignmentInBytes, 4);
    });

    test('int8 is 1 byte with 1-byte alignment', () {
      final t = NativeType(SupportedNativeType.int8);
      expect(t.sizeInBytes, 1);
      expect(t.alignmentInBytes, 1);
    });

    test('intPtr is 4 bytes for wasm32', () {
      final t = NativeType(SupportedNativeType.intPtr);
      expect(t.sizeInBytes, 4);
      expect(t.alignmentInBytes, 4);
    });

    test('uintPtr is 4 bytes for wasm32', () {
      final t = NativeType(SupportedNativeType.uintPtr);
      expect(t.sizeInBytes, 4);
      expect(t.alignmentInBytes, 4);
    });
  });

  group('Struct size and alignment — simple structs', () {
    // struct PointDto { double x; double y; };
    // wasm32: size=16, align=8
    test('PointDto: two doubles → size 16, align 8', () {
      final s = _struct('PointDto', [
        _member('x', _double),
        _member('y', _double),
      ]);
      expect(s.sizeInBytes, 16);
      expect(s.alignmentInBytes, 8);
    });

    // struct PoseDto { PointDto point; double angle; };
    // PointDto is 16 bytes with 8-byte alignment.
    // wasm32: 0: point(16) + 16: angle(8) = 24, align=8
    test('PoseDto: PointDto + double → size 24, align 8', () {
      final pointDto = _struct('PointDto', [
        _member('x', _double),
        _member('y', _double),
      ]);
      final s = _struct('PoseDto', [
        _member('point', pointDto),
        _member('angle', _double),
      ]);
      expect(s.sizeInBytes, 24);
      expect(s.alignmentInBytes, 8);
    });
  });

  group('Struct size and alignment — inline structs', () {
    // struct LineSegmentDto { PointDto start; PointDto end; };
    // wasm32: 0: start(16) + 16: end(16) = 32, align=8
    test('LineSegmentDto: two PointDtos → size 32, align 8', () {
      final pointDto = _struct('PointDto', [
        _member('x', _double),
        _member('y', _double),
      ]);
      final s = _struct('LineSegmentDto', [
        _member('start', pointDto),
        _member('end', pointDto),
      ]);
      expect(s.sizeInBytes, 32);
      expect(s.alignmentInBytes, 8);
    });

    // struct CircularArcDto { PointDto start; PointDto center; double sweep_angle; };
    // wasm32: 0: start(16) + 16: center(16) + 32: sweep_angle(8) = 40, align=8
    test('CircularArcDto: two PointDtos + double → size 40, align 8', () {
      final pointDto = _struct('PointDto', [
        _member('x', _double),
        _member('y', _double),
      ]);
      final s = _struct('CircularArcDto', [
        _member('start', pointDto),
        _member('center', pointDto),
        _member('sweep_angle', _double),
      ]);
      expect(s.sizeInBytes, 40);
      expect(s.alignmentInBytes, 8);
    });

    // struct CurveDto { LineSegmentDto line_segment; CircularArcDto circular_arc; };
    // wasm32: 0: line_segment(32) + 32: circular_arc(40) = 72, align=8
    test('CurveDto: LineSegmentDto + CircularArcDto → size 72, align 8', () {
      final pointDto = _struct('PointDto', [
        _member('x', _double),
        _member('y', _double),
      ]);
      final lineSegmentDto = _struct('LineSegmentDto', [
        _member('start', pointDto),
        _member('end', pointDto),
      ]);
      final circularArcDto = _struct('CircularArcDto', [
        _member('start', pointDto),
        _member('center', pointDto),
        _member('sweep_angle', _double),
      ]);
      final s = _struct('CurveDto', [
        _member('line_segment', lineSegmentDto),
        _member('circular_arc', circularArcDto),
      ]);
      expect(s.sizeInBytes, 72);
      expect(s.alignmentInBytes, 8);
    });
  });

  group('Struct size and alignment — padding between fields', () {
    // struct VelocityDto { double value; VelocityType type; };
    // VelocityType is an enum (int32).
    // wasm32: 0: value(8) + 8: type(4) + 4 tail padding = 16, align=8
    test('VelocityDto: double + int32 (enum) → size 16, align 8', () {
      final s = _struct('VelocityDto', [
        _member('value', _double),
        _member('type', _int32),
      ]);
      expect(s.sizeInBytes, 16);
      expect(s.alignmentInBytes, 8);
    });

    // Reverse order: int32 then double requires padding.
    // struct { int a; double b; };
    // wasm32: 0: a(4) + 4 padding + 8: b(8) = 16, align=8
    test('int32 + double → 4 bytes padding inserted, size 16', () {
      final s = _struct('TestStruct', [
        _member('a', _int32),
        _member('b', _double),
      ]);
      expect(s.sizeInBytes, 16);
      expect(s.alignmentInBytes, 8);
    });

    // struct { int a; int b; double c; };
    // wasm32: 0: a(4) + 4: b(4) + 8: c(8) = 16, align=8 (no padding, a+b fill 8 bytes)
    test('two int32 + double → no padding needed, size 16', () {
      final s = _struct('TestStruct', [
        _member('a', _int32),
        _member('b', _int32),
        _member('c', _double),
      ]);
      expect(s.sizeInBytes, 16);
      expect(s.alignmentInBytes, 8);
    });

    // struct { int a; double b; int c; };
    // wasm32: 0: a(4) + 4 pad + 8: b(8) + 16: c(4) + 4 tail pad = 24, align=8
    test('int32 + double + int32 → padding before double and tail padding, size 24', () {
      final s = _struct('TestStruct', [
        _member('a', _int32),
        _member('b', _double),
        _member('c', _int32),
      ]);
      expect(s.sizeInBytes, 24);
      expect(s.alignmentInBytes, 8);
    });
  });

  group('Struct size and alignment — complex nested struct', () {
    // SegmentDescriptionDto from the C++ header:
    //   char* id;              // ptr: 4 bytes, align 4, offset 0
    //   char* label;           // ptr: 4 bytes, offset 4
    //   CurveType curve_type;  // enum(int32): 4 bytes, offset 8
    //   CurveDto curve;        // 72 bytes, align 8 → pad to offset 16
    //   LinearDirection dir;   // enum(int32): 4 bytes, offset 88
    //   ToolParameterDto* tp;  // ptr: 4 bytes, offset 92
    //   int tp_size;           // int32: 4 bytes, offset 96
    //   VelocityDto vel_limit; // 16 bytes, align 8 → pad to offset 104
    //   double pre_pad_dist;   // 8 bytes, offset 120
    //   VelocityDto pre_pad_vl;// 16 bytes, offset 128
    //   double post_pad_dist;  // 8 bytes, offset 144
    //   VelocityDto post_pad_vl;// 16 bytes, offset 152
    //   int backward_transit;  // 4 bytes, offset 168
    //   double turning_radius; // 8 bytes, align 8 → pad to offset 176
    //   Total: 176 + 8 = 184, align=8
    test('SegmentDescriptionDto → size 184, align 8', () {
      final pointDto = _struct('PointDto', [
        _member('x', _double),
        _member('y', _double),
      ]);
      final lineSegmentDto = _struct('LineSegmentDto', [
        _member('start', pointDto),
        _member('end', pointDto),
      ]);
      final circularArcDto = _struct('CircularArcDto', [
        _member('start', pointDto),
        _member('center', pointDto),
        _member('sweep_angle', _double),
      ]);
      final curveDto = _struct('CurveDto', [
        _member('line_segment', lineSegmentDto),
        _member('circular_arc', circularArcDto),
      ]);
      final velocityDto = _struct('VelocityDto', [
        _member('value', _double),
        _member('type', _int32),
      ]);

      final s = _struct('SegmentDescriptionDto', [
        _member('id', _intPtr), // char* → wasm32 pointer = 4
        _member('label', _intPtr), // char* → wasm32 pointer = 4
        _member('curve_type', _int32), // enum = int32
        _member('curve', curveDto), // 72 bytes, needs 8-byte align
        _member('direction', _int32), // enum = int32
        _member('tool_parameters', _intPtr), // pointer = 4
        _member('tool_parameters_size', _int32),
        _member('velocity_limit', velocityDto),
        _member('pre_padding_distance', _double),
        _member('pre_padding_velocity_limit', velocityDto),
        _member('post_padding_distance', _double),
        _member('post_padding_velocity_limit', velocityDto),
        _member('backward_transit', _int32),
        _member('turning_radius', _double),
      ]);
      expect(s.sizeInBytes, 184);
      expect(s.alignmentInBytes, 8);
    });
  });

  group('Enum codegen', () {
    test('EnumClass with generateAsInt produces abstract class with static const int', () {
      final enumClass = EnumClass(
        name: 'VelocityType',
        nativeType: _int32,
        generateAsInt: true,
        enumConstants: [
          EnumConstant(originalName: 'VELOCITY_TYPE_NONE', name: 'VELOCITY_TYPE_NONE', value: 0),
          EnumConstant(
              originalName: 'VELOCITY_TYPE_LINEAR', name: 'VELOCITY_TYPE_LINEAR', value: 1),
          EnumConstant(
              originalName: 'VELOCITY_TYPE_ANGULAR', name: 'VELOCITY_TYPE_ANGULAR', value: 2),
        ],
      );
      final writer = Writer(
        bindings: [],
        typeBindings: [],
        className: 'TestBindings',
        silenceEnumWarning: true,
        nativeEntryPoints: [],
      );
      final output = enumClass.toBindingString(writer).string;

      expect(output, contains('abstract class VelocityType'));
      expect(output, contains('static const int VELOCITY_TYPE_NONE = 0;'));
      expect(output, contains('static const int VELOCITY_TYPE_LINEAR = 1;'));
      expect(output, contains('static const int VELOCITY_TYPE_ANGULAR = 2;'));
      // Should NOT be a Dart enum
      expect(output, isNot(contains('enum VelocityType')));
    });

    test('EnumClass has size 4 and alignment 4', () {
      final enumClass = EnumClass(
        name: 'CurveType',
        nativeType: _int32,
        generateAsInt: true,
        enumConstants: [],
      );
      expect(enumClass.sizeInBytes, 4);
      expect(enumClass.alignmentInBytes, 4);
    });
  });

  group('Inline struct setter codegen', () {
    test('setter for inline struct uses _copyBytes, not setValue', () {
      final pointDto = _struct('PointDto', [
        _member('x', _double),
        _member('y', _double),
      ]);
      final lineSegmentDto = _struct('LineSegmentDto', [
        _member('start', pointDto),
        _member('end', pointDto),
      ]);
      final writer = Writer(
        bindings: [],
        typeBindings: [],
        className: 'TestBindings',
        silenceEnumWarning: true,
        nativeEntryPoints: [],
      );
      final output = lineSegmentDto.toBindingString(writer).string;

      // Inline struct setters should use _copyBytes
      expect(output, contains('_copyBytes(this.address.addr + 0, val.address.addr, 16)'));
      expect(output, contains('_copyBytes(this.address.addr + 16, val.address.addr, 16)'));
      // Should NOT use setValue for struct fields
      expect(
          output,
          isNot(contains(
              "setValue(Pointer<LineSegmentDto>(this.address.addr + 0), val.address.toJS, '*')")));
    });

    test('setter for primitive fields still uses setValue', () {
      final pointDto = _struct('PointDto', [
        _member('x', _double),
        _member('y', _double),
      ]);
      final writer = Writer(
        bindings: [],
        typeBindings: [],
        className: 'TestBindings',
        silenceEnumWarning: true,
        nativeEntryPoints: [],
      );
      final output = pointDto.toBindingString(writer).string;

      // Primitive setters should use setValue
      expect(output,
          contains("setValue(Pointer<PointDto>(this.address.addr + 0), val.toJS, 'double')"));
      expect(output,
          contains("setValue(Pointer<PointDto>(this.address.addr + 8), val.toJS, 'double')"));
      // Should NOT use _copyBytes for primitives
      expect(output, isNot(contains('_copyBytes')));
    });

    test('setter for enum field uses setValue with i32', () {
      final enumType = EnumClass(
        name: 'VelocityType',
        nativeType: _int32,
        generateAsInt: true,
        enumConstants: [
          EnumConstant(originalName: 'NONE', name: 'NONE', value: 0),
        ],
      );
      final velocityDto = _struct('VelocityDto', [
        _member('value', _double),
        _member('type', enumType),
      ]);
      final writer = Writer(
        bindings: [],
        typeBindings: [],
        className: 'TestBindings',
        silenceEnumWarning: true,
        nativeEntryPoints: [],
      );
      final output = velocityDto.toBindingString(writer).string;

      // Enum fields are ints, should use setValue with i32
      expect(output,
          contains("setValue(Pointer<VelocityDto>(this.address.addr + 8), val.toJS, 'i32')"));
      // Enum getter should return int
      expect(output, contains('int get type'));
      expect(output, contains('set type(int val)'));
    });
  });

  group('Field offset calculation', () {
    test('SegmentDescriptionDto field offsets match wasm32 layout', () {
      final pointDto = _struct('PointDto', [
        _member('x', _double),
        _member('y', _double),
      ]);
      final lineSegmentDto = _struct('LineSegmentDto', [
        _member('start', pointDto),
        _member('end', pointDto),
      ]);
      final circularArcDto = _struct('CircularArcDto', [
        _member('start', pointDto),
        _member('center', pointDto),
        _member('sweep_angle', _double),
      ]);
      final curveDto = _struct('CurveDto', [
        _member('line_segment', lineSegmentDto),
        _member('circular_arc', circularArcDto),
      ]);
      final velocityDto = _struct('VelocityDto', [
        _member('value', _double),
        _member('type', _int32),
      ]);

      final s = _struct('SegmentDescriptionDto', [
        _member('id', _intPtr),
        _member('label', _intPtr),
        _member('curve_type', _int32),
        _member('curve', curveDto),
        _member('direction', _int32),
        _member('tool_parameters', _intPtr),
        _member('tool_parameters_size', _int32),
        _member('velocity_limit', velocityDto),
        _member('pre_padding_distance', _double),
        _member('pre_padding_velocity_limit', velocityDto),
        _member('post_padding_distance', _double),
        _member('post_padding_velocity_limit', velocityDto),
        _member('backward_transit', _int32),
        _member('turning_radius', _double),
      ]);

      final writer = Writer(
        bindings: [],
        typeBindings: [],
        className: 'TestBindings',
        silenceEnumWarning: true,
        nativeEntryPoints: [],
      );
      final output = s.toBindingString(writer).string;

      // Verify field offsets in generated code.
      // id: offset 0 (ptr, 4 bytes)
      expect(output, contains('this.address.addr + 0), val.toJS'));
      // label: offset 4 (ptr, 4 bytes)
      expect(output, contains('this.address.addr + 4), val.toJS'));
      // curve_type: offset 8 (int32, 4 bytes)
      expect(output, contains('this.address.addr + 8), val.toJS'));
      // curve: offset 16 (CurveDto, 72 bytes, needs 8-byte align → 12 padded to 16)
      expect(output, contains('_copyBytes(this.address.addr + 16, val.address.addr, 72)'));
      // direction: offset 88 (int32 after 72-byte struct at 16)
      expect(output, contains('this.address.addr + 88), val.toJS'));
      // tool_parameters: offset 92 (ptr)
      expect(output, contains('this.address.addr + 92), val.toJS'));
      // tool_parameters_size: offset 96 (int32)
      expect(output, contains('this.address.addr + 96), val.toJS'));
      // velocity_limit: offset 104 (VelocityDto, 16 bytes, needs 8-byte align → 100 padded to 104)
      expect(output, contains('_copyBytes(this.address.addr + 104, val.address.addr, 16)'));
      // pre_padding_distance: offset 120 (double)
      expect(output, contains('this.address.addr + 120), val.toJS'));
      // pre_padding_velocity_limit: offset 128 (VelocityDto)
      expect(output, contains('_copyBytes(this.address.addr + 128, val.address.addr, 16)'));
      // post_padding_distance: offset 144 (double)
      expect(output, contains('this.address.addr + 144), val.toJS'));
      // post_padding_velocity_limit: offset 152 (VelocityDto)
      expect(output, contains('_copyBytes(this.address.addr + 152, val.address.addr, 16)'));
      // backward_transit: offset 168 (int32)
      expect(output, contains('this.address.addr + 168), val.toJS'));
      // turning_radius: offset 176 (double, needs 8-byte align → 172 padded to 176)
      expect(output, contains('this.address.addr + 176), val.toJS'));
    });
  });
}
