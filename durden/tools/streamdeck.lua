local cps = {};
local log = suppl_add_logfn("tools");
local relayout_grid;

local icon_shader = build_shader(nil,
	[[
		uniform sampler2D map_tu0;
		uniform float radius;
		varying vec2 texco;
		uniform float obj_opacity;

		float box(vec2 p, vec2 b)
		{
			vec2 d = abs(p) - b;
			return length(
				max(d, vec2(0)) +
				min(
					max(d.x, d.y), 0.0
				)
			);
		}

		void main()
		{
			vec4 color = texture2D(map_tu0, texco);
			float vis = box(texco * 2.0 - 1.0, vec2(0.28)) - radius;
			float step = fwidth(vis);
			vis = smoothstep(step, -step, vis);
			gl_FragColor = vec4(color.rgb, color.a * vis * obj_opacity);
		}
	]],
	"deckicon"
);
shader_uniform(icon_shader, "radius", "f", 0.90);

local primary_handler;
local function reset_cp(tbl, source, noreopen)
	suppl_delete_image_if(source);
	log("name=streamdeck:kind=reset:dev=" .. tbl.name);
	tbl.buttons = {};

-- everthing is anchored to the bg
	suppl_delete_image_if(tbl.bg);
	tbl.bg = nil;
	tbl.got_rt = BADID;
	timer_delete("streamdeck_" .. tbl.name);

	if noreopen then
		return;
	end

-- re-open
	tbl.vid = target_alloc(tbl.name,
		tbl.cell_w * tbl.cols, tbl.cell_h * tbl.rows,
		function(...)
			return primary_handler(tbl, ...);
		end
	);
	if (valid_vid(tbl.vid)) then
		target_flags(tbl.vid, TARGET_BLOCKADOPT);
	else
-- add reopen timer and backoff here
	end
end

local function add_button(ctx, dst)
	if not valid_vid(ctx.lbl) then
		return
	end
	table.insert(dst, {
		vid = ctx.lbl,
		action = function()
			if ctx.click then
				ctx:click();
			end
		end
	});
end

local function gen_tbar(ctx, dst)
	local wnd = active_display().selected;
	if not wnd then
		log("tbar:no_group");
		return;
	end

-- crutch is that we may have a resolution or density mismatch
-- here, and no reliable tracking of the construction argument to
-- the label of the titlebar icon (not entirely true but a bad idea
-- to rely on it for the time being)
	for _,v in ipairs(wnd.titlebar.buttons.left) do
		add_button(v, dst);
	end
	for _,v in ipairs(wnd.titlebar.buttons.right) do
		add_button(v, dst);
	end
end

local function run_label(wnd, label)
	local tbl = {
		kind = "digital",
		label = label,
		translated = true,
		active = true,
		devid = 8,
		subid = 8
	};
	wnd:input_table(tbl);
	tbl.active = false;
	wnd:input_table(tbl);
end

local function gen_labels(ctx, dst, raw)
	local wnd = active_display().selected;

-- note that we currently lack a way of being noted on changes to the
-- label set (or when it is completed even), no nice solution for that
-- at the moment, so possibly need to go with a refresh timer
	if not wnd or not wnd.input_labels then
		log("wnd_lack_labels");
		return;
	end

	ctx.last_label = CLOCK;

-- filter if not raw and no vsymbol, otherwise bias on vsym then fallback
-- to raw icon label and let the caller figure out how to raster
	for k,v in ipairs(wnd.input_labels) do
		local sym;
		local label = raw and v.label or nil;

-- display symbol is, if provided, defer this until we have a mechanism
-- to judge if the font in question can deliver or not
		if false and #v.symbol > 0 then
			sym = icon_lookup_u8(v.symbol, active_display(true));

-- but icons for common/known labels might also be present
		elseif icon_known(v.label) then
			sym = icon_lookup(v.labsl, ctx.icon_w);
		end

-- 'show raw' means that we can always use the label at least
		if sym ~= nil or raw then
			label = string.split(label, "_");
			table.insert(dst, { vid = sym, label = label, action =
			function()
				if wnd.input_table then
					run_label(wnd, v.label);
				end
			end
			});
		end
	end
end

local function gen_custom(ctx, dst)
	if not ctx.custom or #ctx.custom == 0 then
		return;
	end

	for i,v in ipairs(ctx.custom) do
		local ok, hnd = suppl_valid_vsymbol(v[1], ctx.icon_w);

		if ok then
-- ugly little caveate, vsymbol actually creates a copy with its generator
-- function, while the raw icon_ calls return a reference, so we need to
-- make sure to delete the vid returned from the generator
			if type(hnd) == "function" then
				table.insert(dst, {delete_vid = true, vid = hnd(ctx.icon_w), action = v[2]});
