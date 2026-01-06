--!strict
-- ConfigManager.lua
-- Gerencia estado global e de jogadores com alta p segurança.

local ConfigManager = {}
ConfigManager.__index = ConfigManager

-- Dependências do seu ecossistema
local _log: any = nil
local _guard: any = nil
local _events: any = nil

-- Estado Interno
local globalConfig: { [string]: any } = {}
local playerConfigs: { [number]: { [string]: any } } = {}

-- Inicialização
function ConfigManager.Init(logger: any, guard: any, eventManager: any)
	_log = logger
	_guard = guard
	_events = eventManager
end

function ConfigManager.new()
	return setmetatable({}, ConfigManager)
end

-- [[ CONFIGURAÇÕES GLOBAIS ]] --

function ConfigManager:SetGlobal(key: string, value: any)
	if _guard and not _guard:Is(key, "string", true) then return end
	
	local oldValue = globalConfig[key]
	if oldValue == value then return end -- Otimização: não dispara evento se o valor for igual
	
	globalConfig[key] = value
	
	if _events then
		_events:Fire("GlobalConfigChanged", key, value, oldValue)
	end
end

function ConfigManager:GetGlobal(key: string): any
	return globalConfig[key]
end

-- [[ CONFIGURAÇÕES DE PLAYER ]] --

function ConfigManager:SetPlayer(player: Player, key: string, value: any)
	if not _guard or not _guard:IsInstance(player, "Player", true) then return end
	
	local userId = player.UserId
	if not playerConfigs[userId] then
		playerConfigs[userId] = {}
	end
	
	local oldValue = playerConfigs[userId][key]
	if oldValue == value then return end
	
	playerConfigs[userId][key] = value
	
	if _events then
		-- Dispara um evento específico para aquele player
		_events:Fire("PlayerConfigChanged_" .. userId, key, value, oldValue)
		-- Dispara um evento genérico (útil para sistemas de log/analytics)
		_events:Fire("PlayerConfigChanged", player, key, value, oldValue)
	end
end

function ConfigManager:GetPlayer(player: Player, key: string): any
	local config = playerConfigs[player.UserId]
	return config and config[key] or nil
end

-- @desc Remove dados do player para evitar Memory Leak
function ConfigManager:ClearPlayer(player: Player)
	playerConfigs[player.UserId] = nil
	if _log then
		_log:SendMessage("ConfigManager", "Dados limpos para o player: " .. player.Name, "Print")
	end
end

return ConfigManager
