--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@diagnostic disable: duplicate-set-field, duplicate-doc-field
---@class (partial) BP_RegionArea_C
local M = UnLua.Class()
local DFL = require("SandBox.DataFunction")
local Class = require("SandBox.Class")
local Model = require("SandBox.ModelNameInitialize")
local BaseSplineFunction = require("SandBox.Blueprints.BaseSplineFunction")

--- 区域模型组件
--- @class (partial) BP_RegionArea
--- @field radius number 虚线半径
--- @field length number 虚线长度
--- @field width number 虚线宽度
--- @field simplePoints UE.TArray<UE.FVector> 区域轮廓点列（仅平面点）
--- @field points UE.TArray<UE.FVector> 完整点集
--- @field tangents UE.TArray<UE.FVector> 切线向量集
--- @field modelType integer 模型类型标识(16=协作区域，多边形样条模型)
--- @field clickType number 点击类型ID(2=样条线绘制)
--- @field bBuild boolean 是否建造模式
--- @field modelCode string 模型代码("RegionArea")
--- @field showName string 区域展示名
--- @field ownerUserId string 区域拥有者
--- @field modelName string 区域在方案中的唯一标识

--- 重建样条线（生成控制点→构建复杂样条→刷新网格与材质参数）
--- @param self BP_RegionArea_C
local function RebuildSpline(self)
    self.points, self.tangents = BaseSplineFunction:GeneratePipelinePoints(self.simplePoints, self.radius)
    BaseSplineFunction:GenerateComplexSpline(self.SplineAsPath, self.points, self.tangents)
    self:CreateSweepMesh()
    self.Plane:CreateLineWall(self.length, self.SimpleSpline)
    self.materialInstance:SetVectorParameterValue("splineLength",
        UE.FLinearColor(0, self.SimpleSpline:GetSplineLength() / 30, 0, 1))
end

--- 初始化区域模型
--- @function Initialize
--- @param Initializer any 初始化参数
function M:Initialize(Initializer)
    -- 几何参数
    self.radius        = 10
    self.length        = 200
    self.width         = 10

    -- 点集容器
    self.simplePoints  = UE.TArray(UE.FVector)
    self.points        = UE.TArray(UE.FVector)
    self.tangents      = UE.TArray(UE.FVector)
    self.lineColor     = UE.FLinearColor(0.1, 0.6, 0.07, 1)
    self.currentPoint  = 1

    self.ownerUserId   = ""
    self.showName      = ""
    self.ownerUserName = ""
    self.userName      = ""
    self.time          = 0
end

--- 游戏开始事件：初始化截面厚度、获取control引用、设置材质
function M:ReceiveBeginPlay()
    BaseSplineFunction:CreateCircularCrossSection(self.SplineToSweep, self.radius, 8)
    self.control = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(), LoadClass(Class.control))
    self:SetSplineModelMaterial()
    self.PMesh:ClearAllMeshSections()

    self.widgetUI = self.Widget:GetWidget()                           -- 获取UI组件
    self.pawn = UE.UGameplayStatics.GetPlayerPawn(self:GetWorld(), 0) -- 玩家Pawn
    self.time = self.time == 0 and os.time() or self.time
end

--- 序列化模型数据
--- @return table
function M:ModelSave()
    local pointLocations = {}
    for key, value in pairs(self.simplePoints) do
        pointLocations[key] = DFL.fromVector(value)
    end
    return {
        ["PointLocations"] = pointLocations,
        ["showName"]       = self.showName,
        ["ownerUserId"]    = self.ownerUserId,
        ["userName"]       = self.userName,
        ["time"]           = self.time,
    }
end

--- 反序列化模型数据
--- @param table table
function M:ModelLoad(table)
    self.ownerUserId = table["ownerUserId"] or ""
    self.showName    = table["showName"] or self.showName
    self.userName    = table["userName"] or self.userName
    self.time        = table["time"] or self.time
    self.simplePoints:Clear()
    local lStrs = table["PointLocations"]
    if lStrs then
        for _, value in pairs(lStrs) do
            self.simplePoints:Add(DFL.toVector(value))
        end
    end

    self:SetSplineModelMaterial()
    self:SetSplineModel()
    self:SetMessage()
end

--- 获取可编辑数据
--- @return table
function M:GetData()
    return {
        ownerUserId = self.ownerUserId,
        showName    = self.showName,
        userName    = self.userName,
        modelName   = Model.GetActorAccurateDisplayName(self),
        time        = self.time,
    }
end

--- 从外部数据更新模型状态（位置、颜色、文本等）
--- @param table table
function M:SetData(table)
    -- 文本
    self.ownerUserId = table.ownerUserId
    self.showName = table.showName
    self.userName = table.userName
    self:SetMessage()
end

--- 更新文本显示（内容、字体、可见性、颜色）
function M:SetMessage()
    local text = (self.userName == "") and
        self.showName or (self.showName .. "_" .. self.userName)
    self.Widget:SetVisibility(true, false)
    self.widgetUI.Text:SetText(text)
