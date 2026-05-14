--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_Pipeline_C
local M = UnLua.Class()
local Model = require("SandBox.ModelNameInitialize")
local DFL = require("SandBox.DataFunction")


function M:Initialize(Initializer)
    -- 初始化管道半径、点集合和其他属性
    self.radius       = 20
    self.length       = 40
    self.width        = 20

    self.simplePoints = UE.TArray(UE.FVector)
    self.points       = UE.TArray(UE.FVector)
    self.tangents     = UE.TArray(UE.FVector)
    self.currentPoint = 1
    self.modelType    = 4
    self.clickType    = 2
    self.bBuild       = true
    -- self.showName     = ""
    self.bMove        = true
    self.pipeType     = 1
    self.matColor     = UE.FLinearColor(0.4, 0.4, 0.5, 1)
    self.matCode      = "PlasticPipe"
end

-- function M:UserConstructionScript()
-- end

function M:ReceiveBeginPlay()
    -- 设置管道厚度，获取游戏中的控制器等
    self:Thickness()
    local PCClass = LoadClass("/Game/SandBox/BasicConfig/Gameplay/PC.PC_C")
    self.PC = UE.UGameplayStatics.GetPlayerController(self:GetWorld(), 0):Cast(PCClass)
end

-- function M:ReceiveEndPlay()
-- end

function M:ReceiveTick(DeltaSeconds)
    if self.playTimer then
        local f = UE.UKismetSystemLibrary.K2_GetTimerElapsedTimeHandle(self:GetWorld(), self.playTimer)
        -- print(f)
        if f == -1 then
            if self.bSet then
                self.bSet = false
                self:StopAnime()
            elseif self.bPlaying then
                self.StopOutEvent:Broadcast(Model.GetActorAccurateDisplayName(self))
            end
        else
            self:RunAnime(f)
        end
    end
end

-- 数据出
function M:ModelSave()
    local PointLocations = {}
    for key, value in pairs(self.simplePoints) do
        PointLocations[key] = DFL.fromVector(value)
    end
    local table = {
        ["PM"] = self.PM,
        ["Radius"] = self.radius,
        ["CType"] = self.clickType,
        ["PointLocations"] = PointLocations,
        ["PipeType"] = self.pipeType,
        ["Length"] = self.length,
        ["Width"] = self.width,
        ["MColor"] = UE.UJsonLibraryHelpers.JsonValue_Stringify(
            UE.UJsonLibraryHelpers.FromLinearColor(self.matColor)),
        animationDirectionr = self.animationDirectionr,
        ["matCode"] = self.matCode,
    }
    return table
end

-- 数据进
function M:ModelLoad(table)
    self.PM     = table["PM"]
    self.radius = table["Radius"]
    if type(self.radius) == "string" then
        self.radius = tonumber(self.radius)
    end
    self.clickType           = table["CType"] ~= 0 and table["CType"] or self.clickType
    self.modelType           = table["Type"]
    self.pipeType            = table["PipeType"] or self.pipeType
    self.length              = table["Length"] or self.length
    self.width               = table["Width"] or self.width
    local MColor             = table["MColor"] and
        UE.UJsonLibraryHelpers.ToLinearColor(UE.UJsonLibraryHelpers.Parse(table["MColor"])) or self.matColor
    self.matColor            = MColor
    self.animationDirectionr = table.animationDirectionr
    self.matCode             = table["matCode"] or self.matCode

    self.simplePoints:Clear()
    local Lstrs = table["PointLocations"]
    for key, value in pairs(Lstrs) do
        local LVal = UE.UJsonLibraryHelpers.Parse(value)
        local L = UE.UJsonLibraryHelpers.ToVector(LVal)
        self.simplePoints:Add(L)
    end

    if self.pipeType == 1 then
        self:Thickness()
    else
        self:ThicknessBox()
    end

    self:SetSplineModel()
    self:SetSplineModelMaterial()
end

-- 创建管道
function M:SetSplineModel()
    -- 计算管道点位、样条线生成和设置材质
    if self.simplePoints:Num() >= 2 then
        self:UpdateLS()
        self:PipelinePoint()
        self:ComplexSplineGeneration()
    end
end

