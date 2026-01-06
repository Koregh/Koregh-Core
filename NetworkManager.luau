--!strict
-- NetworkManager.lua

local NetworkManager = {}
NetworkManager.__index = NetworkManager

-- Referências injetadas (Log e Segurança)
local _log: any = nil
local _guard: any = nil

-- Configurações de tráfego
local DEFAULT_RATE_LIMIT = 0.1 -- Evita spam (mínimo de 100ms entre disparos)
local playerThrottling = {} -- Controle de cooldown por jogador: { [UserId]: { [eventName]: lastTime } }

-- Tipos para o Luau
export type NetworkManagerType = typeof(setmetatable({} :: {
	_events: { [string]: RemoteEvent },
	_connections: { [string]: { RBXScriptConnection } }
}, NetworkManager))

-- Inicializa as ferramentas de apoio
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

-- Busca uma Remote ou cria uma nova se ela não existir (Lazy Loading)
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

-- Conecta a um evento com tripla proteção: Rate Limit, Validação de Schema e Pcall
function NetworkManager:Connect(name: string, blueprint: {[string]: any}?, callback: (Player, any) -> (), customCooldown: number?)
	local event = self:_getEvent(name)
	local cooldownTime = customCooldown or DEFAULT_RATE_LIMIT

	local connection = event.OnServerEvent:Connect(function(player: Player, data: any)
		-- 1. FILTRO DE SPAM: Bloqueia se o player disparar rápido demais
		local now = os.clock()
		local pId = player.UserId
		playerThrottling[pId] = playerThrottling[pId] or {}
		
		if playerThrottling[pId][name] and (now - playerThrottling[pId][name]) < cooldownTime then
			if _log then _log:SendMessage("Network", `Spam detectado: {player.Name} no evento {name}`, "Warn") end
			return
		end
		playerThrottling[pId][name] = now

		-- 2. FILTRO DE DADOS: Passa o pente fino nos dados recebidos usando o Guard
		if blueprint and _guard then
			if not _guard:Schema(data, blueprint) then
				if _log then _log:SendMessage("Network", `Dados inválidos de {player.Name} em {name}`, "Error") end
				return 
			end
		end

		-- 3. EXECUÇÃO SEGURA: Roda em uma thread separada para um erro não derrubar o resto do sistema
		task.spawn(function()
			local success, err = pcall(callback, player, data)
			if not success and _log then
				_log:SendMessage("NetworkError", `Erro crítico em [{name}] disparado por {player.Name}: {err}`, "Error")
			end
		end)
	end)

	table.insert(self._connections[name], connection)
end

-- Atalho para disparar evento para um player específico
function NetworkManager:FireClient(name: string, player: Player, ...: any)
	local event = self:_getEvent(name)
	event:FireClient(player, ...)
end

-- Atalho para disparar para todo mundo ao mesmo tempo
function NetworkManager:FireAllClients(name: string, ...: any)
	local event = self:_getEvent(name)
	event:FireAllClients(...)
end

-- Desconecta todos os ouvintes de um evento (limpeza de memória)
function NetworkManager:Disconnect(name: string)
	if self._connections[name] then
		for _, connection in ipairs(self._connections[name]) do
			connection:Disconnect()
		end
		self._connections[name] = {}
	end
end

return NetworkManager

