#import "Compiler";
#import "Basic";

#run build();

build :: () {
	set_build_options_dc(.{ do_output = true });

	opts := get_build_options();
	opts.output_type = .EXECUTABLE;
	opts.output_executable_name = "Solide";

	import : [..]string;
	array_add(*import, ..opts.import_path);
	array_add(*import, "./");
	opts.import_path = import;

	w := compiler_create_workspace("Solide");
	set_build_options(opts, w);

	compiler_begin_intercept(w);

	add_build_file("src/main.jai", w);

	while true {
		message := compiler_wait_for_message();

		if message.kind == .COMPLETE break;
	}

	compiler_end_intercept(w);
}