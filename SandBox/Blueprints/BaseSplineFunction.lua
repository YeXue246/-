---@class BaseSplineFunction
local BaseSplineFunction = {}

------------------------------------------- 样条线生成 -------------------------------------------

--- 计算3D空间中的倒角点位置
---@param point0 UE.FVector 起始点坐标
---@param point1 UE.FVector 结束点坐标
---@param radius number 倒角半径值
---@return UE.FVector 计算后的倒角点坐标
---@description 根据两点坐标和倒角半径计算倒角位置:
--- 1. 计算两点之间的直线距离
--- 2. 获取从point0指向point1的单位方向向量
--- 3. 判断半径是否小于两点距离:
---    - 是: 从point0沿方向向量偏移(距离-半径)得到倒角点
---    - 否: 直接返回point0作为倒角点
--- 4. 返回计算后的倒角点坐标
local function CalculateChamferPoint3D(point0, point1, radius)
    local distance = UE.UKismetMathLibrary.Vector_Distance(point0, point1)         -- 计算两点距离
    local direction = UE.UKismetMathLibrary.GetDirectionUnitVector(point0, point1) -- 获取单位方向向量
    local chamferPoint = UE.FVector(0, 0, 0)                                       -- 初始化倒角点

    -- 根据半径与距离关系计算倒角点
    if radius < distance then
        chamferPoint = point0 + direction * (distance - radius) -- 沿方向向量偏移
    else
        chamferPoint = point0                                   -- 距离过小直接使用起点
    end

    return chamferPoint -- 返回计算结果
end

--- 计算切线向量
---@param aLocation UE.FVector 起点
---@param bLocation UE.FVector 终点
---@param angleRadius number 半径值
---@return UE.FVector 计算得到的切线向量
---@description 计算两点间的切线向量:
--- 1. 获取两点方向向量并归一化
--- 2. 根据距离调整切线长度
local function CalculateTangent(aLocation, bLocation, angleRadius)
    local tangent = UE.UKismetMathLibrary.Subtract_VectorVector(aLocation, bLocation)
    tangent:Normalize()
    local distance = UE.UKismetMathLibrary.Vector_Distance(aLocation, bLocation)
    if distance > angleRadius then
        tangent = tangent * angleRadius * 6
    else
        tangent = tangent * angleRadius * 2
    end
    return tangent
end

--- 设置虚线厚度（创建圆形截面）
---@param splineToSweep any 扫掠样条线对象
---@param radius number 圆形截面半径
---@param segment number 截面分段数（默认8）
---@description 创建圆形截面:
--- 1. 清除现有样条点
--- 2. 按指定等分数计算圆周点
--- 3. 更新样条线
function BaseSplineFunction:CreateCircularCrossSection(splineToSweep, radius, segment)
    if not splineToSweep then
        return
    end
    segment = segment or 8            -- 默认8边形截面
    local degrees = 360 / segment     -- 每段角度

    splineToSweep:ClearSplinePoints() -- 清除现有点

    -- 生成圆周点
    for i = 1, segment do
        local radians = (i - 1) * degrees * math.pi / 180 -- 角度转弧度
        local Y = radius * math.sin(radians)
        local Z = radius * math.cos(radians)
        splineToSweep:AddSplinePoint(UE.FVector(0, Y, Z), 0, false)
    end

    splineToSweep:UpdateSpline() -- 更新样条线
end

