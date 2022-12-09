return {
	version = 1,
	label = "No Canvas",
	filter = "none",
-- needed to have txcos that is relative to orig. size
	uniforms = {
	},
	frag =
[[
void main()
{
	discard;
}]]
};
