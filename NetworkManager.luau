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

-- Tipos para o Luau
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

-- [[ MÉTODOS PRIVADOS ]] --

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

-- [[ MÉTODOS PÚBLICOS ]] --

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

	local connection = event.OnServerEvent:Connect(function(player: Player, data: any)
		-- 1. CAMADA DE REDE: Anti-Spam (Rate Limiting)
		local now = os.clock()
		local pId = player.UserId
		playerThrottling[pId] = playerThrottling[pId] or {}
		
		if playerThrottling[pId][name] and (now - playerThrottling[pId][name]) < cooldownTime then
			return -- Bloqueia silenciosamente para economizar processamento
		end
		playerThrottling[pId][name] = now

		-- 2. CAMADA TÉCNICA: Integridade de Dados (GuardClause)
		-- Verifica se o hacker mandou o tipo correto de dado (ex: mandou string em vez de number)
		if blueprint and _guard then
			if not _guard:Schema(data, blueprint) then
				if _log then _log:SendMessage("Network", `Dados maliciosos de {player.Name} em {name}`, "Error") end
				return 
			end
		end

		-- 3. CAMADA LÓGICA: Regras de Negócio (Validator)
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

		-- 4. CAMADA DE EXECUÇÃO: Thread Segura (Isolamento de Erros)
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
function NetworkManager:FireClient(name: string, player: Player, ...: any)
	local event = self:_getEvent(name)
	event:FireClient(player, ...)
end

-- Dispara dados para todos os jogadores simultaneamente
function NetworkManager:FireAllClients(name: string, ...: any)
	local event = self:_getEvent(name)
	event:FireAllClients(...)
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

