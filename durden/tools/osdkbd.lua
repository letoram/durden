--
-- missing / desired
--
--  [ ] buffered input field
--
--  [ ] sending longer strings and not single u8 codepoints
--
--  [ ] completion that uses decode for spelling and IME suggestions
--
--  [ ] audio button that takes capture audio, forwards into encode
--      that does speech-to-text
--
local log, fmt = suppl_add_logfn("tools");
system_load("builtin/osdkbd.lua")()

-- attach to the suppl_widget_path to be treated as a widget on any path as well
-- should probably also attach to the cursor selector for when the inputfield one
-- is desired

local osd = {
	active = false,
	kbd = {},
	names = {}
}
local layout_cache = {}

-- make sure that if the tool gets reloaded, we won't leave hundrds of hanging
-- mouse handlers or button handlers for others to trip on
local function cleanup()
	for k,v in pairs(osd.kbd) do
		if v.ctx then
			v.ctx:destroy()
		end
		v.ctx = nil
	end
end

local function send_press_release(u8, mods, sym, label)
	local ktbl = {
		kind = "digital",
		translated = true,
		active = true,
		utf8 = u8,
		devid = 0,
		subid = sym,
		label = label,
		number = sym,
		modifiers = mods,
		keysym = sym
	}

-- press and release
	durden_input(ktbl)
	ktbl.active = false
	ktbl.utf8 = nil
	durden_input(ktbl)
end

local function list_layouts(rescan)
	if rescan then
		layout_cache = glob_resource("devmaps/osd/*.lua", APPL_RESOURCE);
		for i=#layout_cache, 1 do
			if string.sub(layout_cache[i], -4) ~= ".lua" or #layout_cache[i] == 4 then
				table.remove(layout_cache, i)
			end
		end
	end

	return layout_cache
end

-- the devmaps keyboard format is simplified to tables of strings with
-- some special reserved ones for logic functions to more easily convert
-- and import existing layouts from other systems
local function build_button(kbd, sym)
	local btn = {
		sym = sym,

-- this might need 'per selected window' overrides in order for things like
-- an xkb map to be generated and the corresponding symbol sent in order to
-- work with other clients
		handler =
			function()
				send_press_release(sym, 0, 0, "")
			end
	}

	if string.sub(sym, 1, 1) == "$" then
		local first, rest = string.split_first(sym, ";")
		local cmd, arg = string.split_first(first, "=")
		if #cmd == 0 then
			cmd = arg
		end

		if cmd == "$page" then
			if arg and tonumber(arg) then
				btn.handler = tonumber(arg)
			else
				log("bad_button_definition:" .. sym)
			end
		elseif cmd == "$code" then
			btn.handler = function()
				send_press_release("", 0, tonumber(arg), "")
			end
		elseif cmd == "$alias" then
			btn.handler =
			function()
				send_press_release(arg, 0, 0, "")
			end
		elseif cmd == "$path" then
			btn.handler = function()
				dispatch_symbol(arg)
			end
		elseif cmd == "$hide" then
			btn.handler = function()
				kbd.active = false
				kbd.ctx:hide()
			end
		end
		btn.sym = rest
	end

	return btn
end

local function add_keyboard(val, nostore)
	table.insert(osd.names, val)

	local base = list_layouts()[1]
	local kbd = {
		layout = base,
		position = "cursor",
		name = val,
		bgcol = "\\#111111",
		btnselcol = "\\#999999",
		btncol = "\\#222222",
		latchcol = "\\#aa4400",
		labelcol = "\\#ffffff",
		shadow = {}
	}
	osd.kbd[val] = kbd

	if not nostore then
		local prefix = "osdkbd_" .. val
		local keys = {}

		keys[prefix .. "_layout"] = kbd.layout
		keys[prefix .. "_position"] = kbd.position
		keys[prefix .. "_font_sz"] = kbd.fontsz
		keys[prefix .. "_bgcol"] = kbd.bgcol
		keys[prefix .. "_btncol"] = kbd.btncol
		keys[prefix .. "_latchcol"] = kbd.latchcol
		keys[prefix .. "_labelcol"] = kbd.labelcol

		store_key(keys)
	end
end

-- scan and load defaults, stored as osdkbd_name_[keys]=val
list_layouts(true)
local set = match_keys("osdkbd_%") or {}
for i,v in ipairs(set) do
	local key, val = string.split_first(v, "=")
	local set = string.split(key, "_");

	if not osd.kbd[set[2]] then
		add_keyboard(set[2], true)
	end
	local kbd = osd.kbd[set[2]]
	if set[3] == "layout" then
		kbd.layout = val
	elseif set[3] == "position" then
		kbd.position = val
	elseif string.match(set[3], "col") then
		kbd[set[3]] = val
	end
end

local function rebuild_kbd(v)
	local layout = system_load("devmaps/osd/" .. v .. ".lua")()
	local scalef = active_display().scalef

	local kbd = osd.kbd[v]
	if kbd.ctx then
		kbd.ctx:destroy()
	end

	local opts =
	{
		hpad = math.ceil(10 * scalef),
		vpad = math.ceil(10 * scalef),
		animation_speed = gconfig_get("popup_animation"),
		animation_fn = INTERP_LINEAR,
		input_string =
		function(msg)
-- re-inject as translated durden_input
		end
	}

