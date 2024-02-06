-- this one is really only useful for autolayouter that can set the added state value

local res =
{
	version = 1,
	label = "Sidecolor",
	filter = "none",
	hidden = true,
	uniforms = {
		col = {
			label = "Color",
			utype = "fff",
			default = {1.0, 1.0, 1.0},
			description = "Base color to multiply against"
		}
	},
	frag =
[[
uniform sampler2D map_tu0;
uniform float obj_opacity;
uniform vec3 col;
varying vec2 texco;

void main()
{
	vec3 tx = texture2D(map_tu0, texco).rgb;

	float cv = 0.2126 * tx.r + 0.7152 * tx.g + 0.0722 * tx.b;

	gl_FragColor = vec4(cv * col.r, cv * col.g, cv * col.b, obj_opacity);
}]],
	states = {
		nisse = {uniforms = { col = {1.0, 0.0, 0.0} } }
	}
};

-- add each hc entry number as a 'state', then when the shader is set on the
-- target the assigned uniform set id would resolve to a matching shader_ugroup
local f = 1.0 / 255.0;
for i,v in ipairs(HC_PALETTE) do
	local r, g, b = suppl_hexstr_to_rgb(v);
	res.states[tostring(i)] = { uniforms = { col = {r * f, g * f, b * f} } };
end

return res;
