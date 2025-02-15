-- Description: UI primitive for an icon group management surface
-- Dependencies: assumes builtin/mouse.lua is loaded and acrive.

-- Todo:
--  draw label
--  resize
--  keyboard controls
--
-- Options:
--  snap to edges
--  group icon into icon
--  label at top
--  clickable regions
--    -> these three should be enough for wmaker like behavior
--
-- Durden integrations:
--  exticon target
--
-- ZUI part
--
local spawn_iconview

if (APPLID == "uiprim_icon_test") then

_G[APPLID] =
function(arguments)
	system_load("builtin/mouse.lua")()
	mouse_setup()
	mouse_state().rdrag = true

	system_defaultfont("default.ttf", 12, 1)
	icons = spawn_iconview(
		VRESW, VRESH,
		{
			grid_w = 64,
			grid_h = 64,
			border = 8,
			allow_zoom = true,
			allow_pan = true
		}
	)

	mouse_addlistener(icons.mouse)

	for i=1,2 do
		icons:add(
			"icon_" .. tostring(i),
			{}
		)
	end
end

_G[APPLID .. "_input"] =
function(io)
	if io.translated then
		if io.active then
			icons:add("random",
				{
					label = "some text"
				}
			)
		end
		return
	end

	mouse_input(io)
end

_G[APPLID .. "_clock_pulse"] =
function()
	mouse_tick(1)
end

end

local function icon_at(res, x, y)
	x = x + res.viewport[1]
	y = y + res.viewport[2]

	for i=#res.icons,1,-1 do
		local icon = res.icons[i]
		if x >= icon.x1 and x <= icon.x2 and
			 y >= icon.y1 and y <= icon.y2 then
			 return icon
		end
	end
end

local function get_subset(res, sel)
	local x1 = sel.x1
	local y1 = sel.y1
	local x2 = sel.x2
	local y2 = sel.y2

	if x1 > x2 then
		x1 = sel.x2
		x2 = sel.x1
	end

	if y1 > y2 then
		y1 = sel.y2
		y2 = sel.y1
	end

	local sx = x1 + res.viewport[1]
	local sy = y1 + res.viewport[2]
	local sx2 = sx + (x2 - x1)
	local sy2 = sy + (y2 - y1)

	local set = {}
	for _, v in ipairs(res.icons) do
		if v.x1 < sx2 and v.x2 > sx and
		   v.y1 < sy2 and v.y2 > sy then
			table.insert(set, v)
		end
	end

	return set
end

local function grid_align(maxw, maxh, gw, gh, x, y)
-- nearest kgrid-aligned col
	local lc = math.floor(x / gw) * gw
	local hc = lc + gw
	lc = (x - lc < hc - x) and lc or hc
	while lc + gw > maxw do
		lc = lc - gw
	end

-- nearest grid_aligned row
	local lr = math.floor(y / gh) * gh
	local hr = lr + gh
	lr = (y - lr < hr - y) and lr or hr
	while hr + gh > maxh do
		hr = hr - gh
	end

	return lc, lr
end

local function icon_reraster(icon, vid, tw, th)
	resize_image(vid, tw, th)
	return tw, th
end

local function scale_animation(speed, maxw, maxh, dstx, dsty, curx, cury)
	local dx = dstx - curx
	local dy = dsty - cury

	if dx == 0 and dy == 0 then
		return 0
	end

	local dist = math.sqrt(dx * dx + dy * dy)
	local max = math.sqrt(maxw * maxw + maxh * maxh)
	return speed * (dist / max)
end

local function add_icon(icongroup, name, opts)
	opts = opts or {}

	local w = opts.w or icongroup.icon_w
	local h = opts.h or icongroup.icon_h

