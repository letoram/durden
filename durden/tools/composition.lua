local log, fmt = suppl_add_logfn("tools")

local layouts = {}
local selectors = {}
local populate_slot

-- selector gets four buttons: next, previous, activate, cancel
selectors.coverflow =
function(wnd, v)
end

selectors.list =
function(wnd, v, set)
	log(fmt("name=composition:kind=selector_build:items=%d", #v))
	local fmtstr =
		string.format(
			"\\ffonts/%s,%d\\#%s",
			v.selector_config.font or gconfig_get("font_def"),
			active_display().font_deltav +
			(v.selector_config.font_sz or gconfig_get("font_sz")),
			v.selector_config.text_color or gconfig_get("text_color")
		)

	local set_selected =
	function(selector, ind)
		local props = image_surface_properties(selector.vids[selector.index])
		move_image(selector.vids[selector.index], 20, props.y)

		if ind + selector.offset > #selector.set then
			ind = #selector.set - selector.offset
		end

		local vid = selector.vids[ind]
		local props = image_surface_properties(vid)
		local item = selector.set[selector.index + selector.offset]

		for k,v in pairs(item.slots) do
			if selector.wnd.list[k] then
				populate_slot(selector.wnd.list[k], selector, k, v)
			end
		end

		local animation = v.selector_config.animation
		if animation then
			move_image(vid, 20, props.y)
			move_image(vid, 0, props.y, animation)
		else
			move_image(vid, 0, props.y)
		end

		selector.index = ind
	end

	local synch_set =
	function(selector)
		for i=1,#selector.vids do
			local si = selector.set[selector.offset + i]
			if si then
				render_text(selector.vids[i], {fmtstr, si.text or tostring(i)})
				show_image(selector.vids[i])
			else
				hide_image(selector.vids[i])
			end
		end
	end

-- (returning to a cached set as 'step back' should go the other direction)
	local apply_set =
	function(selector, set, nostack)
		local animation = v.selector_config.animation
		local got_set = #selector.vids > 0

		if got_set and not nostack then
			table.insert(selector.stack, selector.set)
		end

		for i,vid in ipairs(selector.vids) do
			if i == 1 then -- don't animate as first index will be set immediately
				delete_image(vid)
			else
				nudge_image(vid,
					(nostack and 1 or -1) * (v.x2 - v.x), 0,
					v.selector_config.animation or 0
				)
				blend_image(vid, 0, animation or 0)
				expire_image(vid, animation or 0)
			end
		end

		selector.set = set
		selector.vids = {}

		if v.selector_config.background then
			local bgc = v.selector_config.background
			local csrf = fill_surface(1, 1, bgc[1], bgc[2], bgc[3])
			blend_image(v.vid, bgc[4])
			image_sharestorage(csrf, v.vid)
			delete_image(csrf)
		end

-- set the initial view and fill the allocated space with vids
-- as updates will render into the existing store rather than rebuild
		local vadv = 0
		local ind = 1

		while true do
			local si = set[ind]

-- text_surface is the proper way to do this, but it still doesn't have
-- shaped rows which is necessary here. Since it's a fairly limited set
			local vid, _, _, h, _ = render_text({fmtstr, si and si.text or tostring(ind)})
			if not valid_vid(vid) then
				return
			end

			rendertarget_attach(selector.wnd.canvas, vid, RENDERTARGET_DETACH)
			link_image(vid, v.vid)
			image_clip_on(vid, CLIP_SHALLOW)
			image_inherit_order(vid, true)
			if si then
				show_image(vid)
			end

-- animate the current item
			if got_set and animation then
				move_image(vid, nostack and (-(v.x2 - v.x)) or v.x2, vadv)
				move_image(vid, 20, vadv, animation)
			else
				move_image(vid, 20, vadv)
			end

			vadv = vadv + h

			table.insert(selector.vids, vid)

			if v.y + vadv + h > v.y2 then
				break
			end

			ind = ind + 1
		end

		selector.index = 1
		selector.offset = 0
		set_selected(selector, 1)
	end

populate_slot =
function(slot, sel, name, value)
		if slot.last == value then
			return
		end

		local simple, ext = suppl_ext_type(value)
		local ctbl = {
			image = "proto=image",
			video = "proto=media",
			pdf = "proto=pdf",
			audio = "proto=media"
		}

-- we have media, 3d, text, image, pdf
		local vid =
			launch_decode(value, ctbl[simple],
				function(source, status)
				if status.kind == "terminated" then
					delete_image(source)

-- crossfade should go here, set a blend and tag the transform then
-- on tag set_image_as_frame to populate both slots
				elseif status.kind == "resized" then
					table.remove_match(sel.pending, value)
					slot.current = source
					image_sharestorage(source, slot.vid)
				end
			end
		)
		if valid_vid(vid) then
			table.insert(sel.pending, vid)
		end

		slot.last = name
	end

	local function step_set(sel, dx, dy)
		local oldi = sel.index

		if dy ~= 0 then
			for _,v in ipairs(sel.vids) do
				instant_image_transform(v)
			end

			for k,v in pairs(sel.pending) do
				delete_image(v)
			end

			sel.pending = {}

			if dy > 0 then
				local si = sel.index

-- scroll down (if possible)
				if si == #sel.vids then
					if sel.offset + si + 1 < #sel.set then
						sel.offset = sel.offset + #sel.vids
						si = #sel.vids
						synch_set(sel)
					end
					si = 1
				else
					si = si + 1
				end

-- scroll up
				set_selected(sel, si)

			elseif dy < 0 then
				if sel.index == 1 then
					if sel.offset > 0 then
						sel.offset = math.clamp(sel.offset - #sel.vids, 0)
						synch_set(sel)
						sel.index = #sel.vids
					end
					set_selected(sel, sel.index)
				else
					set_selected(sel, math.clamp(sel.index - 1, 1))
				end
			end

-- step in if > 0 and subdir, back if depth > 0
		elseif dx ~= 0 then
		end
	end

	local function step_trigger(sel)
		local item = sel.set[sel.index + sel.offset]

		if item.path then
			dispatch_symbol(item.path)
		end
	end

	local function step_cancel(sel)
		if #sel.stack > 0 then
			sel:update_set(table.remove(sel.stack, #sel.stack), true)
		end
	end

	local selector = {
		update_set = apply_set,
		step = step_set,
		trigger = step_trigger,
		cancel = step_cancel,
		wnd = wnd,
		vids = {},
		stack = {},
		pending = {}
	}

	selector:update_set(set)

	return selector
end

local function wnd_left(wnd)
	if wnd.active_selector then
		wnd.active_selector:step(-1, 0)
	end
end

local function wnd_right(wnd)
	if wnd.active_selector then
		wnd.active_selector:step(1, 0)
	end
end

local function wnd_up(wnd)
	if wnd.active_selector then
		wnd.active_selector:step(0, -1)
	end
end

local function wnd_down(wnd)
	if wnd.active_selector then
		wnd.active_selector:step(0, 1)
	end
end

local function wnd_back(wnd)
	if wnd.active_selector then
		wnd.active_selector:cancel()
	end
end

local function wnd_enter(wnd)
	if wnd.active_selector then
		wnd.active_selector:trigger()
	end
end

local function load_parse_albuminfo(nbio)
	nbio:lf_strip(true)
	local line, alive = nbio:read()
	local in_meta = true
	local md = {}
	local res = {}

-- this becomes implicitly blocking, the proper way would be a set that
-- indicates that we are loading, and then automatically re-set itself.
	while alive or line do

		if line then
			local ch = string.sub(line, 1, 1)

			if ch == "[" then
				local _, _, key, val = string.find(line, "%[(.+)%]%s+(.+)")

				if in_meta then
					if key and val then
						md[key] = val
					end
				else
					key = tonumber(key)
					if key then
						md[key] = val
					end
				end
-- find \=+(%s+)\=+ and mark as separator
			elseif ch == "=" then
				in_meta = false
			else
			end
		end

		line, alive = nbio:read()
	end

	nbio:close()
	return md
end

local function handler_for_file(path, file, set)
	if file == "AlbumInfo.txt" then
		nbio = open_nonblock(path .. "/" .. file, "r")
		if not nbio then
			return
		end

-- all .flac files go into unique items
		local md = load_parse_albuminfo(nbio)
		table.sort(set)

-- we can have audio / video / image (ignore, always use cover)
		local res = {}

		for _, v in ipairs(set) do
			local simple, ext = suppl_ext_type(v)

			if simple == "audio" then
-- metadata: ID, Title, Artists, ReleaseDate, SongNum, Duration
				local _, _, num = string.find(v, "(%d+)%s")
				num = tonumber(num)

				if num then
					table.insert(res, {
						slots = {
							preview = path .. "/" .. "cover.jpg"
						},
						text = md[num] and string.format("[%.2d] - %s", num, md[num]) or v,
						media = path .. "/" .. v,
						type = simple
					})
-- lyrics = lrc
				end
			end
		end

		return res
	end
end

local function gen_set_from_path(wnd, item, path)
	local set = glob_resource(path)
	for i=#set,1,-1 do
		if string.sub(set[i], 1, 1) == "." then
			table.remove(set, i)
		end
	end

	if #set == 0 then
		log("name=composition:kind=bad_empty_path:path=" .. path)
		return
	end

	local res

	for i,v in ipairs(set) do
		res = handler_for_file(path, v, set)
		if res then
			break
		end
	end

-- nothing which absorbed the set
	if not res then
		res = {}

		for i,v in ipairs(set) do
			local _, rt = resource(path .. "/" .. v, SHARED_RESOURCE)

-- default handlers for certain items
			if rt ~= "directory" then
				local simple, ext = suppl_ext_type(v)
				if ext  ~= "*" then
					table.insert(res,
						{
							slots = {},
							text = v
						}
					)
				end

-- allow navigation into subdirs
			else
				table.insert(res,
					{
						slots = {},
						text = v .. "/",
						subdir = true,
						path = string.format(
							"/target/composition/selectors/%s/generate=%s",
							item.selector, path .. "/" .. v
						)
					}
				)
			end
		end
	end

	if #res == 0 then
		table.insert(res,
			{
				slots = {},
				text = ">Empty<"
			}
		)
	end

-- instantiate selector with list, or if we have one, switch set
	if wnd.selectors[item.selector] then
		wnd.selectors[item.selector]:update_set(res)
	else
		wnd.selectors[item.selector] = selectors[item.selector](wnd, item, res)
	end

	if not wnd.active_selector then
		wnd.active_selector = wnd.selectors[item.selector]
	end
end

local function submenu_for_selector(wnd, v)
	local res =
	{
		{
			name = "List",
			label = "List",
			kind = "value",
			description = "Set selector input dataset",
			handler =
			function(ctx, val)
-- just load .lua and items, run same selector instantiation
			end
		},
		{
			name = "generate",
			label = "Generate",
			description = "Build and set a dynamic list from a root path",
			kind = "value",
			handler =
			function(ctx, val)
				gen_set_from_path(wnd, v, val)
			end
		}
	}

	return res
end

local function gen_selector_menu(wnd)
	local res = {}
	for i,v in ipairs(wnd.list) do
		if v.selector then
			if not selectors[v.selector] then
				log(fmt("name=composition:kind=missing_selector:value=%s", v.selector))
				return {}
			end

			table.insert(res,
			{
				name = v.selector,
				label = v.selector,
				kind = "action",
				submenu = true,
				handler = function()
					return submenu_for_selector(wnd, v)
				end
			})
		end
	end
	return res
end

local target_menu =
{
	{
		label = "Selectors",
		name = "selectors",
		description = "Manage dataset selectors",
		kind = "action",
		submenu = true,
		eval =
		function(ctx, val)
			for _,v in ipairs(active_display().selected.list) do
				if v.selector then
					return true
				end
			end
		end,
		handler =
		function()
			return gen_selector_menu(active_display().selected)
		end
	}
}

-- need controls for reposition, restacking, rotation, scale, effects popup
-- toggle for compositing mouse cursor
-- adding audio sources to the mix (represent with icons)

local function cursortag(wnd, accept, src, tag)
	if accept == nil then
		return tag.ref == "window" and src ~= wnd
	end

-- also: grab file-stack from browser, run through decode
	if accept and tag.ref == "window" and valid_vid(src.canvas) then
		local props = image_storage_properties(src.canvas)
		local nsrf = null_surface(props.width, props.height)
		image_sharestorage(src.canvas, nsrf)
		table.insert(wnd.list, nsrf)
		rendertarget_attach(wnd.canvas, nsrf, RENDERTARGET_DETACH)
		show_image(nsrf)
	end
end

local function motion(x, y, rx, ry)
-- check if we are on a selector and let that handle it,
-- otherwise check if the item underneath supports selection
end

local function button(index, press, x, y, lx, ly)
-- check if we are on a selector and let that handle it
end

local function inputtable(wnd, tbl)
-- if we have a selector and it is active, route into there
end

local function dblclick(wnd)
-- if we are on a selector, treat as activate,
-- if we are on interactive / fullscreen, toggle that
end

local function ensure_fields(v)
	local defaults = {
		x = 0,
		x2 = 32,
		y = 0,
		y2 = 32,
		order = 0,
		rotation = 0
	}

	for k,d in pairs(defaults) do
		if not v[k] then v[k] = d end
	end

	return v
end

local function apply_image(wnd, v, vid)
	rendertarget_attach(wnd.canvas, vid, RENDERTARGET_DETACH)
	resize_image(vid, v.x2 - v.x, v.y2 - v.y)
	blend_image(vid, v.opacity or 1.0)
	move_image(vid, v.x, v.y)
	rotate_image(vid, v.rotation)
	order_image(vid, v.order, v.order_anchor)

	if v.shader then
		shader_setup(vid, "simple", v.shader, "default")
	end
end

local function media_to_fname(media)
	media = tostring(media)

-- arm a timer and repeat if one is requested
	if string.sub(media, 1, 8) == "$random:" then
		local prefix = string.sub(media, 9)
		local files = glob_resource(prefix, bit.bor(APPL_RESOURCE, SHARED_RESOURCE))
		local path = string.split_first(prefix, "/%*")
		return (#path == 0 and prefix or path) .. "/" .. files[math.random(1, #files)]
	end

	return media
end

local function load_item(wnd, v)
-- ensure wnd menu has selector controls for setting the list
	if v.selector then
		if not selectors[v.selector] then
			log(fmt(
				"tool=composition:kind=error:message=missing selector (%s)", v.selector
			))
			return
		end
	end

	local nsrf = null_surface(1, 1)
	apply_image(wnd, v, nsrf)

	if tostring(v.static_media) then
		local fn = media_to_fname(v.static_media)
		if not fn then
			log(fmt(
				"tool=composition:kind=error:message=%s matched nothing", v.static_media))
		else
			load_image_asynch(fn,
			function(source, status)
				if status.kind == "loaded" then
					log(fmt("tool=composition:kind=loaded:media=%s", fn))
					image_sharestorage(source, nsrf)
					apply_image(wnd, v, nsrf)
				elseif status.kind == "load_failed" then
					log(
						fmt(
							"tool=composition:kind=error:message=couldn't load media: %s",
							v.static_media
						)
					)
				end
				delete_image(source)
			end
			)
		end

	elseif tostring(v.media) then
-- loop? then append loop argument
		local vid, aid =
		launch_decode(media_to_fname(v.media),
			function(source, status)
				if status.kind == "resized" then
					image_sharestorage(nsrf, source)
					apply_image(wnd, v, nsrf)
				elseif status.kind == "terminated" then
					delete_image(source)
				end
			end
		)
		link_image(vid, wnd.canvas)
	end

	if v.slot then
		wnd.slots[v.slot] = nsrf
		wnd.list[v.slot] = v -- make sure we can index by name
	end

	v.vid = nsrf
end

local function handle_input(wnd, iotbl)
	if iotbl.translated and #iotbl.utf8 > 0 and wnd.active_selector then

	end
end

local function spawn(layout)
	local canvas = alloc_surface(layout.width, layout.height)
	local wnd = active_display():add_window(canvas, {
		scalemode = "client" -- blocks window from being resized
	})

	wnd.actions = {
		{
			name = "composition",
			label = "Composition",
			description = "Dynamic composition controls",
			kind = "action",
			submenu = true,
			handler = target_menu
		}
	}


	wnd.list = {}  -- track current list
	wnd.slots = {} -- track map between logical names / roles and content provided
	wnd.selectors = {} -- instantiated selectors (typically 1 but no firm restriction)

	wnd.bindings[SYSTEM_KEYS["left"]] = wnd_left
	wnd.bindings[SYSTEM_KEYS["right"]] = wnd_right
	wnd.bindings[SYSTEM_KEYS["next"]] = wnd_up
	wnd.bindings[SYSTEM_KEYS["previous"]] = wnd_down
	wnd.bindings[SYSTEM_KEYS["cancel"]] = wnd_back
	wnd.bindings[SYSTEM_KEYS["accept"]] = wnd_enter

-- TAB should cycle selectors (if any)
-- input_table should route to selector or active_target

	wnd.input_table = handle_input
--	wnd.mousemotion = mouse_motion
--	wnd.mousebutton = mouse_button
--	wnd.mousedblclick = dblclick

	show_image(canvas)

-- just something to hold us for now
	local null = null_surface(1, 1)

	define_rendertarget(canvas, {null})

-- allow drag and drop other sources
	if layout.dynamic then
		wnd.receive_cursortag = cursortag
	end

--	wnd:add_handler("resize", rebuild_rt)
	wnd:add_handler("mouse_motion", motion)
	wnd:add_handler("mouse_button", button)

	if layout.items then
		wnd.list = layout.items
		for i=1,#layout.items do
			load_item(wnd, ensure_fields(layout.items[i]))
		end
	end

	if layout.on_load then
		dispatch_symbol(layout.on_load)
	end
end

local function ensure_empty()
	layouts["empty"] =
	{
		name = "empty",
		width = 1280,
		height = 720,
		dynamic = true,
		items = {}
	}
end

local function gen_layout_list()
	local files = glob_resource("devmaps/composition/*.lua", APPL_RESOURCE)
	for i,v in ipairs(files) do
		if not layouts[v] then
			local res =
			suppl_script_load("devmaps/composition/" .. v,
				function(str) log("tool=composition:error=layout_fail:message=" .. str) end
			)
			if not res or not type(res) == "table" then
				log("tool=composition:error=broken_layout:file=" .. v)
				return
			end
			layouts[v] = res
		end
	end

	ensure_empty()

	local set = {}
	for k,v in pairs(layouts) do
		table.insert(set, k)
	end
	table.sort(set)

	local res = {
		{
			name = "flush",
			label = "Flush",
			kind = "action",
			description = "Reload layouts from devmaps/composition",
			handler = function()
				local set = {}
				for k,_ in pairs(layouts) do
					table.insert(set, k)
				end
				for i,v in ipairs(set) do
					layouts[v] = nil
				end
			end
		},
		{
			name = "load",
			label = "Load",
			description = "Load a layout into a new window",
			kind = "value",
			set = set,
			handler =
			function(ctx, val)
				if not layouts[val] then
					log(fmt(
						"tool=composition:kind=error:message=missing layout(%s)", val))
					return
				end
				spawn(layouts[val])
			end
		}
	}

	return res
end

menus_register("global", "tools",
{
	name = "composition",
	kind = "action",
	submenu = true,
	handler = function() return gen_layout_list() end,
	label = "Composition",
	description = "Create a composition window",
}
)
