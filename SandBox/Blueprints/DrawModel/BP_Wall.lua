--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_Wall_C
local M = UnLua.Class()
local DFL = require("SandBox.DataFunction")
local Class = require("SandBox.Class")
local MatT = require("SandBox.MatTable")
local Screen = require("SandBox.Screen")
local HoleDiggingLib = require("SandBox.Blueprints.DrawModel.HoleDiggingLib")
--- 墙体模型初始化方法
--- @function Initialize
--- @param Initializer any 初始化参数
--- @description
---   设置墙体模型基础参数：
---   1. thickness - 墙体厚度(默认20单位)
---   2. height - 墙体高度(默认500单位)
---   3. simplePoints - 墙体控制点集合(TArray<FVector>)
---   4. currentPoint - 当前控制点索引(从1开始)
---   5. modelType - 模型类型标识(5=墙体)
---   6. clickType - 点击类型标识(2=?)
---   7. modelCode - 模型编码("LineWall")
---   8. bMove - 可移动标记(true=可移动)
function M:Initialize(Initializer)
    self.thickness        = 20
    self.height           = 500
    self.simplePoints     = UE.TArray(UE.FVector)
    self.currentPoint     = 1
    self.modelType        = 5
    self.clickType        = 2
    self.modelCode        = "LineWall"
    -- self.showName = ""  -- 显示名称(已注释)
    self.bMove            = true
    self.bClosed          = false
    self.materialCode     = "t1"
    self.associativeModel = ""
    self.holeNum          = 0
    self.debounceTimer    = nil
    self.holes            = UE.TArray(UE.AActor)
end

--- 游戏开始事件处理
--- @function ReceiveBeginPlay
--- @description
---   1. 加载并获取玩家控制器(PC)
---   2. 初始化距离参数(Distance=0)
---   3. 设置建造标记(bBuild=false)
function M:ReceiveBeginPlay()
    self.control = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(), LoadClass(Class.control))
    self.distance = 0
    self.bBuild = false
end

-- function M:ReceiveTick(DeltaSeconds)
--     self:TrackHoleModel()
-- end

--- 模型数据序列化方法
--- @function ModelSave
--- @return table 包含墙体参数的Lua表
--- @description
---   输出墙体当前状态数据：
---   1. Thickness - 墙体厚度
---   2. Height - 墙体高度
---   3. CType - 点击类型
---   4. PointLocations - 控制点位置数组(JSON序列化)
---   5. materialCode - 材质编码
---   6. MColor - 材质颜色(JSON序列化)
---   7. MaterialRatio - 材质比例
function M:ModelSave()
    local PointLocations = {}
    for key, value in pairs(self.simplePoints) do
        PointLocations[key] = DFL.fromVector(value)
    end
    local table = {
        ["Thickness"] = self.thickness,
        ["Height"] = self.height,
        ["CType"] = self.clickType,
        ["PointLocations"] = PointLocations,
        ["MaterialCode"] = self.materialCode,
        ["MColor"] = self.matColor and DFL.fromColor(self.matColor) or nil,
        ["MaterialRatio"] = self.materialRatio,
        ["bClosed"] = self.bClosed,
        ["associativeModel"] = self.associativeModel,
    }
    return table
end

