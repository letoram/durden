--
-- Declarations
--
local NumTemplates, NumPoints, Origin, Diagonal, HalfDiagonal, AngleRange, AnglePrecision
local Point, Rectangle, Template, Result, GestureRecognizer, resample, indicativeangle, rotateby, scaleto, translateto, vectorize, optimalcosinedistance, distanceatbestangle, distanceatangle, centroid, boundingbox, pathdistance, pathlength, distance, deg2rad, rad2deg
local sqrt, atan2, cos, sin, atan, acos, abs, min, pi, Infinity = math.sqrt,math.atan2, math.cos, math.sin, math.atan, math.acos, math.abs, math.min, math.pi, math.huge

--
-- Point class
--
Point = function(x, y) -- constructor
    local self = {}
    self[1]     = x
    self[2]     = y
    return self
end

--
-- Rectangle class
--
Rectangle = function(x, y, width, height) -- constructor
    local self  = Point(x, y)
    self.width  = width
    self.height = height
    return self
end

--
-- Template class: a unistroke template
--
Template = function(name, points, oriented, uniform) -- constructor
    local self    = {}
    self.name     = name
    self.points   = resample(points, NumPoints)
    if not oriented then
        local radians = indicativeangle(self.points)
        self.points   = rotateby(self.points, -radians)
    end
    self.points   = scaleto(self.points, 1, uniform)
    self.points   = translateto(self.points, Origin)
    self.vector   = vectorize(self.points) -- for Protractor
    return self
end

--
-- deg/rad helpers
--
deg2rad = function(d) return (d * pi / 180.0) end
rad2deg = function(r) return (r * 180.0 / pi) end

--
-- GestureRecognizer class constants
--
NumPoints      = 64
Origin         = Point(0, 0)
HalfDiagonal   = 0.5 * sqrt(1 + 1) -- of a unit square
AngleRange     = deg2rad(45.0)
AnglePrecision = deg2rad(2.0)
Phi            = 0.5 * (-1.0 + sqrt(5.0)) -- Golden Ratio

--
-- GestureRecognizer class
--
GestureRecognizer = function(oriented, uniform, protractor) -- constructor
    local self     = {}
    self.templates = {}
    -- 'oriented' option makes gestures rotation-sensitive

    -- this makes it possible to distinguish similar gestures in different orientations
    if oriented == false then self.oriented = false else self.oriented = true end
    -- 'uniform' option makes gestures uniformly scaled, this enables 1D gestures
    if uniform == false then self.uniform = false else self.uniform = true end
    -- 'protractor' option selects faster algorithm, an improvement over original iterative solution
    if protractor == false then self.protractor = false else self.protractor = true end

    -- The $1 Gesture Recognizer API

    self.recognize = function(points)
        local points  = resample(points, NumPoints)
        if #points ~= NumPoints then
            return nil, 0
        end
        if not self.oriented then
            local radians = indicativeangle(points)
            points        = rotateby(points, -radians)
        end
        points        = scaleto(points, 1, self.uniform)
        points        = translateto(points, Origin)
        local vector  = vectorize(points) -- for Protractor

        local closestDistance = Infinity
        local closestIndex = 1
        for i = 1, #self.templates, 1 do -- for each unistroke template
            local d = nil
            if self.protractor then -- for Protractor
                d = optimalcosinedistance(self.templates[i].vector, vector, self.oriented)
                d = (d == d) and d or 0 -- NaN check
            else -- Golden Section Search (original $1)
                d = distanceatbestangle(points, self.templates[i], -AngleRange, AngleRange, AnglePrecision)
            end
            if d < closestDistance then
                closestDistance = d -- best (least) distance
                closestIndex = i -- unistroke template
            end
        end
        local name = self.templates[closestIndex] and self.templates[closestIndex].name or nil
        local score = self.protractor and 1.0 / closestDistance or 1.0 - closestDistance / HalfDiagonal
        return name, score, closestIndex
    end


    self.add = function(name, points)
        table.insert(self.templates, Template(name, points, self.oriented, self.uniform))
        local num = 0
        for i, template in ipairs(self.templates) do
            num = num + (template.name == name and 1 or 0)
        end
        return num
    end


    self.remove = function(name)
        local num = 0
        for i = #self.templates, 1, -1 do
            if self.templates[i].name == name then
                table.remove(self.templates, i)
                num = num + 1
            end
        end
        return num
    end


    self.serialize = function(name)
        local lines = {}
        for i, template in ipairs(self.templates) do
            if not name or name == template.name then
                local points = {}
                for i, point in ipairs(template.points) do
									table.insert(points,
										string.format('%d %d',
											math.ceil(point[1] * 100),
											math.ceil(point[2] * 100)
										)
									)
