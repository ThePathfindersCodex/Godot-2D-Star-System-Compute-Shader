extends Label

func _process(_delta):
	text = "Pts: " + str(%ComputeGalaxy.point_count)
