
println :: (format_string: string, args: .. Any) -> bytes_printed: s64 { 
    builder: String_Builder;
    defer free_buffers(*builder);

    print_to_builder(*builder, format_string, ..args);
	print_to_builder(*builder, "\n");
    written := write_builder(*builder);

    return written;
} @PrintLike

#scope_file
#import "Basic";