-- this can be either a string or 'text as icon' the choice is
-- open if it should be set as vid or label. We have no good way of
-- probing or controlling size, and it is a hazzle to figure out
-- if we get an 'emoji' like path or not, so treat it as a label
			else
				table.insert(dst, {label = hnd, action = v[2]});
			end
		end
	end
end

-- sweep all windows matching the active display and set
-- them as buttons where the button action becomes a select action
local function gen_windows(ctx, dst)
	local wm = active_display();
	local space = wm:active_space();

-- sort the space based on their euclidian distance
	local windows = space:linearize();
	table.sort(windows, function(a, b)
		local av = math.sqrt(a.x * a.x + a.y + a.y);
		local bv = math.sqrt(b.x * b.x + b.y + b.y);
		return av < bv;
	end);

-- and translate into the button destination list
	for _, v in ipairs(windows) do

-- save a button slot by omitting the currently selected window
		if v ~= wm.selected then
			table.insert(dst, {
				vid = v.canvas,
				tag = "window",
-- more interesting options other than selection exist here,
-- but likely better to do as separate modes of operation rather
-- than the button flood fill
				action = function()
					if v.select then
						v:select();
					end
				end
			});
		end
	end

-- return true if we have dynamic contents that update clocked
-- rather than event-driven
	return #windows > 0;
end

local function gen_ws(ctx, dst)
	local tiler = active_display();

-- most of the magic happens in space:preview which build a preview
-- rendertarget, it is a bit too expensive to just let it roll on a refresh
-- timer, but that setting should be kept elsewhere
	for i=1,10 do
		local space = tiler.spaces[i];
		if space and #space.children > 0 and i ~= tiler.space_ind then
			local label = tiler.spaces[i].label or tostring(i);
			local vid = space:preview(ctx.cell_w * 2, ctx.cell_h * 2, 5, 0);

			table.insert(dst, {
				label = label,
				vid = vid,
				delete_vid = true,
				action = function()
					dispatch_symbol("/global/workspace/switch/switch_" .. tostring(i));
				end
			});
		end
	end
end

local function build_buttonlist(tbl)
-- the keys here match the priorities that is set on the table
-- as part of the connection submenu, those that have a non-zero
-- priority will be added accordingly.
	local keys = {
		{"titlebar", gen_tbar},
		{"labels", gen_labels},
		{"labels_raw", function(ctx, dst) return gen_labels(ctx, dst, true); end},
		{"custom", gen_custom},
		{"windows", gen_windows},
		{"workspaces", gen_ws},
	};
	local buttons = {};

-- increment the values here to match #keys, first-come on equal
-- priority values
	for i=1,5 do
		for _,v in ipairs(keys) do
			if tbl.priorities[v[1]] and tbl.priorities[v[1]] == i then
				log(string.format("name=streamdeck:kind=rebuild:" ..
					"category=%s:priority=%d:dev=%s", v[1], i, tbl.name));
				tbl.dynamic = v[2](tbl, buttons) or tbl.dynamic;
			end
		end
	end
	return buttons;
end

local function update_rt(tbl)
-- set clocked mode only if there is dynamic contents from external
-- providers that would be missed otherwise.
	if not valid_vid(tbl.got_rt) then
		return;
	end

-- reset the timer
	tbl.left = tbl.force_rate;

-- redraw, there is a possible optimization/early-out here if we add
-- a method to query the tick.fract stamp of when the storage was last
-- updated, and compared to our run here.
	rendertarget_forceupdate(tbl.got_rt);

-- a forced update does not imply a readback request, so we have to
-- perform that one explicitly.
	stepframe_target(tbl.got_rt, 1);
end

local function project_cell(tbl, v, ent)
	if not ent then
		hide_image(v.icon);
		v:set_label();
		hide_image(v.bg);
		v.action = function() end;
		return;
	end

	v.action = ent.action;
	blend_image(v.bg, tbl.opacity);
	if ent.draw then
		ent:draw(v, tbl);
		return;
	end

	local icon = valid_vid(ent.vid);
	if icon then
		image_sharestorage(ent.vid, v.icon);
		show_image(v.icon);
		if (ent.delete_vid) then
			delete_image(ent.vid);
		end
	else
		hide_image(v.icon);
	end

-- set_label will deal with crop and relayout
	v:set_label(ent.label, icon);
end

local function project_buttons(tbl)
-- simple path
	if #tbl.last_set <= #tbl.buttons then
-- should consider adding some overflow or pagination here, still build
-- the list as before, then share a slice at page boundaries.
		for i,v in ipairs(tbl.buttons) do
			project_cell(tbl, v, tbl.last_set[i]);
		end
		tbl.set_position = 1;
		return;
	end

