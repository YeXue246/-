--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class Button_C
local M = UnLua.Class()

function M:BindHover()
    self.OnHovered:Add(self, self.HoverColor)
    self.OnUnhovered:Add(self, self.UnhoverColor)
end

function M:HoverColor()
    self:SetColorAndOpacity(UE.FLinearColor(0.037, 0.37, 1, 1))
end

function M:UnhoverColor()
    self:SetColorAndOpacity(UE.FLinearColor(1, 1, 1, 1))
end

return M
