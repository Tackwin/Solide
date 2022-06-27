#scope_file
#load "mkl_api.jai";
#import "src/std";

#scope_export
#import "Basic";

Sparse_Matrix :: struct {
	mat : sparse_matrix_t = null;
	
	user_created : bool = false;
	rows : int = -1;
	cols : int = -1;
	rows_start : [] s64;
	col_idx    : [] s64;
	values     : [] float32;
}

create_sparse_matrix :: (
	rows: int,
	cols: int,
	rows_start : [] s64,
	col_idx    : [] s64,
	values     : [] float
) -> Sparse_Matrix {
	mat : Sparse_Matrix;
	mat.rows_start = rows_start;
	mat.col_idx = col_idx;
	mat.values = values;
	mat.rows = rows;
	mat.cols = cols;
	mat.user_created = true;
	status := mkl_sparse_s_create_csr(
		*mat.mat,
		.ZERO,
		rows,
		cols,
		mat.rows_start.data,
		mat.rows_start.data + 1,
		mat.col_idx.data,
		mat.values.data
	);
	status =  mkl_sparse_optimize(mat.mat);
	return mat;
}

free :: (mat: Sparse_Matrix) {
	if (mat.user_created) {
		free(mat.rows_start.data);
		free(mat.col_idx.data);
		free(mat.values.data);
	}
	mkl_sparse_destroy(mat.mat);
}


copy :: (this: Sparse_Matrix) -> Sparse_Matrix {
	desc : matrix_descr;
	desc.type = .GENERAL;

	out: Sparse_Matrix;
	out.user_created = false;

	status := mkl_sparse_copy(this.mat, desc, *out.mat);
	assert(status == .SUCCESS);
	return out;
}

operator * :: (a: Sparse_Matrix, b: Sparse_Matrix) -> Sparse_Matrix {
	c: Sparse_Matrix;

	desc : matrix_descr;
	desc.type = .GENERAL;

	status := mkl_sparse_sp2m(.NON_TRANSPOSE, desc, a.mat, .NON_TRANSPOSE, desc, b.mat, .FULL_MULT, *c.mat);
	assert(status == .SUCCESS);
	return c;
}

mul :: (a: Sparse_Matrix, b: Sparse_Matrix) -> Sparse_Matrix {
	return a * b;
}

mul :: (A: Sparse_Matrix, x: [] float) -> [..] float {
	desc : matrix_descr;
	desc.type = .GENERAL;

	y : [..] float;
	array_resize(*y, A.rows);

	status := mkl_sparse_s_mv(.NON_TRANSPOSE, 1, A.mat, desc, x.data, 0, y.data);
	assert(status == .SUCCESS);
	return y;
}

mul :: (x: [] float, A: Sparse_Matrix) -> [..] float {
	desc : matrix_descr;
	desc.type = .GENERAL;

	y : [..] float;
	array_resize(*y, A.cols);

	status := mkl_sparse_s_mv(.TRANSPOSE, 1, A.mat, desc, x.data, 0, y.data);
	assert(status == .SUCCESS);
	return y;
}

print :: (A: Sparse_Matrix) {
	row_idx := 0;

	dense : [..] float;
	array_resize(*dense, A.rows * A.cols);
	
	for A.values {
		while A.rows_start[row_idx + 1] <= it_index row_idx += 1;

		dense[row_idx * A.cols + A.col_idx[it_index]] = it;
	}

	for r: 0..A.rows-1 {
		for c: 0..A.cols-1 {
			print("% ", dense[r * A.cols + c]);
		}
		print("\n");
	}
}

solve :: (A: Sparse_Matrix, b: [] float) -> [] float {
	x := NewArray(b.count, float);
	desc : matrix_descr;
	desc.type = .GENERAL;
	status := mkl_sparse_s_symgs(.NON_TRANSPOSE, A.mat, desc, 1, b.data, x.data);
	assert(status == .SUCCESS);
	return x;
}