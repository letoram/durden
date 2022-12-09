--
-- X11- bridge, for use with Xarcan.
--
local log, fmt = suppl_add_logfn("x11");
local metawm = {};

--
-- walk the tree in reverse order, reset z- value when unobscured toplevel
--
local
function walk_tree(wnd, node, order, top)
	if node.order == 0 and top then
		order = 1
	end

	if node.overlay then
		order_image(node.overlay.vid, order);
	end

	for i=#node.children,1 do
		order = order + 1;
		local xid = node.children[i];
		local child = wnd.xmeta.nodes[xid];

		if not child then
			log("kind=error:source=reorder:message=inconsistent:id=" .. tostring(xid));
		else
			if node.overlay then
				log(fmt("kind=order:xid=%d:order=%d", xid, order));
				order_image(node.overlay.vid, order);
			end
			order = walk_tree(wnd, child, order, false);
		end
	end

	return order;
end

local counter = 0;
local function dump(wnd, name)
	zap_resource(name);
	local io = open_nonblock(name, true);
	io:write("digraph g {")
	for k,v in pairs(wnd.xmeta.nodes) do
			io:write(string.format(
				"%.0f[label=\"%.0f\" shape=\"%s\"];\n",
				k, k, v.overlay and (v.proxy and "triangle" or "square") or "circle"
			));
	end

	for k,v in pairs(wnd.xmeta.nodes) do
		for i,v in ipairs(v.children) do
			io:write(string.format("%.0f->%.0f;\n", k, v));
			if wnd.xmeta.nodes[v].next then
				io:write(string.format("%.0f->%.0f;\n", v, wnd.xmeta.nodes[v].next));
			end
		end
	end
	io:write("}");
	io:close();
end

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
-- separate
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

function metawm.frame(wnd, src, tbl)
-- Sweep wnd.xmeta queue and update the overlays for wnd, ignore / wait if the
-- event frameid match the current. We can get here without the structures in
-- place if the user resets durden (target_flags are retained).
	if not wnd.xmeta or #wnd.xmeta.queue == 0 then
		return;
	end

	local dirty = false
	local props = image_storage_properties(wnd.external);
	local ss = 1.0 / props.width;
	local st = 1.0 / props.height;

	for i,v in ipairs(wnd.xmeta.queue) do
		local ent = wnd.xmeta.nodes[v.ext_id];

-- we can update the overlay positioning immediately since we composite, but
-- the changed sampling coordinates should be aligned to the frame update
		if ent and ent.overlay then
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
				dirty = i
			end

			move_image(vid, v.rel_x, v.rel_y);
			resize_image(vid, v.anchor_w, v.anchor_h);
		end
	end

	if dirty then
		if dirty == #wnd.xmeta.queue then
			wnd.xmeta.queue = {};
		else
			for i=1,dirty do
				table.remove(wnd.xmeta.queue, 1);
			end
		end
	end

-- The stacking order has changed, since this is rare 'enough' we should be
-- able to just walk the tree and re-order accordingly.
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
-- vid for the cases where we inject a proxy window
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

-- set ut the reverse mapping
	wnd.xmeta.nodes[xid].proxy = wnd.xmeta.proxy[vid];
	if wnd.xmeta.nodes[xid].overlay then
--		setup_overlay_mh(wnd.xmeta[xid]);
	end
	proxy.paired = xid;
	proxy.wnd = wnd;
end

function metawm.viewport(wnd, src, tbl)
	if not wnd.xmeta or not wnd.xmeta.nodes[tbl.ext_id] then
		log("kind=error:source=viewport:reason=ext_id missing or unexpected");
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
		next = next
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

-- map new surfaces as overlays as that feature already takes care of
-- anchoring, stacking, clipping and input routing so all we need to do is use viewport
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

-- there will be a viewport event close to next frame so keep hidden
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

local function toggle_meta(wnd)
	local wnd = wnd or active_display().selected;
	local source = wnd.external;

	if wnd.xmeta then
		target_flags(source, TARGET_VERBOSE, false);
		target_flags(source, TARGET_DRAINQUEUE, false);
		target_input(source, "kind=desynch");
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
	else
		wnd.xmeta = {queue = {}, proxy = {}, nodes = {}, root = {children = {}}};
		target_flags(source, TARGET_VERBOSE);
		target_flags(source, TARGET_DRAINQUEUE);
		target_input(source, "kind=synch");
		wnd.old_input_table = wnd.input_table;
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
end

