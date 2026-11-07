//
// a shader that uses the f32 math intrinsics (sin, sqrt, abs, lerp...) has to #import "Math". their f32 overloads are the ones of Math, this module doesnt declare them (see MATH_MODULE_INTRINSICS).
// without the import the error doesnt point at the cause: abs(f32) resolves to the s32 overload and fails with "Number mismatch".
// Math also declares PI, so dont declare your own, use that one.
//
//
// the module is two parts:
//    the shader language (language.jai, cpu.jai): what a shader file imports, #import "ApilaSpirv".
//    the compiler (compiler.jai): turns the shaders into spirv. the metaprogram imports it with #import "ApilaSpirv"(METAPROGRAM = true), it gets the language too.
//

#module_parameters (METAPROGRAM := false, SPIRV_BUILDER_TYPE := SpirvBuilderType.Byte, DESCRIPTOR_STRIDE_MODE := DescriptorStrideMode.DescriptorSize) () {
   SpirvBuilderType :: enum {
      Byte;
      String;
   }

   // what the index of images[index] and samplers[index] counts
   DescriptorStrideMode :: enum {
      Byte;             // bytes, the index is the byte offset of the descriptor in the heap
      DescriptorSize;   // descriptors
   }
};

#load "language.jai";
#load "cpu.jai";

#if METAPROGRAM {
   #load "compiler.jai";
}
