--!strict
-- NetworkManager.lua
-- Gerenciamento de rede blindado com execução segura, rate limiting dinâmico e logging.

local NetworkManager = {}
NetworkManager.__index = NetworkManager

-- Dependências Injetadas
local _log: any = nil
local _guard: any = nil

-- Configurações Padrão
local DEFAULT_RATE_LIMIT = 0.1 -- 100ms
local playerThrottling = {} -- { [UserId]: { [eventName]: lastTime } }

-- Tipos
export type NetworkManagerType = typeof(setmetatable({} :: {
	_events: { [string]: RemoteEvent },
	_connections: { [string]: { RBXScriptConnection } }
}, NetworkManager))

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

-- @desc Conexão com Proteção de Thread, Validação e Cooldown customizável
function NetworkManager:Connect(name: string, blueprint: {[string]: any}?, callback: (Player, any) -> (), customCooldown: number?)
	local event = self:_getEvent(name)
	local cooldownTime = customCooldown or DEFAULT_RATE_LIMIT

	local connection = event.OnServerEvent:Connect(function(player: Player, data: any)
		-- 1. PROTEÇÃO: Rate Limiting Dinâmico
		local now = os.clock()
		local pId = player.UserId
		playerThrottling[pId] = playerThrottling[pId] or {}
		
		if playerThrottling[pId][name] and (now - playerThrottling[pId][name]) < cooldownTime then
			if _log then _log:SendMessage("Network", `Spam detectado: {player.Name} em {name}`, "Warn") end
			return
		end
		playerThrottling[pId][name] = now

		-- 2. PROTEÇÃO: Validação de Schema (GuardClause)
		if blueprint and _guard then
			if not _guard:Schema(data, blueprint) then
				if _log then _log:SendMessage("Network", `Dados maliciosos/inválidos de {player.Name} no evento {name}`, "Error") end
				return 
			end
		end

		-- 3. EXECUÇÃO BLINDADA (State of the Art)
		-- Usamos task.spawn com pcall para que um erro no seu código não quebre o NetworkManager
		task.spawn(function()
			local success, err = pcall(callback, player, data)
			if not success and _log then
				_log:SendMessage("NetworkError", `Erro crítico no evento [{name}] disparado por {player.Name}: {err}`, "Error")
			end
		end)
	end)

	table.insert(self._connections[name], connection)
end

-- @desc Envia dados para um cliente específico
function NetworkManager:FireClient(name: string, player: Player, ...: any)
	local event = self:_getEvent(name)
	event:FireClient(player, ...)
end

-- @desc Envia dados para todos os clientes
function NetworkManager:FireAllClients(name: string, ...: any)
	local event = self:_getEvent(name)
	event:FireAllClients(...)
end

-- @desc Limpa todas as conexões de um evento específico
function NetworkManager:Disconnect(name: string)
	if self._connections[name] then
		for _, connection in ipairs(self._connections[name]) do
			connection:Disconnect()
		end
		self._connections[name] = {}
	end
end

return NetworkManager

