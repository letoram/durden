-- apply the hide- target config (tgt) defined as part of 'advfloat_hide'
gconfig_register("advfloat_hide", "statusbar-left");

-- needed by the statusbar resolve function to handle size changes
local function resolve_icon(wnd)
	return function(minh)
		if not valid_vid(wnd.canvas) then
			return;
		end

		return wnd:iconify({label = false, background = false, size = minh});
	end
end

local function setup_sbar(wnd, tgt)
	local wm = wnd.wm;
	local pad = gconfig_get("sbar_tpad") * wm.scalef;
	local str = string.sub(tgt, 11);
	local btn;

	local on_destroy;
	on_destroy =
	function()
		if (btn) then
			wnd.minimize_btn = nil;
			btn:destroy();
		end
	end

	local cbase = wm.statusbar.base;
	local old_show = wnd.show;
	btn = wm.statusbar:add_button(str, "sbar_item_bg",
		"sbar_item", resolve_icon(wnd), pad,
		wm.font_resfn, cbase, cbase,
		{
		click =
		function()
			local props = image_surface_resolve(btn.bg);
			wnd.minimize_btn = nil;
			wnd.show = old_show;
			wnd:drop_handler("destroy", on_destroy);
			btn:destroy();
			wnd.wm:switch_ws(wnd.space);
			wnd:select();
			if (#wm.on_wnd_hide > 0) then
				for k,v in ipairs(wm.on_wnd_hide) do
					v(wm, wnd, props.x, props.y, props.width, props.height, false);
				end
			else
				wnd:show();
				wnd:select();
			end
			wnd.space:resize();
		end
		}
		);

-- not enough VIDs to build the button, indicative of leak
	if (not btn) then
		warning("hide-to-button: creation failed");
		return;
	end

-- override this so we drop the icon if the window show is triggered by some other
-- means, do this by simulating a button click so the same code path gets reused.
	wnd.show =
	function(wnd)
		if (btn.bg) then
			btn:click();
		else
			wnd.show = old_show;
			old_show(wnd);
		end
	end;

-- safeguard against window being destroyed while hidden
	wnd:add_handler("destroy", on_destroy);
	wnd:deselect();
	wnd.minimize_btn = btn;

-- event handler registered? (flair tool)
	if (#wm.on_wnd_hide > 0) then
		local props = image_surface_resolve(btn.bg);
		for k,v in ipairs(wm.on_wnd_hide) do
			v(wm, wnd, props.x, props.y, props.width, props.height, true);
		end
	else
		wnd:hide();
		wnd.space:resize();
	end
end

local function hide_tgt(wnd, tgt)
-- prevent dual invocation (from ipc or wherever)
	if wnd.minimize_btn then
		return;
	end

	if (tgt == "statusbar-left" or tgt == "statusbar-right") then
		setup_sbar(wnd, tgt);
	else
		warning("unknown hide target: " .. tgt);
	end
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
	set = {"disabled", "statusbar-left", "statusbar-right", "desktop-icon"},
	handler = function(ctx, val)
		gconfig_set("advfloat_hide", val);
	end
});
