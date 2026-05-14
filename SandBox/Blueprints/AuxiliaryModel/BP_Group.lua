--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_Group_C
local M = UnLua.Class()
local DFL = require("SandBox.DataFunction")
local Model = require("SandBox.ModelNameInitialize")


function M:Initialize(Initializer)
    self.Code = "Group"
    self.modelType = "Group"
    self.showName = "组"
    self.bMove = true
    self.bhandle = true
    self.bGroup = false
    self.clickType = 1
end

-- 数据出
function M:ModelSave()
    local table = {
        ["bGroup"] = self.bGroup,
        ["bhandle"] = self.bhandle,
        ["bMove"] = self.bMove,
    }
    return table
end

-- 数据进
function M:ModelLoad(table)
    self.bGroup = table["bGroup"]
    self.bhandle = table["bhandle"]
    self.bMove = table["bMove"]
end

function M:SetData(table)
    self.showName = table.showname
    local T = UE.UKismetMathLibrary.Conv_RotatorToTransform(UE.FRotator(0, table.angle, 0))
    T.Translation = UE.FVector(table.x, table.y, table.z)
    self:K2_SetActorTransform(T, false, nil, false)
end

function M:GetData()
    local T = self:GetTransform()
    local MDTV = {
        showname = self.showName,
        angle = DFL.integrate(UE.UKismetMathLibrary.Quat_Rotator(T.Rotation).Yaw),
        x = DFL.integrate(T.Translation.X),
        y = DFL.integrate(T.Translation.Y),
        z = DFL.integrate(T.Translation.Z),
        bMove = self.bMove,
    }
    return MDTV
end


function M:Move()
    local childs = self:GetAttachedActors()
    local stas = UE.TArray(UE.AStaticMeshActor)
    Model.GetChildOfStaticMeshActors(childs, stas)
    for k, v in pairs(stas) do
        if v.clickType == 2 then
            v:Update(false)
        end
    end
end

return M
