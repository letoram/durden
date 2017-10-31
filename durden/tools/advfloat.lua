--
-- Advanced float handler
-- This is a "silent" plugin which extends float management
-- with controls over window placement etc.
--
-- Kept here as a means to start removing policy from tiler.lua
-- and letting more parts of the codebase be "opt out"
--

-- this hook isn't "safe", someone who calls attach is expecting
-- that the window will have a compliant state afterwards, but we
-- can hide
gconfig_register("advfloat_spawn", "auto");
local mode = gconfig_get("advfloat_spawn");
local pending, pending_vid;

local function setup_cursor_pick(wm, wnd)
	wnd:hide();
	pending = wnd;
	local w = math.ceil(wm.width * 0.15);
	local h = math.ceil(wm.height * 0.15);
	pending_vid = null_surface(w, h);
	link_image(pending_vid, mouse_state().cursor);
	image_sharestorage(wnd.canvas, pending_vid);
	blend_image(pending_vid, 1.0, 10);
	image_inherit_order(pending_vid, true);
	order_image(pending_vid, -1);
	nudge_image(pending_vid,
	mouse_state().size[1] * 0.75, mouse_state().size[2] * 0.75);
	shader_setup(pending_vid, "ui", "regmark", "active");
end

local function activate_pending(mx, my)
	if (not mx) then
		mx, my = mouse_xy();
	end

	if (pending.move) then
		pending:move(mx, my, false, true, true);
		pending:show();
	end
	delete_image(pending_vid);
	pending = nil;
end

local function wnd_attach(wm, wnd)
	wnd:ws_attach(true);
	if (wnd.wm.active_space.mode ~= "float") then
		return;
	end

	if (pending) then
		activate_pending();
		if (DURDEN_REGIONSEL_TRIGGER) then
			suppl_region_stop();
		end
	end

	if (mode == "cursor") then
		setup_cursor_pick(wm, wnd);
		iostatem_save();
		local col = null_surface(1, 1);
		mouse_select_begin(col);
		dispatch_meta_reset();
		dispatch_symbol_lock();
		durden_input = durden_regionsel_input;

-- the region setup and accept/fail is really ugly, but reworking it
-- right now is not really an option
		DURDEN_REGIONFAIL_TRIGGER = function()
			activate_pending();
			DURDEN_REGIONFAIL_TRIGGER = nil;
		end
		DURDEN_REGIONSEL_TRIGGER = function()
			activate_pending();
			DURDEN_REGIONFAIL_TRIGGER = nil;
		end
	elseif (mode == "draw") then
		setup_cursor_pick(wm, wnd);
		DURDEN_REGIONFAIL_TRIGGER = function()
			activate_pending();
			DURDEN_REGIONFAIL_TRIGGER = nil;
		end
		suppl_region_select(200, 198, 36, function(x1, y1, x2, y2)
			activate_pending(x1, y1);
			local w = x2 - x1;
			local h = y2 - y1;
			if (w > 64 and h > 64) then
				wnd:resize(w, h);
			end
		end);
	end
end

-- hook displays so we can decide spawn mode between things like
-- spawn minimized, cursor-click to position, draw to spawn
display_add_listener(
function(event, name, tiler, id)
	if (event == "added" and tiler) then
		tiler.attach_hook = wnd_attach;
	end
end
);

global_menu_register("settings/wspaces/float",
{
	kind = "value",
	name = "spawn_action",
	initial = gconfig_get("advfloat_spawn"),
	label = "Spawn Method",
-- missing (split/share selected) or join selected
	set = {"click", "cursor", "draw", "auto"},
	handler = function(ctx, val)
		mode = val;
		gconfig_set("advfloat_spawn", val);
	end
});
