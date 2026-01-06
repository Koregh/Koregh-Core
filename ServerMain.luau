-- ServerMain.lua
local Framework = require(game.ReplicatedStorage.Framework)

-- Liga o framework uma única vez
Framework.Init()

-- Agora, qualquer outro script que der require(Framework) 
-- já terá os módulos configurados e prontos para uso.
