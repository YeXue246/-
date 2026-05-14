--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@type UI_SplineMenu_C
local M = UnLua.Class()


function M:Construct()
    self.BT1.OnClicked:Add(self.control, self.control.ShutdownSplineMenu)
    self.BT2.OnClicked:Add(self.control, self.control.ParameterDetermination)
end

return M