-- find free- allocation goes here, unless it is autoarranged
	local x = 0
	local y = 0
	local factory = opts.factory
	if not factory then
		factory =
		function(w, h)
			return fill_surface(w, h,
				math.random(127, 255),
				math.random(127, 255),
				math.random(127, 255)
			)
		end
	end

	local icon = {
		drag = function(li, dx, dy)
			if not li.last_position then
				li.last_position = {li.x1, li.y1, li.x2, li.x2}
			end

			li.x1 = li.x1 + dx
			li.y1 = li.y1 + dy
			li.x2 = li.x2 + dx
			li.y2 = li.y2 + dy
			move_image(li.vid, li.x1, li.y1)
		end,
		deselect = function(icon)
			icongroup.selected[icon] = nil
			order_image(icon.vid, 1)
			if valid_vid(icon.selected) then
				delete_image(icon.selected)
				icon.selected = nil
			end
		end,
		parent = icongroup,
		w = w,
		h = h,
		orig_w = w,
		orig_h = h,
		x1 = x,
		y1 = y,
		x2 = x + w,
		y2 = y + h,
		destroy = function(icon)
			icongroup.selected[icon] = nil
			delete_image(icon.vid)
			for i,v in ipairs(icongroup.icons) do
				if v == icon then
					table.remove(icongroup.icons, i)
					break
				end
			end
		end,
		trigger = opts.trigger or function() end,
		alt_trigger = opts.alt_trigger or function() end,
		reraster = opts.reraster or icon_reraster,
		format = opts.format or "\\f,28",
		label = opts.label or "",
		activate = opts.action,
		context = opts.context
	}

	icon.vid =
		factory(
			opts.w or icongroup.icon_w,
			opts.icon_h or icongroup.icon_h
		)

	icon.draw_label =
	function(icon)
		local width, height = text_dimensions({icon.format, icon.label})
		local label = icon.label

-- crude shortening
		if width > icongroup.grid.w - 4 then
			label = string.sub(icon.label, 1, 3) .. "..." .. string.sub(icon.label, -3)
		end

-- border for contrast and clipping
		local border = fill_surface(icongroup.grid.w, height + 4, 32, 32, 32)
		link_image(border, icon.vid, ANCHOR_LC)
		show_image(border)
		image_inherit_order(border, true)
		move_image(border, -0.5 * icongroup.grid.w, 4)

		local vid, _, width = render_text({icon.format, label})
		show_image(vid)
		link_image(vid, border)
		image_inherit_order(vid, true)
		image_clip_on(vid, CLIP_SHALLOW, icongroup.clipping_anchor)

		icon.label_vid = vid
	end

	icon.select = function(icon)
		if icon.selected then
			return
		end

		icongroup.selected[icon] = icon
		order_image(icon.vid, 3)

-- attach selection geometry
		icon.selected =
			fill_surface(
				icon.w + icongroup.border,
				icon.h + icongroup.border, 64, 128, 64
			)

-- icon is actually centered in the grid snap approach
		show_image(icon.selected)
		link_image(icon.selected, icon.vid)
		move_image(icon.selected, -0.5 * icongroup.border, -0.5 * icongroup.border)

		image_inherit_order(icon.selected, true)
		order_image(icon.selected, -1)
		image_mask_set(icon.selected, MASK_UNPICKABLE)
		image_clip_on(icon.selected, CLIP_SHALLOW, icongroup.clipping_anchor)
	end

-- find decent position based on grid and flow direction by just sweep and test
	link_image(icon.vid, icongroup.position_anchor)
	image_clip_on(icon.vid, CLIP_SHALLOW, icongroup.clipping_anchor)
	show_image(icon.vid)
	image_mask_set(icon.vid, MASK_UNPICKABLE)
	move_image(icon.vid, x, y)
	image_inherit_order(icon.vid, true)

-- this has the caveat of the 64k cap, though possibly not that much of a concern
-- outside of a well populated ZUI where the order and visible set should be
-- quadtreed anyhow.
	table.insert(icongroup.icons, icon)

	icon:draw_label()
	return icon
end

local function resize_view(self, w, h)
-- trigger relayouting
end

local function revert_position(li)
	local res = li.parent
	local ox = li.x1
	local oy = li.y1

	if not li.last_position then
		return
	end

	li.x1 = li.last_position[1]
	li.y1 = li.last_position[2]
	li.x2 = li.last_position[3]
	li.y2 = li.last_position[4]

	move_image(li.vid, li.x1, li.y1,
			scale_animation(
				res.animation_speed,
				res.width, res.height,
				li.x1, li.y1,
				ox, oy)
	)
end

local function realign_item(li)
	local res = li.parent
	local gw = res.grid.w
	local gh = res.grid.h

	local x1, y1 =
		grid_align(
			res.width, res.height,
			res.grid.w * res.scalef, res.grid.h * res.scalef,
			li.x1,
			li.y1
		)

-- check so it's not occupied
	local set = get_subset(
		res,
		{x1 = x1, y1 = y1,
		 x2 = x1 + gw, y2 = y1 + gh
	  }
	)
	for i,v in ipairs(set) do
		if v ~= li then
			revert_position(li)
			return
		end
	end

-- center base on grid position
	x1 = x1 + math.floor(0.5 * (gw - li.w))

	if #li.label == 0 then
		y1 = y1 + math.floor(0.5 * (gh - li.h))
	end

	move_image(li.vid, x1, y1,
		scale_animation(
			res.animation_speed,
			res.width, res.height,
			x1, y1,
			li.x1, li.y1
		)
	)

