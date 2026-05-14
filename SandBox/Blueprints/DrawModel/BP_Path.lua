--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_Path_C
local M = UnLua.Class()
local Model = require("SandBox.ModelNameInitialize")
local DFL = require("SandBox.DataFunction")
local Class = require("SandBox.Class")

--- 初始化函数
---@param Initializer any 初始化参数
function M:Initialize(Initializer)
    self.radius             = 10 -- 路径半径
    self.simplePoints       = UE.TArray(UE.FVector) -- 点集合
    self.points             = UE.TArray(UE.FVector) -- 处理后的点集合
    self.tangents           = UE.TArray(UE.FVector) -- 切线集合
    self.currentPoint       = 1 -- 当前点索引
    self.modelType          = 15 -- 类型ID
    self.clickType          = 2 -- 子类型ID
    self.bMove              = true -- 是否可移动
    self.glModelCode        = "sixcsc1" -- 模型代码
    self.glShowName         = "四向穿梭车" -- 显示名称
    self.matColor           = UE.FLinearColor(0.4, 0.4, 0.5, 1) -- 路径颜色

    -- 动画相关属性
    self.animationDirection = "1"   -- 动画方向(1-正向,2-反向)
    self.movementSpeed      = 0     -- 移动速度
    self.playTimer          = nil   -- 动画计时器
    self.animationObjects   = {}    -- 动画对象集合
    self.isLooping          = false -- 是否循环播放
    self.isPlaying          = false -- 是否正在播放
end

function M:ReceiveBeginPlay()
    -- 设置管道厚度，获取游戏中的控制器等
    self:Thickness()
end

-- function M:ReceiveEndPlay()
-- end

function M:ReceiveTick(DeltaSeconds)
    if self.playTimer then
        local f = UE.UKismetSystemLibrary.K2_GetTimerElapsedTimeHandle(self:GetWorld(), self.playTimer)
        -- print(f)
        if f == -1 then
            self.count = self.count + 1
            if self.maxCount >= self.count then
                self.playTimer = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.RunAnime }, 1, false)
            else
                if self.bSet then
                    self.bSet = false
                    self:StopAnime()
                elseif self.bLoop then
                    self:PlayAnime()
                elseif self.bPlaying then
                    self.StopOutEvent:Broadcast(Model.GetActorAccurateDisplayName(self))
                end
            end
        else
            self:RunAnime(f)
        end
    end
end

-- 数据出
function M:ModelSave()
    local pointLocations = {}
    for key, value in pairs(self.simplePoints) do
        pointLocations[key] = DFL.fromVector(value)
    end
    local table = {
        ["CType"]           = self.CType,
        ["PointLocations"]  = pointLocations,
        ["MColor"]          = UE.UJsonLibraryHelpers.JsonValue_Stringify(UE.UJsonLibraryHelpers.FromLinearColor(
            self.matColor)),
        ["glModelCode"]     = self.glModelCode,
        ["glShowName"]      = self.glShowName,
        animationDirectionr = self.animationDirectionr,
        movementSpeed       = self.movementSpeed,
    }
    return table
end

-- 数据进
function M:ModelLoad(table)
    if type(self.radius) == "string" then
        self.radius = tonumber(self.radius)
    end
    self.CType               = table["CType"] ~= 0 and table["CType"] or self.CType
    self.Type                = table["Type"]
    self.matColor            = DFL.toColor(table["MColor"])
    self.glModelCode         = table["glModelCode"]
    self.glShowName          = table["glShowName"]
    self.animationDirectionr = table.animationDirectionr
    self.movementSpeed       = table.movementSpeed


    self.simplePoints:Clear()
    local lStrs = table["PointLocations"]
    for _, value in pairs(lStrs) do
        local l = DFL.toVector(value)
        self.simplePoints:Add(l)
    end
    self:Thickness()

    self:SetSplineModel()
    self:SetSplineModelMaterial()
end

-- 创建管道
function M:SetSplineModel()
    -- 计算管道点位、样条线生成和设置材质
    if self.simplePoints:Num() >= 2 then
        if not self.modelManage then
            self.modelManage = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(),
                LoadClass(Class.modelManage))
        end
        self:UpdateLS()
        self:PipelinePoint()
        self:ComplexSplineGeneration()
    end
