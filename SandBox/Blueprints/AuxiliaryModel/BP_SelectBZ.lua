--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_SelectBZ_C
local M = UnLua.Class()
local DFL = require("SandBox.DataFunction")

function M:ReceiveBeginPlay()
    self.widgetUI = self.Widget:GetWidget()
end

-- 创建选中物体标注
function M:SetSelectBZ(inputLocation, control, normal, bAlign, actor)
    self.actor = actor
    local location = self:K2_GetActorLocation()
    self.Cable.EndLocation = inputLocation - location
    local SweepHitResult = UE.FHitResult()
    self.EndPoint:K2_SetWorldLocation(inputLocation, false, SweepHitResult, false)
    self.Widget:K2_SetWorldLocation((inputLocation + location) / 2, false, SweepHitResult, false)
    local distance = UE.UKismetMathLibrary.Vector_Distance(location, inputLocation)
    local R = UE.UKismetMathLibrary.FindLookAtRotation(location, inputLocation)
    self.StartPoint:K2_SetWorldRotation(R, false, UE.FHitResult(), false)
    self.EndPoint:K2_SetWorldRotation(R, false, UE.FHitResult(), false)

    if control.bBuild then
        self.widgetUI.EText:SetVisibility(1)
    else
        self.widgetUI.Text:SetVisibility(1)
    end
    self.widgetUI.EText:SetText(tostring(DFL.integrate(distance)))
    self.widgetUI.Text:SetText(tostring(DFL.integrate(distance)))
    self.widgetUI.EText.OnTextCommitted:Add(self, self.MoveActor)

    self.control = control
    self.normal = normal
    if bAlign then
        self.StartPoint:SetMaterial(0, LoadObject('/Game/SandBox/Materials/M_Point2_Inst2.M_Point2_Inst2'))
        self.EndPoint:SetMaterial(0, LoadObject('/Game/SandBox/Materials/M_Point2_Inst2.M_Point2_Inst2'))
        self.Cable:SetMaterial(0, LoadObject('/Game/SandBox/Materials/M_Point2_Inst2.M_Point2_Inst2'))
    end
    if distance < 50 and self.control.clickType == 1 then
        return distance
    end
end

function M:MoveActor(Text)
    local num = tonumber(Text, 10)
    local l1 = self.Cable.StartLocation
    local l2 = self.Cable.EndLocation
    local l3 = UE.UKismetMathLibrary.Subtract_VectorVector(l2 + self.normal * num, l1)
    -- print(L3)
    self.control.undo:AddAction(2, self.control.buildActor)
    self.actor:K2_AddActorWorldOffset(l3, false, UE.FHitResult(), false)
    self.control.modelManage.gizmo:K2_AddActorWorldOffset(l3, false, UE.FHitResult(), false)
    self.control.undo:AddNewSize(self.control.buildActor)
    self.control.modelManage:BuildAllAroundLine(self.actor)
end

return M
