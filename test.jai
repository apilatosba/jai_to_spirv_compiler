#import "Compiler";
#import "POSIX";
#import "Basic";
#import "Hash_Table";
#import "Hash";
#import "Math";

#run {
   set_build_options_dc(.{ do_output = false });

   t: Type = int;
   y: Type = t;

   print("%\n", y);
}
