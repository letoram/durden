-- icon loading, caching and resolution management
--
-- eventually this should be generalizable to a uiprim/ script
-- as manual icon handling, covering all the bases for different
-- displays, optimizing for caching, atlas-slicing etc. is quite
-- hairy.
--
-- For now, we just do the minimal placeholder stuff needed to
-- refactor the icon/font label parts of durden, then see what
-- happens from there. The support sheet used for picking/binding
-- should also be moved from the icons widget to here.
--
-- In that direction, there are three classes of icons - labels
-- textual and client defined. The first one need to be loaded
-- and kept.
--
-- The second needs rasterization against the target display.
--
-- The third needs caching.
--

-- it is almost always useful having a circle primitive to
-- build with, both for generating single colored round icons
-- or to use as a mask together with resample_image
local unit_circle = build_shader(
	nil,
	[[
		uniform float radius;
		uniform vec3 color;
		varying vec2 texco;

		void main()
		{
			float vis = length(texco * 2.0 - vec2(1.0)) - radius;
			float step = fwidth(vis);
			vis = smoothstep(step, -step, vis);
			gl_FragColor = vec4(color.rgb, vis);
		}
	]],
	"iconmgr_circle"
);
shader_uniform(unit_circle, "radius", "f", 0.5);
local function synthesize_icon(w, shader)
	local icon = alloc_surface(w, w);
	if not valid_vid(icon) then
		return;
	end
	resample_image(icon, shader, w, w);
	return icon;
end

-- The nametable mainly contains the active caches of vids based
-- on a base width. Normally icons are square, though it is not
-- a given.
--
-- For icons where we don't need to scale but can use a function
-- to generate the icon in question, the generate function is
-- provided.
local nametable = {
	destroy = {
		generate =
		function(w)
			shader_uniform(unit_circle, "color", "fff", 1.0, 0.1, 0.15);
			return synthesize_icon(w, unit_circle);
		end,
		widths = {}
	},
	minimize = {
		generate =
		function(w)
			shader_uniform(unit_circle, "color", "fff", 0.95, 0.7, 0.01);
			return synthesize_icon(w, unit_circle);
		end,
		widths = {}
	},
	maximize = {
		function(w)
			shader_uniform(unit_circle, "color", "fff", 0.1, 0.6, 0.1);
			return synthesize_icon(w, unit_circle);
		end,
		widths = {}
	},
	placeholder = {
		function(w)
			shader_uniform(unit_circle, "color", "fff", 1.0, 1.0, 1.0);
			return synthesize_icon(w, unit_circle);
		end,
		widths = {}
	}
};

-- take a vsym that passed validation from suppl_valid_vsym and
-- return a vid that can be used for an image_sharestorage into
-- a caller controlled allocation, as well as a possible shader
-- identifier. An open question is if we should allow SDFs. The
-- problem comes with shader used for highlights etc.
function icon_lookup(vsym, px_w)
	if not nametable[vsym] then
		vsym = "placeholder";
	end
	local ent = nametable[vsym];

-- do we have a direct match?
	if ent.widths[px_w] then
		return ent.widths[px_w];
	end

-- can we build one with it?
	if ent.generate then
		local res = ent.generate(px_w);
		if valid_vid(res) then
			ent.widths[px_w] = res;
			return res;
		end
	end

-- find one with the least error
	local errv = px_w;
	local vid = WORLDID;
	for i,v in pairs(ent.widths) do
		local dist = math.abs(px_w - i);
		if dist < errv then
			errv = dist;
			vid = v;
		end
	end

	return vid;
end

-- use a unicode symbol reference (or nametable override)
-- to get an iconic or rastered representation matching the
-- intended display. The display is needed as the rendertarget
-- attachment for the datastore, as that covers the density.
local last_u8;
function icon_lookup_u8(u8, display_rt)
	if valid_vid(last_u8) then
		delete_image(last_u8);
	end

	local rt = set_context_attachment(display_rt);
	last_u8 = render_text({"\\f,0", u8});
	set_context_attachment(rt);
	return last_u8;
end

function icon_known(vsym)
	return vsym ~= nil and #vsym > 0 and nametable[vsym] ~= nil;
end