-- first all of the regular pages
	local max_cols = 1
	local max_rows = 1

	local converted_layout = {}

	for i, page in ipairs(layout) do
		local new_page = {}

		for j, row in ipairs(page) do
			local new_row = {}

			for k, col in ipairs(row) do
				table.insert(new_row, build_button(kbd, col))
			end
			if #new_row > max_cols then
				max_cols = #new_row
			end

			table.insert(new_page, new_row)
			if #new_page > max_rows then
				max_rows = #new_page
			end
		end

		table.insert(converted_layout, new_page)
	end

-- then the special 'bottom' that is omnipresent controls
	if layout.bottom then
		local row = {}
		for _, col in ipairs(layout.bottom) do
			table.insert(row, build_button(kbd, col))
		end
		opts.bottom = row
		max_rows = max_rows + 1
	end

-- calculate the kbd size based on desired UI font metrics, that is the
-- layout font size override combined with the per-display font-delta
	local sz = layout.size and layout.size or gconfig_get("font_sz")
	sz = math.ceil(sz * scalef)
	local fontstr = "\\f," .. tostring(sz) .. kbd.labelcol

	local _, txh = text_dimensions({fontstr, "p!`jY"})
	local txw, _ = text_dimensions({fontstr, "G"})
	local w = max_cols * (opts.hpad + 2 * txw)
	local h = max_rows * (opts.vpad + 2 * txh)

	local anchor = color_surface(w, h, suppl_hexstr_to_rgb(kbd.bgcol))
	image_inherit_order(anchor, true)

	kbd.display = active_display()
	kbd.ctx =
	osdkbd_build(anchor,
		function(sym)
			return
			function(btn, _, w, h)
				local bg = color_surface(w, h, suppl_hexstr_to_rgb(kbd.btncol))
				show_image(bg)
				link_image(bg, anchor)
				image_inherit_order(bg, true)
				order_image(bg, 1)
				shader_setup(bg, "ui", "sbar_item_bg", "inactive")

				local lsym = sym
				if type(lsym) == "function" then
					lsym = lsym(kbd)
				end

-- special reserved symbol factories for meta buttons like page selector,
-- window picker, ..
				local label, _, lw, lh, _ = render_text({fontstr, lsym})

				if valid_vid(label) then
					image_tracetag(label, "osd_ " .. lsym)
					show_image(label)

-- manually align as link_image(.., ANCHOR_C) won't actually align with the grid
-- so text would look weird, this should really be fixed in the engine
					link_image(label, bg)
					move_image(label,
						math.floor(0.5 * (w - lw)),
						math.floor(0.5 * (h - lh))
					)
					image_inherit_order(label, true)
					image_mask_set(label, MASK_UNPICKABLE)
				end
				return bg,
				{
				handler = lsym,
				over =
				function()
					if not btn.latched then
						image_color(bg, suppl_hexstr_to_rgb(kbd.btnselcol));
						shader_setup(bg, "ui", "sbar_item_bg", "active")
					end
				end,
				activate =
				function()
					local flash = color_surface(w, h, 255, 255, 255)
					link_image(flash, bg)
					image_inherit_order(flash, true)
					order_image(flash, 1)
					blend_image(flash, 1.0, 2)
					blend_image(flash, 0.0, 3)
					expire_image(flash, 5)
				end,
				out =
				function()
					if not btn.latched then
						image_color(bg, suppl_hexstr_to_rgb(kbd.btncol));
						shader_setup(bg, "ui", "sbar_item_bg", "inactive")
					end
				end,
				select =
				function()
					shader_setup(bg, "ui", "sbar_item_bg", "active")
				end,
				deselect =
				function()
					shader_setup(bg, "ui", "sbar_item_bg", "inactive")
				end,
				latch =
				function(on)
					btn.latched = on
					image_color(bg, suppl_hexstr_to_rgb(kbd.latchcol));
					shader_setup(bg, "ui", "sbar_item_bg", on and "alert" or "inactive")
				end,
				drag =
				function(ctx, vid, dx, dy)
					nudge_image(anchor, dx, dy)
				end
				}
			end
		end, converted_layout, opts);
end

local function show_kbd(v)
	local kbd = osd.kbd[v]

	link_image(kbd.ctx.canvas, active_display().order_anchor)
	order_image(kbd.ctx.canvas, 4)

	kbd.active = true
	kbd.ctx:show()

-- attach or build/attach
	local props = image_surface_resolve(kbd.ctx.canvas)
	kbd.shadow.anchor = kbd.ctx.canvas
	suppl_region_shadow(kbd.shadow, props.width, props.height)

	local x, y = mouse_xy()
	move_image(osd.kbd[v].ctx.canvas, x, y)
end

local function hide_kbd(v)
	osd.kbd[v].active = false
	osd.kbd[v].ctx:hide()
end

