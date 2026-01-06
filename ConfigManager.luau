--!strict
-- ConfigManager.lua
-- Gerencia estado reativo e replica dados permitidos para o cliente automaticamente.

local ConfigManager = {}
ConfigManager.__index = ConfigManager

-- Dependências Internas
local _log: any = nil
local _guard: any = nil
local _events: any = nil
local _network: any = nil -- Injetado via Init

-- [PAINEL DE CONTROLE]
-- Apenas as chaves nesta tabela serão enviadas para o Cliente.
-- Se uma chave não estiver aqui, ela é considerada "Secret/Server-Only".
local REPLICATED_KEYS: { [string]: boolean } = {
	["Gold"] = true,
	["Level"] = true,
	["Experience"] = true,
	["Inventory"] = true,
	["Class"] = true,
}

local globalConfig: { [string]: any } = {}
local playerConfigs: { [number]: { [string]: any } } = {}

-- Inicialização Centralizada
function ConfigManager.Init(logger: any, guard: any, eventManager: any, networkManager: any)
	_log = logger
	_guard = guard
	_events = eventManager
	_network = networkManager
end

function ConfigManager.new()
	return setmetatable({}, ConfigManager)
end

-- [[ INTEGRAÇÃO COM DATASTORE ]] --

function ConfigManager:ImportPlayerData(player: Player, data: {[string]: any})
	if not _guard:IsInstance(player, "Player") then return end
	playerConfigs[player.UserId] = data
	
	-- Sincronização Inicial: Assim que carrega, manda tudo o que é permitido pro player
	self:SyncAll(player)
	
	if _log then _log:SendMessage("Config", "Dados carregados e sincronizados para " .. player.Name, "Print") end
end

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
	
	-- 1. REPLICAÇÃO AUTOMÁTICA
	-- Se a chave for pública, usamos o NetworkManager para avisar o cliente
	if REPLICATED_KEYS[key] and _network then
		_network:FireClient("ConfigSync", player, {Key = key, Value = value})
	end
	
	-- 2. REATIVIDADE INTERNA (SERVER)
	if _events then
		_events:Fire("PlayerConfigChanged", player, key, value, oldValue)
		_events:Fire(`Update_{userId}`, key, value)
	end
end

-- Envia todos os dados permitidos de uma vez (útil no Join)
function ConfigManager:SyncAll(player: Player)
	if not _network then return end
	local userId = player.UserId
	local data = playerConfigs[userId]
	if not data then return end

	local toSync = {}
	for key, value in pairs(data) do
		if REPLICATED_KEYS[key] then
			toSync[key] = value
		end
	end

	_network:FireClient("ConfigSyncAll", player, toSync)
end

function ConfigManager:SetInTable(player: Player, tableKey: string, subKey: string, value: any)
	local data = self:GetPlayer(player, tableKey)
	if typeof(data) ~= "table" then data = {} end
	
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