end

--- 隐藏区域上的文本 Widget（用于进入“区域内编辑”模式时不再遮挡视图）
function M:HideMessage()
    if self.Widget then
        self.Widget:SetVisibility(false, false)
    end
end

--- 创建动态材质实例并初始化颜色
function M:SetSplineModelMaterial()
    if not self.modelManage then
        local mmClass = LoadClass(Class.modelManage)
        self.modelManage = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(), mmClass)
    end
    self.materialInstance = self.PMesh:CreateDynamicMaterialInstance(0,
        LoadObject("/Game/SandBox/Materials/M_DashedLine.M_DashedLine"), nil)

    self.materialInstancePlane = UE.UKismetMaterialLibrary.CreateDynamicMaterialInstance(self:GetWorld(),
        LoadObject("/Game/SandBox/Materials/M_Plane2.M_Plane2"), "", 0)

    self.Plane:SetMaterial(0, self.materialInstancePlane)
    self:SetColor()
end

--- 将当前线条颜色同步到平面与虚线材质
function M:SetColor()
    self.materialInstancePlane:SetVectorParameterValue("Param", self.lineColor)
    self.materialInstance:SetVectorParameterValue("Param", self.lineColor)
end

--- 预留接口：解析位置数据，根据更新标志刷新模型
--- @param table table
function M:DataSetSplineModel(table)
    local location = UE.FVector(table.x, table.y, table.z)
    local bUpdate  = false
    if bUpdate then self:Update() end
end

--- 加载时建立样条线（≥3点时：更新简单样条→重建）
function M:SetSplineModel()
    if self.simplePoints:Num() >= 2 then
        BaseSplineFunction:UpdateSimpleSpline(self.SimpleSpline, self.simplePoints)
        RebuildSpline(self)

        -- 根据点位数组居中设置WidgetUI位置
        -- local center = UE.FVector(0, 0, 0)
        -- for _, value in pairs(self.simplePoints) do
        --     center = UE.UKismetMathLibrary.Add_VectorVector(center, value)
        -- end
        -- center = center / self.simplePoints:Num()
        -- center.Z = center.Z + self.length * 0.5
        local position = self.simplePoints[1]
        position.Z = position.Z + 2
        self.Widget:K2_SetWorldLocation(position, false, nil, false)
    end
end

--- 运行时刷新样条线（从样条同步点集→重建）
function M:Update()
    BaseSplineFunction:UpdatePointsFromSpline(self.SimpleSpline, self.simplePoints)
    RebuildSpline(self)
end

--- 计算虚线模型中心并更新 Actor 位置
function M:UpdateOrigin()
    local O = UE.FVector(0, 0, 0)
    for _, value in pairs(self.simplePoints) do
        O = UE.UKismetMathLibrary.Add_VectorVector(O, value)
    end
    O   = O / self.simplePoints:Num()
    O.Z = O.Z - self.simplePoints[1].Z
    self:K2_SetActorLocation(O, false, nil, false)
end

--- 根据两点距离自动插值中间控制点，并更新简单样条线
--- @param aLocation UE.FVector 起点
--- @param bLocation UE.FVector 终点
function M:PointCount(aLocation, bLocation)
    local angleRadius = self.PipeType == 1 and self.radius or self.width / 2
    BaseSplineFunction:AppendRightAnglePoints(self.simplePoints, aLocation, bLocation, angleRadius)
    BaseSplineFunction:UpdateSimpleSpline(self.SimpleSpline, self.simplePoints)
end

--- 刷新样条模型并更新 Gizmo（公共逻辑）
local function RefreshSplineAndGizmo(self)
    self:SetSplineModel()
    self.modelManage:BuildPoint(self.simplePoints)
    if self.simplePoints:Find(self.currentPoint) <= 0 then
        self.currentPoint = 1
    end
    local point = self.modelManage.NubPoints:Find(self.currentPoint)
    self.modelManage:CreateGizmo(point)
end

--- 添加点
--- @param location UE.FVector 线段附近点位
function M:AddSplinePoint(location)
    local splinePoint = self.SimpleSpline:FindLocationClosestToWorldLocation(location, 1)
    local key = self.SimpleSpline:FindInputKeyClosestToWorldLocation(location)
    print("key", self.simplePoints:Num())
    self.simplePoints:Insert(splinePoint, math.ceil(key) + 1)
    print("key", self.simplePoints:Num())
    RefreshSplineAndGizmo(self)
end

--- 删除当前选中的点
function M:RemoveSplinePoint()
    -- 至少保留3个点才能形成区域
    if self.simplePoints:Num() > 3 then
        self.simplePoints:Remove(self.currentPoint) -- RemoveAt 使用0-based索引
        RefreshSplineAndGizmo(self)
        return true
    end

    return false
end

return M
