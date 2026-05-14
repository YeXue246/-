--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_Catch_C
local M = UnLua.Class()

function M:Initialize(Initializer)
    self.bindActor = nil
end

function M:SetCatch(actor)
    self.bindActor = actor
    local origin, box = actor:GetActorBounds(true)
    -- local a = UE.FVector(origin.X + box.X, origin.Y + box.Y, origin.Z - box.Z)
    -- local b = UE.FVector(origin.X + box.X, origin.Y - box.Y, origin.Z - box.Z)
    -- local c = UE.FVector(origin.X - box.X, origin.Y - box.Y, origin.Z - box.Z)
    -- local d = UE.FVector(origin.X - box.X, origin.Y + box.Y, origin.Z - box.Z)
    local a = UE.FVector(box.X, box.Y, 0)
    local b = UE.FVector(box.X, -box.Y, 0)
    local c = UE.FVector(-box.X, -box.Y, 0)
    local d = UE.FVector(-box.X, box.Y, 0)
    -- print(a, b, c, d)
    local vertices = UE.TArray(UE.FVector)
    vertices:Add(a)
    vertices:Add(b)
    vertices:Add(c)
    vertices:Add(d)
    local indices = UE.TArray(0)
    indices:Add(0)
    indices:Add(1)
    indices:Add(2)
    indices:Add(0)
    indices:Add(2)
    indices:Add(3)
    self.PMesh:CreateMeshSection(0, vertices, indices, nil, nil, nil, nil, false)
    self.PMesh:SetMaterial(0, LoadObject('/Game/SandBox/Materials/Catch.Catch'))
    for i = 1, 4 do
        self:AddBoxPoint(vertices[i])
        a = i
        b = i + 1 > 4 and 1 or i + 1
        self:AddSpherePoint((vertices[a] + vertices[b]) / 2)
    end
end

return M
