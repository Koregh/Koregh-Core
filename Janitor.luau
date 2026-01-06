--!strict
-- Janitor.lua


local Janitor = {}
Janitor.__index = Janitor

type Task = RBXScriptConnection | Instance | (() -> ()) | { Destroy: (any) -> () } | any

export type Janitor = {
	_tasks: { [any]: Task },
	Add: (self: Janitor, object: Task, methodName: string?, index: any?) -> Task,
	Remove: (self: Janitor, index: any) -> (),
	Cleanup: (self: Janitor) -> (),
	Destroy: (self: Janitor) -> ()
}

function Janitor.new(): Janitor
	return setmetatable({
		_tasks = {}
	}, Janitor) :: any
end

-- Coloca um objeto na lista de limpeza. 
-- Se passar um 'index', ele substitui o que estiver lá (útil para sobrescrever conexões).
function Janitor:Add(object: Task, methodName: string?, index: any?): Task
	local taskIndex = index or object
	
	-- Se o índice já estiver ocupado, mata a tarefa antiga primeiro
	if index and self._tasks[index] then
		self:Remove(index)
	end

	self._tasks[taskIndex] = {
		Object = object,
		Method = methodName
	}
	
	return object
end

-- Mata uma tarefa específica e tira da lista
function Janitor:Remove(index: any)
	local task = self._tasks[index]
	if not task then return end

	local object = task.Object
	local method = task.Method

	-- Decide o melhor jeito de "matar" o objeto
	if method then
		object[method](object)
	elseif typeof(object) == "function" then
		object()
	elseif typeof(object) == "RBXScriptConnection" then
		object:Disconnect()
	elseif object.Destroy then
		object:Destroy()
	end

	self._tasks[index] = nil
end

-- Executa o cleanup de tudo o que foi registrado até agora
function Janitor:Cleanup()
	for index, _ in pairs(self._tasks) do
		self:Remove(index)
	end
end

-- Destrói o Janitor por completo
function Janitor:Destroy()
	self:Cleanup()
	setmetatable(self, nil)
end

return Janitor