--- 根据两点距离自动插值直角中间控制点（不含终点时不加终点）
---@param simplePoints UE.TArray<UE.FVector> 控制点数组（原地追加）
---@param aLocation UE.FVector 起点
---@param bLocation UE.FVector 终点
---@param angleRadius number 倒角半径
---@description 在 aLocation 与 bLocation 之间按直角折线规则插入中间点:
--- 1. 追加起点 aLocation
--- 2. 若 X 差 > angleRadius*2，插入 (bX, aY, aZ) 使路径先水平走
--- 3. 若 X 差 > angleRadius*2，插入 (bX, bY, aZ) 再水平走第二段
--- 4. 若 Z 差 > angleRadius*2，追加终点 bLocation
function BaseSplineFunction:AppendRightAnglePoints(simplePoints, aLocation, bLocation, angleRadius)
    simplePoints:Add(aLocation)
    if math.abs(aLocation.X - bLocation.X) > angleRadius * 2 then
        simplePoints:Add(UE.FVector(bLocation.X, aLocation.Y, aLocation.Z))
    end
    if math.abs(aLocation.X - bLocation.X) > angleRadius * 2 then
        simplePoints:Add(UE.FVector(bLocation.X, bLocation.Y, aLocation.Z))
    end
    if math.abs(aLocation.Z - bLocation.Z) > angleRadius * 2 then
        simplePoints:Add(bLocation)
    end
end

--- 更新简单样条线控制点
---@param simpleSpline any 简单样条线对象
---@param simplePoints UE.TArray<UE.FVector> 控制点数组
---@description 根据当前控制点集重建简单样条线:
--- 1. 清除现有样条点
--- 2. 遍历所有控制点添加到样条线
--- 3. 设置每个点为线性类型
--- 4. 更新样条线
function BaseSplineFunction:UpdateSimpleSpline(simpleSpline, simplePoints)
    if not simpleSpline then
        return
    end
    simpleSpline:ClearSplinePoints()
    for i = 1, simplePoints:Num() do
        simpleSpline:AddSplinePointAtIndex(simplePoints[i], i - 1, 1, false)
        simpleSpline:SetSplinePointType(i - 1, 0, false)
    end
    simpleSpline:UpdateSpline()
end

--- 从样条线更新控制点集
---@param simpleSpline any 简单样条线对象
---@param simplePoints UE.TArray<UE.FVector> 控制点数组（将被更新）
---@description 从简单样条线获取当前控制点位置:
--- 1. 获取样条线点数
--- 2. 清空现有控制点集
--- 3. 遍历样条线获取每个点位置
--- 4. 添加到控制点集
function BaseSplineFunction:UpdatePointsFromSpline(simpleSpline, simplePoints)
    if not simpleSpline then
        return
    end
    local int = simpleSpline:GetNumberOfSplinePoints()
    simplePoints:Clear()
    for i = 1, int do
        local L = simpleSpline:GetLocationAtSplinePoint(i - 1, 1)
        simplePoints:Add(L)
    end
end

--- 生成管道控制点(带倒角)
---@param simplePoints UE.TArray<UE.FVector> 原始控制点数组
---@param radius number 倒角半径
---@return UE.TArray<UE.FVector> 新的点位数组
---@return UE.TArray<UE.FVector> 新的切线数组
---@description 基于简单样条线生成带倒角的管道控制点:
--- 1. 遍历每个控制点计算倒角点
--- 2. 处理相邻点距离判断
--- 3. 添加计算后的点和切线
function BaseSplineFunction:GeneratePipelinePoints(simplePoints, radius)
    local points = UE.TArray(UE.FVector)
    local tangents = UE.TArray(UE.FVector)
    local angleRadius = radius
    local num = simplePoints:Num()

    for i = 1, num do
        local a = i - 1 >= 1 and i - 1 or num
        local b = i + 1 <= num and i + 1 or 1
        local point1 = CalculateChamferPoint3D(
            simplePoints[a], simplePoints[i], angleRadius*3)
        local point2 = CalculateChamferPoint3D(
            simplePoints[b], simplePoints[i], angleRadius*3)
        if UE.UKismetMathLibrary.EqualEqual_VectorVector(point1, point2, 0.5) then
            points:Add(UE.FVector(point1.X, point1.Y, point1.Z))
            tangents:Add(CalculateTangent(simplePoints[i], simplePoints[a], angleRadius))
        else
            points:Add(UE.FVector(point1.X, point1.Y, point1.Z))
            tangents:Add(CalculateTangent(simplePoints[i], simplePoints[a], angleRadius))
            points:Add(UE.FVector(point2.X, point2.Y, point2.Z))
            tangents:Add(CalculateTangent(simplePoints[b], simplePoints[i], angleRadius))
        end
    end

    return points, tangents
