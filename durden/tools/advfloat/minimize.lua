-- apply the hide- target config (tgt) defined as part of 'advfloat_hide'
gconfig_register("advfloat_hide", "statusbar-left");
local log, fmt = suppl_add_logfn("tools")

-- needed by the statusbar resolve function to handle size changes
local function resolve_icon(wnd)
	return function(minh)
		if not valid_vid(wnd.canvas) then
			return;
		end

		return wnd:iconify({label = false, background = false, size = minh});
	end
end

local function restore_wnd(wnd, props)
	local wm = wnd.wm
	wnd.show = wnd.old_show
	wnd.old_show = nil
	wnd:drop_handler("destroy", wnd.bgicon_destroy)
	wnd.bgicon_destroy = nil
	wnd.wm:switch_ws(wnd.space)

	if #wm.on_wnd_hide > 0 then
		for i,v in ipairs(wm.on_wnd_hide) do
			v(wm, wnd, props.x, props.y, props.width, props.height, false)
		end
	else
		wnd:show()
		wnd:select()
	end

	wnd.space:resize()
end

local function setup_icon(wnd, icon)
	wnd.bgicon_destroy =
	function()
		icon:destroy()
	end

-- out of band- show (via menus or bindings)
	wnd.old_show = wnd.show
	wnd.show =
	function(wnd)
		restore_wnd(wnd, image_surface_resolve(icon.vid))
	end

	wnd:add_handler("destroy", on_destroy)
	wnd:deselect()

-- respect flair hooks for animation
	if #wnd.wm.on_wnd_hide > 0 then
		local props = image_surface_resolve(icon.vid)
		for k,v in ipairs(wm.on_wnd_hide) do
			v(wm, wnd, props.x, props.y, props.width, props.height, true)
		end
	else
		wnd:hide()
		wnd.space:resize()
	end
end

local function setup_sbar(wnd, tgt)
	local wm = wnd.wm;
	local pad = gconfig_get("sbar_tpad") * wm.scalef;
	local str = string.sub(tgt, 11);
	local btn;

	local on_destroy;
	wnd.bgicon_destroy =
	function()
		if (btn) then
			wnd.minimize_btn = nil;
			btn:destroy();
		end
	end

	local cbase = wm.statusbar.base;
	wnd.old_show = wnd.show;
	btn = wm.statusbar:add_button(str, "sbar_item_bg",
		"sbar_item", resolve_icon(wnd), pad,
		wm.font_resfn, cbase, cbase,
		{
		click =
		function()
			local props = image_surface_resolve(btn.bg)
			wnd.minimize_btn = nil
			restore_wnd(wnd, props)
			btn:destroy()
		end,
		hover = function(btn, _, x, y, on)
			local vid = null_surface(32, 32);
			image_sharestorage(wnd.canvas, vid);
			mouse_handler_factory.hover_preview(btn, vid, x, y, on)
		end
		}
	);

-- not enough VIDs to build the button, indicative of leak
	if (not btn) then
		log("tool=advfloat:kind=error:button creation failed")
		return
	end

-- override this so we drop the icon if the window show is triggered by some other
-- means, do this by simulating a button click so the same code path gets reused.
	wnd.show =
	function(wnd)
		if (btn.bg) then
			btn:click()
		else
			wnd.show = wnd.old_show;
			wnd:show(wnd)
		end
	end

-- safeguard against window being destroyed while hidden
	wnd:add_handler("destroy", on_destroy)
	wnd:deselect()
	wnd.minimize_btn = btn

-- event handler registered? (flair tool)
	if #wm.on_wnd_hide > 0 then
		local props = image_surface_resolve(btn.bg)
		for k,v in ipairs(wm.on_wnd_hide) do
			v(wm, wnd, props.x, props.y, props.width, props.height, true)
		end
	else
		wnd:hide()
		wnd.space:resize()
	end
end

local function hide_tgt(wnd, tgt)
-- prevent dual invocation (from ipc or wherever)
	if wnd.minimize_btn then
		return;
	end

	if (tgt == "statusbar-left" or tgt == "statusbar-right") then
		setup_sbar(wnd, tgt);
		return
	end

-- desktop-icon:
	local icon
	icon = {
		name = wnd.name .. "_bgicon",
		label = wnd.title,
		factory =
		function(w, h)
			return wnd:iconify({size = w})
		end,
		trigger = function()
			restore_wnd(wnd)
			icon:destroy()
		end
	}

	icon = bgicons_build_icon(icon)
	if not icon then
		log("tool=advfloat:kind=error:message=no icons active")
		hide_tgt(wnd, "statusbar-left")
		return
	end

	setup_icon(wnd, icon)
end

menus_register("target", "window",
{
	kind = "action",
	name = "minimize",
	label = "Minimize",
	description = "Minimize the window to a preset location",
	kind = "action",
	eval = function()
		return
			gconfig_get("advfloat_minimize") ~= "disabled";
	end,
	handler = function()
		local wnd = active_display().selected;
		if (not wnd.hide) then
			return;
		end
		local tgt = gconfig_get("advfloat_hide");
		hide_tgt(wnd, tgt);
	end
});

menus_register("global", "settings/wspaces/float",
{
	kind = "value",
	name = "hide_target",
	description = "Chose where the window hide option will compress the window",
	initial = gconfig_get("advfloat_hide"),
	label = "Hide Target",
	set = function()
		local set = {"disabled", "statusbar-left", "statusbar-right"}
		if gconfig_get("bgicon_enable") then
			table.insert(set, "desktop-icon")
		end
		return set
	end,
	handler = function(ctx, val)
		gconfig_set("advfloat_hide", val);
	end
});
