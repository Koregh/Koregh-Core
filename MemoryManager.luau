--!strict
-- MemoryManager.lua
-- Gerenciamento de ciclo de vida e auditoria de memória.

local MemoryManager = {}
MemoryManager.__index = MemoryManager

-- Tipos
export type CleanupFn = (any) -> ()
export type Entry = {
	Id: number,
	Object: any, -- Referência forte (intencional se o manager for o dono do ciclo de vida)
	Cleanup: CleanupFn?,
}

-- Configurações e Estado
local activeEntries: { [number]: Entry } = {} -- Dicionário para busca O(1)
local idCounter = 0
local _logger = nil :: any? -- Coloque a referência do local do logger

-- Injeção de dependência (Seguindo o padrão do GuardClause)
function MemoryManager.ConnectReporter(reporterInstance: any)
	_logger = reporterInstance
end

local function log(message: string, msgType: "Print" | "Warn" | "Error")
	if _logger then
		_logger:SendMessage("MemoryManager", message, msgType)
	end
end

function MemoryManager.new()
	return setmetatable({}, MemoryManager)
end

-- @desc Rastreia um objeto. 
-- Se o objeto for uma Instance do Roblox, podemos automatizar o .Destroy()
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

-- @desc Destrói pelo ID (Busca instantânea)
function MemoryManager:Destroy(id: number)
	local entry = activeEntries[id]
	if not entry then return end

	-- Executa o Cleanup
	if entry.Cleanup then
		local success, err = pcall(entry.Cleanup, entry.Object)
		if not success then
			log("Erro no Cleanup ID " .. id .. ": " .. tostring(err), "Error")
		end
	elseif typeof(entry.Object) == "Instance" then
		entry.Object:Destroy()
	end

	activeEntries[id] = nil -- Remove do dicionário (O(1))
	log("Objeto destruído e removido: ID " .. id, "Print")
end

-- @desc Limpa TUDO. Ideal para troca de mapas ou reset de rounds.
function MemoryManager:CleanAll()
	log("Iniciando limpeza geral...", "Warn")
	for id, _ in activeEntries do
		self:Destroy(id)
	end
	table.clear(activeEntries)
end

function MemoryManager:GetCount(): number
	local count = 0
	for _ in activeEntries do count += 1 end
	return count
end

return MemoryManager
