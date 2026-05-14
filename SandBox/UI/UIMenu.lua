--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class UI_Menu_C
local M = UnLua.Class()

--function M:Initialize(Initializer)
--end

--function M:PreConstruct(IsDesignTime)
--end

function M:Construct()
    self.BT1:BindHover()
    self.BT2:BindHover()
    self.BT3:BindHover()
    self.BT4:BindHover()
    self.BT5:BindHover()

    self.BT1.OnClicked:Add(self.control, self.control.RenameModels)
    self.BT2.OnClicked:Add(self.control, self.control.HideModels)
    self.BT3.OnClicked:Add(self.control, self.control.AllShowModels)
    self.BT4.OnClicked:Add(self.control, self.control.LockModels)
    self.BT5.OnClicked:Add(self.control, self.control.UnlockModels)
end

--function M:Tick(MyGeometry, InDeltaTime)
--end

return M