-- the way pagination is done is quite complicated and costly as it incurs
-- building the entire set everytime, for some entries, like workspace icons,
-- this - stings -
-- at the same time, infinite time between '..' invocations can happen,
-- so caching the set is in itself not a good idea.

-- four cases:
-- 1. on first page, need to add '..' forward button
-- 2. on middle page, need to add '..' forward and back
-- 3. on last page, need to add '..'  back
-- 4. on a page that is no longer valid, need to re-align
--
-- case 4, but set size is still too large
	local ri = tbl.set_position;
	local nb = #tbl.buttons;
	local di = 1;
	local have_back = false;
	local have_fwd = false;

-- 4 (will transform into 2 or 3)
	if ri > #tbl.last_set then
		nb = nb - 1;
		ri = #tbl.last_set - nb;
	end

-- 1.
	if ri == 1 then
		have_back = false;
		have_fwd = true;
		nb = #tbl.buttons - 1;

-- 2.
	elseif (#tbl.last_set - ri + 1) > (#tbl.buttons - 1) then
		have_back = true;
		have_fwd = true;
		nb = #tbl.buttons - 2;
		di = 2;

-- 3.
	else
		have_back = true;
		have_fwd = false;
		nb = #tbl.buttons - 1;
		di = 2;
	end

-- fill normal buttons
	local count = 0;
	for i=0,nb-1 do
		project_cell(tbl, tbl.buttons[di+i], tbl.last_set[ri + i]);
		if tbl.last_set[ri + i] then
			count = count + 1;
		end
	end

-- add back button
	if have_back then
		project_cell(tbl, tbl.buttons[1], {
			label = '..',
			action = function()
				local nb = #tbl.buttons;

-- back would land us in case 1. or 2?
				if (tbl.set_position - (#tbl.buttons - 1) <= 1) then
					tbl.set_position = 1;
				else
					tbl.set_position = tbl.set_position - (#tbl.buttons - 2);
				end

				tbl:update();
			end
		});
	end

	if have_fwd then
-- write forward- page button or finished?
		project_cell(tbl, tbl.buttons[di + count], {
			label = '...',
			action = function()
				tbl.set_position = ri + count;
				tbl:update();
			end
		});
	end
end

local function menu_for_path(tbl, path)
	local menu, msg, val, enttbl = menu_resolve(table.concat(path, "/"));
	local res = {};

	table.insert(res, {
		label = "[QUIT]",
		action = function()
			tbl.update = relayout_grid;
			tbl:update();
		end
	});

	if not menu or (menu.validator and not menu.validator(val)) then
		return res;
	end

	if type(menu) ~= "table" then
		menu = {menu};
	end

	for k,v in ipairs(menu) do
-- don't have a good way of mapping value fields yet (except perhaps
-- sets then, those could still work)
		if v.kind == "action" and (not v.eval or v.eval()) then
			if v.submenu then
				table.insert(res, {
					label = table.split(v.label, " "),
					action = function()
						table.insert(tbl.menu_path, v.name);
						tbl:update();
					end
				});
			else
				table.insert(res, {
					label = table.split(v.label, " "),
					action = v.action
				});
			end
		end
	end

	return res;
end

local function relayout_menu(tbl)
	if #tbl.buttons == 0 then
		return;
	end

	tbl.last_set = menu_for_path(tbl, tbl.menu_path);
	tbl.set_position = 1;

	project_buttons(tbl);
	update_rt(tbl);
end

-- the meat of the whole unit, step the order of prioritised
-- targets and allocate / render to grid
relayout_grid = function(tbl)
-- this can come from a reset / non-active device
	if #tbl.buttons == 0 then
		return;
	end

-- priorities might have changed, so reset dynamic state tracking
	log("name=streamdeck:kind=relayout:dev=" .. tbl.name);
	tbl.dynamic = false;
	local list = build_buttonlist(tbl);
	log("name=streamdeck:kind=status:size=" ..
		tostring(#list) .. ":limit=" .. tostring(#tbl.buttons));

-- remember new list so it is used in the reprojection
	tbl.last_set = list;
	project_buttons(tbl);
	update_rt(tbl);

-- kill any dangling 'delete me' so we don't hold onto RTs
	if tbl.last_set then
		for _,v in ipairs(tbl.last_set) do
			if v.delete_vid and valid_vid(v.vid) then
				delete_image(v.vid);
			end
		end
	end
end

local function update_lbl(btn, str, icon)
	if not str or #str == 0 then
		hide_image(btn.label);
		local bw = btn.border + btn.border;
		local props = image_storage_properties(btn.icon);
		if (props.width < btn.w - bw) then
			resize_image(btn.icon, props.width, props.height);
			center_image(btn.icon, btn.bg, ANCHOR_C);
		else
			resize_image(btn.icon, btn.w - bw, btn.h - bw);
			move_image(btn.icon, btn.border, btn.border);
		end

		return;
	end

-- multiple options for dealing with a label that does not fit:
-- 1. try stepping down font-size a few PTs
-- 2. crop + ... middle or end
-- 3. line-break (language dependent)
-- 5. just crop
-- 6. clip to icon, then position so last part is visible
--
-- currently go with a mix:
-- y position depends on visibility of icon portion
-- clip to cell background
-- try to shrink size

-- if no icon, allow multiline
	local fmt_tbl = {};
	fmt_tbl[1] = string.format(btn.format, btn.label_size);
	if (type(str) == "table") then
		if icon then
			str = table.concat(str, " ");
		else
			for i,v in ipairs(str) do
				table.insert(fmt_tbl, v);
				table.insert(fmt_tbl, "\\r\\n");
			end
		end
	else
		fmt_tbl[2] = str;
	end

	show_image(btn.label);
	local props;
	for i=0,2 do
		render_text(btn.label, fmt_tbl);
		props = image_surface_resolve(btn.label);
		if props.width <= btn.w then
			break;
		end
		fmt_tbl[1] = string.format(btn.format, btn.label_size - i);
	end

	local y = btn.h - btn.border - props.height;
	local x = btn.w * 0.5 - props.width * 0.5;

-- if the icon isn't visible, center, otherwise put at bottom
	if not icon then
		y = btn.h * 0.5 - props.height * 0.5;
	else
-- two options, either give the label a background, or rescale
-- and reposition the icon, go with the latter
		resize_image(btn.icon, btn.w - btn.border * 2, y - btn.border);
		move_image(btn.icon, btn.border, btn.border);
	end

	move_image(btn.label, x, y);
end

local function load_bg(tbl, val)
	load_image_asynch(val, function(src, stat)
		if stat.kind == "loaded" and valid_vid(tbl.bg) then
			image_sharestorage(src, tbl.bg);
			update_rt(tbl);
		end
		delete_image(src);
	end)
end

-- build the raw structure of an icon/ button (background, icon, label)
-- with hierarchy and clipping. This should be generalized a little more
-- then just moved to suppl so we can use it for other 'button grids' as
-- well.
local function build_button(w, h, border, fontstr, fontsz)
	local cell_bg = color_surface(w, h, 0, 0, 0);
	if not valid_vid(cell_bg) then
		return;
	end

	local cell = null_surface(w - 2 * border, h - 2 * border);
	if not valid_vid(cell) then
		delete_image(cell_bg);
		return;
	end

-- so there is an anchor / background for positioning
-- then an icon area and an optional label area that we enable on/off
-- ignore the opacity mask as we may want a translucent cell bg against
-- a global background
	link_image(cell, cell_bg);
	image_shader(cell, icon_shader);
	order_image(cell, 1);
	image_inherit_order(cell, true);
	show_image({cell, cell_bg});
	move_image(cell, border, border);
	image_mask_clear(cell, MASK_OPACITY);

-- placeholder vid, this can practically fail, best- effort handover if
-- that is the case
	local labelfun = function() end;
	local lbl = render_text("tmp");
	if valid_vid(lbl) then
		link_image(lbl, cell_bg);
		show_image(lbl);
		image_mask_clear(lbl, MASK_OPACITY);
		image_inherit_order(lbl, true);
		image_clip_on(lbl, CLIP_SHALLOW);
		order_image(lbl, 1);
		labelfun = update_lbl;
	end

	fontsz = fontsz or 12;

-- track these in a tab
	return {
		label = lbl,
		bg = cell_bg,
		icon = cell,
		w = w,
		h = h,
		border = border,
		format = fontstr and fonstr or "\\f,%d",
		label_size = fontsz,
		set_label = labelfun,
		action = function()
		end
	};
end

local function build_rendertarget(tbl, source, bind)
	local w = tbl.cell_w * tbl.cols;
	local h = tbl.cell_h * tbl.rows;

-- first the composition buffer
	local buf = alloc_surface(w, h);
	if not valid_vid(buf) then
		if bind then
			reset_cp(tbl, source);
		end
		return;
	end

-- then the background image that will be used for the pipeline
	local bg = fill_surface(w, h, unpack(tbl.bgc));
	if not valid_vid(bg) then
		delete_image(buf);
		return;
	end

-- an image override might also be defined
	if tbl.bg_source then
		load_bg(tbl, tbl.bg_source);
	end

-- setup the rendertarget itself and connect to the frameserver,
-- then tie the lifecycle of it to the frameserver vid as well.
-- The rendertarget will not update by itself, but rather trigger
-- on relayouting events and explicit frame updates.
	define_rendertarget(buf,
		{bg}, RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, 0);

	if bind then
		rendertarget_bind(buf, source);
	end

	tbl.got_rt = buf;
	tbl.bg = bg;
	link_image(buf, source);
	show_image(bg);
	log(string.format(
		"name=streamdeck:kind=rtbind:w=%d:h=%d:dev=%s", w, h, tbl.name));

-- then a null surface for each grid cell, or as many as we can
-- this is slightly 'problematic' as there are not that many nodes
-- allowed in the scene graph, so allocation might fail.
	local cr = 0;
	local cc = 0;

-- this is where we assume uniformly shaped buttons, for certain
-- cases, say, touchbar, we might want wider cells and cover other
-- forms of allocation and traversal
	local attachment = set_context_attachment(buf);
	for i=1,tbl.rows*tbl.cols do
		local button = build_button(
			tbl.cell_w, tbl.cell_h, tbl.border, tbl.font_str, tbl.font_sz);
		if not button then
			break;
		end

-- bind to bg for lifecycle management and positioN
		link_image(button.bg, bg);
		button.x = cc * tbl.cell_w;
		button.y = cr * tbl.cell_h;
		move_image(button.bg, button.x, button.y);
		table.insert(tbl.buttons, button);

-- track destination cell coordinates
		cc = cc + 1;
		if cc == tbl.cols then
			cc = 0;
			cr = cr + 1;
		end
	end
	set_context_attachment(attachment);

-- instead of letting the rendertarget update on a clock basis, bind
-- it to a tick timer with some preset rate, and let the update function
-- enable / disable based on load.
	timer_add_periodic("streamdeck_" .. tbl.name, 1, false,
		function()

-- check if the # of labels or the button state of a window has changed,
-- as there are no stable event-hooks to use for those
			local wnd = active_display().selected;
			local label_update = wnd and tbl.last_label and
				wnd.label_update and tbl.last_label < wnd.label_update;

			if (label_update) then
				tbl:update();
				return;
			end

-- This will not cause (the expensive) reprojection of buttons, only
-- stepping frames so that sampled icons etc. reflect something more
-- recent. A big optimization here would be to also track and detect
-- the number of dirty sources.
			if (tbl.force_rate > 0) then
				tbl.left = tbl.left - 1;
				if tbl.left == 0 then
					tbl:update();
				end

-- Dynamic will "only" cause resampling, still expensive but a lot less
-- than full cell rebuild / reprojection
			elseif tbl.dynamic then
				update_rt(tbl);
			end

		end, true
	);
end

primary_handler = function(tbl, source, status, iotbl)
-- got the requested output, build the offscreen composition
	if status.kind == "registered" then
		if status.segkind ~= "encoder" then
			return reset_cp(tbl, source);
		end

		log("name=streamdeck:kind=registered:dev=" .. tbl.name);
		build_rendertarget(tbl, source, true);
		tbl:update();

-- the button presses
	elseif status.kind == "input" then
-- only go with 'on-rising press'
		if iotbl.digital and iotbl.active then
			local button = tbl.buttons[iotbl.subid];
			if not button then
				return;
			end
			button = button.action;

-- ok, we have something to dispatch, prepare for custom hooks
			if type(button) == "function" then
				button(tbl, source);

-- and normal symbol dispatch into the menu system
			elseif type(button) == "string" then
				dispatch_symbol(button);
			end
		end

-- on client initiated termination, we re-open the connection
-- point and go from there
	elseif status.kind == "terminated" then
		reset_cp(tbl, source);
	end
end

-- we need hooks to determine when to rebuild the button mapping. The slightly
-- problematic part is that frame delivery status is not actively tracked so we
-- don't know when to rebuild workspace previews. This should probably be
-- solved in the tiler layer.
local hooks_active = false;
local function rebuild_all()
	log("name=streamdeck:kind=rebuild");
	for _, v in ipairs(cps) do
		v:update();
	end
end

local function hook_tiler(tiler)
	table.insert(tiler.on_wnd_create, rebuild_all);
	table.insert(tiler.on_wnd_destroy, rebuild_all);
	table.insert(tiler.on_wnd_select, rebuild_all);
end

local function enable_hooks()
	if hooks_active then
		return;
	end

-- need to handle events on all displays
	for tiler in all_tilers_iter() do
		hook_tiler(tiler);
	end

-- and track those that are hotplugged
	tiler_create_listener(
	function()
		hook_tiler(tiler);
	end);

	hooks_active = true;
end

local function add_device(ctx, val)
	local tbl = {
		name = val,
	};

	table.insert(cps, {
		name = val,
		vid = vid,
		border = 4,
		force_rate = 0,
		cell_w = 72,
		cell_h = 72,
		icon_w = 24,
		rows = 3,
		cols = 5,
		font_str = "\\f,%d" .. HC_PALETTE[1],
		font_sz = 12,
		density = 36.171,
		tickrate = 1,
		opacity = 0.5,
		overlay_scale = 1,
		custom = {},
		got_rt = BADID,
		priorities = {},
		buttons = {},
		bgc = {0, 0, 0},
		set_position = 1,
		update = relayout_grid
	});
end

local function gen_destroy_menu()
	local res = {};
	for i,v in ipairs(cps) do
		table.insert(res, {
			name = v.name,
			kind = "action",
			label = v.name,
			description = "Close the " .. v.name .. " device",
			handler = function()
-- since the table might be modified with the menu not rebuild, the index might
-- have changed between building the closure and invoking it, so search
				for j,k in ipairs(cps) do
					if k == v then
						delete_image(v.vid);
						table.remove(cps, j);
						return;
					end
				end
			end
		});
	end
end

local function close_cpoint(name)
	local i = table.find_key_i(cps, "name", name);
	if not i then
		return;
	end
	suppl_delete_image_if(cps[i].vid);
	timer_delete("streamdeck_" .. name);
	table.remove(cps, i);
end

local function valid_constraints(val, name, tbl)
	local tmp = {};
	val = tonumber(val);
	if not val or val <= 0 then
		return false;
	end

	for k,v in pairs(tbl) do
		tmp[k] = v;
	end

	tmp[name] = val;
	if tmp.cell_w * tmp.cols > MAX_SURFACEW then
		return false;
	end
	if tmp.cell_h * tmp.rows > MAX_SURFACEH then
		return false;
	end
	if tmp.cell_w < 8 or tmp.cell_h < 8 or
		tmp.cell_w >= 256 or tmp.cell_h >= 256 then
		return false;
	end
	return true;
end

local function gen_map_tbl(tbl, key, label, desc)
	if not tbl.priorities[key] then
		tbl.priorities[key] = 0;
	end

	return {
		name = key,
		label = label,
		kind = "value",
		hint = "(priorities, 0 <= n <= 5))",
		initial = function()
			return tostring(tbl.priorities[key]);
		end,
		validator = gen_valid_num(0, 5),
		description = desc,
		handler = function(ctx, val)
			log("name=streamdeck:kind=set_priority:key=" .. key .. ":value=" .. val);
			tbl.priorities[key] = tonumber(val);
			tbl:update();
		end
	};
end

local function gen_remove_custom(tbl)
	local res = {
		{
			name = "all",
			label = "All",
			kind = "action",
			description = "Remove all custom item bindings",
			handler = function()
				tbl.custom = {};
				tbl:update();
			end
		}
	};
	for i,v in ipairs(tbl.custom) do
		table.insert(res, {
			name = "remove_" .. tostring(i),
			label = v[2],
			description = "Remove the binding for path: " .. v[2],
			kind = "action",
			handler = function()
				table.remove(tbl.custom, i);
				tbl:update();
			end
		});
	end
	return res;
end

local function gen_mode_menu(tbl)
	return {
		{
			name = "dynamic",
			label = "Dynamic",
			description = "Default mapping mode, buttons are populated dynamically based on group priority",
			kind = "action",
			handler = function()
				log("name=streamdeck:kind=status:mode=dynamic:dev=" .. tbl.name);
				tbl.update = relayout_grid;
				tbl:update();
			end
		},
-- this is actually called from the custom menu buttons, just belong in this
-- group too for testing / development and example to more relevant future
-- mappings.
		{
			name = "menu",
			label = "Menu",
			description = "Map action entries from a menu path",
			kind = "value",
			eval = function() return false; end,
			validator = function(val)
				return shared_valid_str(val);
			end,
			handler = function(ctx, val)
				tbl.last_update = tbl.update;
				tbl.update = relayout_menu;
				tbl.menu_path = {val};
				tbl:update();
			end
		}
-- other interesting inputs to see here would be window selection based on
-- contents, which wouldn't be that big of a stretch
	};
end

local function gen_bg_menu(tbl)
	local res = {};
	table.insert(res, {
		name = "image_browse",
		label = "Image Browse",
		interactive = true,
		block_external = true,
		description = "Browse for an image to set as background",
		kind = "action",
		handler = function()
			dispatch_symbol_bind(
			function(path)
				if (path and #path > 0) then
					tbl.bg_source = path;
					if valid_vid(tbl.bg) then
						load_bg(tbl, path);
					end
				end
			end, "/browse/shared");
		end
	});
	table.insert(res, {
		name = "image",
		label = "Image",
		description = "Set static background image based on a shared-resource relative path",
		kind = "value",
		validator = function(val)
			if not shared_valid_str(val) then
				return;
			end
			return resource(val);
		end,
		handler = function(ctx, val)
			tbl.bg_source = val;
			if valid_vid(tbl.bg) then
				load_bg(tbl, val);
			end
		end,
	});
	table.insert(res, {
			name = "color",
			label = "Color",
			description = "Set background to a solid color",
	});
	suppl_append_color_menu(tbl.bgc, res[#res],
		function(str, r, g, b)
			tbl.bgc = {r, g, b};
			local tmp = fill_surface(32, 32, r, g, b);
			if (valid_vid(tbl.bg) and valid_vid(tmp)) then
				image_sharestorage(tmp, tbl.bg);
			end
		end
	);
	return res;
end

local function gen_map_menu(tbl)
	local res = {};
	res[1] = gen_map_tbl(tbl, "titlebar", "Titlebar", "Current window titlebar buttons");
	res[2] = gen_map_tbl(tbl, "labels", "Labels", "Current window input labels with symbol/icon");
	res[3] = gen_map_tbl(tbl, "labels_raw", "Labels (raw)",
		"Current window input labels with symbol/icon and text fallback");
	res[4] = gen_map_tbl(tbl, "custom", "Custom", "Custom button bindings");
	res[5] = gen_map_tbl(tbl, "windows", "Windows", "Current workspace windows");
	res[6] = gen_map_tbl(tbl, "workspaces", "Workspaces", "Current display workspaces");
	return res;
end

local function window_setup(tbl)
	log("name=streamdeck:kind=open:dev=" .. tbl.name);
	enable_hooks();

-- create a placeholder and piggyback on the external-receiver setup
	local disp = null_surface(tbl.cell_w * tbl.cols, tbl.cell_h * tbl.rows);
	build_rendertarget(tbl, disp);
	tbl.window = active_display():add_window(disp, {scalemode = "stretch"});
	image_sharestorage(tbl.got_rt, tbl.window.canvas);

	tbl.window:add_handler("destroy",
	function()
		tbl.window = nil;
		suppl_delete_image_if(disp);
		suppl_delete_image_if(tbl.got_rt);
		tbl.got_rt = BADID;
		tbl.buttons = {};
	end);

	tbl.window:add_handler("mouse_button",
	function(wnd, subid, btn)
		if not btn then
			return;
		end
		local col = math.floor(wnd.mouse[1] * tbl.cols);
		local row = math.floor(wnd.mouse[2] * tbl.rows);
		local button = tbl.buttons[(row * tbl.cols + col) + 1];
		if not button then
			return;
		end

		button = button.action;
		if type(button) == "function" then
			button(tbl, disp);
		elseif type(button) == "string" then
			dispatch_symbol(button);
		end
	end);

	tbl:update();
end

local function gen_cpoint_menu(name, tbl)
	local res = {};
	table.insert(res, {
		name = "open",
		kind = "action",
		label = "Open",
		eval = function()
			return not tbl.window and not valid_vid(tbl.vid);
		end,
		description = "Bind the device to a connection point and listen for connections",
		handler = function()
			log("name=streamdeck:kind=open:dev=" .. tbl.name);
			enable_hooks();
			reset_cp(tbl, BADID);
		end
	});
	table.insert(res,
	{
		name = "window",
		kind = "action",
		label = "Window",
		eval = function()
			return not tbl.window and not valid_vid(tbl.vid);
		end,
		description = "Bind the device to a window",
		handler = function() window_setup(tbl); end
	});
	table.insert(res, {
		name = "destroy",
		kind = "action",
		label = "Destroy",
		eval = function()
			return valid_vid(tbl.vid);
		end,
		description = "Remove device definition and terminate any active connections",
		handler = function()
			close_cpoint(name);
		end
	});
	table.insert(res, {
		label = "Mode",
		description = "Switch between layout/content mapping modes",
		name = "mode",
		kind = "action",
		submenu = true,
		handler = function()
			return gen_mode_menu(tbl);
		end
	});
	table.insert(res, {
		label = "Mapping",
		description = "Control how content and state gets mapped and displayed on the connected device",
		name = "mapping",
		kind = "action",
		submenu = true,
		handler = function()
			return gen_map_menu(tbl);
		end
	});
	table.insert(res, {
		name = "rows",
		kind = "value",
		labels = "Rows",
		description = "Change the number of button rows",
		initial = function()
			return tostring(tbl.rows);
		end,
		hint = "(n > 0)",
		validator = function(val)
			return valid_constraints(val,	"rows", tbl);
		end,
		handler = function(ctx, val)
			tbl.rows = tonumber(val);
		end
	});
	table.insert(res, {
		name = "cols",
		kind = "value",
		labels = "Cols",
		description = "Change the number of button cols",
		initial = function() return tostring(tbl.cols); end,
		hint = "(n > 0)",
		validator = function(val)
			return valid_constraints(val, "cols", tbl);
		end,
		handler = function(ctx, val)
			tbl.cols = tonumber(val);
		end
	});
	table.insert(res, {
		name = "icon_w",
		kind = "value",
		label = "Width (icon)",
		description = "Change the requested icon base dimension",
		initial = function() return tostring(tbl.icon_w); end,
		hint = "(8 <= n <= (cell_w - 2*border))",
		validator = function(val)
			local num = tonumber(val);
			if not num then
				return false;
			end
			return num >= 8 and num <= tbl.cell_w - tbl.border * 2;
		end,
		handler = function(ctx, val)
			tbl.icon_w = tonumber(val);
		end
	});
	table.insert(res, {
		name = "cell_w",
		kind = "value",
		label = "Width (cell)",
		description = "Change the pixel width for each button",
		initial = function() return tostring(tbl.cell_w); end,
		hint = "(8 <= n < 256)",
		validator = function(val)
			return valid_constraints(val, "cell_w", tbl);
		end,
		handler = function(ctx, val)
			tbl.cell_w = tonumber(val);
		end
	});
	table.insert(res, {
		name = "cell_h",
		kind = "value",
		label = "Height (cell)",
		description = "Change the pixel height for a button",
		initial = function() return tostring(tbl.cell_h); end,
		hint = "(8 <= n < 256)",
		validator = function(val)
			return valid_constraints(val, "cell_h", tbl);
		end,
		handler = function(ctx, val)
			tbl.cell_h = tonumber(val);
		end
	});
	table.insert(res, {
		name = "custom",
		kind = "value",
		label = "Custom",
		description = "Add a new custom item binding",
		widget = "special:icon",
		validator = function(val)
			return suppl_valid_vsymbol(val);
		end,
		handler = function(ctx, val)
			dispatch_symbol_bind(
			function(path)
				if not path or #path == 0 then
					return;
				end
				table.insert(tbl.custom, {val, path});
				tbl:update();
			end);
		end
	});
-- disabled for the time being, some things needed in the menu system for
-- this to be really useful (value- entries need stepping range controls, ...)
	table.insert(res, {
		name = "custom_menu",
		kind = "value",
		label = "Menu Button",
		eval = function()
			return false;
		end,
		description = "Add a button that triggers a custom menu",
		widget = "special:icon",
		validator = function(val)
			return suppl_valid_vsymbol(val);
		end,
		handler = function(ctx, val)
			dispatch_symbol_bind(
			function(path)
				if not path or #path == 0 then
					return;
				end
				table.insert(tbl.custom, {val, path});
				tbl:update();
			end);
		end

	});
	table.insert(res, {
		name = "remove_custom",
		kind = "action",
		label = "Remove Custom",
		submenu = true,
		eval = function()
			return #tbl.custom > 0;
		end,
		handler = function()
			return gen_remove_custom(tbl);
		end
	});
	table.insert(res, {
		name = "background",
		label = "Background",
		description = "Set the color or contents of the device background layer",
		kind = "action",
		submenu = true,
		handler = function()
			return gen_bg_menu(tbl);
		end,
	});
	table.insert(res, {
		name = "refresh",
		kind = "value",
		label = "Refresh",
		description = "Force- set an approximate refresh timer regardless of contents",
		hint = "(0 <= n < 100)",
		validator = gen_valid_num(0, 100),
		handler = function(ctx, val)
			tbl.force_rate = tonumber(val);
			tbl.left = tonumber(val);
		end
	});
	return res;
end

local function gen_device_menu()
	local res = {};
	for k,v in ipairs(cps) do
		table.insert(res, {
			name = v.name,
			label = v.name,
			description = "Modify device '" .. v.name,
			kind = "action",
			submenu = true,
			handler = gen_cpoint_menu(v.name, v)
		});
	end
	return res;
end

local menu = {
	{
		name = "define",
		kind = "value",
		label = "Define",
		validator = function(val)
			for k,v in ipairs(cps) do
				if v.name == val then
					return false;
				end
			end
			return strict_fname_valid(val);
		end,
		description = "Define a new deck device",
		hint = "(a-Z_0-9)",
		handler = add_device
	},
	{
		label = "Devices",
		name = "devices",
		kind = "action",
		submenu = true,
		eval = function()
			return #cps > 0;
		end,
		description = "Open/Destroy or Modify a device",
		handler = function(ctx, val)
			return gen_device_menu();
		end
	},
};

menus_register("global", "tools",
{
	name = "streamdeck",
	label = "Stream Deck",
	description = "Support for dynamic button display devices",
	kind = "action",
	submenu = true,
	handler = menu
});