local function color_for_kbd(v)
	local kbd = osd.kbd[v]
	local res =
	{
		{
			name = "background",
			label = "Background",
			description = "Change the keyboard canvas color",
		},
		{
			name = "button",
			label = "Button",
			description = "Change the default button color"
		},
		{
			name = "latched",
			label = "Latched",
			description = "Change the default latched button color"
		}
	}

	suppl_append_color_menu(kbd.bgcol, res[1],
		function(str)
			kbd.bgcol = str
			store_key("osdkbd_" .. v .. "_bgcol", str)
		end
	)

	suppl_append_color_menu(kbd.btncol, res[2],
		function(str)
			kbd.btncol = str
			store_key("osdkbd_" .. v .. "_btncol", str)
		end
	)

	suppl_append_color_menu(kbd.latchcol, res[3],
		function(str)
			kbd.latchcol = str
			store_key("osdkbd_" .. v .. "_latchcol", str)
		end
	)

	return res
end

local function menu_for_kbd(v)
	local res =
	{
	{
		name = "Layout",
		label = "Layout",
		description = "Switch keyboard layout description",
		initial = osd.kbd[v].layout,
		kind = "value",
		set = list_layouts(),
		handler = function(ctx, val)
			osd.kbd[v].layout = val
			rebuild_kbd(v)
		end
	},
	{
		name = "position",
		label = "Position",
		description = "Set activation and position behaviour",
		kind = "value",
		set = {"float", "cursor", "window", "new_window"},
		initial = osd.kbd[v].position,
		function(ctx, val)
			osd.kbd[v].position = val
		end
	},
	{
		name = "show",
		label = "Show",
		description = "Mark the OSD Keyboard as visible / active",
		kind = "action",
		handler =
		function()
			if not osd.kbd[v].ctx or active_display() ~= osd.kbd[v].display then
				rebuild_kbd(v)
			end
			show_kbd(v)
		end
	},
	{
		name = "set_page",
		label = "Set Page",
		kind = "value",
		eval = function()
			return osd.kbd[v].ctx ~= nil
		end,
		set = function()
			local res = {}
			for i=1,#osd.kbd[v].ctx.pages do
				table.insert(res, tostring(i))
			end
			return res;
		end,
		handler = function(ctx, val)
			osd.kbd[v].ctx:set_page(tonumber(val))
		end
	},
	{
		name = "hide",
		label = "Hide",
		description = "Mark the OSD Keyboard as invisible / hidden",
		kind = "action",
		handler =
		function()
			if not osd.kbd[v].ctx then
				return
			end
			hide_kbd(v)
		end
	},
	{
		name = "toggle",
		label = "Toggle",
		description = "Toggle keyboard visibility",
		kind = "action",
		handler =
		function()
			if not osd.kbd[v].ctx or active_display() ~= osd.kbd[v].display then
				rebuild_kbd(v)
			end
			if osd.kbd[v].active then
				hide_kbd(v)
			else
				show_kbd(v)
			end
		end
	},
	{
		name = "colors",
		label = "Colors",
		description = "Change keyboard, button and text colors",
		kind = "action",
		submenu = true,
		handler = color_for_kbd(v)
	},
	{
		name = "remove",
		label = "Remove",
		description = "Deactive and remove the keyboard definition",
		kind = "action",
		handler = function()
			if osd.kbd[v].ctx then
				osd.kbd[v].ctx:destroy()
			end
			local prefix = "osdkbd_" .. v
			store_key(prefix .. "_layout", "")
			store_key(prefix .. "_position", "")
			osd.kbd[v] = nil
			table.remove_vmatch(osd.kbd, v)
		end,
	}}
	return res
end

local function gen_kbd_menu()
	local res = {}

	for _, v in ipairs(osd.names) do
		table.insert(res,
			{
				name = v,
				label = v,
				kind = "action",
				submenu = true,
				handler = function()
					return menu_for_kbd(v)
				end
			}
		);
	end
	return res
end

local menu =
{{
	name = "rescan",
	kind = "action",
	label = "Rescan",
	description = "Sweep devmaps/osd/*.lua for keyboard layouts",
	handler = function()
		list_layouts(true)
	end
},
{
	name = "error",
	kind = "action",
	label = "Error (no layouts in devmaps/osd)",
	eval = function()
		return #list_layouts() == 0
	end,
	handler = function()
	end,
},
{
	name = "keyboards",
	label = "Keyboards",
	kind = "action",
	submenu = true,
	eval = function()
		return #osd.names > 0 and #list_layouts() > 0
	end,
	handler = function()
		return gen_kbd_menu()
	end,
},
{
	name = "new",
	label = "New",
	description = "Create a new Keyboard from a layout description",
	kind = "value",
	eval = function()
		return #list_layouts() > 0
	end,
	validator = function(val)
		if #val > 0 then
			if table.find_i(osd.kbd, val) then
				return false
			end
			return suppl_valid_name(val)
		end
	end,
	handler = function(ctx, val)
		add_keyboard(val);
	end
}}

suppl_tools_register_closure(cleanup)

menus_register("global", "input",
{
	name = "osdkbd",
	label = "On-Screen Keyboard",
	kind = "action",
	submenu = true,
	handler = menu
})
