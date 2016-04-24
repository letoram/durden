local function pastefun(wnd, msg)
	local dst = wnd.clipboard_out;

	if (not dst) then
		local dst = alloc_surface(1, 1);

-- this approach triggers an interesting bug that may be worthwhile to explore
--		wnd.clipboard_out = define_recordtarget(alloc_surface(1, 1),
--			wnd.external, "", {null_surface(1,1)}, {},
--			RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, 0, function()
--		end);
		wnd.clipboard_out = define_nulltarget(wnd.external,
		function()
		end);
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

local function clipboard_histgen(wnd, lst)
	local res = {};
	for k, v in ipairs(lst) do
		table.insert(res, {
			name = "hist_" .. tostring(k),
			label = string.format("%d:%s", k, string.sub(shorten(v), 1, 20)),
			kind = "action",
			handler = function()
				local m1, m2 = dispatch_meta();
				pastefun(wnd, v);
				if (m1) then
					CLIPBOARD:set_global(v);
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
		table.insert(res, {
			name = "url_" .. tostring(k),
			label = shorten(v),
			kind = "action",
			handler = function()
				local m1, m2 = dispatch_meta();
				pastefun(active_display().selected, v);
				if (m1) then
					CLIPBOARD:set_global(v);
				end
			end
		});
	end
	return res;
end

register_shared("paste_global", clipboard_paste);

return {
	{
		name = "paste",
		label = "Paste",
		kind = "action",
		eval = function() return valid_vid(
			active_display().selected.external, TYPE_FRAMESERVER);
		end,
		handler = clipboard_paste
	},
	{
		name = "lpaste",
		label = "Paste-Local",
		kind = "action",
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
		eval = function()
		return valid_vid(
			active_display().selected.external, TYPE_FRAMESERVER);
		end,
		submenu = true,
		handler = clipboard_local_history
	},
	{
		name = "hist",
		label = "History",
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
