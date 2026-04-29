#import "Compiler";
#import "POSIX";
#import "Basic";
#import "Hash_Table";
#import "Hash";
#import "Math";
#import "Random";
#import "File";
Q :: #import "Queue";

q: Q.Queue(int);

#run {
   set_build_options_dc(.{ do_output = false });

   code := code_of(Q.Enqueue(*q, 5));
   root := compiler_get_nodes(code);
   cpc := cast(*Code_Procedure_Call) root;
   cbo := cast(*Code_Binary_Operator) cpc.procedure_expression;

   print("%\n", cbo.right.kind);
}

