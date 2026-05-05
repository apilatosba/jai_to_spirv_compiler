#import "Compiler";
#import "POSIX";
#import "Basic";
#import "Hash_Table";
#import "Hash";
#import "Math";
#import "Random";
#import "File";

c :: (obj: $T) -> Any #expand {
   copy := New(T);
   copy.* = obj;

   result: Any;
   result.value_pointer = copy;
   result.type = type_info(T);
   return result;
}

#run {
   set_build_options_dc(.{ do_output = false });

   a := 10;
   b := 11;

   GetValue :: (i: int) -> int {
      return i;
   }

   array: [..] Any;

   for a..b {
      value: int = GetValue(it);
      array_add(*array, c(value));
   }

   for array {
      print("%\n", it);
   }
}