local
function on_space_event(space, key, action, wnd)
	if action ~= "attach" then
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

	wnd:destroy();

end

function metawm.preroll(wnd, source, tbl)
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

-- actually create / attach before we have contents which isn't the default
-- otherwise but now the space would have been created and can be forced to the
-- auto mode with some special sauce for the floating layout.
		if wnd.ws_attach then
			wnd:ws_attach();
			wnd.last_float = {width = 1.0, height = 1.0, x = 0, y = 0};
		end

		if gconfig_get("xarcan_autows_nodecor") then
			wnd.want_shadow = false;
			wnd:set_titlebar(false);
			wnd:set_border(false, true, 0);
		end

-- automatically disable the border / shadow / titlebar so it effectively becomes
-- fullscreen with statusbar for float-mode. workaround for window not being
-- 'selected' in the workspace until after it has submitted a frame causing
-- fullscreen to early out.
		if wnd.space and wnd.space[auto] then
			wnd.space.selected = wnd;
			wnd.space[auto](wnd.space);

			if not wnd.space.listeners["x11"] then
				wnd.space.listeners["x11"] = on_space_event;
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
					wnd.space:set_label()
				end
			)
			end
		end

		if gconfig_get("xarcan_clipboard_autopaste") then
			dispatch_symbol_wnd(wnd, "/target/clipboard/autopaste_on");
		end
	end

	target_displayhint(source, wnd.max_w, wnd.max_h, 0, display_output_table(nil));
	if (TARGET_ALLOWGPU ~= nil and gconfig_get("gpu_auth") == "full") then
		target_flags(source, TARGET_ALLOWGPU);
	end
end

function metawm.resized(wnd)
-- metawm synch can't be enabled until after the preroll stage is over
-- as the 'message' event is ignored in preroll
	if not wnd.first_resize then
		if gconfig_get("xarcan_metawm") then
			toggle_meta(wnd);
		end
		wnd.first_resize = true;
	end
	return false;
end

local function colorize(wnd)
-- sweep through the set of windows and set a colored backing store based
-- on type (toplevel or not) and opacity on depth.
	local wnd = active_display().selected;
	local top = fill_surface(1, 1, 0, 255, 0);
	local other = fill_surface(1, 1, 255, 255, 0);

	for k,v in pairs(wnd.xmeta.nodes) do
		if v.txcos and v.overlay then
			image_sharestorage(wnd.external, v.overlay.vid);
			image_set_txcos(v.overlay.vid, v.txcos);
			v.txcos = nil;
		elseif v.overlay then
			v.txcos = image_get_txcos(v.overlay.vid);
			image_sharestorage(
				(v.viewport and v.viewport.embedded and other) or top, v.overlay.vid);
		end
	end

	delete_image(top);
	delete_image(other);
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

	for _,v in ipairs(unsorted) do
		table.insert(res,
			{
				name = "tl_" .. tostring(v),
				label = tostring(v),
				kind = "action",
				description = tostring(v),
				handler =
				function()
					log("kind=eimpl:redirect");
				end
			}
		);
	end

	return res;
-- get toplevel xid with input focus
-- target_alloc into bridge (wnd.external)
-- bind to window
--    hook motion and resize to forwarded actions, route input to
--    bridge
end

local function assign_hook(space, wnd)
-- 'save' external or canvas and kill (or hide?) the window
-- update any external handler to act as a more simplified one
-- register the proxy window
-- pair xid to proxy
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
		eval = function() return DEBUGLEVEL > 0; end,
		name = "colorize",
		label = "Colorize",
		description = "Swap backing stores for overlay surfaces to depth-colored",
		kind = "action",
		handler = colorize,
	},
	{
		name = "dump",
		kind = "value",
		label = "Dump",
		description = "Save tree as .dot",
		eval = function() return DEBUGLEVEL > 0; end,
		handler = function(ctx, val)
			dump(active_display().selected, val)
		end,
	},
	{
		name = "create_proxy",
		kind = "action",
		label = "DebugProxy",
		description = "Create a Proxy window with a random surface",
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
	actions = bridge_menu,
-- props will be projected upon the window during setup (unless there
-- are overridden defaults)
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
};
