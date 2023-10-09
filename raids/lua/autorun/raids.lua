AddCSLuaFile()

if SERVER then
    ---------------------------------------------------------
    ------------ Taken from nodegraph addon -----------------
    ---------------------------------------------------------
do
    RAIDS_MAP_NODES = RAIDS_MAP_NODES or {}
    RAIDS_NODES_DISTANCE_MULT = RAIDS_NODES_DISTANCE_MULT or 1
    
    local SIZEOF_INT = 4
    local SIZEOF_SHORT = 2 
    local AINET_VERSION_NUMBER = 37
    local function toUShort(b)
        local i = {string.byte(b,1,SIZEOF_SHORT)}
        return i[1] +i[2] *256
    end
    local function toInt(b)
        local i = {string.byte(b,1,SIZEOF_INT)}
        i = i[1] +i[2] *256 +i[3] *65536 +i[4] *16777216
        if(i > 2147483647) then return i -4294967296 end
        return i
    end
    local function ReadInt(f) return toInt(f:Read(SIZEOF_INT)) end
    local function ReadUShort(f) return toUShort(f:Read(SIZEOF_SHORT)) end

    --Types (.type):
    --1 = ?
    --2 = info_nodes
    --3 = playerspawns
    --4 = wall climbers
    function ParseFile()
        if foundain then
            validMap = false
            return
        end

        f = file.Open("maps/graphs/"..game.GetMap()..".ain","rb","GAME")
        if(!f) then
            validMap = false
            return
        end

        found_ain = true
        local ainet_ver = ReadInt(f)
        local map_ver = ReadInt(f)
        if(ainet_ver != AINET_VERSION_NUMBER) then
            MsgN("Unknown graph file")
            validMap = false
            return
        end

        local numNodes = ReadInt(f)
        if(numNodes < 0) then
            MsgN("Graph file has an unexpected amount of nodes")
            validMap = false
            return
        end

        for i = 1,numNodes do
            local v = Vector(f:ReadFloat(),f:ReadFloat(),f:ReadFloat())
            local yaw = f:ReadFloat()
            local flOffsets = {}
            for i = 1,NUM_HULLS do
                flOffsets[i] = f:ReadFloat() 
            end
            local nodetype = f:ReadByte()
            local nodeinfo = ReadUShort(f)
            local zone = f:ReadShort()

            if nodetype == 4 then
                continue
            end
            
            local node = {
                pos = v,
                yaw = yaw,
                offset = flOffsets,
                type = nodetype,
                info = nodeinfo,
                zone = zone,
                neighbor = {},
                numneighbors = 0,
                link = {},
                numlinks = 0
            }

            table.insert(RAIDS_MAP_NODES,node)
        end
    end

    hook.Add("Initialize", "raids_load_map_nodes", function()
        ParseFile()
        RAIDS_NODES_DISTANCE_MULT = math.Clamp(math.Remap(table.Count(RAIDS_MAP_NODES), 100, 500, 1, 2), 1, 2)
    end)