function M:SetSplineModelMaterial(Name)
    if Name then
        self.modelCode = Name
        self.matCode = Name
        if Name == "PlasticPipe" then
            self.PM = "/Game/SandBox/Materials/M_PlasticPipe.M_PlasticPipe"
        else
            self.PM = "/Game/SandBox/Materials/M_Tubing.M_Tubing"
        end
    end

    local Mat = self.PMesh:GetMaterial(1)
    if not Mat:Cast(UE.UMaterialInstanceDynamic) then
        Mat = UE.UKismetMaterialLibrary.CreateDynamicMaterialInstance(self:GetWorld(),
            LoadObject(self.PM), "", 0)
        print(Mat)
        local Num = self.PMesh:GetNumMaterials()
        for i = 1, Num do
            self.PMesh:SetMaterial(i - 1, Mat)
        end
    end
    Mat:SetVectorParameterValue("Color", self.matColor)
end

-- 根据半径计算点位布局
function M:Thickness()
    self.bUseSmoothNormal = true
    local segment = 8
    local degrees = 360 / segment
    self.SplineToSweep:ClearSplinePoints()
    for i = 1, segment do
        local radians = (i - 1) * degrees * math.pi / 180
        local Y = self.radius * math.sin(radians)
        local Z = self.radius * math.cos(radians)
        self.SplineToSweep:AddSplinePoint(UE.FVector(0, Y, Z), 0, false)
    end
    self.SplineToSweep:UpdateSpline()
end

-- 根据更据框高计算布局分布
function M:ThicknessBox()
    self.bUseSmoothNormal = false
    self.SplineToSweep:ClearSplinePoints()
    self.SplineToSweep:AddSplinePoint(UE.FVector(0, self.width / 2, self.length / 2), 0, false)
    self.SplineToSweep:AddSplinePoint(UE.FVector(0, self.width / 2, -self.length / 2), 0, false)
    self.SplineToSweep:AddSplinePoint(UE.FVector(0, -self.width / 2, -self.length / 2), 0, false)
    self.SplineToSweep:AddSplinePoint(UE.FVector(0, -self.width / 2, self.length / 2), 0, false)

    self.SplineToSweep:UpdateSpline()
end

-- 外部数据进来
function M:SetData(table)
    if not self.modelManage then
        self.modelManage = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(),
            LoadClass("/Game/SandBox/Blueprints/BP_ModelManage.BP_ModelManage_C"))
    end
    local L = self:DataSetSplineModel(table)
    -- self.showName = table.showname
    self:GetAttachParentActor().showName = table.showname
    return L
end

-- 外部数据设置管道
function M:DataSetSplineModel(table)
    local PointsNum    = table.int
    local Radius       = table.r
    local currentPoint = table.cp
    local PipeType     = table.pipetype
    local Width        = table.width
    local Length       = table.length
    local matCode      = table.matCode
    local MColor       = UE.FLinearColor(table.colorr / 255, table.colorg / 255, table.colorb / 255, 1)
    local Location     = UE.FVector(table.x, table.y, table.z)
    local returnL

    local bUpdate      = false
    if self.currentPoint ~= currentPoint then
        self.currentPoint = currentPoint
        returnL = self.SimpleSpline:GetLocationAtSplinePoint(currentPoint - 1, 1)
        self.modelManage:CreateGizmo(self.modelManage.NubPoints:Find(self.currentPoint))
    else
        local L = self.SimpleSpline:GetLocationAtSplinePoint(self.currentPoint - 1, 1)
        if not UE.UKismetMathLibrary.EqualEqual_VectorVector(Location, L, 0.5) then
            self.SimpleSpline:SetLocationAtSplinePoint(self.currentPoint - 1, Location, 1, true)
            bUpdate = true
        end
    end
    if self.pipeType ~= PipeType then
        self.pipeType = PipeType
        if self.pipeType == 1 then
            self:Thickness()
        else
            self:ThicknessBox()
        end
        bUpdate = true
    else
        if self.pipeType == 1 then
            if self.radius ~= Radius then
                self.radius = Radius
                self:Thickness()
                bUpdate = true
            end
        else
            if self.width ~= Width or self.length ~= Length then
                self.width = Width
                self.length = Length
                self:ThicknessBox()
                bUpdate = true
            end
        end
    end


    local Int = self.SimpleSpline:GetNumberOfSplinePoints()

    if PointsNum > Int then
        local Vector = self.SimpleSpline:GetLocationAtSplineInputKey(self.currentPoint - 0.5, 1)
        self.SimpleSpline:AddSplinePointAtIndex(Vector, self.currentPoint, 1, true)

        bUpdate = true
    elseif PointsNum < Int then
        self.SimpleSpline:RemoveSplinePoint(self.currentPoint - 1, true)

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
    if self.matCode ~= matCode or self.matColor ~= MColor then
        self.matCode = matCode
        self.matColor = MColor
        self:SetSplineModelMaterial(matCode)
    end

    return returnL
