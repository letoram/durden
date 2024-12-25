local shader =
	[[
		uniform float radius;
		uniform float inner_radius;
		varying vec2 texco;

		uniform vec2 current;
		uniform vec2 pending;

		uniform vec3 cur_col;
		uniform vec3 pnd_col;
		uniform vec3 obj_col;
		uniform bool filled;

		void main()
		{
			vec2 range = texco * 2.0 - vec2(1.0);
			float lrange = length(range);

			float vis = lrange - radius;
			float vis2 = lrange - inner_radius;

/* can do without fwidth? just smoothstep(length, 0.0, 0.9) / blur_radius,
   to get a drop shadow we could mix another length on a displaced UV and
	 mix with the colored circle */

			float step = fwidth(vis);
			vis = smoothstep(step, -step, vis);
			float ang = atan(range.t, range.s) + 3.1457;

			step = fwidth(vis2);
			vis2 = smoothstep(step, -step, vis2);

			bool outer = (vis > 0.0 && vis2 > 0.0);
			outer = (filled && !outer) || (!filled && outer);

			vec3 col = obj_col;
			if (ang >= current.s && ang <= current.t)
				col = cur_col;
			else if (ang >= pending.s && ang <= pending.t)
				col = pnd_col;

			gl_FragColor = vec4(mix(col.rgb, obj_col, float(outer)), vis);
		}
	]]

local shid
local function setup_shader()
	shid = build_shader(nil, shader, "round")
	shader_uniform(shid, "radius", "f", 1.0)
	shader_uniform(shid, "inner_radius", "f", 0.9)
	shader_uniform(shid, "pnd_col", "fff", 1.0, 1.0, 1.0)
	shader_uniform(shid, "cur_col", "fff", 0.0, 1.0, 1.0)
	shader_uniform(shid, "obj_col", "fff", 0.3, 0.0, 0.0)
	shader_uniform(shid, "current", "ff", 0.0, 0.1)
	shader_uniform(shid, "pending", "ff", 0.1, 0.1)
	shader_uniform(shid, "filled", "b", true)
	shader_uniform(shid, "current", "ff", 0, 3.14)
end

local function show_circle(wnd)
	local x, y = mouse_xy()
	if not shid then
		setup_shader()
	end

	local button = color_surface(64, 64, 0, 255, 0)
	image_shader(button, shid)
	move_image(button, x, y)
	image_mask_set(button, MASK_UNPICKABLE)

	local capture = color_surface(wnd.wm.width, wnd.wm.height, 255, 0, 0)
	link_image(capture, wnd.wm.order_anchor)
	link_image(button, capture)
	show_image({capture, button})

	image_inherit_order(capture, true)
	image_inherit_order(button, true)

-- MOUSE_WHEELPY, WHEELNY
	local bgmh
	bgmh = {
		name = "wheel_capture",
		button = function(ctx, vid, ind, pressed, x, y)
			if ind ~= MOUSE_WHEELPY and ind ~= MOUSE_WHEELNY then
				mouse_droplistener(bgmh)
				blend_image(button, gconfig_get("animation"))
				expire_image(capture, gconfig_get("animation"))
			end
			print(x, y, ind)
		end,
		own = function(ctx, vid)
			return vid == capture
		end
	}

	mouse_addlistener(bgmh)
	order_image(button, 1)
end

menus_register("target", "input", {
	label = "Scroll Circle",
	description = "Popup a scroll circle at the cursor position",
	name = "scroll_circle",
	kind = "action",
	eval = function()
		return active_display().selected.got_scroll ~= nil
	end,
	handler = function()
		show_circle(active_display().selected)
	end
})
