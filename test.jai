#import "Compiler";
#import "POSIX";
#import "Basic";
#import "Hash_Table";
#import "Hash";
#import "Math";

#run {
   set_build_options_dc(.{ do_output = false });

   M :: struct { }
   tip := New(Type_Info_Pointer);
   tip.pointer_to = cast(*Type_Info) M;
   tip.type = .POINTER;
   tip.runtime_size = 8;

   for get_type_table() {
      print("it: %\n", it.*);
   }

   type := get_type(tip);
   print("%\n", type);
}
