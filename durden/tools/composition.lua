local log, fmt = suppl_add_logfn("tools")

local layouts = {}
local selectors = {}

-- selector gets four buttons: next, previous, activate, cancel
selectors.coverflow =
function(wnd, v)
end

selectors.list =
function(wnd, v, set)
	log(fmt("name=composition:kind=selector_build:items=%d", #v))

-- (returning to a cached set as 'step back' should go the other direction)
	local apply_set =
	function(selector, set)
		local animation = v.selector_config.animation
		for i,v in ipairs(selector.vids) do
			nudge_image(v, -(v.x2 - v.x), 0, v.selector_config.animation or 0)
			blend_image(v, 0, animation or 0)
			expire_image(v, animation or 0)
		end
		v.set = set

		if v.selector_config.background then
			local bgc = v.selector_config.background
			local csrf = fill_surface(1, 1, bgc[1], bgc[2], bgc[3])
			blend_image(v.vid, bgc[4])
			image_sharestorage(csrf, v.vid)
			delete_image(csrf)
		end

		local fmtstr =
			string.format(
				"\\ffonts/%s,%d\\#%s",
				v.selector_config.font or gconfig_get("font_def"),
				active_display().font_deltav +
				(v.selector_config.font_sz or gconfig_get("font_sz")),
				v.selector_config.text_color or gconfig_get("text_color")
			)

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
			image_inherit_order(vid, true)
			if si then
				show_image(vid)
			end

-- animate the current item
			if ind == 1 and animation then
				move_image(vid, 20, vadv)
				move_image(vid, 0, vadv, animation)
				move_image(vid, 20, vadv, animation)
				image_transform_cycle(vid, true)
			else
				move_image(vid, 20, vadv)
			end

			vadv = vadv + h

			table.insert(selector.vids, vid)

			if v.y + vadv + h > v.y2 then
				v.end_index = i
				break
			end
			ind = ind + 1
		end

		v.index = 1
	end

	local function step_set(sel, step)
	end

	local selector = {
		set = apply_set,
		step = step_set,
		wnd = wnd,
		vids = {}
	}

	selector:set(set)
	selector:step(0)

	return selector
end

local function handler_for_file(path, file, set)
	if file == "AlbumInfo.txt" then
-- all .flac files go into unique items
-- LRC ( [mm:ss:fract] (Text) )
-- preview = cover
-- [ID]      ...
-- [Title]   ...
-- [Artists] ...
-- [ReleaseDate] ...
-- [SongNum] ...
-- [Duration] ...
-- with filename matching something like num - group - title
		return true
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

-- allow navigation into subdirs
			else
				table.insert(res,
					{
						slots = {},
						text = v,
						path = string.format(
							"/target/composition/selectors/%s/generate=%s",
							item.selector, path .. "/" .. v
						)
					}
				)
			end
		end
	end

-- instantiate selector with list, or if we have one, switch set
	if wnd.selectors[item.selector] then
		wnd.selectors[item.selector]:set(res)
	else
		wnd.selectors[item.selector] = selectors[item.selector](wnd, item, res)
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
				else
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
	end

	v.vid = nsrf
end

local function handle_input(wnd, iotbl)
-- consume a few basic bindings, these need to be rebindable
-- if something interactive is marked and alive, forward there
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

	wnd.input_table = handle_input

	wnd.list = {}  -- track current list
	wnd.slots = {} -- track map between logical names / roles and content provided
	wnd.selectors = {} -- instantiated selectors (typically 1 but no firm restriction)

	wnd.mousemotion = motion
	wnd.mousebutton = button
	wnd.mousedblclick = dblclick
	wnd.input_table = inputtable

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
		for i=1,#layout.items do
			load_item(wnd, ensure_fields(layout.items[i]))
		end
		wnd.list = layout.items
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
