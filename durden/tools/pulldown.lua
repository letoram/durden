--
-- a pulldown terminal that lives outside the normal window manager
-- downside is that input handling and other features behave differently
--
--
-- MISSING:
-- display migration (with fonts)
-- mouse injection
-- cut/paste
-- terminal font config synch
-- config- menu injection
-- default keybinding setting(?)
--

gconfig_register("dt_pos", "top");
gconfig_register("dt_ofs", true);
gconfig_register("dt_width", 1.0);
gconfig_register("dt_height", 0.4);
gconfig_register("dt_opa", 0.8);

local dstate = {
	dir_x = 0,
	dir_y = 1,
	pos = "top",
	ofs = 0,
	width = 0.5,
	height = 0.3
};

local atype = extevh_archetype("terminal");

local function drop()
	reset_image_transform(dstate.term); -- use RV to adjust animation time?
	local props = image_surface_properties(dstate.term);
	nudge_image(dstate.term,
		-1 * dstate.dir_x * props.width, -1 * dstate.dir_y * props.height,
		gconfig_get("animation")
	);
	dstate.active = false;
	dispatch_toggle(false);
	mouse_lockto(unpack(dstate.lock));

	target_displayhint(dstate.term, 0, 0,
		bit.bor(TD_HINT_UNFOCUSED, TD_HINT_INVISIBLE));
end

-- we intercept symbol- handling so our trigger path can be re-used
-- but forward the rest to the new window
local function ldisp(sym, iotbl, path)
	if (not sym and not iotbl) then
		drop();
		return;
	end

-- label translation
	if (iotbl.label and atype.labels[iotbl.label]) then
		iotbl.label = atype.labels[iotbl.label];
	end

-- don't consume mouse here as we want to translate to the specific surface
	if (iotbl.mouse) then
		return false, sym, iotbl, path;
	end

	target_input(dstate.term, iotbl);

-- run through the terminal archetype label binding
	return true, sym, iotbl, path;
end

-- different rules apply to input and event response compared to normal windows
local function termh(source, status)
	if (status.kind == "resized") then
		resize_image(source, status.width, status.height);
	elseif (status.kind == "terminated") then
		if (dstate.active) then
			drop();
		end
		delete_image(source);
		dstate.term = nil;
	end
end

local function dterm()
-- if we're already toggled, then disable
	if (dstate.active) then
		drop();
		return;
	end

-- if we got a terminal running, prefer that
-- or spawn a new one.. create anchor, attach, order, ...
	local disp = active_display();
	local neww = disp.width * dstate.width;
	local newh = disp.height * dstate.height;

	if (not valid_vid(dstate.term)) then
		dstate.term = spawn_terminal("", true);
		dstate.disp = disp;
		show_image(dstate.term);
		target_updatehandler(dstate.term, termh);
		target_graphmode(dstate.term, gconfig_get("dt_opa"));
	end

-- center on non-dominant axis
	move_image(dstate.term, -1 * neww * dstate.dir_x, -1 * newh * dstate.dir_y);
	if (dstate.dir_x ~= 0) then
		nudge_image(dstate.term, 0.0, 0.5 * (disp.height - newh));
	elseif (dstate.dir_y ~= 0) then
		nudge_image(dstate.term, 0.5 * (disp.width - neww), 0.0);
	end

-- reattach to different output
	if (dstate.disp ~= active_display()) then
		dstate.disp = active_display();
-- send font hint
	end

	local neww = dstate.disp.width * dstate.width;
	local newh = dstate.disp.height * dstate.height;

-- put us in the "special" overlay order range
	order_image(dstate.term, 65532);

-- activate / keyboard input
-- save coords, lock mouse to vid
	target_displayhint(dstate.term,
		dstate.disp.width * dstate.width,
		dstate.disp.height * dstate.height
	);

-- animate
	show_image(dstate.term);
	nudge_image(dstate.term, 1 * dstate.dir_x * neww,
		1 * dstate.dir_y * newh, gconfig_get("animation"));

	dstate.active = true;
	dispatch_toggle(ldisp);

	local v, f, w, s = mouse_lockto(dstate.term,
		function(rx, ry, x, y, state, ind, active)
			local props = image_surface_properties(dstate.term);
			x = x - props.x;
			y = y - props.y;
		end, nil
	);
	dstate.lock = {v, f, w, s};
	target_displayhint(dstate.term, 0, 0, 0);
end

global_menu_register("system",
{
	name = "dterm",
	label = "Drop-down Terminal",
	kind = "action",
	invisible = true, -- (register keybinding instead?)
	handler = dterm
});
