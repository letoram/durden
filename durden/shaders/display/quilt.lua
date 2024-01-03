-- from GH/LoneTech/LookingGlass/lightfield.md

return {
	version = 1,
	label = "Quilt",
	filter = "none",
	uniforms = {
		pitch = {
			label = "Pitch",
			utype = "f",
			low = 0,
			high = 180,
			default = {52.59063022315584}
		},
		slope = {
			label = "Slope",
			utype = "f",
			low = -45,
			high = 45,
			default = {-7.224844213324757},
		},
		center = {
			label = "Center",
			utype = "f",
			low = 0,
			high = 10,
			default = {
				0.176902174949646
--			0.4664787566771096 this was the value found in visual.json, but
--			gives a .. weird effect
			}
		},
		width = {
			label = "Width",
			utype = "f",
			default = {1536},
			low = 640,
			high = 8192
		},
		height = {
			label = "Height",
			utype = "f",
			default = {2048},
			low = 640,
			high = 8192
		},
		dpi = {
			label = "DPI",
			utype = "f",
			default = {324},
			low = 96,
			high = 600
		},
		tiles = {
			label = "Tiles",
			utype = "ff",
			default = {5, 9},
			low = {1},
			high = {20}
		}
	},
	frag =
[[
uniform sampler2D map_tu0;
uniform vec2 tiles;
uniform float width;
uniform float height;
uniform float pitch;
uniform float slope;
uniform float center;
uniform float dpi;

varying vec2 texco;

vec2 map(vec2 pos, float a) {
  vec2 tile = vec2(tiles.x-1.0, 0.0);
	vec2 dir = vec2(-1.0,1.0);

  a = fract(a) * tiles.y;
  tile.y += dir.y * floor(a);
  a = fract(a) * tiles.x;
  tile.x += dir.x * floor(a);
  return (tile + pos) / tiles;
}

void main()
{
	float tilt = -height / (width*slope);
	float pitch_adjusted = pitch * width / dpi * cos(atan(1.0, slope));
	float subp = 1.0 / (3.0*width) * pitch_adjusted;

  vec4 res;
  float a;
  a = (texco.s + texco.t * tilt) * pitch_adjusted - center;
  res.r = texture2D(map_tu0, map(texco, a)).x;
  res.g = texture2D(map_tu0, map(texco, a + subp)).y;
  res.b = texture2D(map_tu0, map(texco, a + 2.0 * subp)).z;
  res.a = 1.0;

	gl_FragColor = res;
}
]]
};