end

function M:Update()
    self:UpdatePoint()
    self:PipelinePoint()
    self:ComplexSplineGeneration()
end

-- 输出管道数据
function M:GetData()
    local Int = self.SimpleSpline:GetNumberOfSplinePoints()
    local Location = self.SimpleSpline:GetLocationAtSplinePoint(self.currentPoint - 1, 1)
    local PDT =
    {
        int       = Int,
        cp        = self.currentPoint,
        r         = self.radius,
        x         = DFL.integrate(Location.X),
        y         = DFL.integrate(Location.Y),
        z         = DFL.integrate(Location.Z),
        -- showname = self.showName,
        showname  = self:GetAttachParentActor().showName,
        bMove     = self.bMove,
        pipetype  = self.pipeType,
        length    = self.length,
        width     = self.width,
        matCode   = self.matCode,
        colorr    = DFL.integrate(self.matColor.r * 255),
        colorg    = DFL.integrate(self.matColor.g * 255),
        colorb    = DFL.integrate(self.matColor.b * 255),
        overallgh = DFL.integrate(self.SimpleSpline:GetSplineLength()),
    }
    return PDT
end

-- 简单样条线点位布局算法
---@param A 起点
---@param B 终点
function M:PointCount(A, B)
    self.simplePoints:Add(A)
    local angleRadius
    if self.pipeType == 1 then
        angleRadius = self.radius
    else
        angleRadius = self.width / 2
    end
    if math.abs(A.X - B.X) > angleRadius * 2 then
        local New = UE.FVector(B.X, A.Y, A.Z)
        self.simplePoints:Add(New)
    end
    if math.abs(A.X - B.X) > angleRadius * 2 then
        local New = UE.FVector(B.X, B.Y, A.Z)
        self.simplePoints:Add(New)
    end
    if math.abs(A.Z - B.Z) > angleRadius * 2 then
        self.simplePoints:Add(B)
    end
    -- print(self.simplePoints:Num() .. "555")
    self:UpdateLS()
end

-- 简单样条线点位更新
function M:UpdateLS()
    self.SimpleSpline:ClearSplinePoints()
    for i = 1, self.simplePoints:Num() do
        -- print(self.simplePoints[i])
        self.SimpleSpline:AddSplinePointAtIndex(self.simplePoints[i], i - 1, 1, false)
        self.SimpleSpline:SetSplinePointType(i - 1, 0, false)
    end
    self.SimpleSpline:UpdateSpline()
end

-- 简单样条线点位更新
function M:UpdatePoint()
    local int = self.SimpleSpline:GetNumberOfSplinePoints()
    self.simplePoints:Clear()
    for i = 1, int do
        local L = self.SimpleSpline:GetLocationAtSplinePoint(i - 1, 1)
        -- print(L)
        self.simplePoints:Add(L)
    end
end