--- 模型数据反序列化方法
--- @function ModelLoad
--- @param table table 包含墙体参数的Lua表
--- @description
---   加载墙体状态数据：
---   1. 解析基础参数(厚度/高度/点击类型)
---   2. 从JSON恢复控制点位置
---   3. 设置材质相关参数(编码/颜色/比例)
---   4. 调用SetSplineModel重建墙体
function M:ModelLoad(table)
    self.thickness        = table["Thickness"]
    self.height           = table["Height"]
    self.clickType        = table["CType"] ~= 0 and table["CType"] or self.clickType
    self.modelType        = table["Type"]
    self.materialCode     = table["MaterialCode"] or "t1"
    self.materialRatio    = table["MaterialRatio"]
    self.bClosed          = table["bClosed"] or false
    self.associativeModel = table["associativeModel"] or ""

    self.simplePoints:Clear()
    local Lstrs = table["PointLocations"]
    for key, value in pairs(Lstrs) do
        local LVal = UE.UJsonLibraryHelpers.Parse(value)
        local L = UE.UJsonLibraryHelpers.ToVector(LVal)
        self.simplePoints:Add(L)
    end
    local MColor  = table["MColor"] and
        UE.UJsonLibraryHelpers.ToLinearColor(UE.UJsonLibraryHelpers.Parse(table["MColor"])) or nil
    self.matColor = MColor
    self.SplineAsPath:SetClosedLoop(self.bClosed, true)

    self.bLoadPlan = table["bLoadPlan"]

    self:SetSplineModel()
end

--- 创建墙体模型
--- @function SetSplineModel
--- @description
---   1. 更新样条线(UpdateLS)
---   2. 创建墙体网格(CreateWall)
---   3. 设置默认材质(t1材质)
function M:SetSplineModel(bNotUpdateArea)
    if not self.modelManage then
        local mmClass = LoadClass(Class.modelManage)
        self.modelManage = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(), mmClass)
    end
    self:UpdateLS()
    self:CreateWall(DFL.integrate(self.thickness), DFL.integrate(self.height))
    self:SetDynamicMaterial()

    if self.bLoadPlan then
        self:SaveModelData()
        return
    end
    if self.bNotUpdateArea then
        return
    end
    self:UpdateArea()
    if not self.control.bBuild then
        if self.debounceTimer then
            UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.debounceTimer)
        end

        -- 创建新的1秒延迟定时器
        self.debounceTimer = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.DelayedExecution }, 1, false)
    end
end

-- 防抖处理：清除现有定时器并创建新的延迟定时器
function M:DelayedExecution()
    self:SaveModelData()
    self:TrackHoleModel()
    self.debounceTimer = nil
end

function M:UpdateArea()
    if self.associativeModel ~= "" and self.modelManage then
        local area = self.modelManage:FindActor(self.associativeModel)
        if area then
            area.simplePoints = self.simplePoints
            area:SetSplineModel(true)
        end
    end
end

--- 设置墙体闭合状态
--- @function SetClosedWall
--- @description
---   当样条点数大于2时切换闭合状态:
---   1. 切换样条线的闭合状态(IsClosedLoop)
---   2. 更新样条线
---   3. 重新设置墙体模型
function M:SetClosedWall()
    if self.SplineAsPath:GetNumberOfSplinePoints() > 2 then
        self.bClosed = not self.bClosed
        self.SplineAsPath:SetClosedLoop(self.bClosed, true)
        self.SplineAsPath:UpdateSpline()
        self:SetSplineModel()
    end
end

--- 更新样条线控制点
--- @function UpdateLS
--- @description
---   从simplePoints重建样条线:
---   1. 清空现有样条点
---   2. 逐个添加simplePoints中的点
---   3. 设置每个点为线性类型(0=线性)
---   4. 更新样条线
function M:UpdateLS()
    self.SplineAsPath:ClearSplinePoints()
    for i = 1, self.simplePoints:Num() do
        self.SplineAsPath:AddSplinePointAtIndex(self.simplePoints[i], i - 1, 1, false)
        self.SplineAsPath:SetSplinePointType(i - 1, 0, false)
    end
    self.SplineAsPath:UpdateSpline()
end

--- 从样条线更新控制点
--- @function UpdatePoint
--- @description
---   将样条线控制点同步到simplePoints:
---   1. 清空现有simplePoints
---   2. 逐个获取样条点位置
---   3. 添加到simplePoints数组
function M:UpdatePoint()
    local int = self.SplineAsPath:GetNumberOfSplinePoints()
    self.simplePoints:Clear()
    for i = 1, int do
        local L = self.SplineAsPath:GetLocationAtSplinePoint(i - 1, 1)
        print(L)
        self.simplePoints:Add(L)
    end
