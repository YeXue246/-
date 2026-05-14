--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_PointTip_C
local M = UnLua.Class()
local DFL = require("SandBox.DataFunction")
function M:Initialize(Initializer)
    self.matTable = {
        LoadObject('/Game/SandBox/Materials/M_Light_Inst.M_Light_Inst'),
        LoadObject('/Game/SandBox/Materials/M_Light_Inst2.M_Light_Inst2'),
    }
end

function M:ReceiveBeginPlay()
end

-- function M:ReceiveTick(DeltaSeconds)
-- end

function M:SetM(Nub)
    self.Sphere:SetMaterial(0, self.matTable[Nub])
end

return M
