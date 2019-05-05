--
-- This tool manages external connection points that route to specific
-- UI elements, such as the statusbar icon groups.
--
local cp_handler, gen_cp_menu, open_cp;
local cps = {};
local clients = {};
local last_click = nil;
local log = suppl_add_logfn("tools");

-- external connection point that accepts a primary ICON segment,
-- treates anything spawned from that as a 'popup' and only in
-- response to input on the segment itself, (media | application | tui)
-- all receiving basic fonts, fixed height, restricted width.
menus_register("global", "settings/statusbar/buttons",
{
	name = "external",
	label = "External",
	submenu = true,
	kind = "action",
	eval = function()
		for k,v in pairs(cps) do
			return true;
		end
	end,
	handler = function() return gen_cp_menu(); end
}
);

menus_register("global", "settings/statusbar/buttons/left",
{
	name = "add_external",
	label = "Add External",
	kind = "value",
	description = "Open an external connection-point for docking icons into the tray",
	hint = "(a-Z_0-9)",
	validator = strict_fname_valid,
	handler = function(ctx, val)
		open_cp(val, "left");
	end
});

menus_register("global", "settings/statusbar/buttons/right",
{
	name = "add_external",
	label = "Add External",
	kind = "value",
	description = "Open an external connection-point for docking icons into the tray",
	hint = "(a-Z_0-9)",
	validator = strict_fname_valid,
	handler = function(ctx, val)
		open_cp(val, "right");
	end
});

local function gen_submenu_for_cp(v)
	return {
	{
		name = "close",
		label = "Close",
		kind = "action",
		description = "Close the connection point but keep existing clients around",
		handler = function()
			table.remove_match(cps, v);
			if (valid_vid(v.vid)) then
				delete_image(v.vid);
			end
		end,
	},
	{
		name = "kill",
		label = "Kill",
		kind = "action",
		description = "Close the connection point and all existing clients",
		handler = function()
			table.remove_match(cps, v);
			delete_image(v.vid);
			for _,v in pairs(clients) do
				if (v.parent == v) then
					v:destroy();
				end
			end
		end,
	}
-- other options here: limit connections, specify destination display,
-- allow specific behavior, allow handover to client spawn
	};
end

gen_cp_menu = function()
	local res = {};
	for k,v in pairs(cps) do
		table.insert(res, {
			name = k,
			label = k,
			kind = "action",
			submenu = true,
			description = "Control connection point behaviour",
			handler = gen_submenu_for_cp(v)
		});
	end
	return res;
end

local function setup_default(name, new_vid, dir)
	cps[name] = {
		vid = new_vid,
		group = dir
	};
end

local function send_fonts(dst)
-- send the default UI font config
	local main = gconfig_get("font_def");
	local fallback = gconfig_get("font_fb");
	local sz = gconfig_get("font_sz");
	local hint = gconfig_get("font_hint");
	target_fonthint(dst, main, sz * FONT_PT_SZ, hint, false);
	target_fonthint(dst, fallback, sz * FONT_PT_SZ, hint, true);
end

open_cp = function(name, dir)
-- did we allocate successfully?
	local new_vid = target_alloc(name,
		function(source, status)
			return cp_handler(cps[name], source, status)
		end
	);

	if (not valid_vid(new_vid)) then
-- otherwise, schedule a fire-once timer to try again until a certain time
		log("name=traybtn:kind=error:message=could not listen on " .. name);
		return
	end

	image_tracetag(new_vid, "adopt_destroy");
	log("name=traybtn:kind=listening:source="
		.. tostring(new_vid) .. ":cp=" .. name);
	setup_default(name, new_vid, dir);
end

local handlers = {
};

handlers["registered"] =
function(ctx, bar, source, status)
	if (status.segkind ~= "icon") then
		log("name=traybtn:kind=error:source=" .. tostring(source) .. ":message="
			.."registered with bad segkind:id=" .. status.segkind);
		ctx:destroy();
		return;
	end

	log("name=traybtn:kind=status:source="
		.. tostring(source) .. ":message=registered");
end

handlers["connected"] =
function(ctx, bar, source, status)
	ctx.key = status.key;

