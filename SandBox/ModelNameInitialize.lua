local M = {}

---模型处理
---@param UE.TMap Actors  第一层级actor
---@param UE.TMap ChildActors 第二层级actor
function M.ModelLoadedInitial(self, Actors, ChildActors, LevelName)
    Actors:Clear()
    ChildActors:Clear()
    local DSAs = UE.UGameplayStatics.GetAllActorsOfClass(self:GetWorld(),
        UE.ADatasmithSceneActor)
    local DSA = nil
    if DSAs:Length() > 0 then
        for key, value in pairs(DSAs) do
            local Name = M.GetActorAccurateDisplayName(value)
            -- print(Name)
            if Name == "DatasmithSceneActor" or Name == LevelName then
                DSA = value
            end
        end
    end
    local AllActors = UE.TArray(UE.AActor)
    if DSA then
        local ChildActors = UE.TArray(UE.AActor)
        DSA:GetAttachedActors(ChildActors, true)
        if ChildActors:Num() > 0 then
            M.ModelFor(ChildActors, AllActors)
            --     for ka, va in pairs(a) do
            --         AllActors:Add(va)
            --         local b = UE.TArray(UE.AActor)
            --         va:GetAttachedActors(b, true)
            --         if b:Num() > 0 then
            --             for kb, vb in pairs(b) do
            --                 AllActors:Add(vb)
            --                 local c = UE.TArray(UE.AActor)
            --                 vb:GetAttachedActors(c, true)
            --                 if c:Num() > 0 then
            --                     for kc, vc in pairs(c) do
            --                         AllActors:Add(vc)
            --                         local d = UE.TArray(UE.AActor)
            --                         vc:GetAttachedActors(d, true)
            --                         if d:Num() > 0 then
            --                             for kd, vd in pairs(d) do
            --                                 AllActors:Add(vd)
            --                             end
            --                         end
            --                     end
            --                 end
            --             end
            --         end
            --     end
        end
    end
    for key, value in pairs(AllActors) do
        if value:Cast(UE.AStaticMeshActor) then
            local str2 = M.GetActorAccurateDisplayName(value)
            ChildActors:Add(str2, value)
        elseif not value:Cast(UE.ADirectionalLight) and not value:Cast(UE.ASkyLight) then
            local str1 = M.GetActorAccurateDisplayName(value)
            Actors:Add(str1, value)
        end
    end
end

-- 子集检测器
function M.ModelFor(Actors, AllActors)
    for kel, value in pairs(Actors) do
        AllActors:Add(value)
        local ChildActors = UE.TArray(UE.AActor)
        value:GetAttachedActors(ChildActors, true)
        if ChildActors:Num() > 0 then
            M.ModelFor(ChildActors, AllActors)
        end
    end
end

-- 子集里的静态网格体收集器
function M.GetChildOfStaticMeshActors(Actors, AllSTAs)
    for kel, value in pairs(Actors) do
        if value:Cast(UE.AStaticMeshActor) then
            AllSTAs:Add(value)
        else
            local ChildActors = UE.TArray(UE.AActor)
            value:GetAttachedActors(ChildActors, true)
            if ChildActors:Num() > 0 then
                M.GetChildOfStaticMeshActors(ChildActors, AllSTAs)
            end
        end
    end
end

---模型名称处理
---@param UE.AActor object
---@return string modelname
function M.GetActorAccurateDisplayName(object)
    local modelname = GobalFunc.GetName(object)
    local int = string.find(modelname, "_", 1, false)
    if int then
        modelname = string.sub(modelname, 1, int - 1)
    end
    return modelname
end

---设置生成的演员名称
---@param UE.AActor Actor
---@param string Name
function M.SetActorName(Actor, Name, showName)
    -- Actor:SetActorLabel(Name, false)
    UE.UMyBFL.ChangeDisplayName(Actor, Name)
    if Actor.modelType == "Group" and showName then
        Actor.showName = showName
    end

    -- local b = UE.UMyBFL.ChangeObjectName(Actor, Name)
    -- print(b)
    -- print(M.GetActorAccurateDisplayName(Actor))
end

--- 获取鼠标位置投射的射线起点、终点和方向向量
---@param pc UE.APlayerController 玩家控制器
---@return UE.FVector start 射线起点
---@return UE.FVector endP 射线终点
---@return UE.FVector worldDirection 射线世界方向向量
function M.GetLineValue(pc)
    -- 初始化射线起点
    local start = UE.FVector()
    -- 初始化射线世界方向向量
    local worldDirection = UE.FVector()
    -- 初始化反投影结果标志
    local res = false
    -- 将鼠标位置反投影到世界空间，获取射线起点和方向
    pc:DeprojectMousePositionToWorld(start, worldDirection, res)
    -- 定义射线长度
    local int = 200000000
    -- 计算射线终点
    local endP = start + worldDirection * int
    return start, endP, worldDirection
end

return M
