local pretty = require "cc.pretty"
local pp = {}
function pp.ren(n) return pretty.render(pretty.pretty(n)) end
function pp.round(n, pre) pre = pre or 1 return math.floor(n/pre+0.5)*pre end
function pp.mVec(M) return vector.new(M[1][1], M[1][2], M[1][3]) end
-- function pp.vColumn(v) return matrix end
function pp.tVec(T) return vector.new(T.x, T.y, T.z) end
function pp.tQuat(T) return quaternion.new(pp.tVec(T.v), T.a) end
function pp.fromPolar(r, theta, y) return vector.new( r * math.cos(theta), y or 0, -r * math.sin(theta) ) end
function pp.clamp(n, min, max) return math.max(min, math.min(n, max)) end
function pp.bound(n, bound, center) center = center or 0 return math.max(-bound + center, math.min(n, bound + center)) end
function pp.invLerp(n, min, max) return (n-min)/(max-min) end
function pp.invLerpClamped(n, min, max) return pp.clamp( pp.invLerp( n, min, max ), 0, 1 ) end
function pp.vMat(v1,v2,v3)
    return  matrix.fromVector( v1 , false )
        :vstack(matrix.fromVector( v2 , false ))
        :vstack(matrix.fromVector( v3 , false ))
end
function pp.has_value(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end
function pp.pitchMatrix(pitch)

    local zhatP = vector.new(0, math.sin(pitch), math.cos(pitch))
    local xhatP = vector.new( 0 , 1 , 0 ):cross( zhatP ):normalize()
    local yhatP = zhatP:cross( xhatP ):normalize()

    return pp.vMat( xhatP, yhatP, zhatP ), xhatP, yhatP, zhatP

end
function pp.yawMatrix(yaw)

    local xhatY   = vector.new(math.cos(yaw), 0, math.sin(yaw))
    local zhatY   = xhatY:cross( vector.new( 0 , 1 , 0 ) ):normalize()
    local yhatY   = zhatY:cross( xhatY ):normalize()

    return pp.vMat( xhatY, yhatY, zhatY ), xhatY, yhatY, zhatY

end

function pp.daemon(func, ...)
    local args = {...}    
    return function()
        while true do func(table.unpack(args)) end
    end
end

function pp.ppprint(...)
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
            v = pp.ren(v)
        end
        msg = msg..v.." "
    end
    return msg
end

function pp.print(...) print(pp.ppprint(...)) end

function pp.rpm(radpersec)
    -- return 360/(2*math.pi) * 1/60 * radpersec
    return ( (2*math.pi)/60 * 1/1 )^(-1) * radpersec
end

function pp.t() return os.epoch("utc")/1000 end

-- =======================================================================================================
-- patnet
-- =======================================================================================================

pp.net = {}

peripheral.find("modem", rednet.open)

pp.net.STATUS          = "OFFLINE"
pp.net.PROTOCOL        = "gd_patmesh"
pp.net.COMPID          = os.getComputerID()
pp.net.networkState    = {} -- allem data indexed by computer id
pp.net.myData          = {} -- what networkState[COMPID] would be
-- pp.net.FLAGS           = {} -- any other racial slurs the computer wishes to share


if rednet.isOpen() then 
    pp.print("network established here on comp #"..pp.net.COMPID)
    pp.net.STATUS = "ONLINE"
else
    pp.print("comp #"..pp.net.COMPID.." is blind to the network without a modem.")
end

-- :::: net foundation :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

function pp.net.postToNetwork(header, data)
    local packet    = {
        protocol    = pp.net.PROTOCOL,
        sender      = pp.net.COMPID,
        header      = header or "UPDATE",
        status      = pp.net.STATUS,
        timeSent    = pp.t(),
        payload     = data or pp.net.myData
        -- flags = pp.net.FLAGS
    }

    -- if header and (header == "UPDATE") then 
    --     pp.net.networkState[packet.sender] = packet.payload 
    -- end
    pp.net.getNetwork(packet.sender, packet)
    -- pp.print("broadcasting")
    rednet.broadcast(packet, pp.net.PROTOCOL)
end

-- pp.print({asdf, "gar"})

function pp.net.getNetwork(idfake, packetfake)

    local id, packet = 0, 0

    if idfake and packetfake then
        id, packet = idfake, packetfake
    else
        id, packet = rednet.receive(pp.net.PROTOCOL, 0.05)
    end

    if not (packet and type(packet) == "table") then return end

    if packet.header == "IMNEWHERE" then

        pp.print("comp #"..packet.sender.." has joined the network.")
        pp.net.postToNetwork()
        return
        
    elseif packet.header == "UPDATE" then

        pp.net.networkState[packet.sender] = packet.payload
        return

    elseif packet.header == "GLOBAL" then

        -- pp.print("GLOBALLL" )
        pp.net[packet.globalKey] = packet.payload
        return

    end

end 

-- :::: patnet api     :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

function pp.net.getNode(compid)
    return pp.net.networkState[compid]
end

function pp.net.updateKey(k, v)
    pp.net.myData[k] = v
    pp.net.postToNetwork()
end

function pp.net.updateGlobalKey(k, v)
    -- pp.print("GLOBALING")
    local packet = {
        protocol    = pp.net.PROTOCOL,
        sender      = pp.net.COMPID,
        header      = "GLOBAL",
        status      = pp.net.STATUS,
        timeSent    = pp.t(),
        payload     = v,
        globalKey   = k
        -- flags = pp.net.FLAGS
    }
    pp.net.getNetwork(packet.sender, packet)

    rednet.broadcast(packet, pp.net.PROTOCOL)
end

-- :::: sublevel stuff :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-- function findOrigin() -- returns id of origin
--     local origins = {}
--     local origin = 0
--     local networkState = pp.net.networkState
--     for id, data in pairs(pp.net.networkState) do
--         print(#pp.net.networkState)
--         if not data         then goto skiporigincheck end
--         -- pp.print("NO DATA")
--         if not data.NAME    then goto skiporigincheck end
--         -- pp.print("NO NAME")
--         if string.find( data.NAME , "gd_0" ) then
--             table.insert(#origins+1, id)
--         end
--         ::skiporigincheck::
--     end
--     if #origins > 1 then -- looks for the lightest origin to filter out imposterororzzz,,,,,

--         local masses = {}
--         local lessermass = math.huge
--         local lessermassid = 0
--         for k, id in pairs(origins) do
--             if not networkState[id].sl then 
--                 table.remove(origins, k) 
--             else
--                 table.insert(masses, id, networkState[id].sl.mass)
--             end
--         end
--         for id, mass in pairs(masses) do
--             if mass < lessermass then
--                 lessermassid = id
--                 lessermass = mass
--             end
--         end
--         origin = lessermass

--     elseif (#origins < 1) and pp.originKnown then
--         pp.print("origin not found")
--         pp.originKnown = false
--         return
--     else
--         origin = origins[1]
--     end
--     pp.originKnown = true
--     return origin
-- end


function pp.net.formatSublevelData()

    local dat = pp.net.myData
    
    dat.sl          = {}
    dat.sl.lp       = dat.sublevel.getLogicalPose
    dat.sl.posTrue  = pp.tVec(dat.sublevel.getLogicalPose.position)
    dat.sl.quatTrue = dat.sublevel.getLogicalPose.orientation
    dat.sl.mass     = dat.sublevel.getMass

    dat.sl.pitchTrue, 
    dat.sl.yawTrue, 
    dat.sl.rollTrue = dat.sl.quatTrue:toEuler()

    if dat.origin then
        
        -- pp.print("PPNETORIGIN!!!! ")
        -- pp.net.origin = dat
        pp.net.updateGlobalKey("origin", dat)
        -- pp.print(pp.net.origin)

        dat.sl.localPos     = vector.new()
        dat.sl.localQuat    = quaternion.new()
        -- pp.print(dat.sl.localQuat)

    elseif pp.net.origin then

        local ori = pp.net.origin

        -- pp.print("orisl: ",ori.sl.pos)
        dat.sl.pos     = dat.sl.pos - pp.tVec(ori.sl.pos)
        dat.sl.quat    = dat.sl.quat:conjugate() * pp.tQuat(ori.sl.quat)
        dat.sl.pitch,
        dat.sl.yaw,
        dat.sl.roll    = dat.sl.quat:toEuler()

    end
    
end 

function pp.net.updateSublevel()

    local t1 = os.epoch("utc")

    if sublevel then
        pp.net.myData.sublevel = {}
        
        local i = 0
        local sld = {}
        for k, v in pairs(sublevel) do
            if k ~= "setName" then
                i = i + 1
                sld[i] = function() pp.net.myData.sublevel[k] = v() end
            end
        end
        
        parallel.waitForAll(table.unpack(sld))
        pp.net.formatSublevelData()
    end

    -- local originID = findOrigin()
    -- if originID then

    --     pp.net.origin = originID

    -- end
    
    pp.net.postToNetwork()

end

-- =======================================================================================================
-- ive got lotion on my dick rn
-- =======================================================================================================

pp.net.postToNetwork("IMNEWHERE")

return pp