end

--- 外部数据输入接口
--- @function SetData
--- @param table table 包含墙体参数的表
--- @return FVector 当前控制点位置(可选)
--- @description
---   1. 初始化模型管理器(modelManage)
---   2. 调用DataSetSplineModel处理数据
function M:SetData(table)
    local L = self:DataSetSplineModel(table)
    return L
end

--- 处理外部数据并更新墙体
--- @function DataSetSplineModel
--- @param table table 包含墙体参数的表
--- @return FVector 当前控制点位置(可选)
--- @description
---   处理外部传入的墙体参数:
---   1. 解析基础参数(点数/厚度/当前点/高度/位置)
---   2. 更新显示名称
---   3. 检查是否需要更新:
---     - 厚度/高度变化
---     - 当前控制点变化
---     - 控制点位置变化
---   4. 处理点数变化(增加/删除点)
---   5. 必要时更新整个墙体
function M:DataSetSplineModel(table)
    local PointsNum                      = table.int
    local Thickness                      = tonumber(table.thickness)
    local currentPoint                   = table.cp
    local Height                         = table.height
    local Location                       = UE.FVector(table.x, table.y, table.z)
    local returnL

    local bUpdate                        = false
    self:GetAttachParentActor().showName = table.showname

    if Thickness ~= self.thickness or Height ~= self.height then
        self.thickness = Thickness
        self.height = Height
        bUpdate = true
    end
    if currentPoint ~= self.currentPoint then
        self.currentPoint = currentPoint
        returnL = self.SplineAsPath:GetLocationAtSplinePoint(currentPoint - 1, 1)
        self.modelManage:CreateGizmo(self.modelManage.NubPoints:Find(self.currentPoint))
    else
        local L = self.SplineAsPath:GetLocationAtSplinePoint(self.currentPoint - 1, 1)
        if not UE.UKismetMathLibrary.EqualEqual_VectorVector(Location, L, 0.5) then
            self.SplineAsPath:SetLocationAtSplinePoint(self.currentPoint - 1, Location, 1, true)
            bUpdate = true
        end
    end
    local Int = self.SplineAsPath:GetNumberOfSplinePoints()

    if PointsNum > Int then
        local Vector = self.SplineAsPath:GetLocationAtSplineInputKey(self.currentPoint - 0.5, 1)
        self.SplineAsPath:AddSplinePointAtIndex(Vector, self.currentPoint, 1, true)
        bUpdate = true
    elseif PointsNum < Int then
        self.SplineAsPath:RemoveSplinePoint(self.currentPoint - 1, true)
        bUpdate = true
    end
    if bUpdate then
        self:Update()
        self.modelManage:BuildPoint(self.simplePoints)
        if self.modelManage.NubPoints:Find(table.cp) then
            self.currentPoint = table.cp
        else
            self.currentPoint = 1
        end
        local Point = self.modelManage.NubPoints:Find(self.currentPoint)
        returnL = Point:K2_GetActorLocation()
        self.modelManage:CreateGizmo(Point)
    end
    return returnL
end

--- 更新墙体状态
--- @function Update
--- @description
---   更新墙体模型的完整流程:
---   1. 从样条线更新控制点(UpdatePoint)
---   2. 重建墙体模型(SetSplineModel)
function M:Update()
    self:UpdatePoint()
    self:SetSplineModel()
end

