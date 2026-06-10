#import "Compiler";
#import "File";
#import "File_Utilities";
#import "Basic";
#import,file "ApilaSpirv.jai";
#import "Process";

// config
BUILD_FOLDER      :: "build";

#run {
   assert(OS == .LINUX, "only linux supported, cause i dont have dlls for windows");

   set_build_options_dc(.{ do_output = false });
   set_working_directory(#filepath);

   rootOptions := get_build_options();

   args := rootOptions.compile_time_command_line;

   w := compiler_create_workspace("Target Program (main)");
   make_directory_if_it_does_not_exist(BUILD_FOLDER);

   _options := get_build_options(w);
   copy_commonly_propagated_fields(rootOptions, *_options);
   // _options.output_executable_name = OUTPUT_EXE_NAME;
   // _options.output_path = BUILD_FOLDER;
   _options.output_type = .NO_OUTPUT;
   set_build_options(_options, w);

   options := GetBuildOptions(w);
   options.buildFolder = BUILD_FOLDER;
   SetBuildOptions(options, w);

   // compile
   {
      compiler_begin_intercept(w);
      defer compiler_end_intercept(w);

      add_build_file("shaders.jai", w);

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

   if (array_find(args, "test")) {
      ok := set_working_directory(BUILD_FOLDER);
      assert(ok);
      defer {
         ok := set_working_directory("..");
         assert(ok);
      }

      // :)) full path. becuase spirv-val has a bug which got fixed but not out yet. thats why.    - apila, 10/06/26
      files := file_list(".");
      for files {
         result := run_command(
            "/home/apila/source/SPIRV-Tools/build/tools/spirv-val",
            it,
            "--relax-block-layout",
            "--allow-localsizeid",
            "--target-env",
            "vulkan1.4",
            "--scalar-block-layout",
         );

         assert(result.type == .EXITED && result.exit_code == 0, "test failed! file: %, type: %, exit code: %", it, result.type, result.exit_code);
      }

      print("ALL TESTS PASS.\n");
   }
}
