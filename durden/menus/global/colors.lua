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

local function gen_palette_menu()
	local list = {};
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
-- text color
-- label color
-- alertstr
-- labelstr
-- menulblstr
-- menulblselstr
-- helperstr
-- errstr
-- seltextstr
-- pretiletext_color
-- tbar_textstr
}
};
