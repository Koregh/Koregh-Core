--!strict
-- ConfigManager.lua
-- Gerencia o estado (Live State) e fornece ganchos para persistência externa.

local ConfigManager = {}
ConfigManager.__index = ConfigManager

local _log: any = nil
local _guard: any = nil
local _events: any = nil

local globalConfig: { [string]: any } = {}
local playerConfigs: { [number]: { [string]: any } } = {}

function ConfigManager.Init(logger: any, guard: any, eventManager: any)
	_log = logger
	_guard = guard
	_events = eventManager
end

function ConfigManager.new()
	return setmetatable({}, ConfigManager)
end

-- [[ INTEGRAÇÃO COM DATASTORE EXTERNO ]] --

-- O seu script de DataStore chamará isso ao carregar os dados
function ConfigManager:ImportPlayerData(player: Player, data: {[string]: any})
	if not _guard:IsInstance(player, "Player") then return end
	playerConfigs[player.UserId] = data
	if _log then _log:SendMessage("Config", "Dados importados para " .. player.Name, "Print") end
end

-- O seu script de DataStore chamará isso para saber o que salvar
function ConfigManager:ExportPlayerData(player: Player): {[string]: any}?
	return playerConfigs[player.UserId]
end

-- [[ MÉTODOS DE ESTADO ]] --

function ConfigManager:SetPlayer(player: Player, key: string, value: any)
	if not _guard:IsInstance(player, "Player", true) then return end
	
	local userId = player.UserId
	playerConfigs[userId] = playerConfigs[userId] or {}
	
	local oldValue = playerConfigs[userId][key]
	if oldValue == value then return end
	
	playerConfigs[userId][key] = value
	
	if _events then
		_events:Fire("PlayerConfigChanged", player, key, value, oldValue)
		-- Evento específico para sistemas que monitoram apenas UM player (ex: UI)
		_events:Fire(`Update_{userId}`, key, value)
	end
end

-- Função "Sênior" para lidar com tabelas internas (Deep Set)
-- Ex: Config:SetInTable(player, "Inventory", "Sword", 1)
function ConfigManager:SetInTable(player: Player, tableKey: string, subKey: string, value: any)
	local data = self:GetPlayer(player, tableKey)
	if type(data) ~= "table" then data = {} end
	
	data[subKey] = value
	self:SetPlayer(player, tableKey, data)
end

function ConfigManager:GetPlayer(player: Player, key: string): any
	local config = playerConfigs[player.UserId]
	return config and config[key] or nil
end

function ConfigManager:ClearPlayer(player: Player)
	playerConfigs[player.UserId] = nil
end

return ConfigManager

