#import "Compiler";
#import "POSIX";
#import "Basic";
#import "Hash_Table";
#import "Hash";
#import "Math";
#import "Random";
#import "File";

#run {
   set_build_options_dc(.{ do_output = false });

   a: int = 5;
   b: s32;
   b = (*a).(*s32).*;

   print("%\n", b);
}