end

function M:SetSplineModelMaterial()
    local mat = self.PMesh:GetMaterial(1)
    if not mat:Cast(UE.UMaterialInstanceDynamic) then
        mat = UE.UKismetMaterialLibrary.CreateDynamicMaterialInstance(self:GetWorld(),
            LoadObject("/Game/SandBox/Materials/M_Path.M_Path"), "", 0)
        print(mat)
        local Num = self.PMesh:GetNumMaterials()
        for i = 1, Num do
            self.PMesh:SetMaterial(i - 1, mat)
        end
    end
    mat:SetVectorParameterValue("Color", self.matColor)
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

-- 外部数据进来
function M:SetData(table)
    local L = self:DataSetSplineModel(table)
    -- self.showName = table.showname
    self:GetAttachParentActor().showName = table.showname
    return L
end

-- 外部数据设置管道
function M:DataSetSplineModel(table)
    local pointsNum    = table.int
    local currentPoint = table.cp
    local matColor     = UE.FLinearColor(table.r / 255, table.g / 255, table.b / 255, 1)
    local location     = UE.FVector(table.x, table.y, table.z)
    self.glModelCode   = table.glModelCode
    self.glShowName    = table.glShowName
    local returnL

    local bUpdate      = false
    if self.currentPoint ~= currentPoint then
        self.currentPoint = currentPoint
        returnL = self.SimpleSpline:GetLocationAtSplinePoint(currentPoint - 1, 1)
        self.modelManage:CreateGizmo(self.modelManage.NubPoints:Find(self.currentPoint))
    else
        local L = self.SimpleSpline:GetLocationAtSplinePoint(self.currentPoint - 1, 1)
        if not UE.UKismetMathLibrary.EqualEqual_VectorVector(location, L, 0.5) then
            self.SimpleSpline:SetLocationAtSplinePoint(self.currentPoint - 1, location, 1, true)
            bUpdate = true
        end
    end


    local Int = self.SimpleSpline:GetNumberOfSplinePoints()

    if pointsNum > Int then
        local Vector = self.SimpleSpline:GetLocationAtSplineInputKey(self.currentPoint - 0.5, 1)
        self.SimpleSpline:AddSplinePointAtIndex(Vector, self.currentPoint, 1, true)

        bUpdate = true
    elseif pointsNum < Int then
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
        local point = self.modelManage.NubPoints:Find(self.currentPoint)
        returnL = point:K2_GetActorLocation()
        self.modelManage:CreateGizmo(point)
    end
    if self.matColor ~= matColor then
        self.matColor = matColor
        self:SetSplineModelMaterial()
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
    local int = self.SimpleSpline:GetNumberOfSplinePoints()
    local location = self.SimpleSpline:GetLocationAtSplinePoint(self.currentPoint - 1, 1)
    local outTable =
    {
        int         = int,
        cp          = self.currentPoint,
        r           = self.radius,
        x           = DFL.integrate(location.X),
        y           = DFL.integrate(location.Y),
        z           = DFL.integrate(location.Z),
        -- showname = self.showName,
        showname    = self:GetAttachParentActor().showName,
        bMove       = self.bMove,
        -- pathLength  = DFL.integrate(self.SplineAsPath:GetSplineLength()),
        r           = DFL.integrate(self.matColor.r * 255),
        g           = DFL.integrate(self.matColor.g * 255),
        b           = DFL.integrate(self.matColor.b * 255),
        glModelCode = self.glModelCode,
        glShowName  = self.glShowName,
        overallgh   = DFL.integrate(self.SimpleSpline:GetSplineLength()),
    }
    return outTable
end

-- 简单样条线点位布局算法
---@param A 起点
---@param B 终点
function M:PointCount(A, B)
    self.simplePoints:Add(A)
    local angleRadius = self.radius

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
        local l = self.SimpleSpline:GetLocationAtSplinePoint(i - 1, 1)
        print(l)
        self.simplePoints:Add(l)
    end
end

