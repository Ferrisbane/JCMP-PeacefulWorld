class "PeacefulPlayer"
function PeacefulPlayer:__init(player, Peaceful)
    self.Peaceful = Peaceful
    self.player = player
    self.start_pos = player:GetPosition()
    self.start_world = player:GetWorld()
    self.inventory = player:GetInventory()
end

function PeacefulPlayer:Enter()
    self.player:SetWorld(self.Peaceful.world)
    self.player:ClearInventory()
    Network:Send(self.player, "PeacefulEnter")
    Network:Send(self.player, "PeacefulWorldID", self.Peaceful.world:GetId())
end

function PeacefulPlayer:Leave()
    self.player:SetWorld(self.start_world)

    self.player:ClearInventory()
    for k,v in pairs(self.inventory) do
        self.player:GiveWeapon(k, v)
    end

    Network:Send(self.player, "PeacefulExit")
end

class "Peaceful"
function table.find(l, f)
  for _, v in ipairs(l) do
    if v == f then
      return _
    end
  end
  return nil
end

function Peaceful:__init()
    self.world = World.Create()
    self.world:SetTimeStep(0)
    self.world:SetTime(10)
    self.spawns = {}
    self.teleports = {}
    self.hotspots = {}
    self.vehicles = {}
    self.players = {}
    self.last_broadcast = 0
	
	SQL:Execute("CREATE TABLE IF NOT EXISTS PeacefulWorld (ID INTEGER UNIQUE)")
	local cmd = SQL:Command("INSERT OR REPLACE INTO PeacefulWorld (ID) values (?)")
    cmd:Bind(1, self.world:GetId())
    cmd:Execute()
    
    Events:Subscribe("PlayerChat", self, self.ChatMessage)
    Events:Subscribe("ModuleUnload", self, self.ModuleUnload)
    Events:Subscribe("PlayerJoin", self, self.PlayerJoined)
    Events:Subscribe("PlayerQuit", self, self.PlayerQuit)
    Events:Subscribe("PlayerSpawn", self, self.PlayerSpawn)
    Events:Subscribe("JoinGamemode", self, self.JoinGamemode)

    self:LoadSpawns("spawns.txt")
end

function Peaceful:LoadSpawns(filename)
    print("Peaceful opening "..filename)
    local file = io.open(filename,"r")

    if file == nil then
        print( "No spawns.txt, aborting loading of spawns" )
        return
    end

    local timer = Timer()
    for line in file:lines() do
        if line:sub(1,1) == "V" then
            self:ParseVehicleSpawn(line)
        elseif line:sub(1,1) == "P" then
			return
        elseif line:sub(1,1) == "T" then
            self:ParseTeleport(line)
        end
    end
    
    for k, v in pairs(self.teleports) do
        table.insert(self.hotspots,{k,v})
    end

    print(string.format("Loaded spawns, %.02f seconds", timer:GetSeconds()))

    file:close()
end

function Peaceful:ParseVehicleSpawn(line)
    line = line:gsub("VehicleSpawn%(","")
    line = line:gsub("%)","")
    line = line:gsub(" ","")
	local tokens = line:split(",")   

    local model_id_str = tokens[1]

    local pos_str = {tokens[2],tokens[3],tokens[4]}
    local ang_str = {tokens[5],tokens[6],tokens[7],tokens[8]}

    local args = {}

    args.model_id = tonumber(model_id_str)
    args.position = Vector3(tonumber(pos_str[1]), tonumber(pos_str[2]), tonumber(pos_str[3]))
    args.angle = Angle(tonumber(ang_str[1]), tonumber(ang_str[2]), tonumber(ang_str[3]), tonumber(ang_str[4]))
	
    if #tokens > 8 then
        if tokens[9] ~= "NULL" then
            args.template = tokens[9]
        end

        if #tokens > 9 then
            if tokens[10] ~= "NULL" then
                args.decal = tokens[10]
            end
        end
    end

    args.enabled = true
    local v = Vehicle.Create(args)
	v:SetWorld(self.world)
    self.vehicles[v:GetId()] = v
end

function Peaceful:ParseTeleport(line)
    line = line:sub(3)
    line = line:gsub(" ", "")

    local tokens = line:split(",")
    local pos_str = {tokens[2], tokens[3], tokens[4]}
    local vector = Vector3(tonumber(pos_str[1]), tonumber(pos_str[2]), tonumber(pos_str[3]))

    self.teleports[tokens[1]] = vector
end