-- 管道基于简单样条线点位增加倒角
-- 基于简单样条线点位，增加倒角计算，生成新的点位和切线数据
function M:PipelinePoint()
    -- 清空之前的点位和切线数据
    self.points:Clear()
    self.tangents:Clear()
    -- 根据管道类型确定倒角半径
    local angleRadius
    if self.pipeType == 1 then
        angleRadius = self.radius
    else
        angleRadius = self.width / 2
    end
    -- 遍历简单样条线的所有点位
    for i = 1, self.simplePoints:Num() do
        -- 处理非起点和终点的中间点位
        if i > 1 and i < self.simplePoints:Num() then
            -- 计算当前点与前一个点的倒角点
            local point1 = self:CalculateChamferPoint3D(
                self.simplePoints[i - 1], self.simplePoints[i], angleRadius * 3)
            -- 计算当前点与后一个点的倒角点
            local point2 = self:CalculateChamferPoint3D(
                self.simplePoints[i + 1], self.simplePoints[i], angleRadius * 3)
            -- 如果两个倒角点重合，则只添加一个点并计算切线
            if UE.UKismetMathLibrary.EqualEqual_VectorVector(point1, point2, 0.5) then
                self.points:Add(UE.FVector(point1.X, point1.Y, point1.Z))
                self:TangentsAdd(self.simplePoints[i], self.simplePoints[i - 1], angleRadius)
            else
                -- 若不重合，添加两个倒角点并分别计算切线
                self.points:Add(UE.FVector(point1.X, point1.Y, point1.Z))
                self:TangentsAdd(self.simplePoints[i], self.simplePoints[i - 1], angleRadius)
                self.points:Add(UE.FVector(point2.X, point2.Y, point2.Z))
                self:TangentsAdd(self.simplePoints[i + 1], self.simplePoints[i], angleRadius)
            end
        else
            -- 处理起点和终点，直接添加原始点位
            self.points:Add(UE.FVector(self.simplePoints[i].X, self.simplePoints[i].Y, self.simplePoints[i].Z))
            if i == 1 then
                -- 起点切线根据起点和下一个点计算
                self:TangentsAdd(self.simplePoints[i + 1], self.simplePoints[i], angleRadius)
            else
                -- 终点切线根据终点和前一个点计算
                self:TangentsAdd(self.simplePoints[i], self.simplePoints[i - 1], angleRadius)
            end
        end
    end
end

function M:TangentsAdd(A, B, angleRadius)
    local T = UE.UKismetMathLibrary.Subtract_VectorVector(A, B)
    T:Normalize()
    local Distance = UE.UKismetMathLibrary.Vector_Distance(A, B)
    if Distance > angleRadius then
        T = T * angleRadius * 6
    else
        T = T * angleRadius * 2
    end
    self.tangents:Add(T)
end

-- 复杂样条线生成
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
    self.SplineAsPath:UpdateSpline()
    self:CreateSweepMesh()
end

-- 计算倒角点位
function M:CalculateChamferPoint3D(Point0, Point1, R)
    local Distance = UE.UKismetMathLibrary.Vector_Distance(Point0, Point1)
    local Direction = UE.UKismetMathLibrary.GetDirectionUnitVector(Point0, Point1)
    local chamferPoint = UE.FVector(0, 0, 0)
    if R < Distance then
        chamferPoint = Point0 + Direction * (Distance - R)
    else
        chamferPoint = Point0
    end
    return chamferPoint
end

-------------- 动画名
function M:GetAnimeData()
    local animeTable = {
        showName            = self:GetAttachParentActor().showName,
        animationDirectionr = self.animationDirectionr,
    }
    return animeTable
end

function M:SetAnimeData(animeTable)
    self.animationDirectionr = animeTable.animationDirectionr
    if self.playTimer then
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.playTimer)
        self.playTimer = nil
    end
    if self.bSet then
        self.bSet = false
        self:StopAnime()
    end
    self.bSet = true
    self:PlayAnime()
end

function M:PlayAnime()
    local l   = self.SplineAsPath:GetSplineLength()
    self.MatI = UE.UKismetMaterialLibrary.CreateDynamicMaterialInstance(self:GetWorld(),
        LoadObject('/Game/SandBox/Materials/M_jy_Inst.M_jy_Inst'), "", 0)
    self.MatI:SetVectorParameterValue("splineLength", UE.FLinearColor(1, l / 150, 1, 1))
    local val = self.animationDirectionr == "1" and 1 or -1
    self.MatI:SetScalarParameterValue("Directionr", val)
    self.MatI:SetScalarParameterValue("jy", 0)
    local Num = self.PMesh:GetNumMaterials()
    for i = 1, Num do
        self.PMesh:SetMaterial(i - 1, self.MatI)
    end
    self.playTimer = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.RunAnime }, 5, false)
end

function M:RunAnime(alpha)
    alpha = alpha or 1
    self.MatI:SetScalarParameterValue("jy", alpha)
end

function M:StopAnime()
    self:SetSplineModelMaterial()
end

function M:PlayAnimation(bLoop)
    if self.bSet then
        self:StopAnime()
        self.bSet = false
    end
    self.bLoop = bLoop
    self:PlayAnime()
end

function M:StopAnimation()
    self.bLoop = false
    self:StopAnime()
end

return M
