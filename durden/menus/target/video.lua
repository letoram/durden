local hint_lut = {
	none = 0,
	mono = 1,
	light = 2,
	normal = 3,
	subpixel = 4
};

local lbl_hint_lut = {};
for k,v in pairs(hint_lut) do lbl_hint_lut[v] = k; end

local function set_scalef(mode)
	local wnd = active_display().selected;
	if (wnd) then
		wnd.scalemode = mode;
		wnd:resize(wnd.width, wnd.height);
	end
end

local function set_filterm(mode)
	local wnd = active_display().selected;
	if (mode and wnd) then
		wnd.filtermode = mode;
		image_texfilter(wnd.canvas, mode);
	end
end

local filtermodes = {
	{
		name = "none",
		label = "None",
		kind = "action",
		handler = function() set_filterm(FILTER_NONE); end
	},
	{
		name = "linear",
		label = "Linear",
		kind = "action",
		handler = function() set_filterm(FILTER_LINEAR); end
	},
	{
		name = "bilinear",
		label = "Bilinear",
		kind = "action",
		handler = function() set_filterm(FILTER_BILINEAR); end
	}
};

local scalemodes = {
	{
		name = "normal",
		label = "Normal",
		kind = "action",
		handler = function() set_scalef("normal"); end
	},
	{
		name = "stretch",
		label = "Stretch",
		kind = "action",
		handler = function() set_scalef("stretch"); end
	},
	{
		name = "aspect",
		label = "Aspect",
		kind = "action",
		handler = function() set_scalef("aspect"); end
	},
	{
		name = "client",
		label = "Client",
		kind = "action",
		handler = function() set_scalef("client"); end
	}
};