-- set the new values
	li.x1 = x1
	li.y1 = y1
	li.x2 = x1 + li.w
	li.y2 = y1 + li.h
	li.last_position = {li.x1, li.y1, li.x2, li.y2}
end

local function update_selector_bounds(res)
	local oset = res.selected
	res.selected = {}

	local sel = res.selector
	local set = get_subset(res, sel)
	local count = 0

	for _,v in ipairs(set) do
		oset[v] = nil
		res.selected[v] = v
		count = count + 1
		v:select() -- no-op if already selected
	end

-- deselect the ones not in the current set
	for _,v in pairs(oset) do
		v:deselect()
	end

	res.multiselect = count > 1
end

local function mouse_drag(res, dx, dy)
	if res.selector then
		local ap = image_surface_resolve(res.clipping_anchor)
		local mx, my = mouse_xy()
		local sel = res.selector

		sel.x2 = sel.x2 + dx
		sel.y2 = sel.y2 + dy

		local w = math.abs(sel.x2 - sel.x1)
		local h = math.abs(sel.y2 - sel.y1)

		resize_image(
			sel.vid,
			w > 0 and w or 1,
			h > 0 and h or 1
		)

		move_image(sel.vid,
			sel.x1 < sel.x2 and sel.x1 or sel.x2,
			sel.y1 < sel.y2 and sel.y1 or sel.y2
		)
		update_selector_bounds(res)
		return
	end

	for _, li in pairs(res.selected) do
		li:drag(dx, dy)
	end
end

local function mouse_drop(res)
-- should check if the icon accepts the drop-set and if so,
-- trigger that instead of resnap.

	if not res.grid.snap then
		for _,li in pairs(res.selected) do
			if li.x2 - li.w * 0.5 > res.width or
				li.y2 - li.h * 0.5 > res.height then
				revert_position(li)
			end
			li.last_position = nil
		end
		return
	end

	for _, li in pairs(res.selected) do
		realign_item(li)
	end
end

local function mouse_dblclick(res, x, y)
	local icon = icon_at(res, x, y)
	if not icon then
		return
	end

	if type(icon.trigger) == "function" then
		icon:trigger()
	end
end

local function mouse_click(res, x, y)
	local icon = icon_at(res, x, y)

--  if modifier is held we shouldn't reset the set
	if not res.check_modifiers() then
		for _, v in ipairs(res.icons) do
			if icon ~= v then
				v:deselect()
			end
		end
	end

	if not icon then
		return
	end

	icon:select()
end

local function mouse_press(res, x, y)
	local icon = icon_at(res, x, y)

	if icon then
		if not res.multiselect then
			for _, v in ipairs(res.icons) do
				if icon ~= v then
					v:deselect()
				end
			end
		end

		icon:select()
		return
	end
	res.multiselect = nil

	res.selector = {
		x1 = x,
		y1 = y,
		x2 = x,
		y2 = y,
		vid = fill_surface(1, 1, unpack(res.selector_color))
	}

	if res.selection_shader then
		res.selection_shader(res.selector.vid)
	end

	link_image(res.selector.vid, res.clipping_anchor)
	image_mask_set(res.selector.vid, MASK_UNPICKABLE)
	image_clip_on(res.selector.vid, CLIP_SHALLOW, res.clipping_anchor)
	image_inherit_order(res.selector.vid, true)
	order_image(res.selector.vid, 2)
	blend_image(res.selector.vid, 0.5)
	return
end

local function mouse_release(res)
	if not res.selector then
		return
	end
	res.region_selected = true
	delete_image(res.selector.vid)
	res.selector = nil
end

local function scaled_region_set(res)
-- swap out for a quadtree like representation when N goes large
	return res.icons
end

local function destroy_view(res)
	for i=#res.icons,1,-1 do
		res.icons[i]:destroy()
	end
	delete_image(res.position_anchor)
	local keys = {}
	for k,v in pairs(res) do
		table.insert(keys, k)
	end
	for i,v in ipairs(keys) do
		res[v] = nil
	end
end

local function rescale(res)
	for _,v in ipairs(scaled_region_set(res)) do
		v.w, v.h = v:reraster(v.vid, v.orig_w * res.scale, v.orig_h * res.scale)
		v.x2 = v.x1 + v.w
		v.y2 = v.y2 + v.h
		if v.selected then
			resize_image(v.selected, v.w + res.border, v.h + res.border)
		end
