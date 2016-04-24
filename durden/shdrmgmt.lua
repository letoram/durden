-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Shader compilation and setup.

if (SHADER_LANGUAGE == "GLSL120") then
local old_build = build_shader;
function build_shader(vertex, fragment, label)
	vertex = vetex and ("#define VERTEX\n" .. vertex) or nil;
	fragment = fragment and ([[
		#ifdef GL_ES
			#ifdef GL_FRAGMENT_PRECISION_HIGH
				precision highp float;
			#else
				precision mediump float;
			#endif
		#else
			#define lowp
			#define mediump
			#define highp
		#endif
	]] .. fragment) or nil;

	return old_build(vertex, fragment, label);
end
end

local shdrtbl = {
	effect = {},
	ui = {},
	display = {},
	audio = {},
	simple = {}
};

local groups = {"effect", "ui", "display", "audio", "simple"};

function shdrmgmt_scan()
 	for a,b in ipairs(groups) do
 		local path = string.format("shaders/%s/", b);

		for i,j in ipairs(glob_resource(path .. "*.lua", APPL_RESOURCE)) do
			local res = system_load(path .. j, false);
			if (res) then
				res = res();
				if (not res or type(res) ~= "table" or res.version ~= 1) then
					warning("shader " .. j .. " failed validation");
				else
					local key = string.sub(j, 1, string.find(j, '.', 1, true)-1);
					shdrtbl[b][key] = res;
				end
		else
				warning("error parsing " .. path .. j);
 			end
		end
	end
end

shdrmgmt_scan();

