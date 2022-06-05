#scope_file
#load "mkl_api.jai";

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

operator * :: (a: Sparse_Matrix, b: Sparse_Matrix) -> Sparse_Matrix {
	c: Sparse_Matrix;
	print("% %\n", a.rows, a.cols);
	print("% %\n", b.rows, b.cols);

	desc : matrix_descr;
	desc.type = .GENERAL;

	status := mkl_sparse_sp2m(.TRANSPOSE, desc, a.mat, .TRANSPOSE, desc, b.mat, .FULL_MULT, *c.mat);
	print("%\n", status);
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