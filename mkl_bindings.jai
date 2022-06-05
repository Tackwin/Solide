#import "Compiler";
#import "Bindings_Generator";
#import "Basic";

main :: () {
	output_filename := "src/mkl.jai";
	opts: Generate_Bindings_Options;
	{
		using opts;
		array_add(*libpaths, "lib");
		array_add(*libnames, "mkl_core");
		array_add(*libnames, "mkl_intel_ilp64");
		array_add(*libnames, "mkl_sequential");
		array_add(*system_include_paths, GENERATOR_DEFAULT_SYSTEM_INCLUDE_PATH);
		array_add(*include_paths, "mkl_include");
		array_add(*source_files, "mkl_include/mkl.h");
		array_add(*extra_clang_arguments, "-x", "c++", "-DMKL_ILP64");
	}

	success := generate_bindings(opts, output_filename);
	print("%\n", success);
}