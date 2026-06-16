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

-- =======================================================================================================
-- patnet
-- =======================================================================================================

lib.net = {}

peripheral.find("modem", rednet.open)

lib.net.STATUS          = "OFFLINE"
lib.net.PROTOCOL        = "gd_patmesh"
lib.net.COMPID          = os.getComputerID()
lib.net.networkState    = {} -- allem data indexed by computer id
lib.net.myData          = {} -- what networkState[COMPID] would be


if rednet.isOpen() then 
    lib.print("network established here on comp #"..lib.net.COMPID)
    STATUS = "ONLINE"
else
    lib.print("comp #"..lib.net.COMPID.." is blind to the network without a modem.")
end

-- :::: net foundation :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

function lib.net.postToNetwork(header)
    local packet = {
        protocol = lib.net.PROTOCOL,
        sender = lib.net.COMPID,
        header = header or "UPDATE",
        status = lib.net.STATUS,
        timeSent = os.epoch("utc"),
        payload = lib.net.myData
    }
    rednet.broadcast(packet, lib.net.PROTOCOL)
end

-- pp.print({asdf, "gar"})

function lib.net.getNetwork()
    local id, packet = rednet.receive(lib.net.PROTOCOL, 0.05)
    if not (packet and type(packet) == "table") then return end
    if packet.header == "IMNEWHERE" then
        pp.print("comp #"..packet.sender.." has joined the network.")
    end
    if packet.header == "UPDATE" then
        lib.net.networkState[packet.sender] = packet.payload
    -- elseif packet.header == ""
    end
end 

-- :::: patnet api     :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

function lib.net.getNode(compid)
    return lib.net.networkState[compid]
end

function lib.net.updateKey(k, v)
    lib.net.myData[k] = v
    lib.net.postToNetwork()
end

-- :::: sublevel stuff :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

function lib.net.formatSublevelData()

    local dat = lib.net.myData
    dat.sl       = {}
    dat.sl.lp    = dat.sublevel.getLogicalPose
    dat.sl.pos   = dat.sublevel.getLogicalPose.position
    dat.sl.quat  = dat.sublevel.getLogicalPose.orientation
    dat.sl.pitch, 
    dat.sl.yaw, 
    dat.sl.roll  = dat.sublevel.getLogicalPose.orientation:toEuler()
    
end 

function lib.net.updateSublevel()

    local t1 = os.epoch("utc")

    if sublevel then
        lib.net.myData.sublevel = {}
        
        local i = 0
        local sld = {}
        for k, v in pairs(sublevel) do
            if k ~= "setName" then
                i = i + 1
                sld[i] = function() lib.net.myData.sublevel[k] = v() end
            end
        end
        
        parallel.waitForAll(table.unpack(sld))
        lib.net.formatSublevelData()
    end

end

-- =======================================================================================================
-- ive got lotion on my dick rn
-- =======================================================================================================

pp.net.postToNetwork("IMNEWHERE")

return lib