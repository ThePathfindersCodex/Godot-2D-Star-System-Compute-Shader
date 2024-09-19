extends Node
func float_byte_array_to_Vector2Array(values : PackedByteArray) -> PackedVector2Array:
	var arr : PackedVector2Array = []
	for i in range(0, values.size(), 8):
		arr.append(Vector2(values.decode_float(i), values.decode_float((i+4))))
	return arr
func get_Vector2_from_byte_array(values: PackedByteArray, idx: int) -> Vector2:
	var offset: int = idx * 8
	var x: float = values.decode_float(offset)
	var y: float = values.decode_float(offset + 4)
	return Vector2(x, y)
func get_int32_from_byte_array(values: PackedByteArray, idx: int) -> int:
	var offset: int = idx * 4
	return values.decode_s32(offset)
func get_float32_from_byte_array(values: PackedByteArray, idx: int) -> float:
	var offset: int = idx * 4
	return values.decode_float(offset)
	
	
	
