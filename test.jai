#import "Compiler";
#import "POSIX";
#import "Basic";
#import "Hash_Table";
#import "Hash";
#import "Math";
#import "Random";
#import "File";

f :: () {
   if (true) {
      print("xd\n");
   }
}

#run {
   set_build_options_dc(.{ do_output = false });

   code := code_of(f);
   root := compiler_get_nodes(code);
   header := cast(*Code_Procedure_Header) root;
   ci := cast(*Code_If) header.body_or_null.block.statements[0];

   print("%\n", ci.then_block);
}
