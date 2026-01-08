--!strict
-- NetworkManager.lua

local NetworkManager = {}
NetworkManager.__index = NetworkManager

-- Referências injetadas (Log e Segurança)
local _log: any = nil
local _guard: any = nil

-- Configurações de tráfego
local DEFAULT_RATE_LIMIT = 0.1 -- 100ms entre disparos
local playerThrottling = {} -- { [UserId]: { [eventName]: lastTime } }

-- IDs de Protocolo (12 Principais)
local PacketType = {
	CFRAME     = 1, VECTOR3    = 2, VECTOR2    = 3,
	COLOR3     = 4, NUMBER     = 5, INT32      = 6,
	BOOLEAN    = 7, STRING     = 8, BRICKCOLOR = 9,
	ENUM       = 10, UDIM2     = 11, INT8      = 12
}

-- Tipos
export type NetworkManagerType = typeof(setmetatable({} :: {
	_events: { [string]: RemoteEvent },
	_connections: { [string]: { RBXScriptConnection } }
}, NetworkManager))

-- Inicializa as ferramentas de apoio (Logger e GuardClause)
function NetworkManager.Init(logger: any, guard: any)
	_log = logger
	_guard = guard
end

function NetworkManager.new(): NetworkManagerType
	return setmetatable({
		_events = {},
		_connections = {}
	}, NetworkManager) :: any
end

-- MÉTODOS PRIVADOS--

-- Serializa dados para envio (Otimização Binária)
local function _serialize(data: any): any
	local t = typeof(data)
	if t == "CFrame" then
		local b = buffer.create(25)
		buffer.writeu8(b, 0, PacketType.CFRAME)
		buffer.writef32(b, 1, data.X); buffer.writef32(b, 5, data.Y); buffer.writef32(b, 9, data.Z)
		local rx, ry, rz = data:ToEulerAnglesXYZ()
		buffer.writef32(b, 13, rx); buffer.writef32(b, 17, ry); buffer.writef32(b, 21, rz)
		return b
	elseif t == "Vector3" then
		local b = buffer.create(13)
		buffer.writeu8(b, 0, PacketType.VECTOR3)
		buffer.writef32(b, 1, data.X); buffer.writef32(b, 5, data.Y); buffer.writef32(b, 9, data.Z)
		return b
	elseif t == "Color3" then
		local b = buffer.create(4)
		buffer.writeu8(b, 0, PacketType.COLOR3)
		buffer.writeu8(b, 1, data.R * 255); buffer.writeu8(b, 2, data.G * 255); buffer.writeu8(b, 3, data.B * 255)
		return b
	elseif t == "number" then
		if data % 1 == 0 and data >= -128 and data <= 127 then
			local b = buffer.create(2); buffer.writeu8(b, 0, PacketType.INT8); buffer.writei8(b, 1, data); return b
		end
		local b = buffer.create(9); buffer.writeu8(b, 0, PacketType.NUMBER); buffer.writef64(b, 1, data); return b
	elseif t == "boolean" then
		local b = buffer.create(2); buffer.writeu8(b, 0, PacketType.BOOLEAN); buffer.writeu8(b, 1, data and 1 or 0); return b
	elseif t == "UDim2" then
		local b = buffer.create(17); buffer.writeu8(b, 0, PacketType.UDIM2)
		buffer.writef32(b, 1, data.X.Scale); buffer.writei32(b, 5, data.X.Offset)
		buffer.writef32(b, 9, data.Y.Scale); buffer.writei32(b, 13, data.Y.Offset); return b
	elseif t == "BrickColor" then
		local b = buffer.create(3); buffer.writeu8(b, 0, PacketType.BRICKCOLOR); buffer.writei16(b, 1, data.Number); return b
	end
	return data
end

