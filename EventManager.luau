--!strict
-- EventManager.lua

local EventManager = {}
EventManager.__index = EventManager

-- Referências para os módulos de log e segurança (injetados no Init)
local _logger: any = nil
local _guard: any = nil

-- Tipos para o Luau não reclamar
export type Callback = (...any) -> ()
export type EventEntry = { [string]: { Callback } }

-- Recebe as dependências do core para evitar o erro de loop (circular dependency)
function EventManager.Init(logger: any, guard: any)
	_logger = logger
	_guard = guard
end

-- Atalho interno para logar mensagens sem precisar checar se o logger existe toda hora
local function log(msg: string, msgType: "Print" | "Warn" | "Error")
	if _logger then _logger:SendMessage("EventManager", msg, msgType) end
end

function EventManager.new()
	local self = setmetatable({}, EventManager)
	self.Events = {} :: EventEntry
	return self
end

-- Registra uma função para um evento. Retorna uma função de "cleanup" para desconectar depois.
function EventManager:Connect(eventName: string, callback: Callback): () -> ()
	if not self.Events[eventName] then self.Events[eventName] = {} end
	table.insert(self.Events[eventName], callback)
	
	-- Se chamar o retorno, ele limpa a conexão automaticamente
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

-- Dispara o evento internamente. Usa task.spawn para uma thread não travar a outra.
function EventManager:Fire(eventName: string, ...: any)
	local callbacks = self.Events[eventName]
	if not callbacks then return end
	for _, callback in ipairs(callbacks) do
		task.spawn(callback, ...)
	end
end

-- Cria uma ponte segura entre uma RemoteEvent e o servidor. 
-- Só deixa o sinal passar se os dados estiverem no formato correto (blueprint).
function EventManager:BindToRemote(remote: RemoteEvent, blueprint: {[string]: any})
	if not _guard then
		log("Erro: O sistema de segurança (Guard) não foi carregado!", "Error")
		return
	end

	remote.OnServerEvent:Connect(function(player: Player, data: any)
		-- Verifica se o player não está tentando mandar lixo ou explorar o evento
		if _guard:Schema(data, blueprint) then
			-- Dados aprovados, jogamos para o resto do servidor processar
			self:Fire(remote.Name, player, data)
		else
			log("Bloqueamos um pacote inválido vindo de: " .. player.Name, "Warn")
		end
	end)
end

-- Reseta todos os eventos registrados (limpeza geral)
function EventManager:Clear()
	table.clear(self.Events)
end

return EventManager

