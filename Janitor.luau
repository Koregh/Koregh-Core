--!strict
-- Janitor.lua
-- Gerencia o ciclo de vida de objetos e conexões, prevenindo vazamentos de memória.

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

-- @desc Adiciona um objeto para ser limpo. 
-- @param methodName Se o objeto não tiver ".Destroy", você diz qual método usar (ex: "Disconnect")
function Janitor:Add(object: Task, methodName: string?, index: any?): Task
	local taskIndex = index or object
	
	-- Se já existe algo nesse índice, limpa o antigo antes
	if index and self._tasks[index] then
		self:Remove(index)
	end

	self._tasks[taskIndex] = {
		Object = object,
		Method = methodName
	}
	
	return object
end

-- @desc Remove e limpa um objeto específico pelo índice
function Janitor:Remove(index: any)
	local task = self._tasks[index]
	if not task then return end

	local object = task.Object
	local method = task.Method

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

-- @desc Limpa TUDO o que foi registrado
function Janitor:Cleanup()
	for index, _ in pairs(self._tasks) do
		self:Remove(index)
	end
end

-- @desc Destrói o Janitor e tudo dentro dele
function Framework:Destroy()
	self:Cleanup()
	setmetatable(self, nil)
end

return Janitor
