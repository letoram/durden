--  fn = vid reference for pre-existing image and video preview sessions
local prev_cache = {};
local lastent = "";
-- track lastpath so we can meta-launch browse internal and resume old path
local lastpath = "";

local function imgwnd(fn, pctx)
	if (pctx and valid_vid(pctx.vid)) then
-- if finished, just take new window and take ownership of vid
-- otherwise update vid with new handler that spawns window on activation
		local st = image_state(pctx.vid);
		if (st == "asynchronous state") then
			pctx.spawn = pctx.vid;
			pctx.title = "image:" .. fn;
			pctx.vid = BADID;
		else
			pctx.vid = BADID;
		end
	else
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

local function toggle_ent(v, match)
	if (not valid_vid(v)) then
		return;
	end

	instant_image_transform(v);
	if (match) then
		if (image_surface_properties(v).opacity < 1.0) then
			blend_image(v, 1.0, gconfig_get("animation"));
			if (valid_vid(v, TYPE_FRAMESERVER)) then
				resume_target(v);
			end
		end
	elseif (image_surface_properties(v).opacity > 0.3) then
		blend_image(v, 0.3, gconfig_get("animation"));
		if (valid_vid(v, TYPE_FRAMESERVER)) then
			suspend_target(v);
		end
	end
end

local function setup_prev(src, anchor, xofs, basew, fn)
	local opa = 0.3;
	if (fn == lastprev) then
		opa = 1.0;
	end

	local time = gconfig_get("animation");
	link_image(src, anchor);
	resize_image(src, basew, 0);
	local props = image_surface_properties(src);
	resize_image(src, 8, 8);
	move_image(src, xofs + basew * 0.5, 0);
	resize_image(src, basew, 0, time);
	blend_image(src, opa, time);
	nudge_image(src, -basew * 0.5, -props.height, time);
	image_inherit_order(src, true);
end

local function decprev(path, name, space, anchor, xofs, basew, mh)
	local fn = path .. "/" .. name;

	if (not resource(fn, space)) then
		return;
	end

	for k,v in pairs(prev_cache) do
		toggle_ent(v, k == fn);
	end

	lastent = fn;

	if (prev_cache[fn]) then
		return;
	end

	prev_cache[fn] =
		launch_decode(fn, "pos=0.5:noaudio:loop",
	function(source, status)
		if (status.kind == "resized") then
			setup_prev(source, anchor, xofs, basew, fn);
			if (mh) then
				mh.child = source;
			end
		elseif (status.kind == "terminated") then
			expire_image(source, gconfig_get("animation"));
			blend_image(source, 0.0, gconfig_get("animation"));
			prev_cache[fn] = nil;
		end
	end);
	return {
		vid = prev_cache[fn],
		name = name,
		destroy = function(ctx)
			prev_cache[fn] = nil;
			if (valid_vid(ctx.vid)) then
				delete_image(ctx.vid);
			end
		end,
		activate = function(ctx)
			decwnd(fn, ctx);
		end
	};
end

local function imgprev(path, name, space, anchor, xofs, basew, mh)
-- cache loaded paths, on trigger we know we are "focused" and
-- should be a bit larger
	local fn = path .. "/" .. name;
	if (not resource(fn, space)) then
		return;
	end

	for k,v in pairs(prev_cache) do
		toggle_ent(v, k == fn);
	end

	if (prev_cache[fn]) then
		return;
	end

	local vid = load_image_asynch(fn,
	function(src, stat)
		if (stat.kind == "loaded") then
			setup_prev(src, anchor, xofs, basew);
			if (mh) then
				mh.child = src;
			end
		end
-- death is easy, destroy will be called by lbar
		end
	);
	prev_cache[fn] = vid;
	return {
		vid = vid,
		name = name,
		destroy = function(ctx)
			prev_cache[fn] = nil;
			if (valid_vid(ctx.vid)) then
				delete_image(vid);
			end
		end,
		activate = function(ctx)
			imgwnd(fn, ctx);
		end
	};
end

local function defprev(fn, path)
	for k,v in pairs(prev_cache) do
		toggle_ent(v, false);
	end
end

local function triggerfun(ctx, a, b, c)
	print("triggered", ctx, a, b, c);
end

local function preview_hnd(ctx)
	print("preview");
end

local function queue_hnd(ctx)
	print("queue");
end

local function cancel_hnd(ctx)
	print("cancel");
end

return function()
-- for universal file picker, this is where we should implement the hooks
-- that redirects to the correct window - all in all we should move this
-- code to a separate suppl path as it is more generic
	local imghnd = {
		run = imgwnd,
		col = HC_PALETTE[1],
		selcol = HC_PALETTE[1],
		preview = gconfig_get("browser_preview") ~= "none" and imgprev or nil,
	};

	local audhnd = {
		run = decwnd,
		col = HC_PALETTE[2],
		selcol = HC_PALETTE[2],
	};

	local dechnd = {
		run = decwnd,
		col = HC_PALETTE[3],
		selcol = HC_PALETTE[3],
		preview = gconfig_get("browser_preview") == "full" and decprev or nil,
	};

-- this is where we can queue a list of handlers to invoke
	local defhnd = {
		run = function() end,
		preview = defprev,
		col = HC_PALETTE[4]
	};

-- decode- frameserver doesn't have a way to query type and extension for
-- a specific resource, and running probes on all files in a folder with
-- 10k entries might be a little excessive
	local ffmts = {jpg = imghnd, jpeg = imghnd, png = imghnd, bmp = imghnd,
		ogg = audhnd, m4a = audhnd, flac = audhnd, mp3 = audhnd,
		mp4 = dechnd, wmv = dechnd, mkv = dechnd, avi = dechnd,
		flv = dechnd, mpg = dechnd, mpeg = dechnd, mov = dechnd,
		webm = dechnd, ["*"] = defhnd,
		on_preview = preview_hnd,
		on_queue = queue_hdn,
		on_cancel = cancel_hnd
	};

	browse_file(nil, ffmts, SHARED_RESOURCE, triggerfun, nil, {});
end
