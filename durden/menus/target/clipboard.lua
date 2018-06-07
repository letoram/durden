local function pastefun(wnd, msg)
	local dst = wnd.clipboard_out;

	if (not dst) then
		local dst = alloc_surface(1, 1);

-- this approach triggers an interesting bug that may be worthwhile to explore
--		wnd.clipboard_out = define_recordtarget(alloc_surface(1, 1),
--			wnd.external, "", {null_surface(1,1)}, {},
--			RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, 0, function()
--		end);
		wnd.clipboard_out = define_nulltarget(wnd.external, "clipboard",
		function(source, status)
			if (status.kind == "terminated") then
				delete_image(source);
				wnd.clipboard_out = nil;
			end
		end);
		link_image(wnd.clipboard_out, wnd.anchor);
	end

	msg = wnd.pastefilter ~= nil and wnd.pastefilter(msg) or msg;

	if (msg and string.len(msg) > 0) then
		target_input(wnd.clipboard_out, msg);
	end
end

local function clipboard_paste()
	local wnd = active_display().selected;
	pastefun(wnd, CLIPBOARD.globals[1]);
end

local function clipboard_paste_local()
	local wnd = active_display().selected;
	pastefun(wnd, CLIPBOARD:list_local(wnd.clipboard)[1]);
end

-- can shorten further by dropping vowels and characters
-- in beginning and end as we match more on those
local function shorten(s)
	if (s == nil or string.len(s) == 0) then
		return "";
	end

	local r = string.gsub(
		string.gsub(s, " ", ""), "\n", ""
	);
	return r and r or "";
end

local function clipboard_histgen(wnd, lst, promote)
	local res = {};
	for k, v in ipairs(lst) do
		local short = shorten(v);
		table.insert(res, {
			name = "hist_" .. tostring(k),
			label = string.format("%d:%s", k, string.sub(short, 1, 20)),
			kind = "action",
			format = suppl_strcol_fmt(short, false),
			select_format = suppl_strcol_fmt(short, true),
			handler = function()
				if (promote) then
					CLIPBOARD:set_global(v);
				else
					local m1, m2 = dispatch_meta();
					pastefun(wnd, v);
				end
			end
		});
	end
	return res;
end

local function clipboard_local_history()
	local wnd = active_display().selected;
	return clipboard_histgen(wnd, CLIPBOARD:list_local(wnd.clipboard));
end

local function clipboard_history()
	return clipboard_histgen(active_display().selected, CLIPBOARD.globals);
end

local function clipboard_urls()
	local res = {};
	for k,v in ipairs(CLIPBOARD.urls) do
		local short = shorten(v);
		table.insert(res, {
			name = "url_" .. tostring(k),
			label = short,
			fmt = suppl_strcol_fmt(short, false),
			select_fmt = suppl_strcol_fmt(short, true),
			kind = "action",
			handler = function()
				local m1, m2 = dispatch_meta();
				pastefun(active_display().selected, v);
			end
		});
	end
	return res;
end

return {
	{
		name = "paste",
		label = "Paste",
		kind = "action",
		description = "Paste the current entry from the global clipboard",
		eval = function() return valid_vid(
			active_display().selected.external, TYPE_FRAMESERVER);
		end,
		handler = clipboard_paste
	},
	{
		name = "lpaste",
		label = "Paste-Local",
		kind = "action",
		description = "Paste the current entry from the local clipboard",
		eval = function()
		return valid_vid(
			active_display().selected.external, TYPE_FRAMESERVER);
		end,
		handler = clipboard_paste_local
	},
	{
		name = "lhist",
		label = "History-Local",
		kind = "action",
		description = "Enumerate the local clipboard history",
		eval = function()
			local wnd = active_display().selected;
			return wnd.clipboard ~= nil and #CLIPBOARD:list_local(wnd.clipboard) > 0;
		end,
		submenu = true,
		handler = function()
			local wnd = active_display().selected;
			return clipboard_histgen(wnd, CLIPBOARD:list_local(wnd.clipboard));
		end
	},
	{
		name = "lhistprom",
		label = "Promote",
		kind = "action",
		description = "Promote an entry from the local clipboard to the global shared one",
		eval = function()
			local wnd = active_display().selected;
			return wnd.clipboard ~= nil and #CLIPBOARD:list_local(wnd.clipboard) > 0;
		end,
		submenu = true,
		handler = function()
			local wnd = active_display().selected;
			return clipboard_histgen(wnd, CLIPBOARD:list_local(wnd.clipboard), true);
		end
	},
	{
		name = "hist",
		label = "History",
		description = "Select an entry from the global history",
		kind = "action",
		submenu = true,
		eval = function()
		return valid_vid(
			active_display().selected.external, TYPE_FRAMESERVER);
		end,
		handler = clipboard_history
	},
	{
		name = "url",
		label = "URLs",
		kind = "action",
		description = "Select an entry from the URL catcher",
		submenu = true,
		eval = function()
			return valid_vid(
				active_display().selected.external, TYPE_FRAMESERVER) and
				#CLIPBOARD.urls > 0;
		end,
		handler = clipboard_urls
	},
	{
		name = "mode",
		label = "Mode",
		kind = "value",
		description = "Change the preprocess filter that will be applied before pasting",
		initial = function()
			local wnd = active_display().selected;
			return wnd.pastemode and wnd.pastemode or "";
		end,
		set = CLIPBOARD:pastemodes(),
		handler = function(ctx, val)
			local wnd = active_display().selected;
			local f, l = CLIPBOARD:pastemodes(val);
			wnd.pastemode = l;
			wnd.pastefilter = f;
		end
	}
}
