-- (1 is used for alpha, the k/v mapping comes from tui
local function key_to_graphmode(k)
	local tbl = {
		primary = 2,
		secondary = 3,
		background = 4,
		text = 5,
		cursor = 6,
		altcursor = 7,
		highlight = 8,
		label = 9,
		warning = 10,
		error = 11,
		alert = 12,
		inactive = 13
	};
	return tbl[k];
end

local preset_set =
{
	monochrome = {
		"\\#a0a0a0",
		"\\#afafaf",
		"\\#bababa",
		"\\#bfbfbf",
		"\\#cacaca",
		"\\#cfcfcf",
		"\\#dadada",
		"\\#dfdfdf"
	},
	default = {
		"\\#efd469",
		"\\#43abc9",
		"\\#cd594a",
		"\\#b5c689",
		"\\#f58b4c",
		"\\#ed6785",
		"\\#d0d0d0",
	},
	pastel = {
		"\\#ffadad",
		"\\#ffd6a5",
		"\\#fdffb6",
		"\\#caffbf",
		"\\#9bf6ff",
		"\\#a0c4ff",
		"\\#bdb2ff",
		"\\#ffc6ff",
	},
	browns = {
		"\\#a48971",
		"\\#8d6b48",
		"\\#9a774f",
		"\\#a9845a",
		"\\#be986d",
		"\\#d2a87d",
		"\\#e8c9ab"
	},
	light = {
		"\\#f1e2d7",
		"\\#f9f9f7",
		"\\#f8d5c2",
		"\\#deeae8",
		"\\#cddcdf",
		"\\#f3e7e3",
		"\\#f8eeea",
		"\\#f5d3c5"
	},
	aqua = {
		"\\#00f0d0",
		"\\#00ffc8",
		"\\#00e2d8",
		"\\#00d3e0",
		"\\#00c5e7",
		"\\#00b6ef",
		"\\#00a8f7",
		"\\#0099ff"
	},
	dull = {
		"\\#cb997e",
		"\\#eddcd2",
		"\\#fff1e6",
		"\\#f0efeb",
		"\\#ddbea9",
		"\\#a5a58d",
		"\\#b7b7a4",
		"\\#c5c5b6"
	}
}

local function gen_palette_menu()
	local pc = {}
	for k,v in pairs(preset_set) do
		table.insert(pc, k)
	end
	table.sort(pc)

	local list = {
		{
			name = "schemes",
			kind = "value",
			label = "Schemes",
			description = "Pick a preset high-contrast scheme",
			set = pc,
			handler = function(ctx, val)
				local pal = preset_set[val]
				HC_PALETTE = pal
				local keys = {
					"lbar_textstr",
					"lbar_alertstr",
					"lbar_labelstr",
					"lbar_menulblstr",
					"lbar_menulblselstr",
					"lbar_helperstr",
					"lbar_errstr"
				}
				for i,v in ipairs(keys) do
					gconfig_set(v, HC_PALETTE[i] .. " ")
				end
				local r, g, b = suppl_hexstr_to_rgb(HC_PALETTE[8])

				gconfig_set("lbar_caret_col", {r, g, b})
			end,
		}
	};

	for i,v in ipairs(HC_PALETTE) do
		local tbl = {
			name = "hc_ind_" .. tostring(i),
			format = HC_PALETTE[i],
			label = "COLOR_" .. tostring(i)
		};
		suppl_append_color_menu(v, tbl,
		function(new)
			HC_PALETTE[i] = new;
		end);
		tbl.hint = {HC_PALETTE[i], "(current color)"},
		table.insert(list, tbl);
	end
	return list;
end

return {
{
	name = "hc_palette",
	kind = "action",
	label = "Palette",
	submenu = true,
	description = "High contrast palette, used for durden UI elements",
	handler = gen_palette_menu()
},
{
	name = "colorscheme",
	label = "Tui/Terminal Scheme",
	kind = "value",
	description = "Change the current and default set of colors used for terminal/tui clients",
	set = function()
		return suppl_colorschemes()
	end,
	initial = function() return gconfig_get("tui_colorscheme"); end,
	handler = function(ctx, val)
		gconfig_set("tui_colorscheme", val)
		for wnd in all_windows("tui", true) do
			suppl_tgt_color(wnd.external, val)
		end
		for wnd in all_windows("terminal", true) do
			suppl_tgt_color(wnd.external, val)
		end
	end
},
};
