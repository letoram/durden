local function segreq(wnd, source, status)
	if status.segkind ~= "popup" then
-- chain-call to the default handler, we just want to cha
		local tmp = wnd.dispatch;
		wnd.dispatch = {};
		local rv = extevh_default(source, status);
		wnd.dispatch = tmp;
		return rv;
	end

-- for popup, track one in a dedicated slot and a new request kills the previous
	if wnd.popup_handler then
		wnd.popup_handler:destroy();
		wnd.popup_handler = nil;
	end

	local vid = accept_target();
	if not valid_vid(vid) then
		return;
	end

-- immediately preroll the parent font property as well as the desired colour
-- scheme with the option of actually having a default alpha in order for some
-- cutesy popup with blur, dropshadow and rounded border to dazzle and amaze.
	if gconfig_get("tui_colorscheme") then
		suppl_tgt_color(source, gconfig_get("tui_colorscheme"))
	end

	if wnd.last_font then
		for i=1,#wnd.last_font[3] do
			local _, cw, ch = target_fonthint(vid,
				wnd.last_font[3][i],
				wnd.last_font[1] * FONT_PT_SZ,
				wnd.last_font[2], i ~= 1
			);
		end
	end

	wnd.popup_handler = wnd:add_popup(vid, false, function() wnd.popup_handler = nil; end)
	target_updatehandler(vid,
		function(source, status)
			if status.kind == "terminated" then
				if wnd.popup_handler then
					wnd.popup_handler:destroy();
				else
					delete_image(source);
				end
			elseif status.kind == "resized" then
				resize_image(source, status.width, status.height);
			elseif status.kind == "viewport" then
				if status.invisible then
					wnd.popup_handler:hide();
				else
					wnd.popup_handler:show();
				end
				wnd.popup_handler:reposition(
					status.rel_x, status.rel_y,
					status.rel_x + status.anchor_w,
					status.rel_y + status.anchor_h,
					status.edge
				);
			end
		end
	)
end

local res = {
	dispatch = {
		preroll = function(wnd, source, status)
			if gconfig_get("tui_colorscheme") then
				suppl_tgt_color(source, gconfig_get("tui_colorscheme"))
			end
			return true;
		end,
		content_state = function(wnd, source, status)
			if status.max_w <= 0 or status.max_h <= 0 or
				not wnd.space or not wnd.space.in_float then
				return true;
			end

-- could have other strategies here for tiled at least where any children or
-- siblings get more space allocated to them, but would take some refactoring
-- of the layout code
			wnd:displayhint(status.max_w, status.max_h, wnd.dispmask);
			return true;
		end,
		segment_request = segreq,

-- message is used for notifications or prompt hints (still in flux, idea
-- was for readline widget to communicate the actual prompt part to integrate
-- with the HUD style prompt but it might just turn out to be a bad idea).
		message = function(wnd, source, tbl)
			if string.sub(tbl.message, 1, 1) == ">" then
				return true;
			end
			notification_add(
				wnd:get_name(),
				nil,
				#tbl.message < 24 and tbl.message or "terminal notification",
				tbl.message, 1
			)
			return true;
		end
	},
-- actions are exposed as target- menu
	actions = {
	},
-- labels is mapping between known symbol and string to forward
	labels = {},
	default_shader = {"simple", "crop"},
	atype = "terminal",
	props = {
		scalemode = "scale",
		autocrop = true,
		centered = false,
		font_block = true,
		filtermode = FILTER_NONE,
		allowed_segments = {"tui", "handover", "popup", "dock"}
	},
};

-- globally listen for changes to the default opacity and forward
gconfig_listen("term_opa", "aterm",
function(id, newv)
	for wnd in all_windows("terminal") do
		if (valid_vid(wnd.external, TYPE_FRAMESERVER)) then
			target_graphmode(wnd.external, 1, newv * 255.0);
		end
	end

	local col = gconfig_get("term_bgcol");
	shader_update_uniform("crop", "simple", "color",
		{col[1], col[2], col[3], newv}, nil, "term-alpha");
end);

-- globally apply changes to terminal font and terminal font sz,
-- share fallback- font system wide though.
gconfig_listen("term_font", "aterm",
function(id, newv)
	for wnd in all_windows("terminal") do
		wnd.font_block = false;
		local tbl = {newv};
		local fbf = gconfig_get("font_fb");
		if (fbf and resource(fbf, SYS_FONT_RESOURCE)) then
			tbl[2] = fbf;
		end
		wnd:update_font(-1, -1, tbl);
		wnd.font_block = true;
	end
end);

gconfig_listen("term_font_hint", "aterm",
function(id, newv)
	for wnd in all_windows("terminal") do
		wnd.font_block = false;
		wnd:update_font(-1, newv);
		wnd.font_block = true;
	end
end);

gconfig_listen("term_font_sz", "aterm",
function(id, newv)
	for wnd in all_windows("terminal") do
		wnd.font_block = false;
		wnd:update_font(tonumber(newv), -1);
		wnd.font_block = true;
	end
end);

res.init = function(res, wnd, source)
	wnd.font_block = false;
	local tbl = {gconfig_get("term_font")};
	local fbf = gconfig_get("font_fb");
	if (fbf and resource(fbf, SYS_FONT_RESOURCE)) then
		tbl[2] = fbf;
	end

	if (gconfig_get("term_bitmap")) then
		wnd.last_font = nil;
		wnd:update_font(gconfig_get("term_font_sz"),
			gconfig_get("term_font_hint"));
		wnd:update_font(gconfig_get("term_font_sz"),
			gconfig_get("term_font_hint"));
	else
		wnd:update_font(gconfig_get("term_font_sz"),
			gconfig_get("term_font_hint"), tbl);
	end

	wnd.font_block = true;
end

res.labels["LEFT"] = "LEFT";
res.labels["UP"] = "UP";
res.labels["DOWN"] = "DOWN";
res.labels["RIGHT"] = "RIGHT"
res.labels["lshift_UP"] = "PAGE_UP";
res.labels["lshift_DOWN"] = "PAGE_DOWN";

return res;
