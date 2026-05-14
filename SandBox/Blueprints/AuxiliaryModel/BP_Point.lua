--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_Point_C
local M = UnLua.Class()
local DFL = require("SandBox.DataFunction")
local Class = require("SandBox.Class")
function M:Initialize(Initializer)
    self.KeyID = 0
    self.control = nil
    self.bMove = false
    self.matTable = {
        '/Game/SandBox/Materials/M_Light_Inst.M_Light_Inst',
        '/Game/SandBox/Materials/M_Light_Inst2.M_Light_Inst2',
    }
end

function M:ReceiveBeginPlay()
end

function M:ReceiveTick(DeltaSeconds)
    if self.LastPoint then
        local L = nil
        L = self:ShowData()
        if self.Location then
            if self:K2_GetActorLocation() ~= self.Location then
                self.Location = self:K2_GetActorLocation()
                if L then
                    self.Location = L
                    self:K2_SetActorLocation(self.Location, false, UE.FHitResult(), false)
                end
                if self.control.drawMode == "RegionArea" then
                    -- 协作区域模式：直接更新 curReg 的控制点并刷新样条，不走 buildActor 的 TTT 分发
                    self.control.curReg.simplePoints[self.KeyID] = self.Location
                    self.control.curReg:SetSplineModel()
                else
                    self.TTT[self.control.buildActor.modelType]()
                end
                self.bMove = true
            elseif self.bMove then
                -- RegionArea 模式下 buildActor 为 nil，ModelDataToView 会崩溃，跳过
                if self.control.drawMode ~= "RegionArea" then
                    self.control:ModelDataToView(true)
                end
                -- JL
                local undoClass = LoadClass(Class.undoClass)
                local undo = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(), undoClass)
                -- curReg 选中时以协作区域 Actor 为目标，否则仍用 buildActor
                local targetActor = self.control.drawMode == "RegionArea" and
                    self.control.curReg or self.control.buildActor
                undo:AddNewSize(targetActor)

                self.control.modelManage:ClearPointBZs()
                for key, value in pairs(self.control.modelManage.NubPoints) do
                    self.control.modelManage:BuildPointBZ(value, self.control)
                end
                self.bMove = false
            end
        end
    end
end

function M:ShowData()
    local LQ = self.LastPoint:K2_GetActorLocation()
    local LC = self:K2_GetActorLocation()

    local L = nil
    if math.abs(LQ.X - LC.X) < 20 then
        self:SetM(2)
        L = UE.FVector(LQ.X, LC.Y, LC.Z)
    elseif math.abs(LQ.Y - LC.Y) < 20 then
        self:SetM(2)
        L = UE.FVector(LC.X, LQ.Y, LC.Z)
    else
        self:SetM(1)
    end
    return L
end

function M:MovePoint(Text)
    local num = tonumber(Text, 10)
    local LC = self.LastPoint:K2_GetActorLocation()
    local Direction = UE.UKismetMathLibrary.Subtract_VectorVector(LC, self.Location)
    if UE.UKismetMathLibrary.NotEqual_VectorVector(Direction, UE.FVector(0, 0, 0), 0.01) then
        Direction:Normalize()
        local D = UE.UKismetMathLibrary.Vector_Distance(LC, self.Location)
        local d = DFL.integrate(D) - num
        local Ld = UE.UKismetMathLibrary.Multiply_VectorFloat(Direction, d)
        self.Location = UE.UKismetMathLibrary.Add_VectorVector(self.Location, Ld)
        print(Direction, self.Location)
        -- JL
        local undoClass = LoadClass(Class.undoClass)
        local undo = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(), undoClass)
        undo:AddAction(2, self.actor)
        self:K2_SetActorLocation(self.Location, false, UE.FHitResult(), false)
        if self.actor.bRec then
            local otherID = self.KeyID == 4 and 1 or self.KeyID + 1
            local otherP = self.control.modelManage.NubPoints:Find(otherID)
            local l = otherP:K2_GetActorLocation()
            -- print(otherP.Location, self.Location, 333333)
            if self.KeyID == 1 or self.KeyID == 3 then
                l.X = self.Location.X
            else
                l.Y = self.Location.Y
            end
            otherP:K2_SetActorLocation(l, false, UE.FHitResult(), false)
        end

        if self.actor.modelType then
            self.TTT[self.actor.modelType]()
        end
        undo:AddNewSize(self.actor)
        self.control:ModelDataToView(true)

        self.control.modelManage:CreateGizmo(self)
        self.control.modelManage:ClearPointBZs()
        for key, value in pairs(self.control.modelManage.NubPoints) do
            self.control.modelManage:BuildPointBZ(value, self.control)
        end
    end
end

function M:SetKey(Int, control)
    self.KeyID = Int
    self.control = control
    self.actor = self.control.drawMode == "RegionArea" and self.control.curReg or self.control.buildActor
    self.BindUI = self.Widget:GetWidget()
    self.BindUI.Key:SetText(self.KeyID)
    self.TTT = {
        [4] = function()
            self.control.buildActor.simplePoints[self.KeyID] = self.Location
            self.control.buildActor:SetSplineModel()
        end,
        [5] = function()
            self.control.buildActor.simplePoints[self.KeyID] = self.Location
            self.control.buildActor:SetSplineModel()
        end,
        [6] = function()
            self.control.buildActor.simplePoints[self.KeyID] = self.Location
            self.control.buildActor:SetSplineModel()
        end,
        [7] = function()
            self.control.buildActor.simplePoints[self.KeyID] = self.Location
            self.control.buildActor:SetSplineModel()
        end,
        [14] = function()
            self.control.buildActor.simplePoints[self.KeyID] = self.Location
            self.control.buildActor:SetSplineModel()
        end,
        [15] = function()
            self.control.buildActor.simplePoints[self.KeyID] = self.Location
            self.control.buildActor:SetSplineModel()
        end,
    }
    self.Location = self:K2_GetActorLocation()
end

function M:SetM(Nub)
    self.Sphere:SetMaterial(0, LoadObject(self.matTable[Nub]))
end

return M
