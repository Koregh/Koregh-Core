--!strict
local ServiceManager = {}
local _services: { [string]: any } = {}

-- Faz o require e organiza os serviços
function ServiceManager.Load(servicesFolder: Folder)
	for _, module in ipairs(servicesFolder:GetChildren()) do
		if module:IsA("ModuleScript") then
			local success, service = pcall(require, module)
			if success then
				_services[module.Name] = service
			else
				warn("[ServiceManager] Erro ao carregar " .. module.Name .. ": " .. tostring(service))
			end
		end
	end
end

-- Roda o Init de todo mundo (Preparação)
function ServiceManager.InitAll(framework: any)
	for name, service in pairs(_services) do
		if type(service.Init) == "function" then
			service.Init(framework)
		end
	end
end

-- Roda o Start de todo mundo (Execução em threads separadas)
function ServiceManager.StartAll()
	for name, service in pairs(_services) do
		if type(service.Start) == "function" then
			task.spawn(service.Start)
		end
	end
end

return ServiceManager
