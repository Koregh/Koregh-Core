--!strict
-- ConfigManager.lua

local ConfigManager = {}
ConfigManager.__index = ConfigManager

-- Dependências injetadas pelo módulo principal
local _log: any = nil
local _guard: any = nil
local _events: any = nil
local _network: any = nil 

-- Chaves que o cliente precisa conhecer (sincronização automática)
local REPLICATED_KEYS: { [string]: boolean } = {
	["Gold"] = true,
	["Level"] = true,
	["Experience"] = true,
	["Inventory"] = true,
	["Class"] = true,
}

local playerConfigs: { [number]: { [string]: any } } = {}

-- Criamos uma cópia profunda para garantir imutabilidade
local function deepCopy(t: any): any
	if typeof(t) ~= "table" then return t end
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Inicializa as dependências necessárias
function ConfigManager.Init(logger: any, guard: any, eventManager: any, networkManager: any)
	_log, _guard, _events, _network = logger, guard, eventManager, networkManager
end

function ConfigManager.new()
	return setmetatable({}, ConfigManager)
end

-- Puxa os dados brutos do DataStore para o estado atual do player
function ConfigManager:ImportPlayerData(player: Player, data: {[string]: any})
	if not _guard:IsInstance(player, "Player") then return end
	
	playerConfigs[player.UserId] = deepCopy(data)
	self:SyncAll(player)
	
	if _log then 
		_log:SendMessage("Config", "Sessão de dados iniciada: " .. player.Name, "Print") 
	end
end

-- Retorna uma cópia limpa dos dados para salvamento seguro
function ConfigManager:ExportPlayerData(player: Player): {[string]: any}?
	local data = playerConfigs[player.UserId]
	return data and deepCopy(data) or nil
end

-- Altera um valor e dispara a replicação/eventos (Ideal para valores simples: strings, numbers)
function ConfigManager:SetPlayer(player: Player, key: string, value: any)
	if not _guard:IsInstance(player, "Player", true) then return end
	
	local userId = player.UserId
	playerConfigs[userId] = playerConfigs[userId] or {}
	
	local internalValue = (typeof(value) == "table") and deepCopy(value) or value
	local oldValue = playerConfigs[userId][key]
	
	if oldValue == internalValue then return end
	playerConfigs[userId][key] = internalValue
	
	-- Replicação padrão (Tabela/Valor Inteiro)
	if REPLICATED_KEYS[key] and _network then
		_network:FireClient("ConfigSync", player, {Key = key, Value = internalValue})
	end
	
	if _events then
		_events:Fire("PlayerConfigChanged", player, key, internalValue, oldValue)
		_events:Fire(`Update_{userId}`, key, internalValue)
	end
end

-- [OTIMIZADO] Atualiza apenas um campo dentro de uma tabela sem reenviar a tabela toda
function ConfigManager:UpdateInTable(player: Player, tableKey: string, subKey: string, value: any)
	local userId = player.UserId
	if not playerConfigs[userId] or typeof(playerConfigs[userId][tableKey]) ~= "table" then
		-- Se a tabela não existe, cria uma nova usando o SetPlayer comum
		self:SetPlayer(player, tableKey, {[subKey] = value})
		return
	end

	-- Atualiza internamente
	local internalTable = playerConfigs[userId][tableKey]
	internalTable[subKey] = (typeof(value) == "table") and deepCopy(value) or value

	-- Em vez de mandar a tabela toda, mandamos um evento de "Delta"
	if REPLICATED_KEYS[tableKey] and _network then
		_network:FireClient("ConfigUpdateSubKey", player, {
			TableKey = tableKey,
			SubKey = subKey,
			Value = value
		})
	end

	-- Avisa o servidor que algo mudou naquela tabela
	if _events then
		_events:Fire("PlayerSubConfigChanged", player, tableKey, subKey, value)
		_events:Fire(`Update_{userId}`, tableKey, internalTable)
	end
end

-- Sempre retorna uma cópia para proteger o dado original
function ConfigManager:GetPlayer(player: Player, key: string): any
	local data = playerConfigs[player.UserId] and playerConfigs[player.UserId][key]
	return deepCopy(data)
end

-- Manda todos os dados relevantes de uma vez (no spawn)
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

-- Limpa o cache quando o jogador sai
function ConfigManager:ClearPlayer(player: Player)
	playerConfigs[player.UserId] = nil
end

return ConfigManager

