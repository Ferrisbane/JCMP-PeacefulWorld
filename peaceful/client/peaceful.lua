class 'Peaceful'

function Peaceful:__init()
    Events:Subscribe("ModuleLoad", self, self.ModulesLoad)
    Events:Subscribe("ModulesLoad", self, self.ModulesLoad)
    Events:Subscribe("ModuleUnload", self, self.ModuleUnload)
	Events:Subscribe("LocalPlayerInput", self, self.DisableGuns)
	
	Network:Subscribe("PeacefulEnter", self, self.Enter)
	Network:Subscribe("PeacefulExit", self, self.Exit)	
	Network:Subscribe("PeacefulWorldID", self, self.PeacefulWorldFunction)
end

function Peaceful:Enter()
	Game:FireEvent("ply.invulnerable")
end

function Peaceful:Exit()
	Game:FireEvent("ply.vulnerable")
end

function Peaceful:ModulesLoad()
    Events:Fire("HelpAddItem",
        {name = "Peaceful",
         text = "The Peaceful world is a place for non-combat gameplay. Very useful for roadtrips.\n \n"..
                "To enter the Peaceful world, type /peaceful in chat and hit enter. "..
                "You will be transported to the Peaceful world, where you will respawn "..
                "until you exit by using the command once more.\n \n"})
end

function Peaceful:ModuleUnload()
    Events:Fire("HelpRemoveItem",{name = "Peaceful"})
end

function Peaceful:DisableGuns(args)
	if (LocalPlayer:GetWorld():GetId()==PeacefulWorldID) then
		if args.input == Action.FireRight then
			return false
		elseif args.input == Action.FireLeft then
			return false
		elseif args.input == Action.VehicleFireLeft then
			return false
		elseif args.input == Action.VehicleFireRight then
			return false
		elseif args.input == Action.FireVehicleWeapon then
			return false
		end
	end
end

function Peaceful:PeacefulWorldFunction(ID)
	PeacefulWorldID = ID
	print("Peaceful world ID received using ID: "..tostring(PeacefulWorldID))
end

Peaceful = Peaceful()