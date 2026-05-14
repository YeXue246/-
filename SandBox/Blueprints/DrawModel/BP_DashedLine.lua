--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_DashedLine_C
local M = UnLua.Class()
local DFL = require("SandBox.DataFunction")

--- 虚线模型组件
--- @class BP_DashedLine
--- @field radius number 虚线半径
--- @field length number 虚线长度
--- @field width number 虚线宽度
--- @field bOverall boolean 是否整体模式
--- @field simplePoints UE.TArray<UE.FVector> 简化点集
--- @field points UE.TArray<UE.FVector> 完整点集
--- @field tangents UE.TArray<UE.FVector> 切线向量集
--- @field modelType number 模型类型ID(13=虚线)
--- @field clickType number 点击类型ID(2=?)
--- @field bBuild boolean 是否建造模式
--- @field bMove boolean 是否可移动
--- @field modelCode string 模型代码("DashedLine")

--- 初始化虚线模型
--- @function Initialize
--- @param Initializer any 初始化参数
--- @description
---   设置虚线模型的默认参数:
---   1. 几何尺寸(半径5,长度200,宽度5)
---   2. 点集容器初始化
---   3. 模型类型和交互设置
---   4. 默认颜色(白色实体,橙色虚线)
function M:Initialize(Initializer)
    -- 几何参数
    self.radius         = 5
    self.length         = 200
    self.width          = 5
    self.bOverall       = true

    -- 点集容器
    self.simplePoints   = UE.TArray(UE.FVector)
    self.points         = UE.TArray(UE.FVector)
    self.tangents       = UE.TArray(UE.FVector)

    -- 模型标识
    self.modelType      = 13
    self.clickType      = 2
    self.bBuild         = true
    self.bMove          = true
    self.modelCode      = "DashedLine"

    -- 文本和颜色
    self.text           = ""
    self.textSize       = 16
    self.color          = UE.FLinearColor(1, 1, 1, 1)    -- 白色
    self.lineColor      = UE.FLinearColor(1, 0.32, 0, 1) -- 橙色
    self.textOffsetSize = UE.FVector(0, 0, 0)            -- 文本偏移
end

--- 游戏开始事件
--- @function ReceiveBeginPlay
--- @description
---   1. 初始化虚线厚度
---   2. 获取UI组件引用
---   3. 缓存玩家Pawn引用
function M:ReceiveBeginPlay()
    self:Thickness()                                                  -- 设置虚线厚度
    self.widgetUI = self.Widget:GetWidget()                           -- 获取UI组件
    self.pawn = UE.UGameplayStatics.GetPlayerPawn(self:GetWorld(), 0) -- 玩家Pawn
end

--- 每帧更新
--- @function ReceiveTick
--- @param DeltaSeconds number 帧间隔时间
--- @description
---   当存在文本时:
---   1. 根据玩家视角旋转调整文本朝向
---   2. 保持文本始终面向玩家
function M:ReceiveTick(DeltaSeconds)
    if self.text ~= "" then
        local r = self.pawn:GetControlRotation()
        self.Widget:K2_SetWorldRotation(UE.FRotator(-r.Pitch + 5, r.Yaw + 180, 0), false, nil, false)
    end
end

--- 序列化模型数据
--- @function ModelSave
--- @return table 包含序列化数据的表
--- @description
---   输出当前模型状态:
---   1. 点击类型
---   2. 简化点集位置
---   3. 文本内容和样式
---   4. 颜色配置
function M:ModelSave()
    local pointLocations = {}
    for key, value in pairs(self.simplePoints) do
        pointLocations[key] = DFL.fromVector(value)
    end
    local table = {
        ["CType"] = self.clickType,
        ["PointLocations"] = pointLocations,
        ["Text"] = self.text,
        ["TSize"] = self.textSize,
        ["TextOffsetSize"] = DFL.fromVector(self.textOffsetSize),
        ["Color"] = DFL.fromColor(self.color),
        ["lineColor"] = DFL.fromColor(self.lineColor),
    }
    return table
end