--- 获取墙体数据
--- @function GetData
--- @return table 包含墙体参数的表
--- @description
---   输出当前墙体状态数据:
---   1. 基础参数(点数/当前点/厚度/高度)
---   2. 控制点位置(x/y/z)
---   3. 显示名称/可移动标记
---   4. 材质相关参数(编码/颜色/比例)
---   5. 样条线总长度
function M:GetData()
    local Int = self.SplineAsPath:GetNumberOfSplinePoints()
    local Location = self.SplineAsPath:GetLocationAtSplinePoint(self.currentPoint - 1, 1)
    local PDT =
    {
        int           = Int,
        cp            = self.currentPoint,
        thickness     = self.thickness,
        height        = self.height,
        x             = DFL.integrate(Location.X),
        y             = DFL.integrate(Location.Y),
        z             = DFL.integrate(Location.Z),
        showname      = self:GetAttachParentActor().showName,
        bMove         = self.bMove,
        materialCode  = self.materialCode,
        r             = self.matColor and DFL.integrate(self.matColor.r * 255) or nil,
        g             = self.matColor and DFL.integrate(self.matColor.g * 255) or nil,
        b             = self.matColor and DFL.integrate(self.matColor.b * 255) or nil,
        materialRatio = self.materialRatio,
        overallgh     = DFL.integrate(self.SplineAsPath:GetSplineLength())
    }
    return PDT
end

--- 设置材质参数
--- @function GetMaterialData
--- @param JSONT table 包含材质参数的表
--- @description
---   处理材质相关参数:
---   1. 解析颜色值(r/g/b)
---   2. 当材质参数变化时更新:
---     - 材质颜色
---     - 材质编码
---     - 材质比例
---   3. 调用SetDynamicMaterial应用材质
function M:GetMaterialData(JSONT)
    local MColor = UE.FLinearColor(JSONT.r / 255, JSONT.g / 255, JSONT.b / 255, 1)
    if MColor ~= self.matColor or JSONT.materialCode ~= self.materialCode or self.materialRatio ~= JSONT.materialRatio then
        self.matColor = MColor
        self.materialCode = JSONT.materialCode
        self.materialRatio = JSONT.materialRatio
        self:SetDynamicMaterial()
    end
end

--- 应用动态材质到墙体模型
--- @function SetDynamicMaterial
--- @description
---   该函数负责为墙体模型设置材质:
---   1. 根据MaterialCode属性加载材质资源
---   2. 将材质应用到墙体网格的所有材质槽
---   3. 注释部分展示了动态材质实例的创建和参数设置流程(当前未启用)
function M:SetDynamicMaterial()
    local matPath = MatT[self.materialCode]
    if not matPath then
        print(self.materialCode)
        return
    end
    local mat = LoadObject(matPath)
    local num = self.PMesh:GetNumMaterials()
    for i = 1, num do
        self.PMesh:SetMaterial(i - 1, mat)
    end
end

function M:SaveModelData()
    self.MeshData = UE.UMeshOpsPluginBPLibrary.CreateMeshDataFromProceduralMesh(self.PMesh)
end

--- 获取附近墙体旋转角度
--- @function GetNearbyWallRotation
--- @return UE.FRotator 墙体旋转角度
--- @description
---   该函数用于获取当前墙体模型附近的墙体旋转角度:
---   1. 遍历当前墙体模型的所有网格组件
---   2. 检查每个组件是否为墙体模型
---   3. 如果是墙体模型,则返回其旋转角度
function M:GetNearbyWallRotation(holePoint)
    return self.SplineAsPath:FindRotationClosestToWorldLocation(holePoint, 1)
end

function M:TrackHoleModel()
    HoleDiggingLib.TrackHoleModel(self)
end

function M:CreatHoleData()
    self.createTimer = nil
    -- 定义筛选函数：筛选类型为2且holeType为1的孔洞模型
    local filterFunc = function(actor)
        return actor.modelType == 2 and actor.holeType == 1
    end

    -- 调用公共库的CreatHoleData函数
    HoleDiggingLib.CreatHoleData(self, UE.ETraceTypeQuery.Model, filterFunc)
end

function M:BooleanMeshOver()
    HoleDiggingLib.BooleanMeshOver(self)
end

function M:ReceiveEndPlay()
    -- 调用公共库的销毁函数，处理洞模型效果还原
    HoleDiggingLib.OnDestroy(self)

    if self.associativeModel ~= "" then
        local area = self.modelManage:FindActor(self.associativeModel)
        if area then
            self.modelManage.ModelDelete[area.modelType](area)
        end
    end
end

return M
