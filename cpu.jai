//
// the cpu implementations of the operators and the intrinsics.
// the structs that are shared between the cpu and the gpu use the vector types, so the operators and the intrinsics have to work on the cpu too (position += velocity).
// the backend never looks at their bodies, it generates the instructions from the operator node or from the call of the intrinsic. the bodies only run on the cpu.
// the functions that only make sense on the gpu (texture, TraceRay, the subgroup functions, the barriers...) still do nothing on the cpu.
//
// the generators below (the bodies are strings) are used by the #insert #run's in module.jai, the Cpu* functions are what the bodies call.
//

#scope_module

VECTOR_COMPONENT_NAMES :: string.["x", "y", "z", "w"];

// f32x3 is 3 components of f32. a scalar (or a matrix) is 1 component of itself
VectorShape :: (type: string) -> component: string, count: int {
   index := find_index_from_left(type, "x");
   if (index == -1 || begins_with(type, "mat")) return type, 1;
   return slice(type, 0, index), cast(int) (type[type.count - 1] - #char "0");
}

// the size of the matrix type (3 for mat3)
MatrixSize :: (type: string) -> int {
   assert(begins_with(type, "mat"), "type: %", type);
   return cast(int) (type[3] - #char "0");
}

// the body of a vector operator. the operands that are vectors are their components (a + b is .{ a.x + b.x, a.y + b.y, ... }), a scalar operand is broadcast.
// jai doesnt have % for floats, it is truncated like FRem.
VectorOperatorBody :: (op: string, type: string, leftIsVector: bool, rightIsVector: bool) -> string {
   component, count := VectorShape(type);
   isFloat := component == "f32" || component == "f64";

   components: [..] string;
   components.allocator = temp;
   for 0..count - 1 {
      left  := ifx leftIsVector  then tprint("a.%", VECTOR_COMPONENT_NAMES[it]) else "a";
      right := ifx rightIsVector then tprint("b.%", VECTOR_COMPONENT_NAMES[it]) else "b";
      if (op == "%" && isFloat) {
         array_add(*components, tprint("cast(%) CpuFloatRemainder(%, %)", component, left, right));
      } else {
         array_add(*components, tprint("% % %", left, op, right));
      }
   }

   return tprint("return .{ % };", join(..components, ", "));
}

// the body of the unary minus of a vector
VectorNegateBody :: (type: string) -> string {
   _, count := VectorShape(type);
   components: [..] string;
   components.allocator = temp;
   for 0..count - 1  array_add(*components, tprint("-a.%", VECTOR_COMPONENT_NAMES[it]));
   return tprint("return .{ % };", join(..components, ", "));
}

IntrinsicParameter :: struct {
   name:  string;
   type:  string;
}

// "(x: f32x3, minValue: f32) -> f32x3" is the parameters and the return type
ParseHeader :: (header: string) -> [..] IntrinsicParameter, returnType: string {
   parameters: [..] IntrinsicParameter;
   parameters.allocator = temp;

   close := find_index_from_left(header, ")");
   assert(header[0] == #char "(" && close != -1, "header: %", header);
   list := slice(header, 1, close - 1);
   if (trim(list)) {
      for split(list, ",") {
         found, name, type := split_from_left(it, #char ":");
         assert(found, "header: %", header);
         array_add(*parameters, .{ trim(name), trim(type) });
      }
   }

   returnType := "";
   arrow := find_index_from_right(header, "-> ");
   if (arrow != -1) returnType = trim(slice(header, arrow + 3, header.count - arrow - 3));
   return parameters, returnType;
}

// the expression of one component: the parameters that are vectors are replaced by their component (x is x.y for the y component). the scalar parameters stay as they are
ExpressionOfComponent :: (expression: string, parameters: [] IntrinsicParameter, componentName: string) -> string {
   builder: String_Builder;
   builder.allocator = temp;

   i := 0;
   while i < expression.count {
      if (!is_alpha(expression[i])) {
         append(*builder, expression[i]);
         i += 1;
         continue;
      }

      start := i;
      while i < expression.count && is_alnum(expression[i])  i += 1;
      identifier := slice(expression, start, i - start);
      append(*builder, identifier);

      // a member (v.x), not a parameter
      if (start > 0 && expression[start - 1] == #char ".") continue;

      for parameters {
         _, count := VectorShape(it.type);
         if (it.name == identifier && count > 1) {
            print_to_builder(*builder, ".%", componentName);
            break;
         }
      }
   }

   return builder_to_string(*builder);
}

// the body of a function whose result is the expression for each component. $R in the expression is the type of a component of the result
ComponentwiseBody :: (expression: string, parameters: [] IntrinsicParameter, returnType: string) -> string {
   component, count := VectorShape(returnType);
   e := replace(expression, "$R", component);
   if (count == 1) return tprint("return cast,no_check(%) (%);", returnType, e);

   components: [..] string;
   components.allocator = temp;
   for 0..count - 1  array_add(*components, tprint("cast,no_check(%) (%)", component, ExpressionOfComponent(e, parameters, VECTOR_COMPONENT_NAMES[it])));
   return tprint("return .{ % };", join(..components, ", "));
}

// the body of an overload of a math intrinsic (see MATH_INTRINSICS). header is the expanded signature.
// the scalar math is done in float64 with the functions of the Math module. the f32 ones would be ambiguous with the f32 overloads of the intrinsics.
MathIntrinsicCpuBody :: (name: string, header: string) -> string {
   parameters, returnType := ParseHeader(header);

   Componentwise :: (expression: string) -> string #expand {
      return ComponentwiseBody(expression, `parameters, `returnType);
   }

   // "a.x * b.x + a.y * b.y..."
   Sum :: (format: string) -> string #expand {
      _, count := VectorShape(`parameters[0].type);
      terms: [..] string;
      terms.allocator = temp;
      for 0..count - 1  array_add(*terms, tprint(format, VECTOR_COMPONENT_NAMES[it], VECTOR_COMPONENT_NAMES[it]));
      return join(..terms, " + ");
   }

   FLOAT64_FUNCTIONS :: string.["sin", "cos", "tan", "asin", "acos", "atan", "sqrt", "exp", "log", "floor", "ceil"];
   if (array_find(FLOAT64_FUNCTIONS, name)) return Componentwise(tprint("%(cast(float64) x)", name));

   if name == {
      case "atan2";        return Componentwise("atan2(cast(float64) y, cast(float64) x)");
      case "inversesqrt";  return Componentwise("1 / sqrt(cast(float64) x)");
      case "pow";          return Componentwise("pow(cast(float64) x, cast(float64) y)");
      case "exp2";         return Componentwise("pow(cast(float64) 2, cast(float64) x)");
      case "log2";         return Componentwise("log(cast(float64) x) / log(cast(float64) 2)");
      case "abs";          return Componentwise("ifx x <= 0 then 0 - x else x");
      case "sign";         return Componentwise("ifx x > 0 then 1 else ifx x < 0 then -1 else 0");
      case "round";        return Componentwise("CpuRoundEven(x)");
      case "trunc";        return Componentwise("CpuTrunc(x)");
      case "frac";         return Componentwise("x - floor(cast(float64) x)");
      case "min";          return Componentwise("ifx y < x then y else x");
      case "max";          return Componentwise("ifx x < y then y else x");
      case "clamp";        return Componentwise("ifx x < minValue then minValue else ifx x > maxValue then maxValue else x");
      case "saturate";     return Componentwise("ifx x < 0 then 0 else ifx x > 1 then 1 else x");
      case "lerp";         return Componentwise("a * (1 - t) + b * t");
      case "step";         return Componentwise("ifx x < edge then 0 else 1");
      case "smoothstep";   return Componentwise("CpuSmoothStep(edge0, edge1, x)");

      // a single invocation doesnt have neighbours to take the derivative with
      case "ddx";          #through;
      case "ddy";          #through;
      case "fwidth";       return Componentwise("0");

      case "asuint";       #through;
      case "asint";        #through;
      case "asfloat";      return Componentwise("(cast(*$R) *x).*");

      case "countbits";    return Componentwise("CpuBitCount(cast,no_check(u32) x)");
      case "reversebits";  return Componentwise("CpuBitReverse(cast,no_check(u32) x)");
      case "firstbithigh"; return Componentwise("CpuFindMsb(x)");
      case "firstbitlow";  return Componentwise("CpuFindLsb(cast,no_check(u32) x)");

      case "dot";          return tprint("return %;", Sum("a.% * b.%"));
      case "cross";        return "return .{ a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x };";
      case "length";       return tprint("return cast(%) sqrt(cast(float64) dot(x, x));", returnType);
      case "distance";     return "return length(a - b);";
      case "normalize";    return "return x / length(x);";
      case "reflect";      return "return incident - normal * (2 * dot(normal, incident));";
      case "refract";      return tprint("d := dot(normal, incident); k := 1 - eta * eta * (1 - d * d); if (k < 0) return .{}; return incident * eta - normal * (eta * d + cast(%) sqrt(cast(float64) k));", parameters[2].type);

      // the matrices are column major, m[i] is the column i
      case "transpose"; {
         n := MatrixSize(returnType);
         builder: String_Builder;
         builder.allocator = temp;
         print_to_builder(*builder, "r: %;", returnType);
         for column: 0..n - 1 {
            rows: [..] string;
            rows.allocator = temp;
            for row: 0..n - 1  array_add(*rows, tprint("m[%].%", row, VECTOR_COMPONENT_NAMES[column]));
            print_to_builder(*builder, " r[%] = .{ % };", column, join(..rows, ", "));
         }
         append(*builder, " return r;");
         return builder_to_string(*builder);
      }

      case "determinant";  return tprint("c := m; return CpuDeterminant(cast(*f32) *c, %);", MatrixSize(parameters[0].type));
      case "inverse";      return tprint("c := m; r: %; CpuInverse(cast(*f32) *c, cast(*f32) *r, %); return r;", returnType, MatrixSize(returnType));

      case "mul"; {
         builder: String_Builder;
         builder.allocator = temp;

         if (parameters[0].name == "a") {
            // matrix times matrix: each column of the result is a times the column of b
            n := MatrixSize(returnType);
            print_to_builder(*builder, "r: %;", returnType);
            for 0..n - 1  print_to_builder(*builder, " r[%] = mul(a, b[%]);", it, it);
            append(*builder, " return r;");
         } else if (parameters[0].name == "m") {
            // matrix times column vector: the columns weighted by the components of the vector
            n := MatrixSize(parameters[0].type);
            terms: [..] string;
            terms.allocator = temp;
            for 0..n - 1  array_add(*terms, tprint("m[%] * v.%", it, VECTOR_COMPONENT_NAMES[it]));
            print_to_builder(*builder, "return %;", join(..terms, " + "));
         } else {
            // row vector times matrix: the vector dotted with each column
            n := MatrixSize(parameters[1].type);
            terms: [..] string;
            terms.allocator = temp;
            for 0..n - 1  array_add(*terms, tprint("dot(v, m[%])", it));
            print_to_builder(*builder, "return .{ % };", join(..terms, ", "));
         }

         return builder_to_string(*builder);
      }

      case "packhalf2x16";    return "return CpuPackHalf2x16(v);";
      case "unpackhalf2x16";  return "return CpuUnpackHalf2x16(x);";
      case "packunorm4x8";    return "return CpuPackNorm(v, 8, false);";
      case "unpackunorm4x8";  return "return CpuUnpackNorm4x8(x, false);";
      case "packsnorm4x8";    return "return CpuPackNorm(v, 8, true);";
      case "unpacksnorm4x8";  return "return CpuUnpackNorm4x8(x, true);";
      case "packunorm2x16";   return "return CpuPackNorm(v, 16, false);";
      case "unpackunorm2x16"; return "return CpuUnpackNorm2x16(x, false);";
      case "packsnorm2x16";   return "return CpuPackNorm(v, 16, true);";
      case "unpacksnorm2x16"; return "return CpuUnpackNorm2x16(x, true);";
   }

   assert(false, "the math intrinsic % doesnt have a cpu implementation. header: %", name, header);
   return "";
}

// the body of an atomic (see the atomics in module.jai). the ones that combine the old value with value are a compare and swap loop
AtomicCpuBody :: (name: string) -> string {
   combined := "";
   if name == {
      case ATOMIC_EXCHANGE_FUNCTION_NAME;          return "return atomic_exchange(pointer, value);";
      case ATOMIC_COMPARE_EXCHANGE_FUNCTION_NAME;  return "success, old := compare_and_swap(pointer, comparator, value); return old;";
      case ATOMIC_ADD_FUNCTION_NAME;  combined = "old + value";
      case ATOMIC_MIN_FUNCTION_NAME;  combined = "ifx value < old then value else old";
      case ATOMIC_MAX_FUNCTION_NAME;  combined = "ifx old < value then value else old";
      case ATOMIC_AND_FUNCTION_NAME;  combined = "old & value";
      case ATOMIC_OR_FUNCTION_NAME;   combined = "old | value";
      case ATOMIC_XOR_FUNCTION_NAME;  combined = "old ^ value";
      case; assert(false, "the atomic % doesnt have a cpu implementation", name);
   }

   return tprint("old := atomic_load(pointer); while true { success, current := compare_and_swap(pointer, old, %); if (success) return old; old = current; } return old;", combined);
}

//
// what the bodies call
//

// hlsl rounds halfway cases to even
CpuRoundEven :: (x: float64) -> float64 {
   if (abs(x) >= 4503599627370496.0) return x; // 2^52, no fraction

   r := floor(x + 0.5);
   if (r - x == 0.5 && (cast(s64) r) % 2 != 0) r -= 1;
   return r;
}

CpuTrunc :: (x: float64) -> float64 {
   return ifx x < 0 then ceil(x) else floor(x);
}

// the sign of the left operand, like FRem and like % on integers in jai
CpuFloatRemainder :: (a: float64, b: float64) -> float64 {
   return a - b * CpuTrunc(a / b);
}

CpuSmoothStep :: (edge0: float64, edge1: float64, x: float64) -> float64 {
   t := (x - edge0) / (edge1 - edge0);
   if (t < 0) t = 0;
   if (t > 1) t = 1;
   return t * t * (3 - 2 * t);
}

CpuBitCount :: (x: u32) -> u32 {
   count: u32 = 0;
   for 0..31  if (x & (cast(u32) 1 << it)) count += 1;
   return count;
}

CpuBitReverse :: (x: u32) -> u32 {
   r: u32 = 0;
   for 0..31  if (x & (cast(u32) 1 << it)) r |= cast(u32) 1 << (31 - it);
   return r;
}

// the index of the lowest bit that is set, -1 if none
CpuFindLsb :: (x: u32) -> s32 {
   for 0..31  if (x & (cast(u32) 1 << it)) return cast(s32) it;
   return -1;
}

// the index of the highest bit that is set, -1 if none
CpuFindMsb :: (x: u32) -> s32 {
   for < 0..31  if (x & (cast(u32) 1 << it)) return cast(s32) it;
   return -1;
}

// for a negative number the highest bit that is not set, -1 if x is 0 or -1
CpuFindMsb :: (x: s32) -> s32 {
   bits := cast,no_check(u32) x;
   if (x < 0) bits = ~bits;
   return CpuFindMsb(bits);
}

// the matrices are n * n floats. the determinant and the inverse dont care if the floats are by column or by row (the result is in the same order).
CpuDeterminant :: (m: *f32, n: int) -> f32 {
   a: [16] float64;
   for 0..n * n - 1  a[it] = m[it];

   determinant: float64 = 1;
   for column: 0..n - 1 {
      pivot := column;
      for row: column + 1..n - 1  if (abs(a[row * n + column]) > abs(a[pivot * n + column])) pivot = row;
      if (a[pivot * n + column] == 0) return 0;

      if (pivot != column) {
         for 0..n - 1 {
            t := a[pivot * n + it];
            a[pivot * n + it] = a[column * n + it];
            a[column * n + it] = t;
         }
         determinant = -determinant;
      }

      determinant *= a[column * n + column];
      for row: column + 1..n - 1 {
         factor := a[row * n + column] / a[column * n + column];
         for column..n - 1  a[row * n + it] -= factor * a[column * n + it];
      }
   }

   return cast(f32) determinant;
}

// gauss jordan. the inverse of a singular matrix is not defined (like in spirv)
CpuInverse :: (m: *f32, result: *f32, n: int) {
   a: [16] float64;
   b: [16] float64;
   for 0..n * n - 1  a[it] = m[it];
   for 0..n - 1      b[it * n + it] = 1;

   for column: 0..n - 1 {
      pivot := column;
      for row: column + 1..n - 1  if (abs(a[row * n + column]) > abs(a[pivot * n + column])) pivot = row;

      if (pivot != column) {
         for 0..n - 1 {
            t := a[pivot * n + it];
            a[pivot * n + it] = a[column * n + it];
            a[column * n + it] = t;

            t = b[pivot * n + it];
            b[pivot * n + it] = b[column * n + it];
            b[column * n + it] = t;
         }
      }

      p := a[column * n + column];
      for 0..n - 1 {
         a[column * n + it] /= p;
         b[column * n + it] /= p;
      }

      for row: 0..n - 1 {
         if (row == column) continue;
         factor := a[row * n + column];
         for 0..n - 1 {
            a[row * n + it] -= factor * a[column * n + it];
            b[row * n + it] -= factor * b[column * n + it];
         }
      }
   }

   for 0..n * n - 1  result[it] = cast(f32) b[it];
}

// round to nearest even
CpuFloatToHalf :: (f: f32) -> u32 {
   bits := (cast(*u32) *f).*;
   sign := (bits >> 16) & 0x8000;
   exponent := cast(s32) ((bits >> 23) & 0xff) - 127 + 15;
   mantissa := bits & 0x7fffff;

   if ((bits & 0x7fffffff) > 0x7f800000) return sign | 0x7e00; // nan
   if (exponent >= 31) return sign | 0x7c00; // too big, infinity

   // denormal
   if (exponent <= 0) {
      if (exponent < -10) return sign;
      mantissa |= 0x800000;
      shift := cast(u32) (14 - exponent);
      half := mantissa >> shift;
      remainder := mantissa & ((cast(u32) 1 << shift) - 1);
      halfway := cast(u32) 1 << (shift - 1);
      if (remainder > halfway || (remainder == halfway && (half & 1) == 1)) half += 1;
      return sign | half;
   }

   // the rounding can carry into the exponent, the biggest half rounds to infinity
   half := (cast(u32) exponent << 10) | (mantissa >> 13);
   remainder := mantissa & 0x1fff;
   if (remainder > 0x1000 || (remainder == 0x1000 && (half & 1) == 1)) half += 1;
   return sign | half;
}

CpuHalfToFloat :: (h: u32) -> f32 {
   sign := (h & 0x8000) << 16;
   exponent := (h >> 10) & 0x1f;
   mantissa := h & 0x3ff;

   bits: u32;
   if (exponent == 0) {
      // zero or denormal (mantissa * 2^-24)
      value := cast(f32) mantissa / 16777216.0;
      return ifx sign != 0 then -value else value;
   } else if (exponent == 31) {
      bits = sign | 0x7f800000 | (mantissa << 13);
   } else {
      bits = sign | ((exponent + 112) << 23) | (mantissa << 13);
   }

   return (cast(*f32) *bits).*;
}

CpuPackHalf2x16 :: (v: f32x2) -> u32 {
   return CpuFloatToHalf(v.x) | (CpuFloatToHalf(v.y) << 16);
}

CpuUnpackHalf2x16 :: (x: u32) -> f32x2 {
   return .{ CpuHalfToFloat(x & 0xffff), CpuHalfToFloat(x >> 16) };
}

// the components are normalized to bits bits, the first one is in the lowest bits.
// unsigned: [0, 1] is [0, 2^bits - 1], signed: [-1, 1] is [-(2^(bits - 1) - 1), 2^(bits - 1) - 1]
CpuPackNorm :: (v: $T, bits: u32, signed: bool) -> u32 {
   components := cast(*f32) *v;
   count := size_of(T) / size_of(f32);
   scale := ifx signed then cast(float64) ((1 << (bits - 1)) - 1) else cast(float64) ((1 << bits) - 1);
   mask := (cast(u32) 1 << bits) - 1;

   result: u32 = 0;
   for 0..count - 1 {
      c := cast(float64) components[it];
      low := ifx signed then -1.0 else 0.0;
      if (c < low) c = low;
      if (c > 1)   c = 1;
      rounded := cast(s64) floor(c * scale + 0.5);
      result |= (cast,no_check(u32) rounded & mask) << (cast(u32) it * bits);
   }

   return result;
}

CpuUnpackNorm :: (x: u32, index: u32, bits: u32, signed: bool) -> f32 {
   value := (x >> (index * bits)) & ((cast(u32) 1 << bits) - 1);
   if (!signed) return cast(f32) (cast(float64) value / cast(float64) ((1 << bits) - 1));

   // sign extend
   s := cast(s64) value;
   if (value & (cast(u32) 1 << (bits - 1))) s -= cast(s64) 1 << bits;
   result := cast(float64) s / cast(float64) ((1 << (bits - 1)) - 1);
   if (result < -1) result = -1;
   return cast(f32) result;
}

CpuUnpackNorm4x8 :: (x: u32, signed: bool) -> f32x4 {
   return .{ CpuUnpackNorm(x, 0, 8, signed), CpuUnpackNorm(x, 1, 8, signed), CpuUnpackNorm(x, 2, 8, signed), CpuUnpackNorm(x, 3, 8, signed) };
}

CpuUnpackNorm2x16 :: (x: u32, signed: bool) -> f32x2 {
   return .{ CpuUnpackNorm(x, 0, 16, signed), CpuUnpackNorm(x, 1, 16, signed) };
}