--- 反序列化模型数据
--- @function ModelLoad
--- @param table table 包含反序列化数据的表
--- @description
---   加载模型状态:
---   1. 恢复点击类型和模型类型
---   2. 恢复文本配置
---   3. 恢复点集位置
---   4. 应用材质和模型
function M:ModelLoad(table)
    -- 基础属性
    self.clickType      = table["CType"] ~= 0 and table["CType"] or self.clickType

    -- 文本属性
    self.text           = table["Text"]
    self.textSize       = table["TSize"]
    self.textOffsetSize = DFL.toVector(table["TextOffsetSize"])

    -- 颜色属性
    self.color          = DFL.toColor(table["Color"])
    self.lineColor      = table["lineColor"] and DFL.toColor(table["lineColor"]) or self.lineColor

    -- 点集恢复
    self.simplePoints:Clear()
    local lStrs = table["PointLocations"]
    for _, value in pairs(lStrs) do
        local l = DFL.toVector(value)
        self.simplePoints:Add(l)
    end

    -- 应用状态
    self:SetSplineModelMaterial()
    self:SetSplineModel()
    self:SetMessage()
    self.textOffsetSize.Z = 100
    self.Widget:K2_SetRelativeLocation(self.textOffsetSize, false, nil, false)
end

--- 获取可编辑数据
--- @function GetData
--- @return table 包含可编辑数据的表
--- @description
---   输出当前可编辑参数:
---   1. 位置坐标
---   2. 文本偏移
---   3. 文本内容
---   4. 颜色值(RGBA)
---   5. 字体大小
function M:GetData()
    local location = self:K2_GetActorLocation()
    local outTable =
    {
        x        = DFL.integrate(location.X),
        y        = DFL.integrate(location.Y),
        z        = DFL.integrate(location.Z),
        ox       = DFL.integrate(self.textOffsetSize.X),
        oy       = DFL.integrate(self.textOffsetSize.Y),
        text     = self.text,
        r        = DFL.integrate(self.color.R * 255),
        g        = DFL.integrate(self.color.G * 255),
        b        = DFL.integrate(self.color.B * 255),
        a        = DFL.integrate(self.color.A * 100),
        lr       = DFL.integrate(self.lineColor.R * 255),
        lg       = DFL.integrate(self.lineColor.G * 255),
        lb       = DFL.integrate(self.lineColor.B * 255),
        la       = DFL.integrate(self.lineColor.A * 100),
        fontSize = self.textSize,
        showname = self:GetAttachParentActor().showName,
        bMove    = self.bMove,
    }
    return outTable
end

--- 虚线模型组件数据设置
--- @function SetData
--- @param table table 包含外部数据的表
--- @description
---   从外部数据更新虚线模型状态:
---   1. 更新模型位置(x/y/z坐标)
---   2. 更新文本偏移量(ox/oy坐标)
---   3. 更新实体颜色(r/g/b/a值)
---   4. 更新虚线颜色(lr/lg/lb/la值)
---   5. 更新文本内容和字体大小
---   6. 更新父Actor显示名称
---   7. 调用SetMessage刷新显示
function M:SetData(table)
    -- 位置更新
    local location = UE.FVector(table.x, table.y, table.z)
    if not UE.UKismetMathLibrary.EqualEqual_VectorVector(location, self:K2_GetActorLocation(), 0.5) then
        self:K2_SetActorLocation(location, false, nil, false)
    end

    -- 文本偏移更新
    local offset = UE.FVector(table.ox, table.oy, 0)
    if not UE.UKismetMathLibrary.EqualEqual_VectorVector(offset, self.textOffsetSize, 1) then
        self.textOffsetSize = offset
        self.textOffsetSize.Z = 100 -- 固定Z轴偏移
        self.Widget:K2_SetRelativeLocation(self.textOffsetSize, false, nil, false)
    end

    -- 颜色更新
    local color = UE.FLinearColor(table.r / 255, table.g / 255, table.b / 255, table.a / 100)
    if not UE.UKismetMathLibrary.LinearColor_IsNearEqual(color, self.color, 0.01) then
        self.color = color
    end

    local lineColor = UE.FLinearColor(table.lr / 255, table.lg / 255, table.lb / 255, table.la / 100)
    if not UE.UKismetMathLibrary.LinearColor_IsNearEqual(lineColor, self.lineColor, 0.01) then
        self.lineColor = lineColor
    end

    -- 文本属性更新
    self.text = table.text
    self.textSize = table.fontSize
    self:GetAttachParentActor().showName = table.showname
    self:SetMessage() -- 应用文本更新
end