-- 管道基于简单样条线点位增加倒角
function M:PipelinePoint()
    self.points:Clear()
    self.tangents:Clear()
    local angleRadius = self.radius

    for i = 1, self.simplePoints:Num() do
        if i > 1 and i < self.simplePoints:Num() then
            local point1 = self:CalculateChamferPoint3D(
                self.simplePoints[i - 1], self.simplePoints[i], angleRadius * 3)
            local point2 = self:CalculateChamferPoint3D(
                self.simplePoints[i + 1], self.simplePoints[i], angleRadius * 3)
            if UE.UKismetMathLibrary.EqualEqual_VectorVector(point1, point2, 1) then
                self.points:Add(UE.FVector(point1.X, point1.Y, point1.Z))
                self:TangentsAdd(self.simplePoints[i], self.simplePoints[i - 1], angleRadius)
            else
                self.points:Add(UE.FVector(point1.X, point1.Y, point1.Z))
                self:TangentsAdd(self.simplePoints[i], self.simplePoints[i - 1], angleRadius)
                self.points:Add(UE.FVector(point2.X, point2.Y, point2.Z))
                self:TangentsAdd(self.simplePoints[i + 1], self.simplePoints[i], angleRadius)
            end
        else
            self.points:Add(UE.FVector(self.simplePoints[i].X, self.simplePoints[i].Y, self.simplePoints[i].Z))
            if i == 1 then
                self:TangentsAdd(self.simplePoints[i + 1], self.simplePoints[i], angleRadius)
            else
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
        movementSpeed       = self.movementSpeed,
    }
    return animeTable
end

function M:SetAnimeData(animeTable)
    self.animationDirectionr = animeTable.animationDirectionr or "1"
    self.movementSpeed       = animeTable.movementSpeed or 0
    if self.playTimer then
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.playTimer)
        self.playTimer = nil
    end
    if self.bSet then
        self:StopAnime()
    end
    self.bSet = true
    self:PlayAnime()
end

function M:PlayAnime()
    local l       = self.SplineAsPath:GetSplineLength()
    self.maxCount = math.floor(l / self.movementSpeed)
    self.playT    = {}
    self.count    = 0
    if not self.modelManage.MeshDatas:Find(self.glModelCode) then
        self:ShowErrorMessage(2, "该模型是上传模型，暂时不能配置，请选择资源包模型")
        return
    end
    local mesh = LoadObject(self.modelManage.MeshDatas:Find(self.glModelCode).Mesh)
    if not mesh then
        self:ShowErrorMessage(3, "该模型是生成化模型，请选择资源包模型")
        return
    end
    self.object    = self:CreateBox(mesh)
    self.playTimer = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.RunAnime }, 1, false)
end

--- 显示错误消息
--- @function ShowErrorMessage
--- @param Type number 错误消息类型 1:成功 2:警告 3:错误
--- @param Message string 错误消息内容
function M:ShowErrorMessage(Type, Message)
    local control = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(), LoadClass(Class.control))
    if control then
        control.ui:UECallWeb("ShowMessage", { Type = Type, Text = Message })
    end
end

function M:RunAnime(alpha)
    if not alpha or not self.object then
        return
    end
    local d = (self.count + alpha) * self.movementSpeed
    local l = self.SplineAsPath:GetSplineLength()
    local current = d
    if self.animationDirectionr == "2" then
        current = l - d
    end
    local location = self.SplineAsPath:GetLocationAtDistanceAlongSpline(current, 1, false)
    local rotation = self.SplineAsPath:GetRotationAtDistanceAlongSpline(current, 1, false)
    location.Z = location.Z + 20
    rotation.Roll = 0
    self.object:K2_SetWorldLocation(location, false, nil, false)
    self.object:K2_SetWorldRotation(rotation, false, nil, false)
    if self.object:IsVisible() ~= self.RootComponent.bVisible then
        self.object:SetVisibility(self.RootComponent.bVisible, false)
    end
    if d > l then
        self.object:K2_DestroyComponent(self)
        self.object = nil
    end
end

function M:StopAnime()
    UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.playTimer)
    self.playTimer = nil

    if self.object then
        self.object:K2_DestroyComponent(self)
        self.object = nil
    end

    self.playT = {}
end

function M:PlayAnimation(bLoop)
    if not self.modelManage then
        self.modelManage = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(),
            LoadClass(Class.ma))
    end
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
