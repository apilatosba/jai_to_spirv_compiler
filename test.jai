#import "Compiler";
#import "POSIX";
#import "Basic";
#import "Hash_Table";
#import "Hash";
#import "Math";

#run {
   set_build_options_dc(.{ do_output = false });

   code := #code a.b.c;
   root := compiler_get_nodes(code);

   cbo := root.(*Code_Binary_Operator);
   print("%\n", cbo.left.(*Code_Binary_Operator).right.(*Code_Ident).name);
}
