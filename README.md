JustCause 2 MP - Peaceful World
==================



Hello, this is a script I created to allow players to enter into a "peaceful" world.

The peaceful world is a world away from the main world that players can't shoot guns, vehicle weapons or run players over.

All players in peaceful cannot die at all (even if their car/plane blows up).

This is very useful for players that do not wish to PvP and be trolled while for example role playing or doing a roadtrip.

Because many scripts like buy menus and boost are limited to the DefaultWorld changes to the scripts need to be made. This is simple by adding this code when all the script on the server loads (on ModulesLoad event):
Code: [Select]
local qry = SQL:Query("SELECT count(*) FROM sqlite_master WHERE type='table' AND name='PeacefulWorld';" )
    result = qry:Execute()
 if result[1]['count(*)'] == '1' then
  local qry2 = SQL:Query("SELECT ID FROM PeacefulWorld")
  PeacefulWorld = qry2:Execute()
  PeacefulWorldID = PeacefulWorld[1].ID
 else
  PeacefulWorldID = 0
 end

The script now has the Peaceful world ID that can be used to tell if a player is in the peaceful world.
Such as:
Code: [Select]
if player:GetWorld():GetId() ~= tonumber(PeacefulWorldID) then
    return
end

Other scripts will not break (with the above code) if the peaceful script is unloaded and the world is no longer running. Or if the script has been removed.

If other scripters wish to include the above code in their script to allow them to be used in peaceful world feel free, and I'll include your script in a list that is supported with PeacefulWorld.

For players to enter peaceful all they need to do is to type in chat /peaceful, and they will toggle in/out of peaceful world.