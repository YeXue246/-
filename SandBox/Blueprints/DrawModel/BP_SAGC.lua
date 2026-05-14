--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_SAGC_C
local M = UnLua.Class()
local Model = require("SandBox.ModelNameInitialize")
local DFL = require("SandBox.DataFunction")
local Class = require("SandBox.Class")

function M:Initialize(Initializer)
    self.modelType = 12
    self.clickType = 1
    self.modelCode = ""
    self.modelManage = nil
    -- self.showName = ""
    self.bMove = true
    self.animeTable = {}
end

function M:GetBox(Type)
    local Origin, BoxExtent = self:GetActorBounds(false)
    self.originalSize = BoxExtent * 2
    self.size = self.originalSize
    self.bBasic = Type ~= 3
    self.clickType = 1
end

-- 数据出
function M:ModelSave()
    if self.size == UE.FVector(0, 0, 0) then
        local Origin, BoxExtent = self:GetActorBounds(false)
        self.size = BoxExtent * 2
    end
    local table = {
        ["ModelCode"] = self.modelCode,
        ["OriginalSize"] = UE.UJsonLibraryHelpers.JsonValue_Stringify(
            UE.UJsonLibraryHelpers.FromVector(self.originalSize)),
        ["BSize"] = UE.UJsonLibraryHelpers.JsonValue_Stringify(UE.UJsonLibraryHelpers.FromVector(self.size)),
        ["bBasic"] = self.bBasic,
        ["CType"] = self.clickType,
        -- ["AnimationName"] = self.animationName,
        -- ["AnimationOrder"] = self.animationOrder,
        -- ["MaterialCode"] = self.materialCode,
        -- ["MaterialRatio"] = self.materialRatio,
        -- ["MColor"] = self.matColor and UE.UJsonLibraryHelpers.JsonValue_Stringify(
        -- UE.UJsonLibraryHelpers.FromLinearColor(self.matColor)) or nil,
    }
    return table
end

-- 数据进
function M:ModelLoad(table)
    local BS          = UE.UJsonLibraryHelpers.ToVector(UE.UJsonLibraryHelpers.Parse(table["BSize"]))
    local OS          = UE.UJsonLibraryHelpers.ToVector(UE.UJsonLibraryHelpers.Parse(table["OriginalSize"]))
    -- local MColor       = table["MColor"] and
    -- UE.UJsonLibraryHelpers.ToLinearColor(UE.UJsonLibraryHelpers.Parse(table["MColor"])) or nil

    self.modelCode    = table["ModelCode"]
    self.bBasic       = table["bBasic"]
    self.clickType    = table["CType"] ~= 0 and table["CType"] or self.clickType
    self.modelType    = table["Type"]
    -- self.animationName  = table["AnimationName"]
    -- self.animationOrder = table["AnimationOrder"]
    -- self.MaterialCode  = table["MaterialCode"]
    -- self.MaterialRatio = table["MaterialRatio"]

    self.size         = BS
    self.originalSize = OS
end

function M:TraceOtherModel()
    local Origin, BoxExtent = self:GetActorBounds(false)
    local ObjectTypes = UE.TArray(UE.EObjectTypeQuery)
    ObjectTypes:Add(UE.EObjectTypeQuery.WorldStatic)
    local ActorsToIgnore = UE.TArray(UE.AActor)
    ActorsToIgnore:Add(self)
    local bTrace = UE.UKismetSystemLibrary.BoxOverlapActors(self:GetWorld(), Origin, BoxExtent,
        ObjectTypes, UE.AStaticMeshActor, ActorsToIgnore, UE.TArray(UE.AActor))
    return bTrace
end

function M:SetData(table)
    self.size = table.Size
    table.T.Scale3D = table.Size / self.originalSize
    -- self.showName = table.showname
    self:GetAttachParentActor().showName = table.showname
    self:K2_SetActorTransform(table.T, false, UE.FHitResult(), false)
end

function M:SetAnimeData(table)
    self.animeTable = table
end

function M:GetData(CH)
    local T = self:GetTransform()
    local MDTV = {
        length      = DFL.integrate(self.size.X),
        width       = DFL.integrate(self.size.Y),
        height      = DFL.integrate(self.size.Z),
        -- top         = CH - DFL.integrate(self.size.Z),
        angle       = DFL.integrate(UE.UKismetMathLibrary.Quat_Rotator(T.Rotation).Yaw),
        x           = DFL.integrate(T.Translation.X),
        y           = DFL.integrate(T.Translation.Y),
        z           = DFL.integrate(T.Translation.Z),
        bBasic      = self.bBasic,
        -- showname      = self.showName,
        showname    = self:GetAttachParentActor().showName,
        bMove       = self.bMove,
        bAnimation  = true,
        modelCode   = self.modelCode,
        bConfigPlay = self.bPlaying,
        animeData   = self.animeTable
        -- materialCode  = self.materialCode,
        -- r             = self.matColor and DFL.integrate(self.matColor.r * 255) or nil,
        -- g             = self.matColor and DFL.integrate(self.matColor.g * 255) or nil,
        -- b             = self.matColor and DFL.integrate(self.matColor.b * 255) or nil,
        -- materialRatio = self.materialRatio,
    }
    return MDTV
end

function M:CheckStopTimer()
    UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.CheckStop }, 1, false)
end

function M:CheckStop()
    if self.SkeletalMesh:IsPlaying() then
        self:CheckStopTimer()
    elseif self.bPlaying then
        self.StopOutEvent:Broadcast(Model.GetActorAccurateDisplayName(self))
    else
        self.StopOutWeb:Broadcast(Model.GetActorAccurateDisplayName(self))
    end
end

function M:PlayAnimation(bLoop, animationCode)
    if self.bPlaying and animationCode then
        return
    end
    animationCode = animationCode or self.animationName
    local url = self:FindAnime(animationCode)
    if url then
        self.SkeletalMesh:PlayAnimation(LoadObject(url), bLoop)
        self.SkeletalMesh:SetPlayRate(1)
    end
end

-- 查找动画
function M:FindAnime(animationCode)
    if not self.modelManage then
        self.modelManage = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(), LoadClass(Class.modelManage))
    end
    return self.modelManage:FindAnime(animationCode)
end

function M:StopAnimation(animationCode)
    if self.bPlaying and animationCode then
        return
    end
    self.SkeletalMesh:Stop()
end

return M