--                    table.insert(points, string.format('{%.2f, %.2f}', point[1], point[2]))
                end
--                local line = string.format("gestures.add('%s', {%s})", template.name, table.concat(points, ', '))
							line = table.concat(points, " ")
							print("number", #points)
							lines["gesture_" .. tostring(i)] = string.format("%s\t%s", name, line)
            end
        end
			return lines
    end

    self.resample = resample

    return self
end
--

-- Private helper functions from this point down
--

resample = function(points, n)
    assert(type(points) == 'table', "points must be flat or nested table of coordinates")
    if type(points[1]) == 'number' then -- convert flat table of coordinates into list of {x, y} pairs
        local flatpoints = points
        assert(#flatpoints % 2 == 0, "Flat points list requires even number of x,y coordinates")
        points = {}
        for i = 1,  math.floor(#flatpoints / 2), 1 do
            points[i] = {flatpoints[i * 2 - 1], flatpoints[i * 2]}
        end
    end
    local I = pathlength(points) / (n - 1) -- interval length
    local D = 0.0
    local newpoints = {points[1]}
    local i = 2
    local prevpoint = points[i - 1]
    local thispoint = points[i]
    while i <= #points do
        local d = distance(prevpoint, thispoint)
        if (D + d) >= I then
            local p1, p2 = prevpoint, thispoint
            local qx = prevpoint[1] + ((I - D) / d) * (thispoint[1] - prevpoint[1])
            local qy = prevpoint[2] + ((I - D) / d) * (thispoint[2] - prevpoint[2])
            local q  = Point(qx, qy)
            newpoints[#newpoints+1] = q -- append new point 'q'
            prevpoint = q -- next iteration use interpolated as previous point
            D = 0.0
        else
            D = D + d
            i = i + 1
            prevpoint = points[i - 1]
            thispoint = points[i]
        end
    end
    -- somtimes we fall a rounding-error short of adding the last point, so add it if so
    if #newpoints == n - 1 then
        newpoints[#newpoints+1] = Point(points[#points][1], points[#points][2])
    end
    return newpoints
end


indicativeangle = function(points)
    local c = centroid(points)
    return atan2(c[2] - points[1][2], c[1] - points[1][1])
end


rotateby = function(points, radians) -- rotates points around centroid
    local c   = centroid(points)
    local cos = cos(radians)
    local sin = sin(radians)

    local newpoints = {}
    for i = 1, #points, 1 do
        local qx = (points[i][1] - c[1]) * cos - (points[i][2] - c[2]) * sin + c[1]
        local qy = (points[i][1] - c[1]) * sin + (points[i][2] - c[2]) * cos + c[2]
        newpoints[#newpoints+1] = Point(qx, qy)
    end
    return newpoints
end


scaleto = function(points, size, uniform) -- non-uniform scale assumes 2D gestures (i.e., no lines)
    local bbox      = boundingbox(points)
    local newpoints = {}
    for i = 1, #points, 1 do
        local qx, qy
        if uniform then
            local scale = math.max(bbox.width, bbox.height)
            qx = points[i][1] * (size / scale)
            qy = points[i][2] * (size / scale)
        else
            qx = points[i][1] * (size / bbox.width)
            qy = points[i][2] * (size / bbox.height)
        end
        newpoints[#newpoints+1] = Point(qx, qy)
    end
    return newpoints
end


translateto = function(points, pt) -- translates points' centroid
    local c         = centroid(points)
    local newpoints = {}
    for i = 1, #points, 1 do
        local qx = points[i][1] + pt[1] - c[1]
        local qy = points[i][2] + pt[2] - c[2]
        newpoints[#newpoints+1] = Point(qx, qy)
    end
    return newpoints
end


vectorize = function(points) -- for Protractor
    local sum    = 0.0
    local vector = {}
    for i = 1, #points, 1 do
        vector[#vector+1] = points[i][1]
        vector[#vector+1] = points[i][2]
        sum = sum + points[i][1] * points[i][1] + points[i][2] * points[i][2]
    end
    local magnitude = sqrt(sum)
    for i = 1, #vector, 1 do
        vector[i] = vector[i] / magnitude
    end
    return vector
end


optimalcosinedistance = function(v1, v2, oriented) -- for Protractor
    local a = 0.0
    local b = 0.0
    for i = 1, #v1, 2 do
        a = a + v1[i] * v2[i] + v1[i + 1] * v2[i + 1]
        b = b + v1[i] * v2[i + 1] - v1[i + 1] * v2[i]
    end
    local angle = atan(b / a)
    local d = acos(a * cos(angle) + b * sin(angle))
    if oriented and abs(angle) > AngleRange then
        d = d + 1
    end
    return d
end


distanceatbestangle = function(points, T, a, b, threshold)
    local x1 = Phi * a + (1.0 - Phi) * b
    local f1 = distanceatangle(points, T, x1)
    local x2 = (1.0 - Phi) * a + Phi * b
    local f2 = distanceatangle(points, T, x2)
    while abs(b - a) > threshold do
        if (f1 < f2) then
            b  = x2
            x2 = x1
            f2 = f1
            x1 = Phi * a + (1.0 - Phi) * b
            f1 = distanceatangle(points, T, x1)
        else
            a  = x1
            x1 = x2
            f1 = f2
            x2 = (1.0 - Phi) * a + Phi * b
            f2 = distanceatangle(points, T, x2)
        end
    end
    return min(f1, f2)
end


distanceatangle = function(points, T, radians)
    local newpoints = rotateby(points, radians)
    return pathdistance(newpoints, T.points)
end


centroid = function(points)
    local x, y = 0.0, 0.0
    for i = 1, #points, 1 do
        x = x + points[i][1]
        y = y + points[i][2]
    end
    x = x / #points
    y = y / #points
    return Point(x, y)
end


boundingbox = function(points)
    local minX, maxX, minY, maxY = Infinity, -Infinity, Infinity, -Infinity
    for i = 1, #points, 1 do
        if points[i][1] < minX then
            minX = points[i][1]
        end
        if points[i][1] > maxX then
            maxX = points[i][1]
        end
        if points[i][2] < minY then
            minY = points[i][2]
        end
        if points[i][2] > maxY then
            maxY = points[i][2]
        end
    end
    return Rectangle(minX, minY, maxX - minX, maxY - minY)
end


pathdistance = function(pts1, pts2)
    local d = 0.0
    for i = 1, #pts1, 1 do -- assumes pts1.length == pts2.length
        d = d + distance(pts1[i], pts2[i])
    end
    return d / #pts1
end


pathlength = function(points)
    local d = 0.0
    for i = 2, #points, 1 do
        d = d + distance(points[i - 1], points[i])
    end
    return d
end


distance = function(p1, p2)
    local dx = p2[1] - p1[1]
    local dy = p2[2] - p1[2]
    return sqrt(dx * dx + dy * dy)
end

return GestureRecognizer
