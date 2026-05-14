--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_DIY_C
local M = UnLua.Class()

function M:Initialize(Initializer)
    self.Code = "DIY"
    self.modelType = "DIY"
    -- self.showName = "幻影"
end

function M:ModelSave()
end

function M:ModelLoad()
end

return M
