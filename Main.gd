extends Node2D

var zoomed_texture_rect: TextureRect
var zoomed_offset: Vector2
var center_offset: Vector2
var texture_size: Vector2
var zoomed_scale_setting: float = 1.0/1.0
var subviewport_size: Vector2

func _process(_delta):
	var mousepos = %ComputeGalaxy.get_local_mouse_position()
	# Adjust the mouse position offset based on the scale of the texture
	zoomed_offset = (-mousepos * zoomed_scale_setting) + (subviewport_size / 2.0)
	zoomed_texture_rect.position = zoomed_offset
	
func _ready():
	prepare_zoom_viewport()
	
func prepare_zoom_viewport():
	zoomed_texture_rect = TextureRect.new()
	zoomed_texture_rect.texture = %ComputeGalaxy.texture  # Reuse the main texture
	texture_size = zoomed_texture_rect.texture.get_size() * zoomed_scale_setting
	zoomed_texture_rect.scale = Vector2(zoomed_scale_setting,zoomed_scale_setting)
	subviewport_size = %SubViewportZoom.size
	center_offset = (subviewport_size - texture_size) / 2
	zoomed_offset = center_offset #start center
	zoomed_texture_rect.position = zoomed_offset
	%SubViewportZoom.add_child(zoomed_texture_rect)

func _on_button_zoom_pressed() -> void:
	%SubViewportContainerZoom.visible = !%SubViewportContainerZoom.visible

func _on_button_perf_graph_pressed() -> void:
	%SubViewportContainerPerfGraph.visible = !%SubViewportContainerPerfGraph.visible

func _on_button_galaxy_pressed() -> void:
	%ComputeGalaxy.visible = !%ComputeGalaxy.visible
