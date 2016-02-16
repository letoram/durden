-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Shader compilation and setup.

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

local shdrtbl = {
	effect = {},
	ui = {},
	audio = {},
	simple = {}
};

function shdrmgmt_scan()
	local groups = {"effect", "ui", "audio", "simple"};
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

function shader_setup(dst, group, name, state)
	if (not shdrtbl[group] or not shdrtbl[group][name]) then
		return warning(string.format(
			"shader_setup called with unknown group(%s) or name (%s) ",
			group and group or "nil",
			name and name or "nil"
		));
	end

	local shader = shdrtbl[group][name];
-- the different groups have different setup approaches
	local outid = 0;
	if (group == "ui" or group == "simple" or group == "audio") then
-- build the main shader, set uniform and then derive substates with
-- uniform overrides
		if (not shader.shid) then
			shader.shid = build_shader(shader.vert, shader.frag, group.."_"..name);
			if (not shader.shid) then
			warning("building shader failed for " .. group.."_"..name);
				return;
			end
-- this is not very robust, bad written shaders will yield fatal()
			for k,v in pairs(shader.uniforms) do
				set_uniform(shader.shid, k, v.utype, v.default, name .. "-" .. k);
			end
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

-- missing, building effect, audio, display, simple and applying
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
	if (not shdrtbl[domain]) then
		return;
	end

	for k,v in pairs(shdrtbl[domain]) do
		if (v.label == name) then
			return k;
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
	if (not shdrtbl[domain]) then
		warning("shader_list requested uknown domain");
		return;
	end

	for k,v in ipairs(shdrtbl[domain]) do
		table.insert(res, v.label);
	end
end