end
    ---------------------------------------------------------
    ------------ Taken from nodegraph addon -----------------
    ---------------------------------------------------------
    local npcsToSpawn = {}

    local gunners = {
        "npc_combine_s",
        "npc_citizen"
    }

    local zombies = {
        "npc_fastzombie",
        "npc_fastzombie",
        "npc_zombie",
        "npc_zombie",
        "npc_zombie",
        "npc_zombie",
        "npc_zombie",
        "npc_zombie",
        "npc_poisonzombie",
        "npc_poisonzombie",
        "npc_zombie_torso",
    }

    local npc_combine_s_Weapons = {
        "weapon_smg1",
        "weapon_smg1",
        "weapon_ar2",
        "weapon_ar2",
        "weapon_shotgun",
    }

    local npc_citizen_Weapons = {
        "weapon_smg1",
        "weapon_smg1",
        "weapon_ar2",
        "weapon_ar2",
        "weapon_shotgun",
        "weapon_pistol",
    }

    local npc_citizen_models = {
        "models/Humans/Group03/Female_01.mdl",
        "models/Humans/Group03/Female_02.mdl",
        "models/Humans/Group03/Female_03.mdl",
        "models/Humans/Group03/Female_04.mdl",
        "models/Humans/Group03/Female_06.mdl",
        "models/Humans/Group03/Female_07.mdl",
        "models/Humans/Group03/Male_01.mdl",
        "models/Humans/Group03/male_02.mdl",
        "models/Humans/Group03/male_03.mdl",
        "models/Humans/Group03/Male_04.mdl",
        "models/Humans/Group03/Male_05.mdl",
        "models/Humans/Group03/male_06.mdl",
        "models/Humans/Group03/male_07.mdl",
        "models/Humans/Group03/male_08.mdl",
        "models/Humans/Group03/male_09.mdl",
    }

    local function countNearbyEnemies(pos, radius)
        local entsInRadius = ents.FindInSphere( pos, radius )
        local count = 0

        for _, ent in pairs(entsInRadius) do
            if ent:IsNPC() then count = count + 1 end
        end

        return count
    end

    local function setUpEnemy(class, pos, offsetNodePos, ply)
        if class == "npc_zombie" then 
            class = table.Random(zombies) 
        end

        local npc = ents.Create(class)
        npc:SetPos(pos)
        npc:Spawn()

        if class == "npc_combine_s" then
            npc:Give(table.Random(npc_combine_s_Weapons))
            
            if npc:GetKeyValues().NumGrenades > 0 then return end -- non-invasive to other addons that want to do anything with their number of nades. But by default combine get no nades on spawn.
            npc:SetKeyValue( "NumGrenades", math.random(1,2) )
        elseif class == "npc_metropolice" then
            npc:Give(table.Random(npc_metropolice_Weapons))
        elseif class == "npc_citizen" then
            npc:Give(table.Random(npc_citizen_Weapons))
            npc:SetModel(table.Random(npc_citizen_models))

            for _, ply in pairs(player.GetAll()) do
                npc:AddEntityRelationship( ply, D_HT, 99 )
            end
        end
        
        timer.Simple(0.1, function()
            if !IsValid(npc) then return end
            npc:SetLastPosition( offsetNodePos )
            npc:SetSchedule( SCHED_FORCED_GO_RUN )
        end)

        timer.Simple(2, function()
            if !IsValid(npc) then return end
            if !IsValid(ply) then return end
            local direction = (ply:GetPos() - npc:GetPos()):GetNormalized() -- These 4 lines get the npc's to face towards the player
            local angle = direction:Angle() 
            angle.p = 0
            npc:SetAngles(angle)
        end)
    end

    util.AddNetworkString("raids warn player")
    local function report(ply, count, limit)
        ply:ChatPrint("RAIDS: Spawned " .. count .. " NPC's!")
        
        if RAIDS_NODES_DISTANCE_MULT >= 2 then 
            net.Start("raids warn player")
            net.WriteString("This map has a lot of nodes, you may want to increase the limit to get more density!")
            net.Send(ply)
        elseif count < limit then
            net.Start("raids warn player")
            net.WriteString("Map doesn't have enough nodes to reach the set limit of " .. limit .. "!", ply)
            net.Send(ply)
        end
    end

    local function checkIfBoxIsColliding(mins, maxs)
        local sampleVec = Vector()

        for z = mins.z, maxs.z, 8 do 
            for x = mins.x, maxs.x, 8 do             
                for y = mins.y, maxs.y, 8 do
                    sampleVec.x, sampleVec.y, sampleVec.z = x, y, z
                    if !util.IsInWorld(sampleVec) then return true end
                end
            end 
        end

        return false
    end 
    
    local offsetDirections = {
        north = Vector(0,128,4),
        northEast = Vector(96,96,4),
        east = Vector(128,0,4),
        southEast = Vector(96, -96, 4),
        south = Vector(0,-128,4),
        southWest = Vector(-96,-96, 4),
        west = Vector(-128,0,4),
        northWest = Vector(-96, 96, 4),
    }

    local function nodeNearDoor(nodePos)
        local potentialDoors = ents.FindInSphere( nodePos, 64 ) 
        
        for _, ent in pairs(potentialDoors) do
            if ent:GetClass() == "prop_door_rotating" or ent:GetClass() == "func_door" or ent:GetClass() == "func_door_rotating" or ent:GetClass() == "func_lookdoor" then
                return true
            end
        end

        return false
    end

    local function findClearSpaceByNode(nodePos)
        local offsetNodePos = nodePos
        local portentialDirections = table.Copy( offsetDirections )

        -- Try to find a random pos by node, give up after sampling around in a circle
        for i = 1, 8 do 
            local randomMult = math.random(0.25,1)
            
            local randomDirectionFromPotentialDirections = table.Random(portentialDirections) * Vector(randomMult, randomMult, 1)
            table.RemoveByValue( portentialDirections, randomDirectionFromPotentialDirections )

            local potentialSpawn = nodePos + randomDirectionFromPotentialDirections 

            if nodeNearDoor(potentialSpawn) then continue end
            if checkIfBoxIsColliding(potentialSpawn + Vector(-16, -16, 0), potentialSpawn + Vector(16, 16, 80)) then continue end

            offsetNodePos = potentialSpawn
            break
        end
        
        return offsetNodePos
    end

    local function spawnNPCs(class, ply, limit)
        local count = 0

        for k, v in pairs(RAIDS_MAP_NODES) do
            local nodePos = v.pos
            if count > limit - 1 then report(ply, count, limit) return end
            if v.type != 2 then continue end    -- If it isn't a valid node fuck off. 
            if math.random(1,5) == 1 then continue end  -- 80% chance to spawn at a node 
            if nodePos:Distance(ply:GetPos()) <= 512 then continue end -- Don't spawn em too close.
            if nodeNearDoor(nodePos) then continue end -- Check if there are any doors nearby, if so fuck off
            if ply:IsLineOfSightClear( nodePos + Vector(0,0,12)) or ply:IsLineOfSightClear( nodePos + Vector(0,0,48)) or ply:IsLineOfSightClear( nodePos + Vector(0,0,72)) then continue end  -- Make sure player can't see enemies spawn
            if countNearbyEnemies(nodePos, math.random(160,256) * RAIDS_NODES_DISTANCE_MULT) > math.random(1,2) then continue end -- Don't spawn too many enemies in one area
        
            local offsetNodePos = findClearSpaceByNode(nodePos)
            setUpEnemy(class, nodePos, offsetNodePos, ply)

            count = count + 1
        end

        report(ply, count, limit)
    end

    concommand.Add("raids_server_spawn_combine", function(ply, cmd, args, argStr)
        if !ply:IsAdmin() then return end

        print("args: " .. args[1])
        spawnNPCs("npc_combine_s", ply, tonumber(args[1]))
    end) 

    concommand.Add("raids_server_spawn_rebels", function(ply, cmd, args, argStr)
        if !ply:IsAdmin() then return end
        
        spawnNPCs("npc_citizen", ply, tonumber(args[1]))
    end) 

    concommand.Add("raids_server_spawn_zombies", function(ply, cmd, args, argStr)
        if !ply:IsAdmin() then return end
        
        spawnNPCs("npc_zombie", ply, tonumber(args[1]))
    end) 
