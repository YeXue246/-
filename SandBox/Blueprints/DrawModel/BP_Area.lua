--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_Area_C
local M = UnLua.Class()
local DFL = require("SandBox.DataFunction")
local Class = require("SandBox.Class")
local MatT = require("SandBox.MatTable")
local Screen = require("SandBox.Screen")
local HoleDiggingLib = require("SandBox.Blueprints.DrawModel.HoleDiggingLib")

function M:Initialize(Initializer)
    self.thickness        = 20
    self.simplePoints     = UE.TArray(UE.FVector)
    self.currentPoint     = 1
    self.modelType        = 6
    self.clickType        = 2
    self.modelCode        = "Area"
    -- self.showName = ""
    self.bMove            = true
    self.bOverall         = false
    self.bRec             = false
    self.associativeModel = ""
    self.holeNum          = 0
    self.materialCode     = "l1"
    -- 防抖定时器
    self.debounceTimer    = nil
    self.holes            = UE.TArray(UE.AActor)
end

function M:ReceiveBeginPlay()
    self.control = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(), LoadClass(Class.control))
end

-- 数据出
function M:ModelSave()
    local pointLocations = {}
    for key, value in pairs(self.simplePoints) do
        pointLocations[key] = DFL.fromVector(value)
    end
    local table = {
        ["Thickness"] = self.thickness,
        ["CType"] = self.clickType,
        ["PointLocations"] = pointLocations,
        ["MaterialCode"] = self.materialCode,
        ["MColor"] = self.matColor and UE.UJsonLibraryHelpers.JsonValue_Stringify(
            UE.UJsonLibraryHelpers.FromLinearColor(self.matColor)) or nil,
        ["MaterialRatio"] = self.materialRatio,
        ["bRec"] = self.bRec,
        ["associativeModel"] = self.associativeModel,
    }
    return table
end

-- 数据进
function M:ModelLoad(table)
    self.thickness     = table["Thickness"]
    self.clickType     = table["CType"] ~= 0 and table["CType"] or self.clickType
    self.modelType     = table["Type"]
    self.materialCode  = table["MaterialCode"] or "l1"
    self.materialRatio = table["MaterialRatio"]
    self.bRec          = table["bRec"] or self.bRec
    if table["bOverall"] ~= nil then
        self.bOverall = table["bOverall"]
    end
    self.associativeModel = table["associativeModel"] or ""

    self.simplePoints:Clear()
    local Lstrs = table["PointLocations"]
    for key, value in pairs(Lstrs) do
        local LVal = UE.UJsonLibraryHelpers.Parse(value)
        local L = UE.UJsonLibraryHelpers.ToVector(LVal)
        self.simplePoints:Add(L)
    end

    local MColor   = table["MColor"] and
        UE.UJsonLibraryHelpers.ToLinearColor(UE.UJsonLibraryHelpers.Parse(table["MColor"])) or nil
    self.matColor  = MColor

    self.bLoadPlan = table["bLoadPlan"]

    self:SetSplineModel()
end

-- 创建自定义地板
function M:SetSplineModel(bNotUpdateWall)
    self.bNotUpdateWall = bNotUpdateWall
    if not self.modelManage then
        local mmClass = LoadClass(Class.modelManage)
        self.modelManage = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(), mmClass)
    end
    self:UpdateLS()
    self:CreateMesh(self.thickness, 0)
    self:SetDynamicMaterial()
    if self.bLoadPlan then
        self:SaveModelData()
        return
    end
    if not self.bNotUpdateWall then
        self:UpdateWall()
    end

    if not self.control.bBuild then
        -- 清除现有定时器
        if self.debounceTimer then
            UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.debounceTimer)
        end

        -- 创建新的1秒延迟定时器
        self.debounceTimer = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.DelayedExecution }, 1, false)
    end
end

-- 防抖处理：清除现有定时器并创建新的延迟定时器
function M:DelayedExecution()
    self:TrackCad()
    self:SaveModelData()
    self:TrackHoleModel()
    -- 执行完成后清除定时器引用
    self.debounceTimer = nil