function Peaceful:ModuleUnload()
    for k,v in pairs(self.vehicles) do
        v:Remove()
    end
    self.vehicles = {}

    for k,v in pairs(self.players) do
        v:Leave()
        self:MessagePlayer(v.player, "Peaceful script unloaded. You have been restored to the main world.")
    end
    self.players = {}
	SQL:Execute("DROP TABLE PeacefulWorld")
end

function Peaceful:IsInPeaceful(player)
    return self.players[player:GetId()] ~= nil
end

function Peaceful:MessagePlayer(player, message)
    player:SendChatMessage("[Peaceful] "..message, Color(0xfff0b010))
end

function Peaceful:MessageGlobal(message)
    Chat:Broadcast("[Peaceful] "..message, Color(0xfff0c5b0))
end

function Peaceful:EnterPeaceful(player)
    if player:GetWorld() ~= DefaultWorld then
        self:MessagePlayer(player, "You must exit all other game modes before joining.")
        return
    end

    local args = {}
    args.name = "Peaceful"
    args.player = player
    Events:Fire("JoinGamemode", args)
	
    local p = PeacefulPlayer(player, self)
    p:Enter()
    
    self:MessagePlayer(player, "You have entered the peaceful world! Type /peaceful to leave.") 
    self.players[player:GetId()] = p
	
end

function Peaceful:LeavePeaceful(player)
    local p = self.players[player:GetId()]
    if p == nil then return end

    p:Leave()
    
    self:MessagePlayer(player, "You have left the peaceful world! Type /peaceful to enter at any time.")    
    self.players[player:GetId()] = nil
end

function Peaceful:ChatMessage(args)
    local msg = args.text
    local player = args.player
    
    if (msg:sub(1, 1) ~= "/") then
        return true
    end    
    
    local cmdargs = {}
    for word in string.gmatch(msg, "[^%s]+") do
        table.insert(cmdargs, word)
    end
    
    if (cmdargs[1] == "/peaceful") then
        if (self:IsInPeaceful(player)) then
            self:LeavePeaceful(player, false)
        else        
            self:EnterPeaceful(player)
        end
	elseif (cmdargs[1]=="/tp") then
		if (self:IsInPeaceful(player)) then
			local dest = cmdargs[2]

			if dest == "" or dest == nil or dest == "help" then
				args.player:SendChatMessage("Teleport locations: ", Color(0,255,0))

				local i = 0
				local str = ""

				for k,v in pairs(self.teleports) do
					i=i+1
					str=str..k

					if i%4 ~= 0 then
						str=str..", "
					else
						args.player:SendChatMessage("    "..str, Color(255,255,255))
						str=""
					end
				end
			elseif self.teleports[dest] ~= nil then
				if args.player:GetWorld():GetId() ~= self.world:GetId() then
					args.player:SendChatMessage("You are not in the peaceful world, yet you are?! Exit any gamemodes and try again.", Color(255,0,0))
					return
				end
				args.player:SetPosition(self:RandomizePosition(self.teleports[dest]))
			else
				args.player:SendChatMessage("Invalid teleport destination!"..tostring(dest), Color(255,0,0))
			end
		end
	end
    return false
end

function Peaceful:RandomizePosition(pos, magnitude, offset)
    if magnitude == nil then
        magnitude = 10
    end

    if offset == nil then
        offset = 250
    end

    return pos + Vector3(math.random(-magnitude, magnitude), math.random(-magnitude, 0)+offset, math.random(-magnitude, magnitude))
end

function Peaceful:PlayerJoined(args)
    self.players[args.player:GetId()] = nil
end

function Peaceful:PlayerQuit(args)
    self.players[args.player:GetId()] = nil
end

function Peaceful:PlayerSpawn(args)
    if (not self:IsInPeaceful(args.player)) then
        return true
    end
    
    self:MessagePlayer(args.player, "You have spawned in the peaceful world. Type /peaceful if you wish to leave.")
    args.player:ClearInventory()
    
    return false
end

function Peaceful:JoinGamemode(args)
    if args.name ~= "Peaceful" then
        self:LeavePeaceful(args.player)
    end
end

DisableDamage = function(args)
	if (args.player:GetWorld():GetId() == self.world:GetId()) then
		return false
	end
end

Events:Subscribe("VehicleCollide", DisableDamage)
Events:Subscribe("LocalPlayerForcePulseHit", DisableDamage)
Events:Subscribe("LocalPlayerExplosionHit", DisableDamage)
Events:Subscribe("LocalPlayerBulletHit", DisableDamage)

Peaceful = Peaceful()