end

--- 生成管道控制点(带倒角，开放样条线)
---@param simplePoints UE.TArray<UE.FVector> 原始控制点数组
---@param angleRadius number 倒角半径
---@return UE.TArray<UE.FVector> 新的点位数组
---@return UE.TArray<UE.FVector> 新的切线数组
---@description 基于开放样条线生成带倒角的管道控制点（起点/终点保留原始位置，中间点计算倒角）:
--- 1. 遍历每个控制点
--- 2. 中间点: 计算前后倒角点并添加
--- 3. 起终点: 直接添加原始点位，分别计算起终切线
function BaseSplineFunction:GenerateOpenPipelinePoints(simplePoints, angleRadius)
    local points = UE.TArray(UE.FVector)
    local tangents = UE.TArray(UE.FVector)
    local num = simplePoints:Num()

    for i = 1, num do
        if i > 1 and i < num then
            -- 中间点：计算前后倒角点
            local point1 = CalculateChamferPoint3D(simplePoints[i - 1], simplePoints[i], angleRadius * 3)
            local point2 = CalculateChamferPoint3D(simplePoints[i + 1], simplePoints[i], angleRadius * 3)
            if UE.UKismetMathLibrary.EqualEqual_VectorVector(point1, point2, 0.5) then
                points:Add(UE.FVector(point1.X, point1.Y, point1.Z))
                tangents:Add(CalculateTangent(simplePoints[i], simplePoints[i - 1], angleRadius))
            else
                points:Add(UE.FVector(point1.X, point1.Y, point1.Z))
                tangents:Add(CalculateTangent(simplePoints[i], simplePoints[i - 1], angleRadius))
                points:Add(UE.FVector(point2.X, point2.Y, point2.Z))
                tangents:Add(CalculateTangent(simplePoints[i + 1], simplePoints[i], angleRadius))
            end
        else
            -- 起点/终点：直接使用原始点位
            points:Add(UE.FVector(simplePoints[i].X, simplePoints[i].Y, simplePoints[i].Z))
            if i == 1 then
                tangents:Add(CalculateTangent(simplePoints[i + 1], simplePoints[i], angleRadius))
            else
                tangents:Add(CalculateTangent(simplePoints[i], simplePoints[i - 1], angleRadius))
            end
        end
    end

    return points, tangents
end

--- 生成复杂样条线
---@param splineAsPath any 复杂样条线对象
---@param points UE.TArray<UE.FVector> 点位数组
---@param tangents UE.TArray<UE.FVector> 切线数组
---@param simpleSpline any 简单样条线对象（保留参数，供扩展使用，可为nil）
---@description 根据处理后的控制点创建最终样条线:
--- 1. 清空现有样条点
--- 2. 根据点数确定曲线类型
--- 3. 添加所有处理后的控制点
--- 4. 设置曲线类型和切线
--- 5. 点数大于2时自动闭合样条线
function BaseSplineFunction:GenerateComplexSpline(splineAsPath, points, tangents, simpleSpline)
    if not splineAsPath then
        return
    end
    splineAsPath:ClearSplinePoints()
    local PType = 1
    if points:Num() > 2 then
        PType = 3
    end
    for i = 1, points:Num() do
        splineAsPath:AddSplinePointAtIndex(points[i], i - 1, 1, false)
        splineAsPath:SetSplinePointType(i - 1, 4, false)
        splineAsPath:SetTangentAtSplinePoint(i - 1, tangents[i], 1, false)
    end
    -- 确保样条线闭合，处理最后一个点的切线
    if points:Num() > 2 then
        splineAsPath:SetClosedLoop(true, false)
    end
    splineAsPath:UpdateSpline()
end

return BaseSplineFunction