end

function M:UpdateWall()
    if self.associativeModel ~= "" and self.modelManage then
        local wall = self.modelManage:FindActor(self.associativeModel)
        if wall then
            wall.simplePoints = self.simplePoints
            wall:SetSplineModel(true)
        end
    end
end

-- 简单样条线点位更新
function M:UpdateLS()
    self.SplineAsPath:ClearSplinePoints()
    for i = 1, self.simplePoints:Num() do
        -- print(self.simplePoints[i])
        self.SplineAsPath:AddSplinePointAtIndex(self.simplePoints[i], i - 1, 1, false)
        self.SplineAsPath:SetSplinePointType(i - 1, 0, false)
    end
    self.SplineAsPath:UpdateSpline()
end

-- 简单样条线点位更新
function M:UpdatePoint()
    local int = self.SplineAsPath:GetNumberOfSplinePoints()
    self.simplePoints:Clear()
    for i = 1, int do
        local L = self.SplineAsPath:GetLocationAtSplinePoint(i - 1, 1)
        -- print(L)
        self.simplePoints:Add(L)
    end
end

-- 外部数据进来
function M:SetData(table)
    local L = self:DataSetSplineModel(table)
    return L
end

-- 外部数据设置管道
function M:DataSetSplineModel(table)
    local PointsNum    = table.int
    local Thickness    = table.thickness
    local Location     = UE.FVector(table.x, table.y, table.z)
    local currentPoint = table.cp
    local bOverall     = table.bOverall
    -- self.showName = table.showname
    local returnL

    if self:GetAttachParentActor().showName ~= table.showname then
        self:GetAttachParentActor().showName = table.showname
        self.modelManage:BuildShowArea(self)
    end

    local bUpdate = false

    if Thickness ~= self.thickness then
        self.thickness = Thickness
        bUpdate = true
    end
    local Int = self.SplineAsPath:GetNumberOfSplinePoints()

    if bOverall ~= self.bOverall then
        self.bOverall = bOverall
        bUpdate = true
        self.PMesh:SetRenderCustomDepth(self.bOverall)
    else
        if self.bOverall then
            self:K2_SetActorLocation(Location, false, nil, false)
            bUpdate = true
        else
            if currentPoint == self.currentPoint then
                local L = self.SplineAsPath:GetLocationAtSplinePoint(self.currentPoint - 1, 1)
                if not UE.UKismetMathLibrary.EqualEqual_VectorVector(Location, L, 0.5) then
                    self.SplineAsPath:SetLocationAtSplinePoint(self.currentPoint - 1, Location, 1, true)
                    bUpdate = true
                end
            else
                self.currentPoint = currentPoint
                returnL = self.SplineAsPath:GetLocationAtSplinePoint(currentPoint - 1, 1)
                local Point = self.modelManage.NubPoints:Find(self.currentPoint)
                returnL = Point:K2_GetActorLocation()
                self.modelManage:CreateGizmo(Point)
            end
        end
    end

    if PointsNum > Int then
        local Vector = self.SplineAsPath:GetLocationAtSplineInputKey(self.currentPoint - 0.5, 1)
        self.SplineAsPath:AddSplinePointAtIndex(Vector, self.currentPoint, 1, true)
        bUpdate = true
    elseif PointsNum < Int then
        self.SplineAsPath:RemoveSplinePoint(self.currentPoint - 1, true)
        bUpdate = true
    end

    if bUpdate then
        self:UpdatePoint()

        if self.bOverall then
            self.modelManage:ClearPoints()

            local L = self:K2_GetActorLocation()
            local O = self:GetActorBounds(true)

            O.Z = DFL.integrate(O.Z) - (self.thickness / 2)

            self:K2_SetActorLocation(O, false, nil, false)
            -- local AddLocation = UE.FVector(L.X - O.X, L.Y - O.Y, 0)
            -- for key, value in pairs(self.simplePoints) do
            --     self.simplePoints[key] = value + AddLocation
            -- end
            self.SplineAsPath:UpdateSpline()
            returnL = O
            self.modelManage:CreateGizmo(self)
        else
            self.modelManage:BuildPoint(self.simplePoints)
            if self.modelManage.NubPoints:Find(table.cp) then
                self.currentPoint = table.cp
            else
                self.currentPoint = 1
            end
            local point = self.modelManage.NubPoints:Find(self.currentPoint)
            returnL = point:K2_GetActorLocation()
            self.modelManage:CreateGizmo(point)
        end
        self:SetSplineModel()
        self.modelManage:BuildShowArea(self)
    end
    return returnL
