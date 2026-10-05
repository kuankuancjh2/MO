shader_type canvas_item;
// 失明/视野：只保留主角周围一圈透明，其余盖上黑幕（像 MC 的失明效果）。
// center 是主角在屏幕上的归一化位置（由 HUD 每帧写入）。
uniform vec2 center = vec2(0.5, 0.5);
uniform float radius : hint_range(0.0, 1.5) = 0.45;    // 透明圈半径（按屏幕高度计）
uniform float softness : hint_range(0.01, 1.0) = 0.22; // 边缘过渡
uniform float darkness : hint_range(0.0, 1.0) = 0.0;   // 黑幕浓度
uniform float aspect = 1.777;

void fragment() {
	vec2 d = UV - center;
	d.x *= aspect;                       // 按宽高比校正，让圈是正圆而不是椭圆
	float dist = length(d);
	float a = smoothstep(radius, radius + softness, dist) * darkness;
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
