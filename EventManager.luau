--!strict
-- EventManager.lua
-- Sistema de eventos modular com suporte a Bindings de Remotes e Validação Automática.

local EventManager = {}
EventManager.__index = EventManager

-- Dependências Injetadas (Para evitar erro circular)
local _logger: any = nil
local _guard: any = nil

-- Tipos
export type Callback = (...any) -> ()
export type EventEntry = { [string]: { Callback } }

-- Configuração de Injeção
function EventManager.Init(logger: any, guard: any)
	_logger = logger
	_guard = guard
end

local function log(msg: string, msgType: "Print" | "Warn" | "Error")
	if _logger then _logger:SendMessage("EventManager", msg, msgType) end
end

function EventManager.new()
	local self = setmetatable({}, EventManager)
	self.Events = {} :: EventEntry
	return self
end

-- [1] CONEXÃO INTERNA 
function EventManager:Connect(eventName: string, callback: Callback): () -> ()
	if not self.Events[eventName] then self.Events[eventName] = {} end
	table.insert(self.Events[eventName], callback)
	
	return function()
		local list = self.Events[eventName]
		if not list then return end
		for i, cb in ipairs(list) do
			if cb == callback then
				table.remove(list, i)
				break
			end
		end
	end
end

-- [2] DISPARO INTERNO
function EventManager:Fire(eventName: string, ...: any)
	local callbacks = self.Events[eventName]
	if not callbacks then return end
	for _, callback in ipairs(callbacks) do
		task.spawn(callback, ...)
	end
end

-- [3] AUTO-BIND (A Blindagem de Remotes)
-- Esta função "escuta" uma Remote e só dispara o evento se os dados passarem no Guard
function EventManager:BindToRemote(remote: RemoteEvent, blueprint: {[string]: any})
	if not _guard then
		log("Erro: GuardClause não inicializado no EventManager!", "Error")
		return
	end

	remote.OnServerEvent:Connect(function(player: Player, data: any)
		-- Blindagem automática usando o GuardClause
		if _guard:Schema(data, blueprint) then
			-- Se o dado for válido, dispara internamente com o player como primeiro argumento
			self:Fire(remote.Name, player, data)
		else
			log("Tentativa de chamada inválida bloqueada de: " .. player.Name, "Warn")
		end
	end)
end

function EventManager:Clear()
	table.clear(self.Events)
end

return EventManager