local function set_uniform(dstid, name, typestr, vals, source)
	local len = string.len(typestr);
	if (type(vals) == "table" and len ~= #vals) or
		(type(vals) ~= "table" and len > 1) then
		warning("set_uniform called from broken source: " .. source);
 		return false;
	end
	if (type(vals) == "table") then
		shader_uniform(dstid, name, typestr, unpack(vals));
 	else
		shader_uniform(dstid, name, typestr, vals);
	end
	return true;
end

local function setup_shader(shader, name, group)
	if (shader.shid) then
		return true;
	end

	local dvf = (shader.vert and
		type(shader.vert == "table") and shader.vert[SHADER_LANGUAGE])
		and shader.vert[SHADER_LANGUAGE] or shader.vert;

	local dff = (shader.frag and
		type(shader.frag == "table") and shader.frag[SHADER_LANGUAGE])
		and shader.frag[SHADER_LANGUAGE] or shader.frag;

	shader.shid = build_shader(dvf, dff, group.."_"..name);
	if (not shader.shid) then
		warning("building shader failed for " .. group.."_"..name);
	return false;
	end
-- this is not very robust, bad written shaders will yield fatal()
	for k,v in pairs(shader.uniforms) do
		set_uniform(shader.shid, k, v.utype, v.default, name .. "-" .. k);
	end
	return true;
end

-- for display, state is actually the display name
local function dsetup(shader, dst, group, name, state)
	if (not setup_shader(shader, dst, name)) then
		return;
	end

	if (not shader.states) then
		shader.states = {};
	end

	if (not shader.states[state]) then
		shader.states[state] = shader_ugroup(shader.shid);
	end
	image_shader(dst, shader.states[state]);
end

local function ssetup(shader, dst, group, name, state)
	if (not shader.shid) then
		setup_shader(shader, name, group);

-- states inherit shaders, define different uniform values
		if (shader.states) then
			for k,v in pairs(shader.states) do
				shader.states[k].shid = shader_ugroup(shader.shid);

				for i,j in pairs(v.uniforms) do
					set_uniform(v.shid, i, shader.uniforms[i].utype, j,
						string.format("%s-%s-%s", name, k, i));
				end
			end
		end
	end
-- now the shader exists, apply
	local shid = ((state and shader.states and shader.states[state]) and
		shader.states[state].shid) or shader.shid;
	image_shader(dst, shid);
end

-- all the boiler plate needed to figure out the types a uniform has,
-- generate the corresponding menu entry and with validators for type
-- and range, taking locale and separators into accoutn.
local bdelim = (tonumber("1,01") == nil) and "." or ",";
local rdelim = (bdelim == ".") and "," or ".";

-- note: boolean and 4x4 matrices are currently ignored
local utype_lut = {
i = 1, f = 1, ff = 1, fff = 1, ffff = 1
};

local function unpack_typestr(typestr, val, lowv, highv)
	string.gsub(val, rdelim, bdelim);
	local rtbl = string.split(val, ' ');
	for i=1,#rtbl do
		rtbl[i] = tonumber(rtbl[i]);
		if (not rtbl[i]) then
			return;
		end
		if (lowv and rtbl[i] < lowv) then
			return;
		end
		if (highv and rtbl[i] > highv) then
			return;
		end
	end
	return rtbl;
end

local function gen_typestr_valid(utype, lowv, highv, defaultv)
	return function(val)
		local tbl = unpack_typestr(utype, val, lowv, highv);
		return tbl ~= nil and #tbl == string.len(utype);
	end
end

local function add_stateref(res, uniforms, shid)
	for k,v in pairs(uniforms) do
		if (not v.ignore) then
			table.insert(res, {
			name = k,
			label = v.label,
			kind = "value",
			hint = (type(v.default) == "table" and
				table.concat(v.default, " ")) or tostring(v.default),
			eval = function()
				return utype_lut[v.utype] ~= nil;
			end,
			validator = gen_typestr_valid(v.utype, v.low, v.high, v.default),
			handler = function(ctx, val)
				shader_uniform(shid, k, v.utype, unpack(
					unpack_typestr(v.utype, val, v.low, v.high)));
			end
		});
		end
	end
end

local function smenu(shdr, grp, name)
	if (not shdr.uniforms) then
		return;
	end

	local found = false;
	for k,v in pairs(shdr.uniforms) do
		if (not v.ignore) then
			found = true;
			break;
		end
	end
	if (not found) then
		return;
	end

	local res = {
	};

	if (shdr.states) then
		for k,v in pairs(shdr.states) do
			if (v.shid) then
				table.insert(res, {
					name = "state_" .. k,
					label = k,
					kind = "action",
					submenu = true,
					handler = function()
						local res = {};
						add_stateref(res, shdr.uniforms, v.shid);
						return res;
					end
				});
			end
		end
	else
		add_stateref(res, shdr.uniforms, shdr.shid);
	end

	return res;
end

local function dmenu(shdr, grp, name, state)
	local res = {};
	if (not shdr.uniforms) then
		return res;
	end

	if (not shdr.states[state]) then
		warning("display shader does not have matching display");
		return res;
	end

	local found = false;
	for k,v in pairs(shdr.uniforms) do
		if (not v.ignore) then
			found = true;
			break;
		end
	end

	if (not found) then
		return res;
	end

	add_stateref(res, shdr.uniforms, shdr.states[state]);
	return res;
end

local fmtgroups = {
	ui = {ssetup, smenu},
	effect = {
		function() warning("effect incomplete"); end,
		function() return {}; end,
	},
	display = {dsetup, dmenu},
	audio = {ssetup, smenu},
	simple = {ssetup, smenu}
};

function shader_setup(dst, group, name, state)
	if (not fmtgroups[group]) then
		group = group and group or "no group";
		warning("shader_setup called with unknown group " .. group);
		return dst;
	end

	if (not shdrtbl[group] or not shdrtbl[group][name]) then
		warning(string.format(
			"shader_setup called with unknown group(%s) or name (%s) ",
			group and group or "nil",
			name and name or "nil"
		));
		return dst;
	end

	return fmtgroups[group][1](shdrtbl[group][name], dst, group, name, state);
end

function shader_uform_menu(name, group, state)
	if (not fmtgroups[group]) then
		warning("shader_setup called with unknown group " .. group);
		return {};
	end

	if (not shdrtbl[group] or not shdrtbl[group][name]) then
		warning(string.format(
			"shader_setup called with unknown group(%s) or name (%s) ",
			group and group or "nil",
			name and name or "nil"
		));
		return {};
	end

	return fmtgroups[group][2](shdrtbl[group][name], group, name, state);
end

-- update shader [sname] in group [domain] for the uniform [uname],
-- targetting either the global [states == nil] or each individual
-- instanced ugroup in [states].
function shader_update_uniform(sname, domain, uname, args, states)
	assert(shdrtbl[domain]);
	assert(shdrtbl[domain][sname]);
	local shdr = shdrtbl[domain][sname];
	if (not states) then
		states = {"default"};
	end

	for k,v in ipairs(states) do
		local dstid, dstuni;
-- special handling, allow default group to be updated alongside substates
		if (v == "default") then
			dstid = shdr.shid;
			dstuni = shdr.uniforms;
		else
			if (shdr.states[v]) then
				dstid = shdr.states[v].shid;
				dstuni = shdr.states[v].uniforms;
			end
		end
-- update the current "default" if this is set, in order to implement
-- uniform persistance across restarts
		if (dstid) then
			if (set_uniform(dstid, uname, shdr.uniforms[uname].utype,
				args, "update_uniform-" .. sname .. "-"..uname) and dstuni[uname]) then
				dstuni[uname].default = args;
			end
		end
	end
end

function shader_getkey(name, domain)
	if (not domain) then
		domain = groups;
	end

	if (type(domain) ~= "table") then
		domain = {domain};
	end

-- the end- slide of Lua, why u no continue ..
	for i,j in ipairs(domain) do
		if (shdrtbl[j]) then
			for k,v in pairs(shdrtbl[j]) do
				if (v.label == name) then
					return k, j;
				end
			end
		end
	end
end

function shader_key(label, domain)
	for k,v in ipairs(shdrtbl[domain]) do
		if (v.label == label) then
			return k;
 		end
 	end
end

function shader_list(domain)
	local res = {};

	if (type(domain) ~= "table") then
		domain = {domain};
	end

	for i,j in ipairs(domain) do
		if (shdrtbl[j]) then
			for k,v in pairs(shdrtbl[j]) do
				table.insert(res, v.label);
			end
		end
	end
	return res;
end
