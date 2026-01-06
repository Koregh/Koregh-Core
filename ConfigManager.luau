--!strict
-- ConfigManager.lua

local ConfigManager = {}
ConfigManager.__index = ConfigManager

-- Dependências injetadas pelo módulo principal
local _log: any = nil
local _guard: any = nil
local _events: any = nil
local _network: any = nil 

-- Chaves que o cliente precisa conhecer (sincronização automática, coloque as chaves que você deseja serem replicadas)
local REPLICATED_KEYS: { [string]: boolean } = {
	["Gold"] = true,
	["Level"] = true,
	["Experience"] = true,
	["Inventory"] = true,
	["Class"] = true,
}

local playerConfigs: { [number]: { [string]: any } } = {}

-- Criamos uma cópia profunda para garantir que ninguém altere a tabela original por referência
local function deepCopy(t: any): any
	if typeof(t) ~= "table" then return t end
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Inicializa as dependências necessárias para o funcionamento do módulo
function ConfigManager.Init(logger: any, guard: any, eventManager: any, networkManager: any)
	_log, _guard, _events, _network = logger, guard, eventManager, networkManager
end

function ConfigManager.new()
	return setmetatable({}, ConfigManager)
end

-- Puxa os dados brutos do DataStore para o estado atual do player
function ConfigManager:ImportPlayerData(player: Player, data: {[string]: any})
	if not _guard:IsInstance(player, "Player") then return end
	
	-- Trabalhamos sempre com uma cópia para evitar side-effects
	playerConfigs[player.UserId] = deepCopy(data)
	
	self:SyncAll(player)
	
	if _log then 
		_log:SendMessage("Config", "Sessão de dados iniciada: " .. player.Name, "Print") 
	end
end

-- Retorna uma cópia limpa dos dados para salvamento seguro no DataStore
function ConfigManager:ExportPlayerData(player: Player): {[string]: any}?
	local data = playerConfigs[player.UserId]
	return data and deepCopy(data) or nil
end

-- Altera um valor e dispara a replicação/eventos se necessário
function ConfigManager:SetPlayer(player: Player, key: string, value: any)
	if not _guard:IsInstance(player, "Player", true) then return end
	
	local userId = player.UserId
	playerConfigs[userId] = playerConfigs[userId] or {}
	
	-- Se o valor for tabela, clonamos para o estado interno não ser corrompido de fora
	local internalValue = (typeof(value) == "table") and deepCopy(value) or value
	local oldValue = playerConfigs[userId][key]
	
	-- Só prossegue se o valor realmente mudou
	if oldValue == internalValue then return end
	playerConfigs[userId][key] = internalValue
	
	-- Notifica o cliente se a chave estiver na lista de replicação
	if REPLICATED_KEYS[key] and _network then
		_network:FireClient("ConfigSync", player, {Key = key, Value = internalValue})
	end
	
	-- Avisa o restante do servidor sobre a mudança
	if _events then
		_events:Fire("PlayerConfigChanged", player, key, internalValue, oldValue)
		_events:Fire(`Update_{userId}`, key, internalValue)
	end
end

-- Sempre retorna uma cópia para o resto do script não "sujar" o dado original
function ConfigManager:GetPlayer(player: Player, key: string): any
	local data = playerConfigs[player.UserId] and playerConfigs[player.UserId][key]
	return deepCopy(data)
end

-- Facilita a atualização de um campo específico dentro de uma tabela aninhada
function ConfigManager:SetInTable(player: Player, tableKey: string, subKey: string, value: any)
	local data = self:GetPlayer(player, tableKey)
	if typeof(data) ~= "table" then data = {} end
	
	data[subKey] = value
	self:SetPlayer(player, tableKey, data)
end

-- Manda todos os dados relevantes de uma vez para o client (usado no spawn)
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

-- Limpa o cache quando o jogador sai do servidor
function ConfigManager:ClearPlayer(player: Player)
	playerConfigs[player.UserId] = nil
end

return ConfigManager