--- 更新文本显示
--- @function SetMessage
--- @description
---   1. 设置UI文本内容
---   2. 更新字体大小
---   3. 根据文本内容控制可见性
---   4. 应用文本颜色
---   5. 更新材质颜色
function M:SetMessage()
    self.widgetUI.Text:SetText(self.text)     -- 设置文本内容
    self.FontInfo.Size = self.textSize        -- 更新字体大小
    self.widgetUI.Text:SetFont(self.FontInfo) -- 应用字体

    -- 控制文本可见性(非空时显示)
    self.Widget:SetVisibility(self.text ~= "", false)

    -- 应用文本颜色
    self.CO.SpecifiedColor = self.color
    self.widgetUI.Text:SetColorAndOpacity(self.CO)

    self:SetColor() -- 更新材质颜色
end

--- 设置样条线材质实例
--- @function SetSplineModelMaterial
--- @description
---   1. 为虚线创建动态材质实例
---   2. 为平面创建动态材质实例
---   3. 将材质应用到平面组件
---   4. 调用SetColor初始化颜色
function M:SetSplineModelMaterial()
    -- 虚线材质实例
    self.materialInstance = self.PMesh:CreateDynamicMaterialInstance(0,
        LoadObject("/Game/SandBox/Materials/M_DashedLine.M_DashedLine"), nil)

    -- 平面材质实例
    self.materialInstancePlane = UE.UKismetMaterialLibrary.CreateDynamicMaterialInstance(self:GetWorld(),
        LoadObject("/Game/SandBox/Materials/M_Plane.M_Plane"), "", 0)

    self.Plane:SetMaterial(0, self.materialInstancePlane) -- 应用平面材质
    self:SetColor()                                       -- 初始化颜色
end

--- 更新材质颜色
--- @function SetColor
--- @description
---   将当前线条颜色应用到:
---   1. 平面材质实例
---   2. 虚线材质实例
function M:SetColor()
    self.materialInstancePlane:SetVectorParameterValue("Param", self.lineColor)
    self.materialInstance:SetVectorParameterValue("Param", self.lineColor)
end

--- 设置样条线模型数据
--- @function DataSetSplineModel
--- @param table table 包含样条线数据的表
--- @description
---   预留接口:
---   1. 解析位置数据
---   2. 根据更新标志决定是否刷新模型
function M:DataSetSplineModel(table)
    local location = UE.FVector(table.x, table.y, table.z)
    local bUpdate = false -- 更新标志

    if bUpdate then
        self:Update() -- 刷新模型
    end
end

--- 创建样条线模型
--- @function SetSplineModel
--- @description
---   当有足够控制点时(≥3个):
---   1. 更新简单样条线
---   2. 生成管道控制点
---   3. 创建复杂样条线
function M:SetSplineModel()
    if self.simplePoints:Num() >= 3 then
        self:UpdateLS()                -- 更新简单样条线
        self:PipelinePoint()           -- 生成管道控制点
        self:ComplexSplineGeneration() -- 创建复杂样条线
    end
end

--- 设置虚线厚度
--- @function Thickness
--- @description
---   创建圆形截面:
---   1. 清除现有样条点
---   2. 按8等分计算圆周点
---   3. 更新样条线
function M:Thickness()
    local segment = 8                      -- 8边形截面
    local degrees = 360 / segment          -- 每段角度

    self.SplineToSweep:ClearSplinePoints() -- 清除现有点

    -- 生成圆周点
    for i = 1, segment do
        local radians = (i - 1) * degrees * math.pi / 180 -- 角度转弧度
        local Y = self.radius * math.sin(radians)
        local Z = self.radius * math.cos(radians)
        self.SplineToSweep:AddSplinePoint(UE.FVector(0, Y, Z), 0, false)
    end

    self.SplineToSweep:UpdateSpline() -- 更新样条线
end

--- 更新模型
--- @function Update
--- @description
---   刷新模型状态:
---   1. 更新控制点
---   2. 生成管道控制点
---   3. 创建复杂样条线
function M:Update()
    self:UpdatePoint()             -- 更新控制点
    self:PipelinePoint()           -- 生成管道控制点
    self:ComplexSplineGeneration() -- 创建复杂样条线
end

