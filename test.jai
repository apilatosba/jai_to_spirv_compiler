#import "Compiler";
#import "POSIX";
#import "Basic";
#import "Hash_Table";
#import "Hash";
#import "Math";

#run {
   set_build_options_dc(.{ do_output = false });

   factorial :: (x: int) -> int {
      if x < 2 return 1;
      return x * factorial(x - 1);
   }
   code := #code X :: #run factorial(3);
   root := compiler_get_nodes(code);
   cd := cast(*Code_Declaration)root;
   print("%\n", cd.expression.kind);
}
