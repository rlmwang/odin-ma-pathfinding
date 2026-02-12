package sapf

a: i32 = 0

@export
add :: proc "c" (b: i32) -> i32 {
    a += b
	return a
}