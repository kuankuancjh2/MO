extends Node
## 音效单例。
##
## ★ 往里面放音频的方法：
##   把文件丢进 res://assets/audio/，文件名用下面 NAMES 里的名字，
##   后缀 .ogg / .wav / .mp3 都行。例如 assets/audio/jump.ogg。
##   不需要改代码，找不到文件就静默跳过（只在启动时提示一次缺哪些）。
##
## 代码里用：Sfx.play("jump")

const DIR := "res://assets/audio"
const EXTENSIONS := ["ogg", "wav", "mp3"]
const POOL_SIZE := 8

const NAMES := [
	"jump",       ## 起跳
	"land",       ## 落地
	"vanish",     ## 方块消失
	"stomp",      ## 踩死怪
	"shatter",    ## 字块碎裂
	"transform",  ## 变成新字
	"hit",        ## 主角受击
	"coin",       ## 吃金币
]

var _streams: Dictionary = {}      ## name -> AudioStream
var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	var missing: Array[String] = []
	for n in NAMES:
		var s := _load_stream(n)
		if s != null:
			_streams[n] = s
		else:
			missing.append(n)
	if not missing.is_empty():
		print("MO: 缺少音效文件（丢进 %s/ 即可，见 docs/技术文档.md 第 9 章）：%s"
			% [DIR, ", ".join(missing)])


func _load_stream(name: String) -> AudioStream:
	for ext in EXTENSIONS:
		var path := "%s/%s.%s" % [DIR, name, ext]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


## 播放一个音效。找不到对应文件就什么都不做。
func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s: AudioStream = _streams.get(name, null)
	if s == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## 随机音高，避免重复听起来发闷
func play_varied(name: String, spread: float = 0.08) -> void:
	play(name, 0.0, randf_range(1.0 - spread, 1.0 + spread))
