--
-- Simple resource browser / file picker, when entered, extends the
-- normal menu with additional behavior as long as it is within the
-- /browse/ path.
--
-- Number of things to improve here, with the ideal being that all
-- the visual preview / information etc. gets registered as a widget
-- part of /browse/*
--

-- flush on generate a new path or via alias resolve
local glob_cache = {};

local last_path = "/browse/shared";
function browse_get_last()
	return last_path;
end

local function imgwnd(fn, pctx)
	load_image_asynch(fn, function(src, stat)
		if (stat.kind == "loaded") then
			wnd = active_display():add_window(src, {scalemode = "aspect"});
			wnd:set_title("image:" .. fn);
		elseif (valid_vid(src)) then
			delete_image(src);
			active_display():message("couldn't load " .. fn);
		end
	end);
end

local function decwnd(fn, path)
	lastpath = path;
	local vid = launch_decode(fn, function(s, st) end);

	if (valid_vid(vid)) then
		durden_launch(vid, "", fn);
		durden_devicehint(vid);
	else
		active_display():message("decode- frameserver broken or out-of-resources");
	end
end

local function setup_preview(state, dst)
	local w = state.last_w;
	local ofs = state.last_ofs;
	local sel = state.selected;
	local old_vid = state.vid;

	if (not valid_vid(old_vid)) then
		delete_image(dst);
		return;
	end

	state.vid = dst;

-- relink and take over the role of the intermediate vid
	local parent, attachment = image_parent(old_vid);
	if (valid_vid(parent)) then
		link_image(dst, parent);
	end

	image_inherit_order(dst, true);
	delete_image(old_vid);

	local opa = sel and 1.0 or 0.3;
	local time = gconfig_get("animation");
	if (not valid_vid(dst)) then
		return;
	end

	resize_image(dst, w, 0); -- let engine give us aspect
	local props = image_surface_properties(dst);
	resize_image(dst, 8, 8);
	move_image(dst, ofs + w * 0.5, 0);
	resize_image(dst, w, 0, time);
	blend_image(dst, opa, time);
	nudge_image(dst, -w * 0.5, -props.height, time);
end

-- slight defect here is that if the decode source actually
-- resizes during runtime after the first time, it won't be
-- reflected in the aspect ratio
local function asynch_decode(state, self)
	if (not valid_vid(state.vid)) then
		return;
	end

	local cmd = string.format(
		"pos=%f:noaudio:loop", gconfig_get("browser_position") * 0.01);
	cmd = string.gsub(cmd, ",", ".");

	local vid = launch_decode(self.preview_path, cmd,
		function(source, status)
			if (status.kind == "resized" and state.in_asynch) then
				setup_preview(state, source);
				state.in_asynch = false;

-- not likely to happen as we run with :loop
			elseif (status.kind == "terminated") then
				delete_image(source);
			end
		end
	);

-- since we don't know how long time the resize- etc. will take, link
-- to the anchor now so we will be autodeleted if we get out of scope
	if (valid_vid(vid)) then
		link_image(vid, state.vid);
	end
end

local function asynch_image(state, self)
	load_image_asynch(self.preview_path,
		function(source, status)
			if (status.kind == "loaded") then
				setup_preview(state, source);
				state.in_asynch = false;
				self.last_state = state;
			elseif (status.kind == "load_failed") then
				delete_image(source);
			end
		end
	);
end

-- three states (nil, select, not selected), return a handle to the
-- preview if possible should the caller want a zoomed in version
-- somewhere - though maybe we should have some LRU and destroy-
-- cache state as well
local function update_preview(state, active, xofs, width)
	if (active == nil) then
		if (valid_vid(state.vid)) then
			delete_image(state.vid);
		end
		return;
	end

	if (valid_vid(state.vid)) then
		instant_image_transform(state.vid);
		move_image(state.vid, xofs, -image_surface_properties(state.vid).height);
	end

	if (active == false) then
		if (valid_vid(state.vid) and not state.in_asynch) then
			blend_image(state.vid, 0.3, gconfig_get("animation"));
		end

		state.selected = false;
		return;
	end

	if (valid_vid(state.vid) and not state.in_asynch) then
		blend_image(state.vid, 1.0, gconfig_get("animation"));
	end

	state.selected = true;
	state.last_w = width;
	state.last_ofs = xofs;
end

local function prepare_preview(callback, self, anchor, ofs, width)
-- states we need to track as upvalues from the returned function
	local state = {
		in_asynch = true,
		last_ofs = ofs,
		last_w = width,
		selected = true,
		menu = self,
		vid = null_surface(1, 1)
	};

	if (not valid_vid(state.vid)) then
		return {update = function() end};
	end

	link_image(state.vid, anchor);
	image_inherit_order(state.vid, true);

-- hook it up to a timer or activate immediately?
	local cnt = gconfig_get("browser_timer");
	if (cnt > 0) then
		timer_add_periodic(
			"_preview_" .. tostring(ofs),
			cnt, true, function() callback(state, self); end, true
		);
	else
		callback(state, self);
	end

	state.update = update_preview;
	return state;
end

-- list of default behaviors per extension, this should be extended
-- with some context- option where we can chose the destination, and
-- an option for decode frameserver to 'probe' if it is a supported
-- format or not.
local handlers = {
["image"] = {
	run = imgwnd,
	col = HC_PALETTE[1],
	selcol = HC_PALETTE[1],
	preview = gconfig_get("browser_preview") == "none" and nil or
	function(...) return prepare_preview(asynch_image, ...); end
},
["audio"] = {
	run = decwnd,
	col = HC_PALETTE[2],
	selcol = HC_PALETTE[2]
},
["video"] = {
	run = decwnd,
	col = HC_PALETTE[3],
	selcol = HC_PALETTE[3],
	preview = gconfig_get("browser_preview") == "none" and nil or
	function(...) return prepare_preview(asynch_decode, ...); end
}};

-- These menus act like normal menus, but they install separate
-- handlers that override preview behavior, add additional input/
-- filters etc. The big headscratcher is how this is supposed to
-- work when there is asynchronous globbing going on.
local gen_menu_for_path;
local function gen_menu_for_resource(path, v, descr, prefix, ns)
	local fqn = path .. (path == "/" and "" or "/") .. v;
	if (descr == "directory") then
		return {
			label = v,
			name = v,
			kind = "action",
			description = v,
			submenu = true,
			handler = function()
				return gen_menu_for_path(fqn, prefix);
			end
		};
	elseif (descr == "file") then
		local exth = handlers[suppl_ext_type(v, ffmts)];
		if (not exth) then
			return;
		end

		local res = {
			label = v,
			name = v,
			description = v,
			format = exth.col,
			select_format = exth.selcol,
			kind = "action",
			preview = exth.preview,
			preview_path = fqn,
		};
		res.handler = function(ctx)
-- currently no way of querying the preview handler for a decoded resource
			exth.run(fqn, res.last_state);
		end
		return res;
	else
	end
end

gen_menu_for_path = function(path, prefix, ns)
	local gpath = path == "/" and "/*" or path .. "/*";
	local files = glob_resource(gpath, ns);

	local res = {
	};

	for i,v in ipairs(files) do
		if (v ~= "." and v ~= "..") then
			local _, descr = resource(path .. "/" .. v, ns);
			if (descr) then
				local menu = gen_menu_for_resource(path, v, descr, prefix, ns);
				if (menu) then
					table.insert(res, menu);
				end
			end
		end
	end

	table.insert(res, {
		label = ".",
		name = "refresh",
		kind = "action",
		alias = prefix .. path,
		interactive = true,
		handler = function()
			glob_cache[path] = nil;
		end
	});

-- Note that this will update the 'last visited path' no matter what
-- the origin. This means that IPC, timer and binding based operations
-- will change the starting point.
	last_path = prefix .. path;

	return res;
end

return function()
	return {
	{
		name = "shared",
		label = "Shared",
		kind = "action",
		submenu = true,
		description = "The shared resources namespace",
		handler = function()
			return gen_menu_for_path("", "/browse/shared", SHARED_RESOURCE);
		end
	},
	{
		name = "durden",
		label = "Durden",
		kind = "action",
		description = "Durden generated output",
		submenu = function()
			return gen_menu_for_path("output", "/browse/durden", APPL_TEMP_RESOURCE);
		end
	},
	{
		label = "Last",
		name = "last",
		description = "Return to the last visited browse/ path",
		kind = "action",
		alias = function() return last_path; end,
		handler = function()
		end
	}
	};
end