-- Deserializa dados recebidos (Reconstrução Binária)
local function _deserialize(b: any): any
	if typeof(b) ~= "buffer" then return b end
	local header = buffer.readu8(b, 0)
	if header == PacketType.CFRAME then
		return CFrame.new(buffer.readf32(b, 1), buffer.readf32(b, 5), buffer.readf32(b, 9)) * CFrame.Angles(buffer.readf32(b, 13), buffer.readf32(b, 17), buffer.readf32(b, 21))
	elseif header == PacketType.VECTOR3 then
		return Vector3.new(buffer.readf32(b, 1), buffer.readf32(b, 5), buffer.readf32(b, 9))
	elseif header == PacketType.COLOR3 then
		return Color3.fromRGB(buffer.readu8(b, 1), buffer.readu8(b, 2), buffer.readu8(b, 3))
	elseif header == PacketType.NUMBER then
		return buffer.readf64(b, 1)
	elseif header == PacketType.INT8 then
		return buffer.readi8(b, 1)
	elseif header == PacketType.BOOLEAN then
		return buffer.readu8(b, 1) == 1
	elseif header == PacketType.UDIM2 then
		return UDim2.new(buffer.readf32(b, 1), buffer.readi32(b, 5), buffer.readf32(b, 9), buffer.readi32(b, 13))
	elseif header == PacketType.BRICKCOLOR then
		return BrickColor.new(buffer.readi16(b, 1))
	end
	return b
end

-- Localiza ou cria a RemoteEvent (Lazy Loading)
function NetworkManager:_getEvent(name: string): RemoteEvent
	if self._events[name] then return self._events[name] end
	
	local storage = game:GetService("ReplicatedStorage")
	local remoteFolder = storage:FindFirstChild("Remotes") or Instance.new("Folder", storage)
	remoteFolder.Name = "Remotes"
	
	local remote = remoteFolder:FindFirstChild(name) or Instance.new("RemoteEvent", remoteFolder)
	remote.Name = name
	
	self._events[name] = remote :: RemoteEvent
	self._connections[name] = {}
	return remote
end

--  MÉTODOS PÚBLICOS --

-- Conecta a um evento com tripla proteção.
-- @param validator: (Opcional) Função que recebe (player, data) e retorna (boolean, string_erro)
function NetworkManager:Connect(
	name: string, 
	blueprint: {[string]: any}?, 
	callback: (Player, any) -> (), 
	customCooldown: number?,
	validator: ((Player, any) -> (boolean, string?))?
): RBXScriptConnection
	local event = self:_getEvent(name)
	local cooldownTime = customCooldown or DEFAULT_RATE_LIMIT

	local connection = event.OnServerEvent:Connect(function(player: Player, rawData: any)
		-- 1. CAMADA DE REDE: Anti-Spam (Rate Limiting)
		local now = os.clock()
		local pId = player.UserId
		playerThrottling[pId] = playerThrottling[pId] or {}
		
		if playerThrottling[pId][name] and (now - playerThrottling[pId][name]) < cooldownTime then
			return -- Bloqueia silenciosamente para economizar processamento
		end
		playerThrottling[pId][name] = now

		-- Conversão Binária (SerdeLayer Inline)
		-- Converte buffers de volta para o tipo original do Roblox antes da validação
		local data = _deserialize(rawData)

		-- Integridade de Dados (GuardClause)
		-- Verifica se o hacker mandou o tipo correto de dado (ex: mandou string em vez de number)
		if blueprint and _guard then
			if not _guard:Schema(data, blueprint) then
				if _log then _log:SendMessage("Network", `Dados maliciosos de {player.Name} em {name}`, "Error") end
				return 
			end
		end

		-- Regras de Negócio (Validator)
		-- Verifica se a ação faz sentido no jogo (ex: checar se tem dinheiro ou se está perto)
		if validator then
			local success, reason = validator(player, data)
			if not success then
				if _log then 
					_log:SendMessage("Security", `Ação bloqueada [{name}] para {player.Name}: {reason or "Violação de regra"}`, "Warn") 
				end
				return 
			end
		end

		-- Thread Segura (Isolamento de Erros)
		task.spawn(function()
			local success, err = pcall(callback, player, data)
			if not success and _log then
				_log:SendMessage("NetworkError", `Falha crítica no callback [{name}] (Player: {player.Name}): {err}`, "Error")
			end
		end)
	end)

	table.insert(self._connections[name], connection)
	return connection
end

-- Dispara dados para um cliente específico
function NetworkManager:FireClient(name: string, player: Player, data: any)
	local event = self:_getEvent(name)
	event:FireClient(player, _serialize(data))
end

-- Dispara dados para todos os jogadores simultaneamente
function NetworkManager:FireAllClients(name: string, data: any)
	local event = self:_getEvent(name)
	event:FireAllClients(_serialize(data))
end

-- Limpa todas as conexões de um evento e mata os ouvintes
function NetworkManager:Disconnect(name: string)
	if self._connections[name] then
		for _, connection in ipairs(self._connections[name]) do
			connection:Disconnect()
		end
		self._connections[name] = {}
	end
end

return NetworkManager
