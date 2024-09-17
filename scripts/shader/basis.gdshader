shader_type spatial;
render_mode unshaded;

uniform mat3 basis;

void vertex() {
	if (VERTEX_ID == 1){VERTEX = basis[0];}
	else if (VERTEX_ID == 3){VERTEX = basis[1];}
	else if (VERTEX_ID == 5){VERTEX = basis[2];}
	// Called for every vertex the material is visible on.
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
	// Called for every pixel the material is visible on.
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
