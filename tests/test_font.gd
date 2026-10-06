extends Control
# LOC-02: font phải đủ dấu tiếng Việt, kiểm tra cả in đậm.

const SAMPLE := "ằ ẫ ộ ữ đ Ằ Ẫ Ộ Ữ Đ"
const SENTENCE := "Đồng hồ tự bạo: lực lượng quân địch đã tiến sát cổng thành!"

@export var regular: Font
@export var bold: Font


func _ready() -> void:
	var ok := true
	for font in [regular, bold]:
		for c in SAMPLE.replace(" ", "") + SENTENCE:
			if not font.has_char(c.unicode_at(0)):
				ok = false
				print("FAIL: %s thiếu ký tự '%s'" % [font.resource_path.get_file(), c])
	print("LOC-02 glyph check: %s" % ("PASS" if ok else "FAIL"))

	var shot := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot = arg.trim_prefix("--shot=")
	if shot != "":
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit(0 if ok else 1)
