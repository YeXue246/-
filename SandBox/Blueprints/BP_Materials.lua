--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_Materials_C
local M = UnLua.Class()

function M:SetCreateM(STA, Color, bTransparent)
    local CreateM = bTransparent and
        LoadObject("/Game/SandBox/Materials/M_CreateTransparent.M_CreateTransparent") or
        LoadObject("/Game/SandBox/Materials/M_Create.M_Create")

    local Nub = 0
    local Component = STA.StaticMeshComponent
    if STA.modelType == 12 then
        Component = STA.SkeletalMesh
    end
    local NubMax = Component:GetNumMaterials()
    while Nub < NubMax do
        Component:SetMaterial(Nub, CreateM)
        Nub = Nub + 1
    end
    -- if NubMax ~= 0 then
    --     while Nub < NubMax do
    --         STA.StaticMeshComponent:SetMaterial(Nub, CreateM)
    --         Nub = Nub + 1
    --     end
    -- else
    --     NubMax = STA.PMesh:GetNumMaterials()
    --     if not self.Ms then
    --         self.Ms = {}
    --         while Nub < NubMax do
    --             local M = STA.PMesh:GetMaterial(Nub)
    --             self.Ms:insert(M)
    --             STA.PMesh:SetMaterial(Nub, CreateM)
    --             Nub = Nub + 1
    --         end
    --     else
    --         while Nub < NubMax do
    --             STA.PMesh:SetMaterial(Nub, CreateM)
    --             Nub = Nub + 1
    --         end
    --     end
    -- end
    local MP = LoadObject("/Game/SandBox/Materials/MPC_All.MPC_All")
    UE.UKismetMaterialLibrary.SetVectorParameterValue(self:GetWorld(), MP, "CreateColor", Color)
end

function M:StoreM(STA)
    local Nub = 0
    local Component = STA.StaticMeshComponent
    if STA.modelType == 12 then
        Component = STA.SkeletalMesh
    end
    local NubMax = Component:GetNumMaterials()
    while Nub < NubMax do
        Component:SetMaterial(Nub, nil)
        Nub = Nub + 1
    end
    -- if NubMax ~= 0 then
    --     while Nub < NubMax do
    --         STA.StaticMeshComponent:SetMaterial(Nub, nil)
    --         Nub = Nub + 1
    --     end
    -- else
    --     print(#self.Ms)
    --     NubMax = STA.PMesh:GetNumMaterials()
    --     while Nub < NubMax do
    --         STA.PMesh:SetMaterial(Nub, self.Ms[Nub + 1])
    --         Nub = Nub + 1
    --     end
    --     self.Ms = nil
    -- end
end

return M
