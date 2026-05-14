--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_SplineBZ_C
local M = UnLua.Class()
local DFL = require("SandBox.DataFunction")

-- function M:Initialize(Initializer)
-- end

-- function M:UserConstructionScript()
-- end

function M:ReceiveBeginPlay()
    self.widgetUI = self.Widget:GetWidget()
end

-- function M:ReceiveTick(DeltaSeconds)
-- end

function M:SetSplineBZ(Point, control, ModelRadius)
    local L = self:K2_GetActorLocation()
    local Location = Point:K2_GetActorLocation()

    local D = UE.UKismetMathLibrary.Vector_Distance(L, Location)
    local SweepHitResult = UE.FHitResult()
    self.EndPoint:K2_SetRelativeLocation(UE.FVector(0, D, 0), false, SweepHitResult, false)
    self.Widget:K2_SetRelativeLocation(UE.FVector(-180, D / 2, 0), false, SweepHitResult, false)
    self.Scene:K2_SetRelativeLocation(UE.FVector(0, ModelRadius, 0), false, SweepHitResult, false)
    self.Cable.EndLocation = self.EndPoint:K2_GetComponentLocation() - L


    local R = UE.UKismetMathLibrary.FindLookAtRotation(L, Location)
    self:K2_SetActorRotation(R, false, UE.FHitResult(), false)

    -- self.widgetUI.EText:SetText(tostring(DFL.integrate(D)))
    -- self.widgetUI.EText.OnTextCommitted:Add(Point, Point.MovePoint)

    if control.bBuild then
        self.widgetUI.EText:SetText(tostring(DFL.integrate(D)))
        self.widgetUI.EText:SetIsReadOnly(true)
    else
        self.widgetUI.EText:SetText(tostring(DFL.integrate(D)))
        self.widgetUI.EText.OnTextCommitted:Add(Point, Point.MovePoint)
    end
end

return M
