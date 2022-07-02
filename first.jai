#import "Compiler";
#import "String";
#import "Basic";
#import "Hash_Table";

#run build();

Action :: struct {
	name: string;
	has_trigger: bool;
	has_compute: bool;
	index: int;
}

actions : Table(string, Action);

build :: () {
	set_build_options_dc(.{ do_output = false });

	opts := get_build_options();
	opts.output_type = .EXECUTABLE;
	opts.output_executable_name = "Solide";

	import : [..]string;
	array_add(*import, ..opts.import_path);
	array_add(*import, "./");
	opts.import_path = import;
	opts.entry_point_name = "main";

	w := compiler_create_workspace("Solide");
	set_build_options(opts, w);

	compiler_begin_intercept(w);

	add_build_file("src/main.jai", w);

	while true {
		message := compiler_wait_for_message();

		if message.kind == .COMPLETE break;
		if message.kind == .TYPECHECKED handle_typecheck(cast(*Message_Typechecked) message);
		if message.kind == .PHASE
		if (cast(*Message_Phase) message).phase == .TYPECHECKED_ALL_WE_CAN
		if actions.count > 0
		{
			vec_actions := NewArray(actions.count, Action, allocator=temp);
			for actions vec_actions[it.index] = it;

			defer table_reset(*actions);
			builder: String_Builder;
			defer free_buffers(*builder);

			append(*builder, "#import \"src/app\";\n");
			append(*builder, "GetRect :: #import \"GetRect\";\n");

			append(
				*builder,
				"trigger_routines :: (#type (ui: *Ui_State, r: *GetRect.Rect) -> bool).[\n"
			);
			for vec_actions if it.has_trigger append(*builder, tprint("\ttrigger_%,\n", it.name));
			append(*builder, "\ttrigger_null\n];\n\n\n");

			append(
				*builder, "compute_routines :: #type (ui: *Ui_State, s: *Scene_State).[\n"
			);
			for vec_actions if it.has_compute append(*builder, tprint("\tcompute_%,\n", it.name));
			append(*builder, "\tcompute_null\n];\n\n\n");

			str := builder_to_string(*builder, temp);
			add_build_string(str, w);
		}
	}

	compiler_end_intercept(w);
}


handle_typecheck :: (msg: *Message_Typechecked) {
	for header: msg.procedure_headers {
		action: Action;
		action.name = header.expression.name;
		if starts_with(action.name, "trigger_") action.has_trigger = true;
		if starts_with(action.name, "compute_") action.has_compute = true;

		found := false;
		for header.expression.notes if scan2(it.text, "Action(%)", *action.index) found = true;
		if !found continue;

		if !action.has_trigger && !action.has_compute continue;

		action.name.count -= 8;
		action.name.data += 8;
		ptr := table_find_pointer(actions, action.name);
		if !ptr ptr = table_add(*actions, action.name, action);
		ptr.has_trigger |= action.has_trigger;
		ptr.has_compute |= action.has_compute;
	}
}