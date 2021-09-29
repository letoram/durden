local DataDumper; -- (value, varname, fastmode, ident)


--[[ DataDumper.lua
Copyright (c) 2007 Olivetti-Engineering SA

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
]]

local dumplua_closure = [[
local closures = {}
local function closure(t)
  closures[#closures+1] = t
  t[1] = assert(loadstring(t[1]))
  return t[1]
end

for _,t in pairs(closures) do
  for i = 2,#t do
    debug.setupvalue(t[1], i-1, t[i])
  end
end
]]

local lua_reserved_keywords = {
  'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for',
  'function', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat',
  'return', 'then', 'true', 'until', 'while' }

local function keys(t)
  local res = {}
  local oktypes = { stringstring = true, numbernumber = true }
  local function cmpfct(a,b)
    if oktypes[type(a)..type(b)] then
      return a < b
    else
      return type(a) < type(b)
    end
  end
  for k in pairs(t) do
    res[#res+1] = k
  end
  table.sort(res, cmpfct)
  return res
end

local c_functions = {}
for _,lib in pairs{'_G', 'string', 'table', 'math',
    'io', 'os', 'coroutine', 'package', 'debug'} do
  local t = _G[lib] or {}
  lib = lib .. "."
  if lib == "_G." then lib = "" end
  for k,v in pairs(t) do
    if type(v) == 'function' and not pcall(string.dump, v) then
      c_functions[v] = lib..k
    end
  end
end

DataDumper = function(value, varname, fastmode, ident)
  local defined, dumplua = {}
  -- Local variables for speed optimization
  local string_format, type, string_dump, string_rep =
        string.format, type, string.dump, string.rep
  local tostring, pairs, table_concat =
        tostring, pairs, table.concat
  local keycache, strvalcache, out, closure_cnt = {}, {}, {}, 0
  setmetatable(strvalcache, {__index = function(t,value)
    local res = string_format('%q', value)
    t[value] = res
    return res
  end})
  local fcts = {
    string = function(value) return strvalcache[value] end,
    number = function(value) return value end,
    boolean = function(value) return tostring(value) end,
    ['nil'] = function(value) return 'nil' end,
    ['function'] = function(value)
      return string_format("loadstring(%q)", string_dump(value))
    end,
    userdata = function() error("Cannot dump userdata") end,
    thread = function() error("Cannot dump threads") end,
  }
  local function test_defined(value, path)
    if defined[value] then
      if path:match("^getmetatable.*%)$") then
        out[#out+1] = string_format("s%s, %s)\n", path:sub(2,-2), defined[value])
      else
        out[#out+1] = path .. " = " .. defined[value] .. "\n"
      end
      return true
    end
    defined[value] = path
  end
  local function make_key(t, key)
    local s
    if type(key) == 'string' and key:match('^[_%a][_%w]*$') then
      s = key .. "="
    else
      s = "[" .. dumplua(key, 0) .. "]="
    end
    t[key] = s
    return s
  end
  for _,k in ipairs(lua_reserved_keywords) do
    keycache[k] = '["'..k..'"] = '
  end
  if fastmode then
    fcts.table = function (value)
      -- Table value
      local numidx = 1
      out[#out+1] = "{"
      for key,val in pairs(value) do
        if key == numidx then
          numidx = numidx + 1
        else
          out[#out+1] = keycache[key]
        end
        local str = dumplua(val)
        out[#out+1] = str..","
      end
      if string.sub(out[#out], -1) == "," then
        out[#out] = string.sub(out[#out], 1, -2);
      end
      out[#out+1] = "}"
      return ""
    end
  else
    fcts.table = function (value, ident, path)
      if test_defined(value, path) then return "nil" end
      -- Table value
      local sep, str, numidx, totallen = " ", {}, 1, 0
      local meta, metastr = (debug or getfenv()).getmetatable(value)
      if meta then
        ident = ident + 1
        metastr = dumplua(meta, ident, "getmetatable("..path..")")
        totallen = totallen + #metastr + 16
      end
      for _,key in pairs(keys(value)) do
        local val = value[key]
        local s = ""
        local subpath = path or ""
        if key == numidx then
          subpath = subpath .. "[" .. numidx .. "]"
          numidx = numidx + 1
        else
          s = keycache[key]
          if not s:match "^%[" then subpath = subpath .. "." end
          subpath = subpath .. s:gsub("%s*=%s*$","")
        end
        s = s .. dumplua(val, ident+1, subpath)
        str[#str+1] = s
        totallen = totallen + #s + 2
      end
      if totallen > 80 then
        sep = "\n" .. string_rep("  ", ident+1)
      end
      str = "{"..sep..table_concat(str, ","..sep).." "..sep:sub(1,-3).."}"
      if meta then
        sep = sep:sub(1,-3)
        return "setmetatable("..sep..str..","..sep..metastr..sep:sub(1,-3)..")"
      end
      return str
    end
    fcts['function'] = function (value, ident, path)
      if test_defined(value, path) then return "nil" end
      if c_functions[value] then
        return c_functions[value]
      elseif debug == nil or debug.getupvalue(value, 1) == nil then
        return string_format("loadstring(%q)", string_dump(value))
      end
      closure_cnt = closure_cnt + 1
      local res = {string.dump(value)}
      for i = 1,math.huge do
        local name, v = debug.getupvalue(value,i)
        if name == nil then break end
        res[i+1] = v
      end
      return "closure " .. dumplua(res, ident, "closures["..closure_cnt.."]")
    end
  end
  function dumplua(value, ident, path)
    return fcts[type(value)](value, ident, path)
  end
  if varname == nil then
    varname = "return "
  elseif varname:match("^[%a_][%w_]*$") then
    varname = varname .. " = "
  end
  if fastmode then
    setmetatable(keycache, {__index = make_key })
    out[1] = varname
    table.insert(out,dumplua(value, 0))
    return table.concat(out)
  else
    setmetatable(keycache, {__index = make_key })
    local items = {}
    for i=1,10 do items[i] = '' end
    items[3] = dumplua(value, ident or 0, "t")
    if closure_cnt > 0 then
      items[1], items[6] = dumplua_closure:match("(.*\n)\n(.*)")
      out[#out+1] = ""
    end
    if #out > 0 then
      items[2], items[4] = "local t = ", "\n"
      items[5] = table.concat(out)
      items[7] = varname .. "t"
    else
      items[2] = varname
    end
    return table.concat(items)
  end
end

local fnlist = {
	"color_surface",
	"fill_surface",
	"alloc_surface",
	"raw_surface",
	"render_text",
	"define_rendertarget",
	"define_linktarget",
	"define_recordtarget",
	"define_calctarget",
	"define_linktarget",
	"define_nulltarget",
	"define_arcantarget",
	"launch_target",
	"accept_target",
	"target_alloc",
	"load_image",
	"launch_decode",
	"launch_avfeed",
	"load_image_asynch",
};

local fnbuf
local alist

local function toggle_alloc()
	if fnbuf then
		print("disable alloc tracing")
		for k,v in pairs(fnbuf) do
			_G[k] = v
		end
		fnbuf = nil
		for k,v in pairs(alist) do
			if valid_vid(k) then
				print("alive", image_tracetag(k), v)
			end
		end

		alist = nil
		return
	end

	fnbuf = {}
	alist = {}
	print("enable alloc tracing")

	for _,v in ipairs(fnlist) do
		fnbuf[v] = _G[v]
		_G[v] = function(...)
			print(v, debug.traceback())
			local vid, a, b, c, d, e, f, g = fnbuf[v](...)
			if valid_vid(vid) then
				print("=>", vid)
				alist[vid] = debug.traceback()
			end
			return vid, a, b, c, d, e, f, g
		end
	end
end

local function spawn_debug_wnd(vid, title)
	show_image(vid);
	local wnd = active_display():add_window(vid, {scalemode = "stretch"});
	wnd:set_title(title);
end

local function gen_displaywnd_menu()
	local res = {};
	for disp in all_displays_iter() do
		table.insert(res, {
			name = "disp_" .. tostring(disp.name),
			handler = function()
				local nsrf = null_surface(disp.tiler.width, disp.tiler.height);
				image_sharestorage(disp.rt, nsrf);
				if (valid_vid(nsrf)) then
					spawn_debug_wnd(nsrf, "display: " .. tostring(k));
				end
			end,
			label = disp.name,
			kind = "action"
		});
	end

	return res;
end

local function gettitle(wnd)
	return string.format("%s/%s:%s", wnd.name,
		wnd.title_prefix and wnd.title_prefix or "unk",
		wnd.title_text and wnd.title_text or "unk");
end

local dump_menu = {
{
	name = "video",
	label = "Video",
	kind = "value",
	description = "Debug Snapshot of the video subsystem state",
	hint = "(debug/)",
	validator = strict_fname_valid,
	handler = function(ctx, val)
		zap_resource("debug/" .. val);
		system_snapshot("debug/" .. val);
	end
},
{
	name = "global",
	label = "Global",
	kind = "value",
	description = "Dump the global table recursively (slow)",
	hint = "(debug/)",
	validator = strict_fname_valid,
	handler = function(ctx, val)
	end
},
{
	name = "active_display",
	label = "Active Display",
	description = "Dump the active display window table",
	hint = "(debug/)",
	kind = "value",
	validator = strict_fname_valid,
	handler = function(ctx, val)
		print(DataDumper(val, _G));
	end
},
};

local counter = 0;
return {
	{
		name = "dump",
		label = "Dump",
		kind = "action",
		submenu = true,
		handler = dump_menu
	},
	-- for testing fallback application handover
	{
		name = "broken",
		label = "Broken Call (Crash)",
		kind = "action",
		handler = function() does_not_exist(); end
	},
	{
		name = "testwnd",
		label = "Color window",
		kind = "action",
		handler = function()
			counter = counter + 1;
			spawn_debug_wnd(
				fill_surface(math.random(200, 600), math.random(200, 600),
					math.random(64, 255), math.random(64, 255), math.random(64, 255)),
				"color_window_" .. tostring(counter)
			);
		end
	},
	{
		name = "worldid_wnd",
		label = "WORLDID window",
		kind = "action",
		handler = function()
			local wm = active_display();
			local newid = null_surface(wm.width, wm.height);
			if (valid_vid(newid)) then
				image_sharestorage(WORLDID, newid);
				spawn_debug_wnd(newid, "worldid");
			end
		end
	},
	{
		name = "display_wnd",
		label = "display_window",
		kind = "action",
		submenu = true,
		handler = gen_displaywnd_menu
	},
	{
		name = "animation_cycle",
		label = "Animation Cycle",
		kind = "action",
		description = "Add an animated square that moves up and down the display",
		handler = function()
			if not DEBUG_ANIMATION then
				DEBUG_ANIMATION = {};
			end
			local vid = color_surface(64, 64, 0, 255, 0);
			if (not valid_vid(vid)) then
				return;
			end
			show_image(vid);
			order_image(vid, 65530);
			move_image(vid, 0, active_display().height - 64, 200);
			move_image(vid, 0, 0, 200);
			image_transform_cycle(vid, true);
			table.insert(DEBUG_ANIMATION, vid);
		end
	},
	{
		name = "stop_animation",
		label = "Stop Animation",
		eval = function() return DEBUG_ANIMATION and #DEBUG_ANIMATION > 0 or false; end,
		handler = function()
			for _,v in ipairs(DEBUG_ANIMATION) do
				if (valid_vid(v)) then
					delete_image(v);
				end
			end
			DEBUG_ANIMATION = nil;
		end
	},
	{
		name = "alert",
		label = "Random Alert",
		kind = "action",
		handler = function()
			timer_add_idle("random_alert" .. tostring(math.random(1000)),
				math.random(1000), false, function()
				local tiler = active_display();
				tiler.windows[math.random(#tiler.windows)]:alert();
			end);
		end
	},
	{
		name = "stall",
		label = "Frameserver Debugstall",
		kind = "value",
		eval = function() return frameserver_debugstall ~= nil; end,
		validator = gen_valid_num(0, 100),
		handler = function(ctx,val) frameserver_debugstall(tonumber(val)*10); end
	},
	{
		name = "dump_tree",
		label = "Dump Space-Tree",
		kind = "action",
		eval = function() return active_display().spaces[
			active_display().space_ind] ~= nil; end,
		handler = function(ctx)
			local space = active_display().spaces[active_display().space_ind];
			local fun;
			print("<space>");
			fun = function(node, level)
				print(string.format("%s<node id='%s' horiz=%f vert=%f>",
					string.rep("\t", level), gettitle(node),
					node.weight, node.vweight));
				for k,v in ipairs(node.children) do
					fun(v, level+1);
				end
				print(string.rep("\t", level) .. "</node>");
			end
			fun(space, 0);
			print("</space>");
		end
	},
	{
		name = "cursor_vid",
		label = "Print Cursor",
		kind = "action",
		description = "Dump the tracetag of vid beneath cursor as warning",
		handler = function(ctx)
			local mx, my = mouse_xy();
			local list = pick_items(mx, my, 10, true, active_display(true));

			print(#list, "items at: ", mx, my);
			for i, v in ipairs(list) do
				print(string.format("%s%s", string.rep("-", i), image_tracetag(v)))
			end
		end
	},
	{
		name = "dump_alloc",
		label = "Dump Allocations",
		kind = "action",
		description = "Toggle vid tracing allocation as messages on stdout",
		handler = function(ctx)
			toggle_alloc();
		end
	}
};
