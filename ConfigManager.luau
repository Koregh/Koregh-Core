--!strict
-- ConfigManager.lua
-- Gerencia estado reativo, replica dados permitidos e protege a integridade da memória.

local ConfigManager = {}
ConfigManager.__index = ConfigManager

-- Dependências Injetadas
local _log: any = nil
local _guard: any = nil
local _events: any = nil
local _network: any = nil 

-- [PAINEL DE CONTROLE DE REPLICAÇÃO]
local REPLICATED_KEYS: { [string]: boolean } = {
	["Gold"] = true,
	["Level"] = true,
	["Experience"] = true,
	["Inventory"] = true,
	["Class"] = true,
}

local playerConfigs: { [number]: { [string]: any } } = {}

-- [[ UTILITÁRIOS PRIVADOS ]] --

-- Protege contra modificações acidentais em tabelas (Imutabilidade)
local function deepCopy(t: any): any
	if typeof(t) ~= "table" then return t end
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- [[ INICIALIZAÇÃO ]] --

function ConfigManager.Init(logger: any, guard: any, eventManager: any, networkManager: any)
	_log, _guard, _events, _network = logger, guard, eventManager, networkManager
end

function ConfigManager.new()
	return setmetatable({}, ConfigManager)
end

-- [[ INTEGRAÇÃO DATASTORE ]] --

function ConfigManager:ImportPlayerData(player: Player, data: {[string]: any})
	if not _guard:IsInstance(player, "Player") then return end
	playerConfigs[player.UserId] = deepCopy(data) -- Importa uma cópia limpa
	
	self:SyncAll(player)
	
	if _log then _log:SendMessage("Config", "Sessão de dados iniciada: " .. player.Name, "Print") end
end

function ConfigManager:ExportPlayerData(player: Player): {[string]: any}?
	local data = playerConfigs[player.UserId]
	return data and deepCopy(data) or nil -- Exporta uma cópia para o DataStore salvar com segurança
end

-- [[ MÉTODOS DE ESTADO (BLINDADOS) ]] --

function ConfigManager:SetPlayer(player: Player, key: string, value: any)
	if not _guard:IsInstance(player, "Player", true) then return end
	
	local userId = player.UserId
	playerConfigs[userId] = playerConfigs[userId] or {}
	
	-- Garante que se o valor for uma tabela, o Config guarde uma CÓPIA interna
	local internalValue = (typeof(value) == "table") and deepCopy(value) or value
	local oldValue = playerConfigs[userId][key]
	
	-- Comparação básica para evitar disparos inúteis
	if oldValue == internalValue then return end
	playerConfigs[userId][key] = internalValue
	
	-- 1. REPLICAÇÃO AUTOMÁTICA (Server -> Client)
	if REPLICATED_KEYS[key] and _network then
		_network:FireClient("ConfigSync", player, {Key = key, Value = internalValue})
	end
	
	-- 2. EVENTOS INTERNOS (Server -> Server)
	if _events then
		_events:Fire("PlayerConfigChanged", player, key, internalValue, oldValue)
		_events:Fire(`Update_{userId}`, key, internalValue)
	end
end

-- RETORNO PROTEGIDO: O resto do jogo recebe uma cópia, nunca a tabela original
function ConfigManager:GetPlayer(player: Player, key: string): any
	local data = playerConfigs[player.UserId] and playerConfigs[player.UserId][key]
	return deepCopy(data)
end

function ConfigManager:SetInTable(player: Player, tableKey: string, subKey: string, value: any)
	local data = self:GetPlayer(player, tableKey) -- Isso já retorna uma cópia via GetPlayer
	if typeof(data) ~= "table" then data = {} end
	
	data[subKey] = value
	self:SetPlayer(player, tableKey, data) -- Atualiza e replica a tabela inteira
end

-- [[ GERENCIAMENTO DE SESSÃO ]] --

function ConfigManager:SyncAll(player: Player)
	if not _network then return end
	local data = playerConfigs[player.UserId]
	if not data then return end

	local toSync = {}
	for key, value in pairs(data) do
		if REPLICATED_KEYS[key] then
			toSync[key] = value
		end
	end
	_network:FireClient("ConfigSyncAll", player, toSync)
end

function ConfigManager:ClearPlayer(player: Player)
	playerConfigs[player.UserId] = nil
end

return ConfigManager

