--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_Multi_C
local M = UnLua.Class()
local Model = require("SandBox.ModelNameInitialize")
local Class = require("SandBox.Class")


function M:Initialize(Initializer)
    self.modelType = "Multi"
    self.bMove = true
    self.Location = nil
    self.bActorMove = false
end

function M:ReceiveTick(DeltaSeconds)
    if self.Location then
        local Location = self:K2_GetActorLocation()
        if not UE.UKismetMathLibrary.EqualEqual_VectorVector(Location, self.Location, 0.01) then
            self.bActorMove = true
            self:Move(Location - self.Location)
            self.Location = Location
            if not self.control then
                self.control = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(),
                    LoadClass(Class.control))
            end
        elseif self.bActorMove and self.control and not self.control.modelManage.gizmo.WasMouseDown then
            if self.MultiActors:Num() > 0 then
                self.control.undo:AddNewSize(self)
                self.bActorMove = false
            end
        end
    end
end

function M:Select(bValue)
    if self.STCActors:Num() <= 0 then
        self:CollectStaticMeshActor(self.MultiActors)
    end
    self:SetDepth(bValue)
    if bValue then
        -- print("Multi", self.STCActors:Num())
        local O, B = UE.UGameplayStatics.GetActorArrayBounds(self.STCActors, true)
        self.Location = O
        self:K2_SetActorLocation(self.Location, false, nil, false)
    else
        self:K2_DestroyActor()
    end
end

function M:CollectStaticMeshActor(Actors)
    for k, val in pairs(Actors) do
        if val.modelType == "Group" then
            local Childs = UE.TArray(UE.AActor)
            val:GetAttachedActors(Childs, true)
            self:CollectStaticMeshActor(Childs)
        elseif val:Cast(UE.AStaticMeshActor) then
            self.STCActors:Add(val)
        end
    end
end

function M:SetDepth(bValue)
    for k, val in pairs(self.STCActors) do
        local Components = val.RootComponent:GetChildrenComponents(true)
        Components:Add(val.RootComponent)
        for key, value in pairs(Components) do
            if value:Cast(UE.UPrimitiveComponent) then
                value:SetRenderCustomDepth(bValue)
            end
        end
    end
end

function M:Delete(control)
    for key, value in pairs(self.MultiActors) do
        if value then
            control.modelManage.ModelDelete[value.modelType](value, control)
        end
    end
    self:K2_DestroyActor()
end

function M:Move(Location)
    for key, value in pairs(self.MultiActors) do
        -- print(Model.GetActorAccurateDisplayName(value))
        if string.find(Model.GetActorAccurateDisplayName(value), "Group") ~= nil then
            value:K2_AddActorWorldOffset(Location, false, nil, false)
        elseif value.modelType == "Group" then
            -- local ChildActors = UE.TArray(UE.AActor)
            -- value:GetAttachedActors(ChildActors, true)
            -- print(value.showName,key)
            value:K2_AddActorWorldOffset(Location, false, nil, false)
        end
    end
    -- local t = { 4, 5, 6, 7, 13 }
    for k, v in pairs(self.STCActors) do
        if v.clickType == 2 then
            v:Update(false)
        end
    end
end

return M
