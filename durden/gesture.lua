--
-- Simple gesture analyzer/classifier
-- group/accumulate points over time
-- filter/merge group
-- vectorize by translating each group around its center,
-- adding their components (track the sum to normalize) and
--
--
-- training:
--  classifier = gesture_setup("example");
--  classifier:train("test")
--  repeatedly classifier:input(id, dx, dy, timestamp)
--  classifier:finish();
--
-- use:
--  classifier = gesture_setup("example");
--
-- repeatedly:
--   classifier:input("example");
--   classifier:candidates() => {} 0..n entries
--   classifier:finish(ignore_collision) => true/false
--
-- inspection/visualization:
--   classifier:vector_set() { {id,x,y,magn} }
--

local function ocd(inp, gest)
	local acc1 = 0;
	local acc2 = 0;
	for i=1,#gest,2 do
		local i1 = inp[i];
		local i2 = inp[i+1];
		local g1 = inp[i];
		local g2 = inp[i+1];
		ac1 = acc1 + g1*i1 + g2*i2;
		ac2 = acc2 + g1*i2 - g2*i1;
	end
	local cac = math.atan2(ac2, ac1);
	return math.acos(ac1*math.cos(cac) + b*math.sin(cac));
end

local function vectorize(list)
	-- get centroid
	-- translate
	-- normalize
end

local function classify(ctx)
end

local function train(ctx)
end

local function voidinput(ctx)
end

function gesture_setup(key)
-- 1. sweep database and load list of vectors and
	return {
		input = voidinput,
		select = select,
		classify = classify,
		finish = finish,
		train = train,
		vector_set
	};
end
