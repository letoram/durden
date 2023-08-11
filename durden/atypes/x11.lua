--
-- X11- bridge, for use with Xarcan.
--
-- This one is big as it supports quite a few ways of integrating.
--
-- One is the rootfull 'as a VM' where we either treat it as a normal window OR
-- give it a workspace to control. In the later case it is then also allowed to
-- adopt any window that migrates or is created in its workspace (referred to
-- as proxies). Xorg will then annotate with viewport events where the regions
-- for logical windows are and they are treated / created as window overlays.
--
-- Then it can be hybrid, where chosen windows are 'pulled out' into a logical
-- arcan one and redirected away from the Xorg side.
--
-- Both of these modes allows X11 to manage its own windows.
--
-- Lastly it can be rootless, where the main x11 window isn't visible at all,
-- and only acts as a mediator for its subwindows. Here we need to integrate
-- with Durden's own workspace modes and decorations with four complications:
--
--  1. Respecting 'embedded' viewport property is a bit different as what we
--     are embedding to is the entire x11 space. This represents
--     'overrideRedirect'.
--     'focused' is used to indicate if something has the global input grab.
--     'ext_id' conveys the XID identifier.
--     'parent' refers to the XID of a transient_for parent (if present).
--     'order' the resolved stacking order if something is not toplevel or
--     occluded.
--
--  2. the 'invisible' viewport property is used for windows that go into an
--     unmapped state. This is used to cut down on allocations. Although it
--     is possible to treat the redirected windows as regular ones that are
--     suceptible to delete_image, new segments might get allocated very
--     often. It is safer to reset_target them as a way of marking that the
--     window was closed and let Xarcan take it from there.
--
--  3. detailed feeback on stacking and position. For input to route correctly
--     and windows to be spawned 'right', feedback is needed about its current
--     state. This is done through the 'target_anchorhint' calls.
--
--  4. X has a different type/hint model. To support conveying the less
--     relevant such metadata, 'message' is used with
--     string.unpack_shmif_argstr to get a key-value table.
--
-- Follow -build_redirwnd- for how an active redirected window is treated,
-- and -build_pending- for the ready-to-be-reused state.
--
-- Then we need to integrate other features, clipboard is fairly easy as it
-- behaves as expected except for redirected windows. There is one clipboard
-- per root so any window paste etc. action should redirect into that VID.
--
-- We could do that by setting each Xorg as a clipboard monitor, ensuring that
-- they are all in synch but this won't trigger a paste in Xorg, it still needs
-- an input event that would have the focused client actually act upon it.
--
-- Worse still is that we'd then need to synthesis whatever 'apropriate' paste
-- input the client expects, but that might interfere with what the outer WM
-- things.
--
local log, fmt = suppl_add_logfn("x11");
local metawm = {};
local enable_xmeta;

local function resize_proxy(tbl)
	if not tbl.paired then
		return;
	end

-- easier than trying to tag all events going back and forth trying to translate
-- between configures and display hints, might want to schedule a timer though
	if tbl.last_hint and math.abs(CLOCK - tbl.last_hint) < 5 then
		return;
	end

	target_input(tbl.wnd.external, string.format(
		"kind=configure:id=%d:w=%.0f:h=%.0f", tbl.paired, tbl.last_w, tbl.last_h));
end

-- Create the simplified dispatch that ignores most arcan features in favour of
-- a dumber x11 window, anything from extev.lua that requires fancier features
-- from custom cursors, handover segments, binary chunk transfers, clipboard,
-- drag'n'drop are all ignored. It could be done by retaining the window in the
-- regular hierarchy and keeping it hidden forever but there are so many
-- possible edge conditions that this is the safer bet. It is a fairly niche
-- feature in this context. This code was written to be split out into a
-- separate support script eventually that could be added to the base
-- distribution.
local
function build_handler(wnd, tbl)
	return
	function(source, status)
		if status.kind == "resized" then
			tbl.last_w = status.width;
			tbl.last_h = status.height;
			tbl.origo_ll = status.origo_ll;
			resize_proxy(tbl);
		end
	end
end

