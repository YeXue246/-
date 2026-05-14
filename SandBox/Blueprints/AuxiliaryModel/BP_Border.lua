--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_Border_C
local M = UnLua.Class()

function M:Initialize(Initializer)

end

function M:SetModel(actor, hitResult)
    local origin, box = actor:GetActorBounds(true)
    local face, width, height = self:GetCollisionDirection(hitResult, box * 2)

    self.SimpleSpline:ClearSplinePoints()
    self.SimpleSpline:AddSplinePoint(UE.FVector(width / 2, height / 2, 0), 0, true)
    self.SimpleSpline:SetSplinePointType(0, 0, false)
    self.SimpleSpline:AddSplinePoint(UE.FVector(-width / 2, height / 2, 0), 0, true)
    self.SimpleSpline:SetSplinePointType(1, 0, false)
    self.SimpleSpline:AddSplinePoint(UE.FVector(-width / 2, -height / 2, 0), 0, true)
    self.SimpleSpline:SetSplinePointType(2, 0, false)
    self.SimpleSpline:AddSplinePoint(UE.FVector(width / 2, -height / 2, 0), 0, true)
    self.SimpleSpline:SetSplinePointType(3, 0, false)


    self.Plane:CreateMesh(self.SimpleSpline, 0, 0)
    self.Box:CreateWall(10, 10, self.SimpleSpline)
    local rota = UE.FRotator(0, 0, 0)
    local location = origin
    if face == 1 then
        rota = UE.FRotator(0, 0, 90)
        location.Y = location.Y + box.Y
    elseif face == 2 then
        rota = UE.FRotator(0, 0, -90)
        location.Y = location.Y - box.Y
    elseif face == 3 then
        rota = UE.FRotator(-90, 0, 0)
        location.X = location.X + box.X
    elseif face == 4 then
        rota = UE.FRotator(90, 0, 0)
        location.X = location.X - box.X
    else
        location.Z = location.Z + box.Z
    end
    self:k2_SetActorLocation(location, false, nil, false)
    self:K2_SetActorRotation(rota, false, nil, false)
    self:SetMat(0)
end

function M:GetCollisionDirection(hitResult, box)
    -- 获取碰撞点的法线
    local normal = hitResult.ImpactNormal

    local forward = UE.FVector(0, 1, 0)
    local right = UE.FVector(1, 0, 0)
    local up = UE.FVector(0, 0, 1)

    -- 计算法线在各个方向上的投影
    local dotForward = UE.UKismetMathLibrary.Dot_VectorVector(normal, forward)
    local dotRight = UE.UKismetMathLibrary.Dot_VectorVector(normal, right)
    local dotUp = UE.UKismetMathLibrary.Dot_VectorVector(normal, up)

    -- 判断碰撞点的方向
    if math.abs(dotForward) > math.abs(dotRight) and math.abs(dotForward) > math.abs(dotUp) then
        local width, length = box.X, box.Z
        if dotForward > 0 then
            return 1, width, length
        else
            return 2, width, length
        end
    elseif math.abs(dotRight) > math.abs(dotForward) and math.abs(dotRight) > math.abs(dotUp) then
        local width, length = box.Z, box.Y
        if dotRight > 0 then
            return 3, width, length
        else
            return 4, width, length
        end
    else
        local width, length = box.X, box.Y
        return 5, width, length
    end
end

function M:SetMat(type)
    if not UE.UKismetSystemLibrary.IsValid(self.boxMat) then
        local matObject = LoadObject('/Game/SandBox/Materials/M_Border.M_Border')
        self.boxMat = UE.UKismetMaterialLibrary.CreateDynamicMaterialInstance(self:GetWorld(), matObject, "", 0)
        self.Box:SetMaterial(0, self.boxMat)
        self.boxMat:SetVectorParameterValue("Color", UE.FLinearColor(1, 0.5, 0, 1))

        self.planeMat = UE.UKismetMaterialLibrary.CreateDynamicMaterialInstance(self:GetWorld(), matObject, "", 0)
        self.Plane:SetMaterial(0, self.planeMat)
        self.planeMat:SetVectorParameterValue("Color", UE.FLinearColor(0, 1, 0.5, 1))
    end
    if type == 0 then
        self.boxMat:SetScalarParameterValue("Param", 0.1)
        self.planeMat:SetScalarParameterValue("Param", 0.1)
    elseif type == 1 then
        self.boxMat:SetScalarParameterValue("Param", 0.5)
        self.planeMat:SetScalarParameterValue("Param", 0.1)
    elseif type == 2 then
        self.boxMat:SetScalarParameterValue("Param", 0.1)
        self.planeMat:SetScalarParameterValue("Param", 0.5)
    end
end

function M:Trace(traceStart, traceEnd)
    local objectT = {
        self.Box,
        self.Plane,
    }
    for k, v in pairs(objectT) do
        local hitLocation = UE.FVector()
        local bHit = v:K2_LineTraceComponent(traceStart, traceEnd, false, false, false, hitLocation, nil, "", nil)
        if bHit then
            self:SetMat(k)
            if k == 1 then
                hitLocation = self.SimpleSpline:FindLocationClosestToWorldLocation(hitLocation, 1)
            end
            return hitLocation
        end
    end
end

return M