-- and re-open (do from this context so the backend knows that it can just
-- re-use the same socket immediately, there's tracking for this internally)
	log("name=traybtn:kind=connected:key="
		.. status.key .. ":source=" .. tostring(source));
	open_cp(status.key, ctx.group);
end

handlers["preroll"] =
function(ctx, bar, source, status)
-- pick the thickness and go square, no matter the direction, but also
-- set a display that match a smaller version of the bar.

	local dtbl = {};
	for k,v in pairs(bar.owner.disptbl) do
		dtbl[k] = v;
	end

-- vertical bar?
	if (bar.height > bar.width) then
		dtbl.height = dtbl.height * 0.5;
		target_displayhint(source, bar.width, bar.width, 0, dtbl);

-- nope, horizontal or square(?!) - later case just bias a direction
	else
		dtbl.width = dtbl.width * 0.5;
		target_displayhint(source, bar.height, bar.height, 0, dtbl);
	end

-- and some 'icons' is actually text, like a date / user / ...
	send_fonts(source);
end

handlers["terminated"] =
function(ctx, bar, source, status)
	ctx:destroy();
	log("name=traybtn:kind=status:message=terminated:id=" .. tostring(source));
end

local function button_mh(ctx, source)
-- want to track this so we don't give the grab to someone else
	last_click = ctx;
	return {
		name = "tray_mouseh",

-- send both press and release
		click = function()
			log("name=traybtn:kind=clicked:source="..tostring(source));
			target_input(source, {
				kind = "digital",
				mouse = true,
				gesture = true,
				active = true,
				label = "click"
			});

			target_input(source, {
				kind = "digital",
				mouse = true,
				active = false
			});
		end,
	};
end

handlers["labelhint"] =
function(ctx, bar, source, status)
	log("name=traybtn:kind=labelhint:label=" .. status.label);
-- append to the context itself, let the menu expose ways of triggering it
-- if we allow 'global mapping', register that one
end

handlers["resized"] =
function(ctx, bar, source, status)
-- resize after initial size set, should be permitted or ignored?
-- allow for now and force a relayout
	if (ctx.button) then
		log(string.format("name=traybtn:kind=resized:source=%d:"
			.. "width=%d:height=%d", source, status.width, status.height));
		resize_image(source, status.width, status.height);
		ctx.button:update(source);
		bar:relayout();
		return;
	end

-- Treat it like the message area (no border or any of that jazz),
-- we allow the button on any group.
	local base = bar.height > bar.width and bar.width or bar.height;
	resize_image(source, base, base);
	ctx.button = bar:add_button(ctx.group, "sbar_msg_bg", "sbar_msg_text",
		source, 0,
-- set the scale- function resolver to nothing as we are all external
		function()
			return 1;
		end,
-- and the suggested icon size is on the button base
		base, base,
-- lastly forward mouse handler with the proper context
		button_mh(ctx, source), {}
	);
	ctx.button.owner = ctx;
	log(string.format("name=traybtn:kind=resized-first:source=%d:base=%d"
		.. ":width=%d:height=%d", source, base, status.width, status.height));
	ctx.button:update(source);
	bar:relayout();
end

local function setup_grab(ctx, bar, source, status)
-- the anchor here is simply a hidden surface we play at the relative order
-- of the wm components, and it will absorb mouse motion until we release it
	local anchor = null_surface(bar.owner.width, bar.owner.height);
	show_image(anchor);
	if not (valid_vid(anchor)) then
		delete_image(source);
		return;
	end
	image_tracetag(anchor, "traybtn_mouse_anchor");
	link_image(anchor, source);
	image_inherit_order(anchor, true);
	order_image(anchor, -1);
	image_mask_clear(anchor, MASK_POSITION);

-- save input handler until we release the grab
	local old_ioh = _G[APPLID .. "_input"];

-- path the input function so we get the keyboard events and just forward
-- the old so we keep device discovery and translation.
	_G[APPLID .. "_input"] = function(iotbl)
		if (not iotbl.translated) then
			return old_ioh(iotbl);
		end

-- and for the translated, we use the SYMTABLE global (if present)
		local sym, outsym;
		if (SYMTABLE) then
			sym, outsym = SYMTABLE:patch(iotbl);
		end

-- special meaning for ESCAPE: delete and drop, otherwise: forward!
		if (not valid_vid(
			source, TYPE_FRAMESERVER) or (sym and sym == "ESCAPE")) then
			ctx:destroy();
-- or just send to the client
		else
			target_input(source, iotbl);
		end
	end

-- need to block normal input event handling as there are so many
-- interactions that are likely to break things (timers, external
-- IPC, ...)
	dispatch_symbol_lock();

-- mouse handler for the grab- surface and for the popup itself,
-- forward motion and buttons to the source, destroy on grab-click
	local mouseh = {
		own = function(mctx, vid)
			return vid == anchor or vid == source;
		end,
		motion = function(ctx, vid, x, y, rx, ry)
			if vid ~= source then
				return
			end
			local aprops = image_surface_resolve(source);
			local lx = x - aprops.x;
			local ly = y - aprops.y;
			target_input(source, {
				kind = "analog", mouse = true, devid = 0, subid = 0,
				samples = {lx, rx}
			});
			target_input(source, {
				kind = "analog", mouse = true, devid = 0, subid = 1,
				samples = {ly, ry}
			});
		end,
		button = function(ctx, vid, ind, pressed, x, y)
			if vid == source then
			target_input(source, { active = pressed,
				devid = 0, subid = ind, kind = "digital", mouse = true});
			end
		end,
		click = function(mctx, vid)
			if vid == anchor then
				ctx:destroy();
			end
		end,
		name = "extbtn_grab_anchor"
	};
	mouse_addlistener(mouseh, {"click", "motion", "button"});

-- add our handler
	ctx.destroy = function()
		_G[APPLID .. "_input"] = old_ioh;
		dispatch_symbol_unlock(true);
		ctx.destroy = nil;

		local time = gconfig_get("animation");
		if (valid_vid(source)) then
			expire_image(source, time);
			blend_image(source, 0.0, time);
		end
		mouse_droplistener(mouseh);
	end

-- use the source properties and the ctx.button vid to figure out
-- position of the popup itself
end

local function reposition(source, bar, btn)
	local ap = gconfig_get("sbar_pos");
	local sprop = image_surface_resolve(source);
	local bprop = image_surface_properties(btn.bg);

-- align to the lower left unless overflow, then end at lower right
	if (ap == "top") then
		move_image(source, 0, bprop.height);
	else
		move_image(source, 0, -sprop.height);
	end

	log(string.format("%f, %f", sprop.x + sprop.width, bar.owner.width));
	if (sprop.x + sprop.width > bar.owner.width) then
		nudge_image(source, -sprop.width + bprop.width, 0);
	end
end

local function popup_handler(ctx, bar, source, status)
	log("name=traybtn:kind=popup_handler:event="
		.. status.kind .. ":source=" .. tostring(source));

	if (status.kind == "resized") then
		if (last_click ~= ctx.parent_ctx) then
-- If the client was slow to wake up and something else was clicked in
-- between, we can / should just kill it off.
			log("name=traybtn:kind=error:source="
				.. tostring(source) .. ":message=don't own popup slot");

			if (ctx.destroy) then
				ctx:destroy();
			else
				delete_image(source);
			end
			return;
		end

-- link to the button anchor itself for positioning
		show_image(source);
		rendertarget_attach(bar.owner.rtgt_id, source, RENDERTARGET_DETACH);
		link_image(source, ctx.parent_ctx.button.bg);

		image_inherit_order(source, true);
		order_image(source, 1);
		resize_image(source, status.width, status.height);

-- set source as anchor attribute so shadow gets attached right
		ctx.anchor = source;
		suppl_region_shadow(ctx, status.width, status.height);

-- then resolve display- space coordinates and adjust versus screen edge
-- this has quite a few edge cases due to possible 'overflow' and to cover
-- both bar orientations
		reposition(source, bar, ctx.parent_ctx.button);
		if (not ctx.destroy) then
			setup_grab(ctx, bar, source, status);
		end

	elseif (status.kind == "preroll") then
-- send the current display density
		target_displayhint(source, 0, 0, 0, bar.owner.disptbl);
		send_fonts(source);

	elseif (status.kind == "terminated") then
		if (last_click == ctx) then
			last_click = nil;
		end

		if (ctx.destroy) then
			ctx:destroy();
		else
			delete_image(source);
		end
	end
end

handlers["segment_request"] =
function(ctx, bar, source, status)
	log("name=traybtn:kind=segreq:segkind=" .. status.segkind);
	local base = bar.height > bar.width and bar.width or bar.height;

-- Hint the dimensions based on the display the bar is attached to, grab
-- at most, a third of each axis. The uiprim_bar does not actually track
-- this, but tiler.lua tags the bar.
	local owner = bar.owner;
	local outw = VRESW * 0.3;
	local outh = VRESH * 0.3;

	if (owner) then
		outw = owner.width * 0.3;
		outh = owner.height * 0.3;
	else
	end

	local popup_ctx = {
		parent = source,
		parent_ctx = ctx,
		outw = outw,
		outh = outh
	};

	local vid = accept_target(source, outw, outh,
		function(source, status)
			return popup_handler(popup_ctx, bar, source, status);
		end
	);

-- tag the image in a way that it will be destroyed when trying to recover
-- from a crash, as the parent / producer (the icon) should be able to spawn
-- a new one instead.
	if (valid_vid(vid)) then
		image_tracetag(vid, "adopt_destroy");
	end
end

local function free_tray_button(ctx)
	if (ctx.button) then
		ctx.button:destroy();
	end
	if (valid_vid(ctx.vid)) then
		delete_image(ctx.vid);
	end
	clients[ctx.vid] = nil;
end

cp_handler = function(ctx, source, status)
	local bar = ctx.statusbar and ctx.statusbar or active_display().statusbar;
	if (not bar) then
		delete_image(source);
		clients[source] = nil;
		return;
	end

	if (not clients[source]) then
		clients[source] = {
			vid = source,
			group = ctx.group,
			destroy = free_tray_button
		};
		image_tracetag(source, "adopt_destroy");
	end

	if (handlers[status.kind]) then
		return handlers[status.kind](clients[source], bar, source, status);
	else
		log("name=traybtn:kind=unhandled:message=" ..
			status.kind .. ":source=" .. tostring(source));
	end
end