end

if CLIENT then
    concommand.Add ( "raids_spawn_combine", function(ply, cmd, args, argStr) 
        local maxNPCs = #args > 0 and args[1] or 64
        ply:ConCommand("raids_server_spawn_combine" .. " " .. maxNPCs)
    end)

    concommand.Add ( "raids_spawn_rebels", function(ply, cmd, args, argStr) 
        local maxNPCs = #args > 0 and args[1] or 64
        ply:ConCommand("raids_server_spawn_rebels" .. " " .. maxNPCs)
    end)


    concommand.Add ( "raids_spawn_zombies", function(ply, cmd, args, argStr) 
        local maxNPCs = #args > 0 and args[1] or 64
        ply:ConCommand("raids_server_spawn_zombies" .. " " .. maxNPCs)
    end)

    net.Receive("raids warn player", function()   
        chat.AddText( Color(216,82,29), "RAIDS: " .. net.ReadString())
    end)
end

--[[
⣿⣿⣿⣿⣿⣿⣿⣿⡿⠿⠛⠛⠛⠋⠉⠈⠉⠉⠉⠉⠛⠻⢿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⡿⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠛⢿⣿⣿⣿⣿
⣿⣿⣿⣿⡏⣀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣤⣤⣄⡀⠀⠀⠀⠀⠀⠀⠀⠙⢿⣿⣿
⣿⣿⣿⢏⣴⣿⣷⠀⠀⠀⠀⠀⢾⣿⣿⣿⣿⣿⣿⡆⠀⠀⠀⠀⠀⠀⠀⠈⣿⣿
⣿⣿⣟⣾⣿⡟⠁⠀⠀⠀⠀⠀⢀⣾⣿⣿⣿⣿⣿⣷⢢⠀⠀⠀⠀⠀⠀⠀⢸⣿
⣿⣿⣿⣿⣟⠀⡴⠄⠀⠀⠀⠀⠀⠀⠙⠻⣿⣿⣿⣿⣷⣄⠀⠀⠀⠀⠀⠀⠀⣿
⣿⣿⣿⠟⠻⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠶⢴⣿⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀⣿
⣿⣁⡀⠀⠀⢰⢠⣦⠀⠀⠀⠀⠀⠀⠀⠀⢀⣼⣿⣿⣿⣿⣿⡄⠀⣴⣶⣿⡄⣿
⣿⡋⠀⠀⠀⠎⢸⣿⡆⠀⠀⠀⠀⠀⠀⣴⣿⣿⣿⣿⣿⣿⣿⠗⢘⣿⣟⠛⠿⣼
⣿⣿⠋⢀⡌⢰⣿⡿⢿⡀⠀⠀⠀⠀⠀⠙⠿⣿⣿⣿⣿⣿⡇⠀⢸⣿⣿⣧⢀⣼
⣿⣿⣷⢻⠄⠘⠛⠋⠛⠃⠀⠀⠀⠀⠀⢿⣧⠈⠉⠙⠛⠋⠀⠀⠀⣿⣿⣿⣿⣿
⣿⣿⣧⠀⠈⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠟⠀⠀⠀⠀⢀⢃⠀⠀⢸⣿⣿⣿⣿
⣿⣿⡿⠀⠴⢗⣠⣤⣴⡶⠶⠖⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⡸⠀⣿⣿⣿⣿
⣿⣿⣿⡀⢠⣾⣿⠏⠀⠠⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠛⠉⠀⣿⣿⣿⣿
⣿⣿⣿⣧⠈⢹⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⣿⣿⣿⣿
⣿⣿⣿⣿⡄⠈⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣴⣾⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣧⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣦⣄⣀⣀⣀⣀⠀⠀⠀⠀⠘⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡄⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⠀⠀⠙⣿⣿⡟⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠇⠀⠁⠀⠀⠹⣿⠃⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⡿⠛⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⢐⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⠿⠛⠉⠉⠁⠀⢻⣿⡇⠀⠀⠀⠀⠀⠀⢀⠈⣿⣿⡿⠉⠛⠛⠛⠉⠉
⣿⡿⠋⠁⠀⠀⢀⣀⣠⡴⣸⣿⣇⡄⠀⠀⠀⠀⢀⡿⠄⠙⠛⠀⣀⣠⣤⣤⠄⠀
--]]
