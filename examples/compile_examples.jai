#import "Compiler";
#import "File";
#import "File_Utilities";
#import "Basic";
#import,file "../ApilaSpirv.jai";
#import "Process";

#run {
   set_build_options_dc(.{ do_output = false });
   set_working_directory(#filepath);

   rootOptions := get_build_options();

   w := compiler_create_workspace("shader examples");

   _options := get_build_options(w);
   copy_commonly_propagated_fields(rootOptions, *_options);
   _options.output_type = .NO_OUTPUT;
   _options.import_path = rootOptions.import_path;

   set_build_options(_options, w);

   // compile
   {
      compiler_begin_intercept(w);
      defer compiler_end_intercept(w);

      add_build_file("examples.jai", w);

      while true {
         message := compiler_wait_for_message();
         ProcessMessage(message);

         if message.kind == {
            case .COMPLETE; {
               mc := cast(*Message_Complete) message;

               if mc.error_code != .NONE {
                  compiler_set_workspace_status(.FAILED, w);
                  exit(69);
               }
               break;
            }
         }
      }
   }
}
