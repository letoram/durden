--
-- menu- popup tool
--
-- this is simply to allow user- bindable / scriptable controls to use
-- the uiprim/popup and the corresponding uimap/popup to glue together
-- user customizable popup menus, real implementation is thus in the
-- other scripts mentioned.
--
local log = suppl_add_logfn("tools");
local mpos = mouse_xy;

local function popup(path, x, y)
	local menu = menu_resolve(path);
	if not menu then
		log("tool=popup:kind=error:message=couldn't resolve:path=" .. path);
		return;
	end

-- convert single entry resolve
	if (type(menu[1]) ~= "table") then
		menu = {menu};
	end

	log("tool=popup:kind=status:message=spawn menu, " .. tonumber(#menu) .. " entries");
	uimap_popup(menu, x, y);
end

local popup_positions = {
{
	kind = "cursor",
	label = "Cursor",
	kind = "action",
	description = "Spawn new popups at the current mouse cursor",
	handler = function()
		mpos = mouse_xy;
	end,
},
{
	kind = "position",
	label = "Position",
	kind = "value",
	hint = "(normalised: 0..1 0..1)",
	validator = suppl_valid_typestr("ff", 0, 1, 0),
	description = "Spawn new popups at a fixed position on the current screen",
	handler = function(val)
		local tbl = suppl_unpack_typestr("ff", 0, 1, 0);
		if not tbl then
			return;
		end
		local x = tbl[1];
		local y = tbl[2];
		mpos = function()
			local ad = active_display();
			return math.floor(ad.max_w * x), math.floor(ad.max_h * y);
		end
	end
}
};

local popup_menu = {
{
	name = "position",
	label = "Position",
	kind = "action",
	submenu = true,
	handler = popup_positions
},
{
	name = "menu",
	kind = "value",
	label = "Menu",
	description = "Spawn a popup for the specified menu path",
	hint = "(/path/to/elem)",
	validator = function(val)
		return val and #val > 0;
	end,
	handler = function(ctx, val)
		local x, y = mpos();
		popup(val, x, y);
	end,
},
};

menus_register("global", "tools",
{
	name = "popup",
	label = "Popup",
	kind = "action",
	submenu = true,
	description = "Popup- spawning related controls",
	handler = popup_menu
});
