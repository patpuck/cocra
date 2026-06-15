local pretty = require "cc.pretty"
local lib = {}
function lib.ren(n) return pretty.render(pretty.pretty(n)) end
function lib.round(n, pre) pre = pre or 1 return math.floor(n/pre+0.5)*pre end
function lib.mVec(M) return vector.new(M[1][1], M[1][2], M[1][3]) end
-- function lib.vColumn(v) return matrix end
function lib.fromPolar(r, theta, y) return vector.new( r * math.cos(theta), y or 0, -r * math.sin(theta) ) end
function lib.clamp(n, min, max) return math.max(min, math.min(n, max)) end
function lib.invLerp(n, min, max) return (n-min)/(max-min) end
function lib.invLerpClamped(n, min, max) return lib.clamp( lib.invLerp( n, min, max ), 0, 1 ) end
function lib.vMat(v1,v2,v3)
    return  matrix.fromVector( v1 , false )
        :vstack(matrix.fromVector( v2 , false ))
        :vstack(matrix.fromVector( v3 , false ))
end
function lib.has_value(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end
function lib.pitchMatrix(pitch)

    local zhatP = vector.new(0, math.sin(pitch), math.cos(pitch))
    local xhatP = vector.new( 0 , 1 , 0 ):cross( zhatP ):normalize()
    local yhatP = zhatP:cross( xhatP ):normalize()

    return lib.vMat( xhatP, yhatP, zhatP ), xhatP, yhatP, zhatP

end
function lib.yawMatrix(yaw)

    local xhatY   = vector.new(math.cos(yaw), 0, math.sin(yaw))
    local zhatY   = xhatY:cross( vector.new( 0 , 1 , 0 ) ):normalize()
    local yhatY   = zhatY:cross( xhatY ):normalize()

    return lib.vMat( xhatY, yhatY, zhatY ), xhatY, yhatY, zhatY

end

function lib.daemon(func, ...)
    local args = {...}    
    return function()
        while true do func(table.unpack(args)) end
    end
end

function lib.ppprint(...)
    local maxlen = 8
    local tstr = textutils.formatTime(os.time("local"))
    local msgs = {...}
    local msg = "["..string.rep("0", maxlen-#tstr)..tstr.."]: "
    for k, v in pairs(msgs) do
        if v == nil then
            v = "nil"
        elseif v ~= v then
            v = "NaN"
        elseif type(v) == "string" then
            v = v
        else
            v = lib.ren(v)
        end
        msg = msg..v.." "
    end
    return msg
end

function lib.print(...) print(lib.ppprint(...)) end

return lib