end

function M:Update()
    self:UpdatePoint()
    self:SetSplineModel()
end

-- 输出管道数据
function M:GetData(FH)
    local Int = self.SplineAsPath:GetNumberOfSplinePoints()

    local Location
    if self.bOverall then
        Location = self:K2_GetActorLocation()
    else
        Location = self.SplineAsPath:GetLocationAtSplinePoint(self.currentPoint - 1, 1)
    end

    -- self.Height = self.simplePoints[1].Z - FH
    local PDT =
    {
        int           = Int,
        cp            = self.currentPoint,
        thickness     = self.thickness,
        x             = DFL.integrate(Location.X),
        y             = DFL.integrate(Location.Y),
        z             = DFL.integrate(Location.Z),
        -- showname      = self.showName,
        showname      = self:GetAttachParentActor().showName,
        bMove         = self.bMove,
        bOverall      = self.bOverall,
        materialCode  = self.materialCode,
        r             = self.matColor and DFL.integrate(self.matColor.r * 255) or nil,
        g             = self.matColor and DFL.integrate(self.matColor.g * 255) or nil,
        b             = self.matColor and DFL.integrate(self.matColor.b * 255) or nil,
        materialRatio = self.materialRatio,
    }
    return PDT
end

function M:GetMaterialData(JSONT)
    local MColor = UE.FLinearColor(JSONT.r / 255, JSONT.g / 255, JSONT.b / 255, 1)
    if MColor ~= self.matColor or JSONT.materialCode ~= self.materialCode or self.materialRatio ~= JSONT.materialRatio then
        self.matColor = MColor
        self.materialCode = JSONT.materialCode
        self.materialRatio = JSONT.materialRatio
        self:SetDynamicMaterial()
    end
end

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

function M:TrackCad()
    -- 获取区域边界框
    local o, b = self:GetActorBounds(true)
    -- 执行盒体碰撞检测
    local outHits = UE.TArray(UE.FHitResult())

    UE.UKismetSystemLibrary.BoxTraceMulti(
        self:GetWorld(), o, o, b, UE.FRotator(0, 0, 0),
        UE.ETraceTypeQuery.Cad, true, nil, 0, outHits, true
    )
    -- 处理碰撞结果
    for _, value in pairs(outHits) do
        local cad = value.HitObjectHandle.Actor
        local l = cad:K2_GetActorLocation()
        local selfL = self:K2_GetActorLocation()
        l.z = selfL.z + self.thickness + 2
        cad:K2_SetActorLocation(l, false, nil, false)
    end
end

function M:SaveModelData()
    self.MeshData = UE.UMeshOpsPluginBPLibrary.CreateMeshDataFromProceduralMesh(self.PMesh)
end

-- 检测并处理与当前区域相交的孔洞模型
function M:TrackHoleModel()
    HoleDiggingLib.TrackHoleModel(self)
end

-- 收集所有相交的孔洞模型数据，为后续布尔运算做准备
function M:CreatHoleData()
    -- 定义筛选函数：筛选类型为2且holeType为2的孔洞模型
    local filterFunc = function(actor)
        return actor.modelType == 2 and actor.holeType == 2
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
        local wall = self.modelManage:FindActor(self.associativeModel)
        if wall then
            self.modelManage.ModelDelete[wall.modelType](wall)
        end
    end
end

return M
