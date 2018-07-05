--
-- 'Middle-weight' border shader based on a discard stage
--
-- The distinction between state color and obj_color is to have a per-object
-- coloring with state overrides without resorting to another dimension of
-- ugroups.
--
-- The weight is used as color blend weight against the object color
--
return {
	label = "Border(Float)",
	version = 1,
	frag =
[[
	uniform float border;
	uniform float thickness;
	uniform float obj_opacity;
	uniform vec4 col;
	uniform vec2 obj_output_sz;
	uniform vec3 obj_col;
	uniform float weight;
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

		gl_FragColor = vec4(mix(obj_col.rgb, col.rgb, weight), col.a * obj_opacity);
	}
]],
	uniforms = {
		border = {
			label = 'Area Width',
			utype = 'f',
			ignore = true,
			default = gconfig_get("borderw_float"),
			low = 0.1,
			high = 40.0
		},
		thickness = {
			label = 'Thickness',
			utype = 'f',
			ignore = true,
			default = (gconfig_get("borderw_float") - gconfig_get("bordert_float")),
			low = 0.1,
			high = 20.0
		},
		col = {
			label = 'Color',
			utype = 'ffff',
			default = {1.0, 1.0, 1.0, 1.0}
		},
		weight = {
			label = 'Weight',
			utype = 'f',
			default = {0.0},
			description = 'Mix weight between source color and state color'
		},
	},
	states = {
		suspended = {uniforms = { col = {0.6, 0.0, 0.0, 0.9}, weight = 1.0 } },
		active = { uniforms = { col = {0.0, 0.0, 0.0, 0.9}, weight = 0.0} },
		inactive = { uniforms = { col = {0.0, 0.0, 0.0, 0.9}, weight = 0.8} },
		alert = { uniforms = { col = {1.0, 0.54, 0.0, 0.9}, weight = 1.0} },
	}
};