--- 更新原点位置
--- @function UpdateOrigin
--- @description
---   计算虚线模型的中心位置并更新Actor位置:
---   1. 计算所有控制点的平均值作为中心点
---   2. 调整Z轴位置(减去第一个点的Z值)
---   3. 设置Actor到计算出的中心位置
function M:UpdateOrigin()
    local O = UE.FVector(0, 0, 0)
    for key, value in pairs(self.simplePoints) do
        O = UE.UKismetMathLibrary.Add_VectorVector(O, value)
    end
    O = O / self.simplePoints:Num()
    O.Z = O.Z - self.simplePoints[1].Z
    self:K2_SetActorLocation(O, false, nil, false)
    -- self.SimpleSpline:UpdateSpline()
    -- self.SplineAsPath:UpdateSpline()
end

--- 简单样条线点位布局算法
--- @function PointCount
--- @param aLocation UE.FVector 起点位置
--- @param bLocation UE.FVector 终点位置
--- @description
---   根据两点距离自动插入中间控制点:
---   1. 添加起点到控制点集
---   2. 根据管道类型确定半径值
---   3. X轴距离过大时插入X轴中间点
---   4. Y轴距离过大时插入Y轴中间点
---   5. Z轴距离过大时添加终点
---   6. 调用UpdateLS更新样条线
function M:PointCount(aLocation, bLocation)
    self.simplePoints:Add(aLocation)
    local angleRadius
    if self.PipeType == 1 then
        angleRadius = self.radius
    else
        angleRadius = self.width / 2
    end
    if math.abs(aLocation.X - bLocation.X) > angleRadius * 2 then
        local New = UE.FVector(bLocation.X, aLocation.Y, aLocation.Z)
        self.simplePoints:Add(New)
    end
    if math.abs(aLocation.X - bLocation.X) > angleRadius * 2 then
        local New = UE.FVector(bLocation.X, bLocation.Y, aLocation.Z)
        self.simplePoints:Add(New)
    end
    if math.abs(aLocation.Z - bLocation.Z) > angleRadius * 2 then
        self.simplePoints:Add(bLocation)
    end
    -- print(self.simplePoints:Num() .. "555")
    self:UpdateLS()
end

--- 更新简单样条线控制点
--- @function UpdateLS
--- @description
---   根据当前控制点集重建简单样条线:
---   1. 清除现有样条点
---   2. 遍历所有控制点添加到样条线
---   3. 设置每个点为线性类型
---   4. 更新样条线
function M:UpdateLS()
    self.SimpleSpline:ClearSplinePoints()
    for i = 1, self.simplePoints:Num() do
        -- print(self.simplePoints[i])
        self.SimpleSpline:AddSplinePointAtIndex(self.simplePoints[i], i - 1, 1, false)
        self.SimpleSpline:SetSplinePointType(i - 1, 0, false)
    end
    self.SimpleSpline:UpdateSpline()
end

--- 从样条线更新控制点集
--- @function UpdatePoint
--- @description
---   从简单样条线获取当前控制点位置:
---   1. 获取样条线点数
---   2. 清空现有控制点集
---   3. 遍历样条线获取每个点位置
---   4. 添加到控制点集
function M:UpdatePoint()
    local int = self.SimpleSpline:GetNumberOfSplinePoints()
    self.simplePoints:Clear()
    for i = 1, int do
        local L = self.SimpleSpline:GetLocationAtSplinePoint(i - 1, 1)
        print(L)
        self.simplePoints:Add(L)
    end
end

--- 生成管道控制点(带倒角)
--- @function PipelinePoint
--- @description
---   基于简单样条线生成带倒角的管道控制点:
---   1. 清空点和切线集
---   2. 遍历每个控制点计算倒角点
---   3. 处理相邻点距离判断
---   4. 添加计算后的点和切线
function M:PipelinePoint()
    self.points:Clear()
    self.tangents:Clear()
    local angleRadius = self.radius
    local num = self.simplePoints:Num()
    for i = 1, num do
        local a = i - 1 >= 1 and i - 1 or num
        local b = i + 1 <= num and i + 1 or 1
        local point1 = self:CalculateChamferPoint3D(
            self.simplePoints[a], self.simplePoints[i], angleRadius * 3)
        local point2 = self:CalculateChamferPoint3D(
            self.simplePoints[b], self.simplePoints[i], angleRadius * 3)
        if UE.UKismetMathLibrary.EqualEqual_VectorVector(point1, point2, 0.5) then
            self.points:Add(UE.FVector(point1.X, point1.Y, point1.Z))
            self:TangentsAdd(self.simplePoints[i], self.simplePoints[a], angleRadius)
        else
            self.points:Add(UE.FVector(point1.X, point1.Y, point1.Z))
            self:TangentsAdd(self.simplePoints[i], self.simplePoints[a], angleRadius)
            self.points:Add(UE.FVector(point2.X, point2.Y, point2.Z))
            self:TangentsAdd(self.simplePoints[b], self.simplePoints[i], angleRadius)
        end
    end
