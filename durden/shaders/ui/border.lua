return {
	label = "Border",
	version = 1,
	frag =
[[
	uniform float border;
	uniform float thickness;
	uniform float obj_opacity;
	uniform vec3 color;
	uniform vec2 obj_output_sz;
	varying vec2 texco;

	void main()
	{
		float margin_s = (border / obj_output_sz.x);
		float margin_t = (border / obj_output_sz.y);
		float margin_w = (thickness / obj_output_sz.x);
		float margin_h = (thickness / obj_output_sz.y);

/* discard both inner and outer border in order to support 'gaps' */
		if (
			( texco.s <= 1.0 - margin_s && texco.s >= margin_s &&
			texco.t <= 1.0 - margin_t && texco.t >= margin_t ) ||
			(
				texco.s < margin_w || texco.t < margin_h ||
				texco.s > 1.0 - margin_w || texco.t > 1.0 - margin_h
			)
		)
			discard;

		gl_FragColor = vec4(color.rgb, obj_opacity);
	}
]],
	uniforms = {
		border = {
			label = 'Area Width',
			utype = 'f',
			default = gconfig_get("borderw"),
			low = 0.1,
			high = 40.0
		},
		thickness = {
			label = 'Thickness',
			utype = 'f',
			default = (gconfig_get("borderw") - gconfig_get("bordert")),
			low = 0.1,
			high = 20.0
		},
		color = {
			label = 'Color',
			utype = 'fff',
			default = {1.0, 1.0, 1.0}
		}
	},
	states = {
		suspended = {uniforms = { color = {0.6, 0.0, 0.0} } },
		active = { uniforms = { color = {0.235, 0.4078, 0.53} } },
		inactive = { uniforms = { color = {0.109, 0.21, 0.349} } },
		alert = { uniforms = { color = {1.0, 0.54, 0.0} } },
	}
};
