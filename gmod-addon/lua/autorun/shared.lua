AddCSLuaFile()
resource.AddFile("materials/mute-icon.png")

FILEPATH = "ttt_discord_bot.dat"
TRIES = 3

muted = {}

ids = {}
ids_raw = file.Read(FILEPATH, "DATA")

if (CLIENT) then
	local drawMute = false
	local muteIcon = Material("materials/mute-icon.png")

	net.Receive("drawMute", function()
		drawMute = net.ReadBool()
	end)

	hook.Add("HUDPaint", "ttt_discord_bot_HUDPaint", function()
		if (!drawMute) then return end
		
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(muteIcon)
		surface.DrawTexturedRect(0, 0, 128, 128)
	end)

	return
end

util.AddNetworkString("drawMute")

CreateConVar("discordbot_host", "localhost", FCVAR_ARCHIVE, "Sets the node server address.")
CreateConVar("discordbot_port", "37405", FCVAR_ARCHIVE, "Sets the node server port.")
CreateConVar("discordbot_name", "TTT Discord Bot", FCVAR_ARCHIVE, "Sets the Plugin Prefix for helpermessages.")

if(ids_raw) then
	ids = util.JSONToTable(ids_raw)
end

function saveIDs()
	file.Write(FILEPATH, util.TableToJSON(ids))
end


function GET(req,params,cb,tries)
	httpAdress = ("http://"..GetConVar("discordbot_host"):GetString()..":"..GetConVar("discordbot_port"):GetString())
	print(httpAdress);
	
	http.Fetch(httpAdress, function(res)
		cb(util.JSONToTable(res))
	end, function(err)
		print("["..GetConVar("discordbot_name"):GetString().."] ".."¿Está prendido?")
		print("Err: ".. err)
		if (!tries) then tries = TRIES end
		if (tries != 0) then GET(req, params, cb, tries-1) end
		
	end, {req=req,params=util.TableToJSON(params)});
	
end

function sendClientIconInfo(ply,mute)
	net.Start("drawMute")
	net.WriteBool(mute)
	net.Send(ply)
end


function isMuted(ply)
	return muted[ply]
end

function mute(ply)
	if (ids[ply:SteamID()]) then
		if (!isMuted(ply)) then
			GET("mute",{mute=true,id=ids[ply:SteamID()]},function(res)
				if (res) then
					if (res.success) then
						ply:PrintMessage(HUD_PRINTCENTER,"["..GetConVar("discordbot_name"):GetString().."] ".."Estás muteado en discord")
						sendClientIconInfo(ply,true)
						muted[ply] = true
					end
					if (res.error) then
						print("["..GetConVar("discordbot_name"):GetString().."] ".."Error: "..res.err)
					end
				end

			end)
		end
	end
end

function unmute(ply)
	if (ply) then
		if (ids[ply:SteamID()]) then
			if (isMuted(ply)) then
				GET("mute",{mute=false,id=ids[ply:SteamID()]},function(res)
					if (res.success) then
						if (ply) then
							ply:PrintMessage(HUD_PRINTCENTER,"["..GetConVar("discordbot_name"):GetString().."] ".."Ya no estás muteado!")
						end
						sendClientIconInfo(ply,false)
						muted[ply] = false
					end
					if (res.error) then
						print("["..GetConVar("discordbot_name"):GetString().."] ".."Error: "..res.err)
					end
				end)
			end
		end
	else
		for ply, val in pairs(muted) do
			if val then unmute(ply) end
		end
	end
end

function commonRoundState()
  if gmod.GetGamemode().Name == "Trouble in Terrorist Town" or
     gmod.GetGamemode().Name == "TTT2 (Advanced Update)" then
    -- Round state 3 => Game is running
    return ((GetRoundState() == 3) and 1 or 0)
  end

  if gmod.GetGamemode().Name == "Murder" then
    -- Round state 1 => Game is running
    return ((gmod.GetGamemode():GetRound() == 1) and 1 or 0)
  end

  -- Round state could not be determined
  return -1
end

hook.Add("PlayerSay", "ttt_discord_bot_PlayerSay", function(ply,msg)
	if (string.sub(msg,1,9) != '!discord ') then return end
	tag = string.sub(msg, 10)

	print(tag);
	
	GET("connect",{tag=tag},function(res)
		if (res.answer == 0) then ply:PrintMessage(HUD_PRINTTALK,"["..GetConVar("discordbot_name"):GetString().."] ".."No se encontró a nadie en el server con el nombre '"..tag.."'") end
		if (res.answer == 1) then ply:PrintMessage(HUD_PRINTTALK,"["..GetConVar("discordbot_name"):GetString().."] ".."Found more than one user with a discord tag like '"..tag.."'. Please specify!") end
		if (res.tag && res.id) then
			ply:PrintMessage(HUD_PRINTTALK,"["..GetConVar("discordbot_name"):GetString().."] ".."Usuario de Discord '"..res.tag.."' enlazado.")
			ids[ply:SteamID()] = res.id
			saveIDs()
		end
	end)
	return ""
end)

hook.Add("PlayerInitialSpawn", "ttt_discord_bot_PlayerInitialSpawn", function(ply)
	if (ids[ply:SteamID()]) then
		ply:PrintMessage(HUD_PRINTTALK,"["..GetConVar("discordbot_name"):GetString().."] ".."Conectado con discord.")
	else
		ply:PrintMessage(HUD_PRINTTALK,"["..GetConVar("discordbot_name"):GetString().."] ".."No estás conectado a Discord. Escribí '!discord DISCORDTAG' en el chat. Ej. '!discord Esteban#5549'")
	end
end)

hook.Add("PlayerSpawn", "ttt_discord_bot_PlayerSpawn", function(ply)
	unmute(ply)
end)

hook.Add("PlayerDisconnected", "ttt_discord_bot_PlayerDisconnected", function(ply)
	unmute(ply)
end)

hook.Add("ShutDown","ttt_discord_bot_ShutDown", function()
	unmute()
end)

hook.Add("TTTEndRound", "ttt_discord_bot_TTTEndRound", function()
	timer.Simple(0.1, function() unmute() end)
end)

hook.Add("TTTBeginRound", "ttt_discord_bot_TTTBeginRound", function()--in case of round-restart via command
	unmute()
end)

hook.Add("OnEndRound", "ttt_discord_bot_OnEndRound", function()
    timer.Simple(0.1,function() unmute() end)
end)

hook.Add("OnStartRound", "ttt_discord_bot_OnStartRound", function()
	unmute()
end)

hook.Add("PostPlayerDeath", "ttt_discord_bot_PostPlayerDeath", function(ply)
	if (commonRoundState() == 1) then
		mute(ply)
	end
end)