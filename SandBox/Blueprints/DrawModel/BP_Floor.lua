--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_Floor_C
local M = UnLua.Class()

function M:Initialize(Initializer)
    self.High = 0
    self.modelType = 1
    self.FName = ""
    -- self.showName = ""
    self.bMove = false
end

function M:CreateFloor()
    local Vertices = UE.TArray(UE.FVector)
    Vertices:Add(UE.FVector(200000, 200000, 0))
    Vertices:Add(UE.FVector(-200000, 200000, 0))
    Vertices:Add(UE.FVector(-200000, -200000, 0))
    Vertices:Add(UE.FVector(200000, -200000, 0))
    local Triangles = UE.TArray(0)
    Triangles:Add(0)
    Triangles:Add(2)
    Triangles:Add(1)
    Triangles:Add(0)
    Triangles:Add(3)
    Triangles:Add(2)
    local Normals = UE.TArray(UE.FVector)
    Normals:Add(UE.FVector(0, 0, 1))
    Normals:Add(UE.FVector(0, 0, 1))

    local Vertices1 = UE.TArray(UE.FVector)
    Vertices1:Add(UE.FVector(200000, 200000, 0))
    Vertices1:Add(UE.FVector(-200000, 200000, 0))
    Vertices1:Add(UE.FVector(-200000, -200000, 0))
    Vertices1:Add(UE.FVector(200000, -200000, 0))
    Vertices1:Add(UE.FVector(200000, 200000, -40))
    Vertices1:Add(UE.FVector(-200000, 200000, -40))
    Vertices1:Add(UE.FVector(-200000, -200000, -40))
    Vertices1:Add(UE.FVector(200000, -200000, -40))
    local Triangles1 = UE.TArray(0)
    Triangles1:Add(1)
    Triangles1:Add(0)
    Triangles1:Add(4)
    Triangles1:Add(4)
    Triangles1:Add(1)
    Triangles1:Add(5)

    Triangles1:Add(2)
    Triangles1:Add(1)
    Triangles1:Add(5)
    Triangles1:Add(5)
    Triangles1:Add(2)
    Triangles1:Add(6)

    Triangles1:Add(3)
    Triangles1:Add(2)
    Triangles1:Add(6)
    Triangles1:Add(6)
    Triangles1:Add(3)
    Triangles1:Add(7)

    Triangles1:Add(0)
    Triangles1:Add(3)
    Triangles1:Add(7)
    Triangles1:Add(7)
    Triangles1:Add(0)
    Triangles1:Add(4)


    local Normals1 = UE.TArray(UE.FVector)
    Normals1:Add(UE.FVector(1, 0, 0))
    Normals1:Add(UE.FVector(0, 1, 0))
    Normals1:Add(UE.FVector(0, -1, 0))
    Normals1:Add(UE.FVector(-1, 0, 0))

    self.PMesh:ClearAllMeshSections()

    -- local Vertices = UE.TArray(UE.FVector)
    -- local Triangles = UE.TArray(0)
    -- local Normals = UE.TArray(UE.FVector)
    -- local UVs = UE.TArray(UE.FVector2D)
    -- local VertexColors = UE.TArray(UE.FColor)
    -- local Tangents = UE.TArray(UE.FVector)
    -- UE.UKismetProceduralMeshLibrary.GenerateBoxMesh(UE.FVector(200000, 200000, 20), Vertices,
    --     Triangles, Normals, UVs, Tangents)

    -- for key, value in pairs(Vertices) do
    --     value.Z = value.Z - 10
    -- end

    -- 更新地板网格
    self.PMesh:CreateMeshSection(0, Vertices, Triangles, Normals, nil, nil, nil, true)
    self.PMesh:CreateMeshSection(1, Vertices1, Triangles1, Normals1, nil, nil, nil, true)

    self.PMesh:SetMaterial(0, LoadObject("/Game/SandBox/Materials/M_Floor_Inst.M_Floor_Inst"))
    self.PMesh:SetMaterial(1, LoadObject("/Game/SandBox/Materials/M_Bai.M_Bai"))
end

function M:ClearFloor()
    self.PMesh:ClearAllMeshSections()
end

function M:ModelSave()
    local table = {
        ["High"] = self.High,
        ["FName"] = self.FName,
    }
    return table
end

function M:ModelLoad(table)
    self.High      = table["High"]
    self.FName     = table["FName"]
    self.modelType = table["Type"]
    self.PMesh:ClearAllMeshSections()
    self:CreateFloor()
end

--- 获取地板参数
---@param FLength number 长度（单位：cm）
---@param FWith number 宽度（单位：cm）
---@param FHigh number 高度（单位：cm）
---@param High number 层高（单位：cm）
---@param Opacity number 透明度
function M:GetFloorData(FloorInt)
    local floorData = {
        floor = FloorInt,
        floorName = self.FName,
        height = self.High,
    }
    return floorData
end

--- 设置地板参数
---@param FLength number 长度（单位：cm）
---@param FWith number 宽度（单位：cm）
---@param FHigh number 高度（单位：cm）
---@param High number 层高（单位：cm）
---@param Opacity number 透明度
function M:SetData(FT)
    self.PMesh:ClearAllMeshSections()
    self:CreateFloor()

    -- 更新高度和名称
    self.High = FT.High
    if FT.FName ~= "" then
        self.FName = FT.FName
    end
end

return M
