--!strict
-- NetworkManager.lua
-- Gerenciamento de rede ultra-seguro, escalável e com gerenciamento automático de estado.

local NetworkManager = {}
NetworkManager.__index = NetworkManager

-- Dependências Injetadas
local _logger: any = nil
local _guard: any = nil

-- Configurações de Performance/Segurança
local RATE_LIMIT_MS = 100 
local playerThrottling: {[number]: {[string]: number}} = {}

-- Tipos
export type NetworkManagerType = typeof(setmetatable({} :: {
	_events: { [string]: RemoteEvent | RemoteFunction },
	_connections: { [string]: { RBXScriptConnection } },
	_middlewares: { (Player, any) -> boolean }
}, NetworkManager))

-- Inicialização com Injeção de Dependência
function NetworkManager.Init(logger: any, guard: any)
	_logger = logger
	_guard = guard
	
	-- Lifecycle: Limpa cache de throttling quando o player sai para evitar Memory Leak
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		playerThrottling[player.UserId] = nil
	end)
end

local function report(msg: string, msgType: "Warn" | "Error")
	if _logger then _logger:SendMessage("Network", msg, msgType) end
end

function NetworkManager.new(): NetworkManagerType
	return setmetatable({
		_events = {},
		_connections = {},
		_middlewares = {} -- Permite adicionar verificações globais (ex: BanCheck)
	}, NetworkManager) :: any
end

-- [[ GERENCIAMENTO DE INSTÂNCIAS ]] --

function NetworkManager:GetEvent(name: string, isFunction: boolean?): RemoteEvent | RemoteFunction
	if self._events[name] then return self._events[name] end
	
	local storage = game:GetService("ReplicatedStorage")
	local remoteFolder = storage:FindFirstChild("Remotes") or Instance.new("Folder", storage)
	remoteFolder.Name = "Remotes"
	
	local className = isFunction and "RemoteFunction" or "RemoteEvent"
	local remote = remoteFolder:FindFirstChild(name) or Instance.new(className, remoteFolder)
	remote.Name = name
	
	self._events[name] = remote :: any
	self._connections[name] = {}
	return self._events[name]
end

-- [[ MIDDLEWARE SYSTEM ]] --

-- Permite adicionar uma função que roda antes de TODOS os eventos
-- Útil para: Verificar se o player está atordoado, se está banido, etc.
function NetworkManager:AddGlobalMiddleware(fn: (Player, any) -> boolean)
	table.insert(self._middlewares, fn)
end

-- [[ CONEXÕES BLINDADAS ]] --

function NetworkManager:Connect(name: string, blueprint: {[string]: any}?, callback: (Player, any) -> ())
	local event = self:GetEvent(name) :: RemoteEvent
	
	local connection = event.OnServerEvent:Connect(function(player: Player, data: any)
		-- 1. PROTEÇÃO: Rate Limiting
		local now = os.clock()
		local pId = player.UserId
		playerThrottling[pId] = playerThrottling[pId] or {}
		
		if playerThrottling[pId][name] and (now - playerThrottling[pId][name]) < (RATE_LIMIT_MS / 1000) then
			report("Rate limit atingido por: " .. player.Name .. " no evento: " .. name, "Warn")
			return
		end
		playerThrottling[pId][name] = now

		-- 2. PROTEÇÃO: Middlewares Globais
		for _, middleware in ipairs(self._middlewares) do
			if not middleware(player, data) then return end
		end

		-- 3. PROTEÇÃO: GuardClause Schema (Agora aceita Deep Schema da V3)
		if blueprint and _guard then
			if not _guard:Schema(data, blueprint) then
				report("Dados maliciosos/inválidos de: " .. player.Name, "Error")
				return 
			end
		end

		-- 4. EXECUÇÃO SEGURA
		task.spawn(callback, player, data)
	end)

	table.insert(self._connections[name], connection)
end

-- [[ INVOKE (REMOTE FUNCTIONS) ]] --

function NetworkManager:HandleInvoke(name: string, blueprint: {[string]: any}?, callback: (Player, any) -> any)
	local remoteFunc = self:GetEvent(name, true) :: RemoteFunction
	
	remoteFunc.OnServerInvoke = function(player: Player, data: any)
		-- Aplica as mesmas proteções do Connect
		if blueprint and _guard then
			if not _guard:Schema(data, blueprint) then return nil end
		end
		
		return callback(player, data)
	end
end

-- [[ ENVIO DE SINAIS ]] --

function NetworkManager:FireClient(name: string, player: Player, ...: any)
	local event = self:GetEvent(name) :: RemoteEvent
	event:FireClient(player, ...)
end

function NetworkManager:FireAllClients(name: string, ...: any)
	local event = self:GetEvent(name) :: RemoteEvent
	event:FireAllClients(...)
end

-- [[ CLEANUP ]] --

function NetworkManager:DisconnectEvent(name: string)
	if self._connections[name] then
		for _, conn in ipairs(self._connections[name]) do
			conn:Disconnect()
		end
		self._connections[name] = {}
	end
end

return NetworkManager