end

--- 添加切线向量
--- @function TangentsAdd
--- @param aLocation UE.FVector 起点
--- @param bLocation UE.FVector 终点
--- @param angleRadius number 半径值
--- @description
---   计算两点间的切线向量:
---   1. 获取两点方向向量并归一化
---   2. 根据距离调整切线长度
---   3. 添加到切线集
function M:TangentsAdd(aLocation, bLocation, angleRadius)
    local tangent = UE.UKismetMathLibrary.Subtract_VectorVector(aLocation, bLocation)
    tangent:Normalize()
    local distance = UE.UKismetMathLibrary.Vector_Distance(aLocation, bLocation)
    if distance > angleRadius then
        tangent = tangent * angleRadius * 6
    else
        tangent = tangent * angleRadius * 2
    end
    self.tangents:Add(tangent)
end

--- 生成复杂样条线
--- @function ComplexSplineGeneration
--- @description
---   根据处理后的控制点创建最终样条线:
---   1. 清空现有样条点
---   2. 根据点数确定曲线类型
---   3. 添加所有处理后的控制点
---   4. 设置曲线类型和切线
---   5. 创建扫掠网格和平面
---   6. 设置材质参数
function M:ComplexSplineGeneration()
    self.SplineAsPath:ClearSplinePoints()
    local PType = 1
    if self.points:Num() > 2 then
        PType = 3
    end
    for i = 1, self.points:Num() do
        -- print(self.points[i])
        self.SplineAsPath:AddSplinePointAtIndex(self.points[i], i - 1, 1, false)
        self.SplineAsPath:SetSplinePointType(i - 1, 4, false)
        self.SplineAsPath:SetTangentAtSplinePoint(i - 1, self.tangents[i], 1, false)
    end
    -- 确保样条线闭合，处理最后一个点的切线
    if self.points:Num() > 2 then
        self.SplineAsPath:SetClosedLoop(true, false)
    end
    self.SplineAsPath:UpdateSpline()
    self:CreateSweepMesh()
    self.Plane:CreateWall(self.width, self.length, self.SimpleSpline)
    self.materialInstance:SetVectorParameterValue("splineLength",
        UE.FLinearColor(0, self.SimpleSpline:GetSplineLength() / 30, 0, 1))
end

--- 计算3D空间中的倒角点位置
--- @function CalculateChamferPoint3D
--- @param point0 UE.FVector 起始点坐标
--- @param point1 UE.FVector 结束点坐标
--- @param ridus number 倒角半径值
--- @return UE.FVector 计算后的倒角点坐标
--- @description
---   根据两点坐标和倒角半径计算倒角位置:
---   1. 计算两点之间的直线距离
---   2. 获取从point0指向point1的单位方向向量
---   3. 判断半径是否小于两点距离:
---     - 是: 从point0沿方向向量偏移(距离-半径)得到倒角点
---     - 否: 直接返回point0作为倒角点
---   4. 返回计算后的倒角点坐标
function M:CalculateChamferPoint3D(point0, point1, ridus)
    local distance = UE.UKismetMathLibrary.Vector_Distance(point0, point1)         -- 计算两点距离
    local direction = UE.UKismetMathLibrary.GetDirectionUnitVector(point0, point1) -- 获取单位方向向量
    local chamferPoint = UE.FVector(0, 0, 0)                                       -- 初始化倒角点

    -- 根据半径与距离关系计算倒角点
    if ridus < distance then
        chamferPoint = point0 + direction * (distance - ridus) -- 沿方向向量偏移
    else
        chamferPoint = point0                                  -- 距离过小直接使用起点
    end

    return chamferPoint -- 返回计算结果
end

return M