-- determine if we're at the cutoff for disabling label or not
	end

	res.viewport[3] = res.viewport[1] + res.width * res.scalef
	res.viewport[4] = res.viewport[2] + res.height * res.scalef
end

local function zoom_pan(res, dx, dy)
	if res.drag_zoom then
-- figure out offset based on cursor position
		res:step_scale(res.scale_step[2])
		return
	end

	res.viewport[1] = res.viewport[1] + (dx * res.scalef)
	res.viewport[2] = res.viewport[2] + (dy * res.scalef)

-- this relies on the anchor to do panning / clipping
	move_image(res.position_anchor, res.viewport[1], res.viewport[2])
end

spawn_iconview =
function(w, h, opts)
	local res = {
		clipping_anchor = null_surface(w, h), -- used for clipping
		position_anchor = null_surface(w, h),
		width = w,
		height = h,
		icons = {},
		scale = 1.0,
		scalef = 1.0, -- 1.0 / scale
		scale_step = {opts.scale_step or 0.2, 0.01},
		viewport = {0, 0, w, h},
		step_scale = step_scale,
		selected = {},
		border = opts.border or 8,
		resize = resize_view,
		allow_pan = opts.allow_pan,
		allow_zoom = opts.allow_zoom,
		animation_speed = opts.animation_speed or 25,
		add = add_icon,
		destroy = destroy_view,
		selector_color = opts.selector_color or {127, 127, 127},
		check_modifiers = opts.check_modifiers or function() end,
		click_through = opts.click_through or function() end,
		selection_shader = opts.selection_shader,
		grid = {
			snap = opts.grid_snap,
			w = opts.grid_w or 64,
			h = opts.grid_h or 64
		},
		icon_w = opts.icon_w or 32,
		icon_h = opts.icon_h or 32,
	}

	res.step_scale =
	function(ctx, dz, lx, ly)
		local old_scale = res.scalef

		res.scale = res.scale + dz
		res.scalef = 1.0 / res.scale

-- find the scale point in the current reference frame, and translate it to a
-- position in the new one
		if lx then
			local ap = image_surface_resolve(res.clipping_anchor)
			lx = (lx - ap.x) * old_scale

			lx = ctx.viewport[1] + (lx - ap.x) * old_scale
			ly = ctx.viewport[2] + (ly - ap.y) * old_scale
			ctx.viewport[1] = lx - 0.5 * ctx.width * res.scalef
			ctx.viewport[2] = ly - 0.5 * ctx.width * res.scalef
			move_image(ctx.position_anchor, ctx.viewport[1], ctx.viewport[2])
		end

		rescale(ctx, lx, ly)
	end

-- this needs to be added manually or proxied into when there's a window or some
-- other outer mouse management to respect
	res.mouse =
		{
			name = "iconview",
-- we use one handler to allow hundreds of icons with our own testing heuristic
			own =
			function(ctx, vid)
				return vid == res.clipping_anchor
			end,

-- if no hit draw selector
			press =
			function(_, _, x, y)
				mouse_press(res, x, y)
			end,

-- if we have selector, remove it
			release =
			function()
				mouse_release(res)
			end,

-- treat cursor going outside as a release to not miss it
			out = function()
				mouse_release(res)
			end,

-- for right drag, zoom/pan in zui mode
			drag =
			function(_, _, dx, dy, ind)
				if ind == MOUSE_RBUTTON then
					zoom_pan(res, dx, dy)
				else
					mouse_drag(res, dx, dy)
				end
			end,

-- reorder / snap based on grid
			drop =
			function(ctx)
				mouse_drop(res)
			end,

			dblclick =
			function(_, _, x, y)
				mouse_dblclick(res, x, y)
			end,

			button =
			function(_, _, index, active, x, y)
				if not active then
					return
				end

				if index == MOUSE_WHEELPY then
					res:step_scale(res.scale_step[1], x, y)

				elseif index == MOUSE_WHEELNY then
					res:step_scale(-res.scale_step[1], x, y)
				end
			end,

			rclick =
			function(_, _, x, y)
				local icon = icon_at(res, x, y)
				if not icon then
					res.drag_zoom = not res.drag_zoom
					res.click_through(MOUSE_RBUTTON, x, y)
				else
					mouse_click(res, x, y)
				end
			end,

			click =
			function(_, _, x, y)
				mouse_click(res, x, y)
			end
		}

	image_mask_set(res.position_anchor, MASK_UNPICKABLE)
	image_inherit_order(res.clipping_anchor, true)

	show_image(res.clipping_anchor)
	show_image(res.position_anchor)

	return res
end

return spawn_iconview