local function fs_handler(wnd, sym, iotbl, path)
	if (not sym and not iotbl) then
		display_fullscreen(active_display(
			false, true).name, BADID, val == "Mode Switch");
		return;
	end
	if (valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		target_input(wnd.external, iotbl);
	end
-- HACK: the dispatch- override wasn't intended for this purpose, but
-- will forward mouse samples for us as well. The "ok, outsym,.."
-- value matching in durden_input only interrupts input for digital
-- sources though as that would otherwise break mouse routing, but that
-- is what we want here.
	iotbl.digital = true;
	return true, sym, iotbl, path;
end

local function mouse_lockfun(rx, ry, x, y, wnd, ind, act)
-- simulate the normal mouse motion in the case of constrained input
	if (true) then return; end
	if (ind) then
		wnd.mousebutton({tag = wnd}, ind, act, x, y);
	else
		wnd.mousemotion({tag = wnd}, x, y, rx, ry);
	end
end

local advanced = {
	{
		name = "source_fs",
		label = "Source-Fullscreen",
		kind = "value",
		eval = function() return not display_simple() and valid_vid(
			active_display().selected.external, TYPE_FRAMESERVER); end,
		set = {"Stretch", "Mode Switch"},
		handler = function(ctx, val)
			local wnd = active_display().selected;
			display_fullscreen(active_display(false, true).name,
				wnd.external, val == "Mode Switch");
			dispatch_toggle(function(sym, iot, path)
				return fs_handler(wnd, sym, iot, path);
			end
			);
		end
	},
	{
		name = "density_override",
		label = "Override Density",
		kind = "value",
		hint = "(10..100)",
		eval = function(ctx, val)
			local wnd = active_display().selected;
			return (valid_vid(wnd and wnd.external, TYPE_FRAMESERVER));
		end,
		validator = gen_valid_num(15, 100),
		handler = function(ctx, val)
			local wnd = active_display().selected;
			wnd.density_override = tonumber(val);
			target_displayhint(wnd.external,
				0, 0, wnd.dispmask, wnd:display_table(wnd.wm.disptbl));
		end
	},
	{
		name = "source_hpass",
		label = "Toggle Handle Passing",
		kind = "action",
		eval = function(ctx, val)
			local wnd = active_display().selected;
			return (valid_vid(wnd and wnd.external, TYPE_FRAMESERVER));
		end,
		handler = function(ctx, val)
			target_flags(active_display().selected.external, TARGET_NOBUFFERPASS, true);
		end
	},
	{
	name = "source_color",
	label = "Color/Gamma Sync",
	kind = "value",
	set = {"None", "Global"},
	eval = function(ctx, val)
		local wnd = active_display().selected;
			return (valid_vid(wnd and wnd.external, TYPE_FRAMESERVER));
	end,
	handler = function(ctx, val)
		local wnd = active_display().selected;
		wnd.gamma_mode = string.lower(val);
		target_flags(active_display().selected.external, TARGET_ALLOWCM, true);
	end
	},
	{
	name = "block_rz",
	label = "Block Resize Hints",
	kind = "value",
	set = {LBL_YES, LBL_NO},
	initial = function()
		return active_display().selected.block_rz_hint and LBL_YES or LBL_NO;
	end,
	handler = function(ctx, val)
		active_display().selected.block_rz_hint = val == LBL_YES;
	end
	}
};

-- simply copied from display and modified to retrieve from window if possible.
-- this is messier in that we need to manage the font_block property, and work
-- around the fact that terminal uses its own prefix
local font_override = {
	{
		name = "size",
		label = "Size",
		kind = "value";
		validator = gen_valid_num(1, 100),
		eval = function() return active_display().selected.last_font ~= nil; end,
		initial = function()
			local wnd = active_display().selected;
			return tostring(wnd.last_font[1]);
		end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			local ob = wnd.font_block;
			wnd.font_block = false;
			wnd:update_font(tonumber(val), -1);
			wnd.font_block = ob;
		end
	},
	{
		name = "hinting",
		label = "Hinting",
		kind = "value",
		set = {"none", "mono", "light", "normal", "subpixel"},
		eval = function() return active_display().selected.last_font ~= nil; end,
		initial = function()
			return lbl_hint_lut[active_display().selected.last_font[2]];
		end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			local ob = wnd.font_block;
			wnd.font_block = false;
			wnd:update_font(-1, hint_lut[val]);
			wnd.font_block = ob;
		end
	},
	{
		name = "name",
		label = "Font",
		kind = "value",
		set = function()
			local set = glob_resource("*", SYS_FONT_RESOURCE);
			set = set ~= nil and set or {};
			return set;
		end,
		eval = function() return active_display().selected.last_font ~= nil; end,
		initial = function()
			return active_display().selected.last_font[3][1];
		end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			local ob = wnd.font_block;
			wnd.font_block = false;
			wnd.last_font[3][1] = val;
			wnd:update_font(-1, -1, wnd.last_font[3]);
			wnd.font_block = ob;
		end
	},
	{
		name = "fbfont",
		label = "Fallback",
		kind = "value",
		set = function()
			local set = glob_resource("*", SYS_FONT_RESOURCE);
			set = set ~= nil and set or {};
			return set;
		end,
		eval = function() return active_display().selected.last_font ~= nil; end,
		initial = function()
			return active_display().selected.last_font[3][2];
		end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			local ob = wnd.font_block;
			wnd.font_block = false;
			wnd.last_font[3][2] = val;
			wnd:update_font(-1, -1, wnd.last_font[3]);
			wnd.font_block = ob;
		end
	}
};

return {
	{
		name = "scaling",
		label = "Scaling",
		kind = "action",
		submenu = true,
		handler = scalemodes
	},
	{
		name = "filtering",
		label = "Filtering",
		kind = "action",
		submenu = true,
		handler = filtermodes
	},
	{
		name = "screenshot",
		label = "Screenshot",
		kind = "value",
		hint = "(stored in output/)",
		validator = function(val)
			return string.len(val) > 0 and not resource("output/" .. val) and
				not string.match(val, "%.%.");
		end,
		handler = function(ctx, val)
			save_screenshot("output/" .. val, FORMAT_PNG,
				active_display().selected.canvas);
		end
	},
-- there are tons of controls that could possibly be added here,
-- the better solution is probably to allow a record-tool window with
-- all the knobs needed for mixing, adding / dropping sources etc.
	{
		name = "record",
		label = "Record",
		kind = "value",
		hint = suppl_recarg_hint,
		hintsel = suppl_recarg_eval,
		validator = suppl_recarg_valid,
		eval = function()
			return not active_display().selected.in_record and
				suppl_recarg_eval();
		end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			wnd.in_record = suppl_setup_rec(wnd, val);
		end
	},
	{
		name = "record_noaudio",
		label = "Record (no sound)",
		kind = "value",
		hint = suppl_recarg_hint,
		hintsel = suppl_recarg_eval,
		validator = suppl_recarg_valid,
		eval = function()
			return not active_display().selected.in_record and
				suppl_recarg_eval();
		end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			wnd.in_record = suppl_setup_rec(wnd, val, true);
		end
	},
	{
		name = "stop_record",
		label = "Stop Record",
		kind = "action",
		eval = function(val)
			return valid_vid(active_display().selected.in_record);
		end,
		handler = function()
			local wnd = active_display().selected;
			delete_image(wnd.in_record);
			wnd.in_record = nil;
		end
	},
	{
		name = "shader",
		label = "Shader",
		kind = "value",
		set = function() return shader_list({"effect", "simple"}); end,
		handler = function(ctx, val)
			local key, dom = shader_getkey(val, {"effect", "simple"});
			if (key ~= nil) then
				shader_setup(active_display().selected.canvas, dom, key);
			end
		end
	},
	{
		name = "opacity",
		label = "Opacity",
		hint = "(0..1)",
		initial = function()
			return
				image_surface_resolve(active_display().selected.canvas).opacity;
		end,
		kind = "value",
		validator = gen_valid_num(0.0, 1.0),
		handler = function(ctx, val)
			blend_image(active_display().selected.canvas, tonumber(val));
		end
	},
	{
		name = "font",
		label = "Font",
		kind = "action",
		eval = function() return active_display().selected.last_font ~= nil; end,
		submenu = true,
		handler = font_override,
	},
	{
		label = "Advanced",
		name = "advanced",
		submenu = true,
		kind = "action",
		handler = advanced
	}
};