local
function import_surface(wnd, vid)
	local props;
	local tbl = {last_w = 0, last_h = 0};

	if valid_vid(vid, TYPE_FRAMESERVER) then
		props = image_storage_properties(vid);
		tbl.last_w = props.width;
		tbl.last_h = props.height;
		target_updatehandler(vid, build_handler(wnd, tbl));
	elseif valid_vid(vid) then
		props = image_surface_properties(vid);
	else
		return;
	end

-- workaround, zero-state - just pick something as we have no contextual information
	if props.width * props.height <= 32 then
		local xsz = image_storage_properties(wnd.external);
		props.width = xsz.width * 0.5;
		props.height = xsz.height * 0.5;
	end

	tbl.vid = vid;
	wnd.xmeta.proxy[vid] = tbl;
	link_image(vid, wnd.anchor);
	target_input(wnd.external,
		string.format("kind=new:w=%0.f:h=%0.f:id=%d", props.width, props.height, vid));
end

-- used for .frame handler in degenerated composition
local function synch_overlay(wnd, ent, i, v)
	local dirty = false;
	log(fmt("viewport:target_frame=%d:frame=%d", v.frame, tbl.number));
	ent.viewport = v;
	local vid = ent.overlay.vid;
	blend_image(vid, v.invisible and 0 or 1);

-- track the window with focus for redirect and for proxying
	if v.focus and ent ~= wnd.xmeta.focus then
		wnd.xmeta.focus = ent;
	end

	if ent.proxy then
		image_sharestorage(ent.proxy.vid, ent.overlay.vid);
		image_set_txcos_default(ent.overlay.vid, ent.proxy.origo_ll);
		shader_setup(ent.overlay.vid, "simple", "stretchcrop");

-- to apply we clip the active region to the surface and skew the texture coordinates
	elseif v.frame <= tbl.number then
		local x2 = v.rel_x + v.anchor_w;
		local y2 = v.rel_y + v.anchor_h;
		if v.rel_x < 0 then
			v.anchor_w = v.anchor_w + v.rel_x;
			v.rel_x = 0;
		elseif x2 > props.width then
			v.anchor_w = v.anchor_w - (x2 - props.width);
		end

		if v.rel_y < 0 then
			v.anchor_h = v.anchor_h + v.rel_y;
			v.rel_y = 0;
		elseif y2 > props.height then
			v.anchor_h = v.anchor_h - (y2 - props.height);
		end

		local bx = v.rel_x * ss;
		local by = v.rel_y * st;
		local bx2 = bx + v.anchor_w * ss;
		local by2 = by + v.anchor_h * st;

		image_set_txcos(vid, {bx, by, bx2, by, bx2,  by2, bx,  by2});
		dirty = i;
	end

	move_image(vid, v.rel_x, v.rel_y);
	resize_image(vid, v.anchor_w, v.anchor_h);
	return dirty;
end

function metawm.frame(wnd, src, tbl)
-- Sweep wnd.xmeta queue and update the overlays for wnd, ignore / wait if the
-- event frameid match the current. We can get here without the structures in
-- place if the user resets durden (target_flags are retained) or toggles the
-- xmeta on/off while running.
	if not wnd.xmeta or #wnd.xmeta.queue == 0 then
		return;
	end

-- queue is filled with the set of changes to the degenerate rectangles that
-- are sampled out of the surface, so for them to be accurate the window src
-- rectangle need to be updated aligned with the new frame.
	local dirty = false
	local props = image_storage_properties(wnd.external);
	local ss = 1.0 / props.width;
	local st = 1.0 / props.height;

