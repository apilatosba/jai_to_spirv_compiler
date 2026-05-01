#import "Compiler";
#import "POSIX";
#import "Basic";
#import "Hash_Table";
#import "Hash";
#import "Math";
#import "Random";
#import "File";

GenerateArray :: () -> [] u8 {
   result := NewArray(64, u8);
   for * result {
      it.* = xx it_index;
   }

   // for result {
   //    print("%\n", it);
   // }

   return result;
}

MY_ARRAY :: #run GenerateArray();

#run {
   // set_build_options_dc(.{ do_output = false });

}

main :: () {
   for MY_ARRAY {
      print("%\n", it);
   }
}

