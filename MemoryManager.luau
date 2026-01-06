--!strict
-- MemoryManager.lua

local MemoryManager = {}
MemoryManager.__index = MemoryManager

-- Tipos para o Luau
export type CleanupFn = (any) -> ()
export type Entry = {
	Id: number,
	Object: any, -- Mantemos a referência forte para garantir que o manager controle o ciclo
	Cleanup: CleanupFn?,
}

-- Estado interno: IDs crescentes e dicionário para acesso rápido
local activeEntries: { [number]: Entry } = {} 
local idCounter = 0
local _logger = nil :: any?

-- Injeção de dependência para reportar logs no console central
function MemoryManager.ConnectReporter(reporterInstance: any)
	_logger = reporterInstance
end

-- Atalho para o logger interno (se existir)
local function log(message: string, msgType: "Print" | "Warn" | "Error")
	if _logger then
		_logger:SendMessage("MemoryManager", message, msgType)
	end
end

function MemoryManager.new()
	return setmetatable({}, MemoryManager)
end

-- Coloca um objeto sob vigilância. 
-- Se for uma Instance e não passar Cleanup, ele tenta o .Destroy() padrão.
function MemoryManager:Track(Object: any, Cleanup: CleanupFn?): number
	if Object == nil then return -1 end

	idCounter += 1
	local id = idCounter
	
	local entry: Entry = {
		Id = id,
		Object = Object,
		Cleanup = Cleanup,
	}

	activeEntries[id] = entry
	log(string.format("Rastreando: [%d] %s", id, tostring(Object)), "Print")

	return id
end

-- Localiza o objeto pelo ID e força a destruição/desconexão
function MemoryManager:Destroy(id: number)
	local entry = activeEntries[id]
	if not entry then return end

	-- Roda a função de limpeza customizada ou vai no .Destroy() se for Instance
	if entry.Cleanup then
		local success, err = pcall(entry.Cleanup, entry.Object)
		if not success then
			log("Falha ao limpar ID " .. id .. ": " .. tostring(err), "Error")
		end
	elseif typeof(entry.Object) == "Instance" then
		entry.Object:Destroy()
	end

	-- Remove do rastreio imediatamente (O(1))
	activeEntries[id] = nil 
	log("Removido do rastreio: ID " .. id, "Print")
end

-- Use isso em resets de round ou quando trocar o mapa.
function MemoryManager:CleanAll()
	log("Derrubando todos os processos rastreados...", "Warn")
	for id, _ in activeEntries do
		self:Destroy(id)
	end
	table.clear(activeEntries)
end

-- Retorna a quantidade de itens que ainda estão "vivos" na memória
function MemoryManager:GetCount(): number
	local count = 0
	for _ in activeEntries do count += 1 end
	return count
end

return MemoryManager

