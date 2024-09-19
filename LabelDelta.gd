extends Label

func _process(_delta):
	text = "dt: " + str(snapped(%ComputeGalaxy.dt,.0001))