-- apply each pedning, mark the queue index of the last applied frame-matched
-- (as the queue can contain updates from different timeslices, ones that apply
-- to the current frame and those for future ones.
	for i,v in ipairs(wnd.xmeta.queue) do
		local ent = wnd.xmeta.nodes[v.ext_id];
		if ent and ent.overlay then
			local old = synch_overlay(wnd, ent, i, v);
			if old ~= false then
				dirty = old;
			end
		end
	end

	if dirty then
		if dirty == #wnd.xmeta.queue then
			wnd.xmeta.queue = {};
		else
			while dirty > 0 do
				table.remove(wnd.xmeta.queue, 1);
			end
		end
	end

-- The stacking order has changed, since this is rare 'enough' we should be
-- able to just walk the tree and re-order accordingly. This will repeatedly
-- call order_image that act as an insert-re-insert which can cascade.
	if wnd.xmeta.queue.restacked then
		if not wnd.xmeta.root then
			log("restack:broken_root");
		else
			log("restack");
			walk_tree(wnd, wnd.xmeta.root, 1, true);
		end
		wnd.xmeta.queue.restacked = false;
	end
end

-- pair tells about a new association between Xorg drawable ID and arcan
-- vid for the cases where we inject a proxy window and need to compose
-- ourselves.
function metawm.pair(wnd, args)
	local xid = tonumber(args.xid);
	local vid = tonumber(args.vid);
	if not xid or not vid then
		log("kind=error:source=pair:reason=missing or bad xid/vid");
		return;
	end
	if not wnd.xmeta then
		log("kind=error:source=pair:reason=window not in xmeta state");
		return;
	end

-- pair can arrive before the actual window creation
	if not wnd.xmeta.nodes[xid] then
		wnd.xmeta.nodes[xid] = {children = {}};
	end
-- other end might try to steal a vid
	local proxy = wnd.xmeta.proxy[vid];
	if not proxy then
		log(fmt("kind=error:source=pair:reason=unregistered:id=%d", vid));
		return;
	end
-- collisions not permitted
	if proxy.paired then
		log(fmt("kind=error:source=pair:reason=pair-collision:id=%d", vid));
		return;
	end

-- reverse-mapping tracking
	wnd.xmeta.nodes[xid].proxy = wnd.xmeta.proxy[vid];
	if wnd.xmeta.nodes[xid].overlay then
--		setup_overlay_mh(wnd.xmeta[xid]);
	end
	log(fmt("kind=status:source=pair:xid=%d:vid=%d", xid, vid));
	proxy.paired = xid;
	proxy.wnd = wnd;
end

function metawm.viewport(wnd, src, tbl)
-- 'dynamic redirect' only is indicated by invisible state on root window
	log("metawm_viewport");

	if wnd.ext_id == 0 then
		if wnd.invisible then
			log(fmt("kind=status:vid=%d:redirect_only", src));
			return;
		end
	end

	if not wnd.xmeta or not wnd.xmeta.nodes[tbl.ext_id] then
		log(fmt("kind=error:source=viewport:ext_id:%d:reason=ext_id not in table", tbl.ext_id));
		return;
	end

-- not visible? then track immediately
	if not wnd.xmeta.nodes[tbl.ext_id].overlay then
		wnd.xmeta.nodes[tbl.ext_id].viewport = tbl;
		return;
	end

-- tied to a proxy window and different ext_w, ext_h? then forward as hint,
-- the comparison also needs to take border into account
	local proxy = wnd.xmeta.nodes[tbl.ext_id].proxy;
	if proxy then
		local w = tbl.anchor_w + tbl.border[1] + tbl.border[1];
		local h = tbl.anchor_h + tbl.border[1] + tbl.border[1];
		if (w ~= proxy.last_w or h ~= proxy.last_h) and valid_vid(proxy.vid, TYPE_FRAMESERVER) then
			target_displayhint(proxy.vid, w, h);
			proxy.last_hint = CLOCK;
		end
	end

-- otherwise add to the queue and align to frame update
	table.insert(wnd.xmeta.queue, tbl);
  log(fmt("kind=status:source=viewport:queue_size=%d:frame=%d", #wnd.xmeta.queue, tbl.frame));
end

local function insert_before(dst, xid, id)
	local ind = 1;

	while dst.children[ind] do
		if dst.children[ind] == id then
			break;
		end
		ind = ind + 1;
	end

	table.insert(dst, ind, xid);
end

function metawm.create(wnd, args)
	local xid = tonumber(args.xid);
	local parent = tonumber(args.parent);
	local next = tonumber(args.next);

	if not xid or not parent or not next then
		log("kind=error:source=create:reason=create missing/bad xids");
		return;
	end

	if wnd.xmeta.nodes[xid] then
		log("kind=create_known");
		return;
	end

	local new = {
		children = {},
		parent = wnd.xmeta.nodes[parent],
		next = next,
		xid = xid
	};

	if not new.parent then
		wnd.xmeta.root = new;
	else
		insert_before(new.parent, xid, next);
	end
	wnd.xmeta.nodes[xid] = new;
end

function metawm.restack(wnd, args)
	local xid = tonumber(args.xid);
	local parent_id = tonumber(args.parent);
	local sibling_id = tonumber(args.next);
	local first = args.first;

	if not xid or not sibling_id or not wnd.xmeta.nodes[xid] or not parent_id then
		log("kind=error:source=restack:reason=missing or bad xid/vid");
		return;
	end

	log(fmt("kind=restack:xid=%d:parent=%d:sibling=%d:first=%s",
		xid, parent_id, sibling_id, first and "yes" or "no"));

-- orphan then determine if root or adopted
	local xwnd = wnd.xmeta.nodes[xid];
	local parent = wnd.xmeta.nodes[parent_id];
	xwnd.next = sibling_id > 0 and sibling_id or nil;

	if parent then
		table.remove_match(parent.children, xid);
		xwnd.parent = nil;
	end

-- mark as new root if we are that
	if parent_id == 0 then
		log(fmt("kind=restack:new_root=" .. tostring(xid)));
		wnd.xmeta.root = xwnd;
		xwnd.parent = nil;

-- otherwise track ID at correct local order
	elseif parent then
		xwnd.parent = parent;
		insert_before(parent, xid, sibling_id);
	end

-- mark as dirty so we can reorder
	wnd.xmeta.queue.restacked = true;
end

-- Mapped 'windows' in x11 are treated as 'overlays' here, drawn and processed
-- as part of the durden logical window. This is useful when Xarcan gets its
-- own workspace to treat 'as a VM'. We can still logically manipulate, compose
-- and otherwise use the different surfaces but they are presented as a whole.
function metawm.realize(wnd, args)
	local xid = tonumber(args.xid);
	if not xid then
		log("kind=error:source=realize:reason=create missing/bad xid");
		return;
	end

	if not wnd.xmeta.nodes[xid] then
		log("kind=error:source=realize:reason=realize on unknown xid");
		return;
	end

	if wnd.xmeta.nodes[xid].overlay then
		log("kind=realize_known:xid=%d", xid);
		return;
	end

-- there will be a viewport event close to next erame so keep hidden
	local new = null_surface(1, 1);
	wnd.xmeta.nodes[xid].overlay = wnd:add_overlay(xid, new, {block_mouse = true});
	image_sharestorage(wnd.external, new);
	hide_image(new);
 	wnd.xmeta.queue.restacked = true;
	log(fmt("kind=status:source=realize:vid=%d:overlay", new));
end

function metawm.unrealize(wnd, args)
	local xid = tonumber(args.xid);
	if not xid or not wnd.xmeta.nodes[xid] or not wnd.xmeta.nodes[xid].overlay then
		log("kind=error:source=unrealize:reason=not realized");
		return;
	end
	wnd:drop_overlay(xid);
	wnd.xmeta.nodes[xid].overlay = nil;
end

function metawm.destroy(wnd, args)
	local xid = tonumber(args.xid);
	if not xid or not wnd.xmeta.nodes[xid] then
		log("kind=error:source=destroy:reason=create missing/bad xid");
		return;
	end

-- removing it from the tracking table might still keep references around
-- due to viewport/restack events, so mark it as such
	local tgt = wnd.xmeta.nodes[xid];
	tgt.dead = true;
	tgt.overlay = nil;
	wnd:drop_overlay(xid);

-- orphan, siblings will restack
	if tgt.parent then
		table.remove_match(tgt.parent.children, xid);
	else
		wnd.xmeta.root = nil;
	end
end

-- these serialize the scenegraph changes prior to submitting a frame
function metawm.message(wnd, src, tbl)
	local args = string.unpack_shmif_argstr(tbl.message);

	if wnd.xmeta and metawm[args.kind] then
		metawm[args.kind](wnd, args);
		return;
	end
	log(fmt("kind=error:source=message:reason=missing_handler:id=%s", args.kind));
end

local function disable_xmeta(wnd)
	local source = wnd.external;
	if valid_vid(source, TYPE_FRAMESERVER) then
		target_flags(source, TARGET_VERBOSE, false);
		target_flags(source, TARGET_DRAINQUEUE, false);
		target_input(source, "kind=desynch");
	end
	wnd.xmeta.queue = nil;
	wnd.xmeta.root = nil;

	for k,_ in pairs(wnd.xmeta.nodes) do
		wnd:drop_overlay(k);
	end
	for k,v in pairs(wnd.xmeta.proxy) do
		if valid_vid(v.vid) then
			delete_image(v.vid);
		end
	end

	wnd.xmeta = nil;
	wnd.input_table = wnd.old_input_table;
	wnd.old_input_table = nil;
end

enable_xmeta =
function(wnd)
	local wnd = wnd or active_display().selected;
	local source = wnd.external;

	wnd.xmeta = {
		queue = {},
		redirect = {},
		proxy = {},
		nodes = {},
		root = {children = {}}
	};

-- these give better timing and input characteristics
	target_flags(source, TARGET_VERBOSE);
	target_flags(source, TARGET_DRAINQUEUE);
	target_input(source, "kind=synch");
	wnd.old_input_table = wnd.input_table;

-- Swap out the input handler for the X11 'root' window. For new inputs, check
-- if the focused window is associated with a proxy (arcan window injected as
-- an overlay). If it is, send the input to the arcan client instead of X11.
	wnd.input_table =
		function(wnd, tbl, ...)
			if wnd.xmeta.focus and wnd.xmeta.focus.proxy then
				if valid_vid(wnd.xmeta.focus.proxy.vid, TYPE_FRAMESERVER) then
					target_input(wnd.xmeta.focus.proxy.vid, tbl);
				end
			else
				return wnd.old_input_table(wnd, tbl, ...);
			end
		end
end

local function toggle_meta(wnd)
	if wnd.xmeta then
		disable_xmeta(wnd);
	else
		enable_xmeta(wnd);
	end
end

-- this handler
local
function on_space_event(wmwnd)
return function(space, key, action, wnd)
	if action ~= "attach" or not wmwnd.xmeta then
		return;
	end

	if wnd.external and wmwnd.xmeta.redirect[wnd.external] then
		return;
	end

	local surf;
	if valid_vid(wnd.external) then
		surf = wnd.external;
		wnd.external_prot = true;
	else
		surf = null_surface(1, 1);
		image_sharestorage(wnd.canvas, surf);
	end

-- now the window is dead but surf lives on, import it
	log("import_surface:vid=" .. tostring(surf));
	wnd:destroy();
	import_surface(wmwnd, surf);
end
end

-- a segment that was marked invisible wait for the new viewport and a frame
-- or resized being delived after it.
local build_redirwnd;

-- handler that will be used on a new segment for redirection, slightly
-- different from reusing an existing segment activated via a viewport event as
-- this is triggered by the first frame resized.
local
function build_pending_first(parent, vid, aid, cookie, xid)
	local last_viewport = {invisible = false};
	if not valid_vid(vid, TYPE_FRAMESERVER) then
		return;
	end
	target_flags(vid, TARGET_VERBOSE, true);
	hide_image(vid);

	if not parent.xmeta then
		delete_image(vid);
		return
	end

-- redirect table can track window backed surfaces and override-redirects,
-- the later needs their own mouse cursor handler
	local ictx = parent.xmeta.redirect[vid];
	if ictx then
		mouse_droplistener(ictx);
		parent.xmeta.redirect[vid] = nil;
	end

	target_updatehandler(vid,
		function(source, status)
			if status.kind == "terminated" then
				delete_image(vid);

			elseif status.kind == "viewport" then
				last_viewport = status;

			elseif status.kind == "frame" and not last_viewport.invisible then
				build_redirwnd(parent, vid, aid, cookie, xid, last_viewport);

			elseif status.kind == "resized" and not last_viewport.invisible then
				log(fmt("new_window:vid=%d:xid=%d", vid, xid));
				build_redirwnd(parent, vid, aid, cookie, xid, last_viewport);
			end
		end
	);
end

local
function build_override_redirect_surface(parent, vid, aid, cookie, xid, viewport)
	log("build_redirwnd:surface_override_redirect");

-- just to be safe, shouldn't happen (pending_first should clear)
	if parent.xmeta.redirect[vid] then
		mouse_droplistener(parent.xmeta.redirect[vid]);
	end

	local mx, my = mouse_xy();
	local tbl =
	{
		name = "override_redirect_x11_" .. tostring(vid),
		own = function(ctx, tgt)
			return tgt == vid;
		end,
		lx = mx,
		ly = my,
		motion =
		function(ctx, vid, x, y)
			target_input(parent.external, {
				kind = "analog", devid = 0, subid = 2, mouse = true,
				samples = {x, x - ctx.lx, y, y - ctx.ly},
			});
			ctx.lx = x;
			ctx.ly = y;
		end,
		button =
		function(ctx, vid, ind, pressed, x, y)
			target_input(parent.external, {
				kind = "digital", devid = 0, subid = ind, mouse = true,
				active = pressed});
		end
	};

-- the 'parent' here is an unattached window and thus does not have a workspace,
-- so we have to make do with the one that is currently active
	link_image(vid, active_display():active_space().anchor);
	image_mask_clear(vid, MASK_POSITION);

	mouse_addlistener(tbl);
	parent.xmeta.redirect[vid] = tbl;

	local handler =
	function(source, status)
		if status.kind == "viewport" then
			if status.invisible then
				build_pending_first(parent, source, aid, cookie, status.ext_id);
				return;
			end

			log(fmt("viewport_parent:%d", status.parent));
			local pwnd = parent.xmeta.redirect[status.parent];
			if status.parent > 0 and pwnd then
				link_image(source, parent.anchor);
				image_mask_clear(source, MASK_LIVING);
			end

			local props = image_storage_properties(source);
			resize_image(source, props.width, props.height);

			move_image(source, status.rel_x, status.rel_y);
			order_image(source, 65530);
			show_image(source);

		elseif status.kind == "resized" then
			resize_image(source, status.width, status.height);

		elseif status.kind == "terminated" then
			delete_image(vid);
		end
	end

	target_updatehandler(vid, handler);
	if viewport then
		handler(vid, viewport);
	end
end

build_redirwnd =
function(parent, vid, aid, cookie, xid, viewport)
	if not valid_vid(vid) then
		return nil;
	end

	viewport = viewport and viewport or {};

-- override-redirect / embedded, shouldn't have a window of its own, if a
-- parent is set overlay and link to that, if not,
	if viewport.embedded then
		return build_override_redirect_surface(parent, vid, aid, cookie, xid, viewport);
	end

-- block the registered event and force the type, otherwise the same handler
-- as we are in now would be applied and we really just want it to be like
-- any other window
	local new = durden_launch(vid, "");
	new.dispatch["registered"] =
	function()
		return nil;
	end

-- save and interpose the actual attach so that when the first-frame is
-- delivered we first evaluate how to treat it based on x-typed behaviour (e.g.
-- parent overlay/embed)
	local new_attach = new.ws_attach;
	new.ws_attach = function(...)
		return new_attach(...);
	end;

	extevh_apply_atype(new, "x11-redirect", vid);

-- as an optimisation we are interested in a surface going mapped / unmapped,
-- this could be part of the atypes/x11-redirect instead
	new.dispatch["viewport"] =
	function(wnd, source, status)
		wnd.last_viewport = status;

		if status.invisible then
			new:destroy();
		elseif status.embed then
		end

		return nil;
	end;

-- Sort-reset on destroy, this causes Xarcan to repeat-loop try and tell the
-- source to kill the window and eventually force-kill it. Another option would
-- be to track it as a set of mispaired surface and delete_image it on timer
-- or at least track it.
	new:add_handler("destroy",
	function(wnd)
		if valid_vid(wnd.external) then
			build_pending_first(parent, vid, aid, cookie, xid);
			reset_target(wnd.external, false);
		end
	end);

	local send_anchorhint =
	function(wnd, x, y)
	local space = image_surface_resolve(wnd.space.anchor);
		local rx = x + wnd.pad_left + wnd.ofs_x + space.x;
		local ry = y + wnd.pad_top + wnd.ofs_y + space.y;

-- Feature relies on arcan >= 6.3 Lua API, this will notify the source about
-- the current resolved anchor position so that other clients and tools know where
-- it is at.
		if target_anchorhint and valid_vid(vid) then
			target_anchorhint(vid, ANCHORHINT_SEGMENT, WORLDID, rx, ry);
		end
	end

-- make sure the vid doesn't get removed on termination, but also don't forward
-- the anchor until it has been dropped (if dragged) to cut down on event storms
	new.external_prot = true;
	new:add_handler("move",
		function(wnd, x, y)
			if wnd.in_drag_move then
				return;
			end
			send_anchorhint(wnd, x, y);
		end
	);

	new:add_handler("resize",
		function(wnd)
			send_anchorhint(wnd, wnd.x, wnd.y);
		end
	);

-- remember that this window now owns the vid, when VIEWPORT to invisible we
-- kill off the window but keep the vid to reduce allocation pressure
	parent.xmeta.redirect[vid] = new;

-- the cursor is actually tied to the parent, so work through that
	new.custom_cursor = parent.custom_cursor;

-- Same with the clipboard, reroute. This will only update the selection buffer
-- on the other end, not actually paste anything. This does not indicate the
-- intended target, e.g. primary or selection so Xarcan will just do both.
	new.paste =
		function(wnd, ...)
			clipboard_paste_default(parent, ...);
		end

	if new.ws_attach then
		new:ws_attach();
		local props = image_storage_properties(vid);
		new:resize(props.width, props.height);
	end

	return nil;
end

local
function autows_rootwnd(wnd, source)
	local auto = gconfig_get("xarcan_autows");
	wnd.synch_overlays = function() end;

-- find an empty workspace, switch to that mode and displayhint based on that window
	if auto ~= "none" then
		local disp = active_display()
		for i=1,10 do
			if disp.spaces[i] == nil then
				wnd.default_workspace = i
				break
			end
		end
	end

-- actually create / attach before we have contents which isn't the default
-- otherwise but now the space would have been created and can be forced to the
-- auto mode with some special sauce for the floating layout.
	if wnd.ws_attach then
		wnd:ws_attach();
		wnd.last_float = {width = 1.0, height = 1.0, x = 0, y = 0};
	end

-- automatically disable the border / shadow / titlebar so it effectively becomes
-- fullscreen with statusbar for float-mode. workaround for window not being
-- 'selected' in the workspace until after it has submitted a frame causing
-- fullscreen to early out.
	if gconfig_get("xarcan_autows_nodecor") then
		wnd.want_shadow = false;
		wnd:set_titlebar(false);
		wnd:set_border(false, true, 0);
	end

-- and set the desired automode, like fullscreen
	if wnd.space and wnd.space[auto] then
		wnd.space.selected = wnd;
		wnd.wm:switch_ws(wnd.space);
		wnd.space[auto](wnd.space);

		if not wnd.space.listeners["x11"] then
			wnd.space.listeners["x11"] = on_space_event(wnd);
		end

-- automatically tag the workspace name with the instance identity so that we see
-- what the corresponding DISPLAY=: should be.
		if gconfig_get("xarcan_autows_tagname") then
			local label = ""
			wnd.set_ident =
			function(wnd, msg)
				wnd.ident = ident
				label = "X11:" .. (msg or "")
				wnd.space:set_label(label)
			end

-- untag the label on destruction so workspace autopruning won't try to save it
		table.insert(
			wnd.handlers.destroy,
			function()
				wnd.space:set_label("")
			end
		)
		end
	end
end

function metawm.preroll(wnd, source, tbl)
-- (his synchs the clipboard so that any new items are automatically 'pasted' into
-- the x11 window, giving the x11 clipboard access to it.
	if gconfig_get("xarcan_clipboard_autopaste") then
		dispatch_symbol_wnd(wnd, "/target/clipboard/autopaste_on");
	end

-- forward the current display constraints as we don't have a 'normal' window now
-- that would send this on relayout / migration
	target_displayhint(source, wnd.max_w, wnd.max_h, 0, display_output_table(nil));

-- allow-gpu is from older dri stacks where there is a challenge response scheme
-- for authenticating accellerated GPU access, some might still make use of it
-- though.
	if (TARGET_ALLOWGPU ~= nil and gconfig_get("gpu_auth") == "full") then
		target_flags(source, TARGET_ALLOWGPU);
	end
end

function metawm.resized(wnd, src, tbl)
-- first frame submitted means that Xarcan is not 'redirect-only' and has a
-- composited root to work through.
	if not wnd.space then
		log("enable_composited_root");
		autows_rootwnd(wnd, src);
	end
end

function metawm.segment_request(wnd, source, status)
-- there are two reasons for bridge-x11 to be requested.
--
-- 1. it is running in -redirect mode where a pool of segments are used to
--    represent windows, and viewport hints to position and toggle on / off.
--
-- 2. A window has explicitly been redirected at our behest.
--
-- both mostly behave the same in that they can be treated as a window with
-- slightly different lifecycle - avoid delete_image on it, provide feedback
-- on its position (target_anchorhint) and 'fake-delete' on unrealize.
--
	if status.segkind == "bridge-x11" then
		log("kind=redirect:xid=" .. tonumber(status.reqid));

		if not wnd.xmeta then
			enable_xmeta(wnd);
		end

		local vid, aid, cookie =
			accept_target(source, status.width, status.height);

		build_pending_first(wnd, vid, aid, cookie, status.reqid);
	end

-- this will chain back to the regular segment_request handler with default
-- subtype handler for clipboard and cursor.
	return false;
end

local function redirect()
	local res = {};

	local wnd = active_display().selected;
	if not wnd.xmeta or not wnd.xmeta.root then
		return res;
	end

-- first just populate all toplevel candidates, then if we have more metadata
-- e.g. window title then sort based on that
	local unsorted = {};
	for k,v in pairs(wnd.xmeta.nodes) do
		if v.parent and v.parent == wnd.xmeta.root and v.overlay then
			table.insert(unsorted, v);
		end
	end

	local focus = wnd.xmeta.focus;
	if focus then
		table.insert(res,
			{
				name = "focus",
				label = "Focus",
				description = tostring(focus.xid),
				kind = "action",
				handler =
				function()
					target_input(wnd.external, "kind=redirect:id=" .. tostring(focus.xid));
				end
			}
		);
	end

-- The actual entry just sends a redirect rather than a new segment immediately
-- (e.g. target_alloc). The reason for this is to be able to have the exact same
-- allocation path for a 'redirected default' as for this 'dynamic rootless'.
	for _,v in ipairs(unsorted) do
		local strv = tostring(v.xid);
		table.insert(res,
			{
				name = "tl_" .. strv,
				label = strv,
				kind = "action",
				description = strv,
				handler =
				function()
					target_input(wnd.external, "kind=redirect:id=" .. strv);
				end
			}
		);
	end

	return res;
end

-- test the proxy code with a terminal emulator
local function create_proxy()
	local wnd = active_display().selected;
	import_surface(wnd, launch_avfeed("", "terminal", function() end));
end

local x11_menu =
{
	{
		name = "toggle_meta",
		label = "Meta WM",
		description = "Toggle workspace mapping on/off",
		kind = "action",
		handler = toggle_meta,
	},
	{
		name = "create_proxy",
		kind = "action",
		label = "DebugProxy",
		description = "Create a Proxy window with a afsrv_terminal",
		eval = function() return DEBUGLEVEL > 0; end,
		handler = create_proxy,
	},
	{
		name = "redirect",
		kind = "action",
		label = "Redirect",
		eval = function()
			return #redirect() > 0;
		end,
		submenu = true,
		description = "Redirect a toplevel window",
		handler = redirect
	},
	{
		name = "xresource",
		kind = "value",
		label = "Resource",
		description = "Set .Xresource property string",
		validator = shared_valid_str,
		handler = function(ctx, val)
			local kv = string.split(val, "=");
			target_input(active_display().selected.external, "kind=xresource:val=" .. val);
		end
	}
};

local bridge_menu =
{
	{
	kind = "action",
	name = "x11",
	label = "X11",
	submenu = true,
	handler = x11_menu,
	description = "Control how X11 clients are managed"
	}
};

return {
	atype = "bridge-x11",
	default_shader = {"simple", "noalpha"},
	allowed_segments = {},
	actions = bridge_menu,
-- props will be projected upon the window during setup (unless there are overridden defaults)
	props =
	{
		kbd_period = 0,
		kbd_delay = 0,
		centered = true,
		scalemode = "normal",
		filtermode = FILTER_NONE,
		rate_unlimited = true,
		clipboard_block = false,
		font_block = true,
	},
	dispatch = metawm
}
