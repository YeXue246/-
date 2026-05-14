--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_SSX_C
local M = UnLua.Class()
local Screen = require("SandBox.Screen")
local Model = require("SandBox.ModelNameInitialize")
local DFL = require("SandBox.DataFunction")
local Class = require("SandBox.Class")

--- SSX模型初始化方法
--- @function Initialize
--- @param Initializer any 初始化参数
--- @description
---   初始化SSX模型基础属性：
---   1. 几何参数(半径/宽度/间隔)
---   2. 样条数据容器(点坐标/切线)
---   3. 模型类型标识(7=SSX专用类型)
---   4. 动画控制参数(类型/循环标记)
---   5. 材质资源路径配置
function M:Initialize(Initializer)
    self.radius       = 20                    -- 模型基础半径(单位：厘米)
    self.ssdWitch     = 50                    -- 特殊宽度参数
    self.zzSize       = UE.FVector2D(4, 4)    -- 尺寸参数(X/Y分量)
    self.zzinterval   = 200                   -- 间隔距离
    -- 样条数据容器
    self.simplePoints = UE.TArray(UE.FVector) -- 简化点坐标集合
    self.currentPoint = 1                     -- 当前操作点索引
    self.points       = UE.TArray(UE.FVector) -- 精确点坐标集合
    self.tangents     = UE.TArray(UE.FVector) -- 切线向量集合
    -- 模型标识参数
    self.ssdType      = 1                     -- SSX子类型标识
    self.modelType    = 7                     -- 模型分类ID(7=SSX专用)
    self.clickType    = 2                     -- 交互模式(2=可拖拽)
    self.animeType    = 1                     -- 动画类型标识
    -- 状态标记
    self.bSet         = false                 -- 设置完成标记
    self.bLoop        = false                 -- 循环播放标记
    self.bMove        = true                  -- 允许移动
    -- 材质资源路径表(索引1/2对应不同材质)
    self.STT          = {
        '/Game/SandBox/SSX/Materials/M_SSX1.M_SSX1',
        '/Game/SandBox/SSX/Materials/M_SSX2.M_SSX2'
    }
end

--- 每帧更新逻辑
--- @function ReceiveTick
--- @param DeltaSeconds number 帧间隔时间(秒)
--- @description
---   处理SSX动画播放逻辑：
---   1. 当存在活动计时器时：
---     - 检测计时器状态(f=-1表示触发)
---     - 根据计数器和最大计数决定是否继续动画
---   2. 状态切换控制：
---     - bSet标记控制单次播放结束
---     - bLoop标记控制循环播放
function M:ReceiveTick(DeltaSeconds)
    if self.playTimer then
        -- 获取计时器经过时间(f=-1表示计时结束)
        local f = UE.UKismetSystemLibrary.K2_GetTimerElapsedTimeHandle(self:GetWorld(), self.playTimer)
        if f == -1 then
            self.count = self.count + 1 -- 动画帧计数器递增
            if self.maxCount >= self.count then
                -- 创建动画盒子并重置计时器
                self:CreateAnimeBox()
                self.playTimer = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.RunAnime }, 1, false)
            else
                -- 状态切换控制
                if self.bSet then
                    self.bSet = false
                    self:StopAnime() -- 停止单次动画
                elseif self.bLoop then
                    self:PlayAnime() -- 循环播放
                elseif self.bPlaying then
                    -- 广播停止事件(带模型名称参数)
                    self.StopOutEvent:Broadcast(Model.GetActorAccurateDisplayName(self))
                end
            end
        else
            self:RunAnime(f) -- 执行动画更新
        end
    end
end

--- 模型数据序列化方法
--- @function ModelSave
--- @return table 包含模型状态的Lua表
--- @description
---   导出SSX模型关键数据：
---   1. 几何参数(间隔/宽度/半径/尺寸)
---   2. 样条点坐标集合(JSON序列化)
---   3. 动画控制参数(创建间隔/数量/速度/方向)
function M:ModelSave()
    -- 序列化样条点坐标
    local PointLocations = {}
    for key, value in pairs(self.simplePoints) do
        PointLocations[key] = DFL.fromVector(value) -- 使用DataFunction库转换
    end

    -- 组织输出数据表
    local table = {
        ["zzinterval"]          = self.zzinterval,          -- 间隔距离
        ["ssdWitch"]            = self.ssdWitch,            -- 特殊宽度
        ["CType"]               = self.clickType,           -- 交互类型
        ["Radius"]              = self.radius,              -- 基础半径
        ["zzSizeX"]             = self.zzSize.X,            -- 尺寸X分量
        ["zzSizeY"]             = self.zzSize.Y,            -- 尺寸Y分量
        ["ssdType"]             = self.ssdType,             -- SSX子类型
        ["PointLocations"]      = PointLocations,           -- 样条点数组
        ["modelCreateSpace"]    = self.modelCreateSpace,    -- 模型创建间隔
        ["modelCreateNumber"]   = self.modelCreateNumber,   -- 模型创建数量
        ["modelSpeed"]          = self.modelSpeed,          -- 动画速度
        ["animationDirectionr"] = self.animationDirectionr, -- 动画方向
    }
    return table
end

--- 模型数据反序列化方法
--- @function ModelLoad
--- @param table table 包含模型数据的Lua表
--- @description
---   1. 加载基础参数(尺寸/类型/半径)
---   2. 解析样条点坐标数据
---   3. 重建样条模型
function M:ModelLoad(table)
    -- 加载基础参数
    self.zzinterval          = table["zzinterval"]
    self.ssdWitch            = table["ssdWitch"]
    self.clickType           = table["CType"] ~= 0 and table["CType"] or self.clickType -- 默认值保护
    self.modelType           = table["Type"]
    self.radius              = table["Radius"]
    self.zzSize.X            = table["zzSizeX"]
    self.zzSize.Y            = table["zzSizeY"]
    self.ssdType             = table["ssdType"]
    -- 动画参数
    self.modelCreateSpace    = table.modelCreateSpace
    self.modelCreateNumber   = table.modelCreateNumber
    self.modelSpeed          = table.modelSpeed
    self.animationDirectionr = table.animationDirectionr

    -- 重建样条点集合
    self.simplePoints:Clear()
    local Lstrs = table["PointLocations"]
    for key, value in pairs(Lstrs) do
        local LVal = UE.UJsonLibraryHelpers.Parse(value)       -- JSON解析
        local location = UE.UJsonLibraryHelpers.ToVector(LVal) -- 转换为向量
        self.simplePoints:Add(location)
    end
    self:SetSplineModel() -- 重建样条模型
end

--- 创建SSX管道模型
--- @function SetSplineModel
--- @description
---   SSX模型生成流程：
---   1. 更新样条线(UpdateLS)
---   2. 计算管道点位(SSXlinePoint)
---   3. 生成复杂样条(ComplexSplineGeneration)
function M:SetSplineModel()
    self:UpdateLS()                -- 更新样条线数据
    self:SSXlinePoint()            -- 计算管道特征点
    self:ComplexSplineGeneration() -- 生成最终样条模型
end

--- 外部数据设置接口
--- @function SetData
--- @param table table 外部输入数据表
--- @return any 处理结果
--- @description
---   1. 延迟加载模型管理器(BP_ModelManage)
---   2. 调用DataSetSplineModel处理输入数据
function M:SetData(table)
    -- 延迟加载模型管理器
    if not self.modelManage then
        local mmClass = LoadClass(Class.modelManage)
        self.modelManage = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(), mmClass)
    end
    -- 处理数据并返回结果
    local location = self:DataSetSplineModel(table)
    return location
end

--- SSX模型数据设置方法
--- @function DataSetSplineModel
--- @param table table 包含模型参数的数据表
--- @return any 返回更新后的控制点位置
--- @description
---   处理外部传入的SSX模型参数：
---   1. 解析基础参数(半径/间隔/宽度/尺寸)
---   2. 更新控制点位置
---   3. 根据参数变化重建模型
function M:DataSetSplineModel(table)
    -- 参数解析
    local pointsNum = table.int                                                -- 样条点总数
    local currentPoint = table.cp                                              -- 当前控制点索引
    local zzinterval = table.sillPillarInterval                                -- 支柱间隔
    local ssdWitch = table.ssdWidth                                            -- 输送带宽度
    local webLocation = UE.FVector(table.x, table.y, table.z)                  -- 位置坐标
    local radius = table.r                                                     -- 管道半径
    local zzSize = UE.FVector2D(table.sillPillarLength, table.sillPillarWidth) -- 支柱尺寸
    local ssdType = table.type                                                 -- 输送带类型
    local returnL
    -- 显示名称设置
    self:GetAttachParentActor().showName = table.showname

    local bUpdate = false -- 更新标记

    -- 检查几何参数变化
    if radius ~= self.radius or zzinterval ~= self.zzinterval or ssdWitch ~= self.ssdWitch
        or zzSize ~= self.zzSize or ssdType ~= self.ssdType then
        self.radius = radius
        self.zzinterval = zzinterval
        self.ssdWitch = ssdWitch
        self.zzSize = zzSize
        self.ssdType = ssdType
        bUpdate = true
    end

    -- 控制点位置更新逻辑
    if currentPoint ~= self.currentPoint then
        self.currentPoint = currentPoint
        returnL = self.SimpleSpline:GetLocationAtSplinePoint(currentPoint - 1, 1)
        self.modelManage:CreateGizmo(self.modelManage.NubPoints:Find(self.currentPoint))
    else
        -- 位置变化检测
        local location = self.SimpleSpline:GetLocationAtSplinePoint(self.currentPoint - 1, 1)
        if not UE.UKismetMathLibrary.EqualEqual_VectorVector(webLocation, location, 0.5) then
            self.SimpleSpline:SetLocationAtSplinePoint(self.currentPoint - 1, webLocation, 1, true)
            bUpdate = true
        end
    end

    -- 样条点数量变化处理
    local Int = self.SimpleSpline:GetNumberOfSplinePoints()
    if pointsNum > Int then
        -- 添加新控制点
        local Vector = self.SimpleSpline:GetLocationAtSplineInputKey(self.currentPoint - 0.5, 1)
        self.SimpleSpline:AddSplinePointAtIndex(Vector, self.currentPoint, 1, true)
        bUpdate = true
    elseif pointsNum < Int then
        -- 移除控制点
        self.SimpleSpline:RemoveSplinePoint(self.currentPoint - 1, true)
        bUpdate = true
    end

    -- 执行模型更新
    if bUpdate then
        self:Update()                                  -- 更新模型
        self.modelManage:BuildPoint(self.simplePoints) -- 重建控制点

        -- 更新当前控制点索引
        if self.modelManage.NubPoints:Find(table.cp) then
            self.currentPoint = table.cp
        else
            self.currentPoint = 1
        end
        local Point = self.modelManage.NubPoints:Find(self.currentPoint)
        returnL = Point:K2_GetActorLocation()
        self.modelManage:CreateGizmo(Point) -- 创建操作手柄
    end
    return returnL
end

--- 模型更新方法
--- @function Update
--- @description
---   执行SSX模型完整更新流程：
---   1. 更新控制点数据
---   2. 计算管道特征点
---   3. 生成复杂样条模型
function M:Update()
    self:UpdatePoint()             -- 更新控制点
    self:SSXlinePoint()            -- 计算管道特征点
    self:ComplexSplineGeneration() -- 生成复杂样条
end

--- 获取模型数据
--- @function GetData
--- @return table 包含模型参数的Lua表
--- @description
---   输出SSX模型当前状态数据：
---   1. 几何参数(半径/间隔/宽度/尺寸)
---   2. 位置信息(X/Y/Z坐标)
---   3. 样条信息(控制点数量/总长度)
function M:GetData()
    local Int = self.SimpleSpline:GetNumberOfSplinePoints()
    local Location = self.SimpleSpline:GetLocationAtSplinePoint(self.currentPoint - 1, 1)

    local PDT = {
        int = Int,                                                      -- 控制点总数
        cp = self.currentPoint,                                         -- 当前控制点索引
        sillPillarInterval = self.zzinterval,                           -- 支柱间隔
        ssdWidth = self.ssdWitch,                                       -- 输送带宽度
        x = Location.X,                                                 -- X坐标
        y = Location.Y,                                                 -- Y坐标
        z = Location.Z,                                                 -- Z坐标
        r = self.radius,                                                -- 管道半径
        showname = self:GetAttachParentActor().showName,                -- 显示名称
        sillPillarLength = self.zzSize.X,                               -- 支柱长度
        sillPillarWidth = self.zzSize.Y,                                -- 支柱宽度
        type = self.ssdType,                                            -- 输送带类型
        bMove = self.bMove,                                             -- 可移动标记
        overallgh = DFL.integrate(self.SimpleSpline:GetSplineLength()), -- 样条总长度
    }
    return PDT
end

--- 简单样条点布局算法
--- @function PointCount
--- @param A userdata 起点坐标(FVector)
--- @param B userdata 终点坐标(FVector)
--- @description
---   根据两点间距离自动添加中间控制点：
---   1. X轴距离超过半径时添加水平中间点
---   2. Z轴距离超过半径时添加垂直中间点
function M:PointCount(A, B)
    self.simplePoints:Add(A) -- 添加起点
    -- X轴方向中间点处理
    if math.abs(A.X - B.X) > self.radius then
        local New = UE.FVector(B.X, A.Y, A.Z)
        self.simplePoints:Add(New)
    end
    -- Y轴方向中间点处理
    if math.abs(A.X - B.X) > self.radius then
        local New = UE.FVector(B.X, B.Y, A.Z)
        self.simplePoints:Add(New)
    end
    -- Z轴方向中间点处理
    if math.abs(A.Z - B.Z) > self.radius then
        self.simplePoints:Add(B) -- 添加终点
    end
    self:UpdateLS()              -- 更新样条线
end

--- 简单样条线更新
--- @function UpdateLS
--- @description
---   根据simplePoints重建简单样条线：
---   1. 清空现有样条点
---   2. 逐个添加新坐标点
---   3. 设置曲线类型为线性(0=线性)
function M:UpdateLS()
    self.SimpleSpline:ClearSplinePoints() -- 清空样条点
    for i = 1, self.simplePoints:Num() do
        -- 添加样条点(索引从0开始)
        self.SimpleSpline:AddSplinePointAtIndex(self.simplePoints[i], i - 1, 1, false)
        self.SimpleSpline:SetSplinePointType(i - 1, 0, false) -- 设置为线性点
    end
    self.SimpleSpline:UpdateSpline()                          -- 提交更新
end

--- 控制点数据更新
--- @function UpdatePoint
--- @description
---   从简单样条线同步控制点数据：
---   1. 清空现有控制点集合
---   2. 从样条线重新获取所有点坐标
function M:UpdatePoint()
    local int = self.SimpleSpline:GetNumberOfSplinePoints()
    self.simplePoints:Clear() -- 清空控制点集合
    -- 重新获取所有控制点
    for i = 1, int do
        local location = self.SimpleSpline:GetLocationAtSplinePoint(i - 1, 1)
        self.simplePoints:Add(location)
    end
end

--- 基于简单样条线生成管道特征点(增加倒角处理)
--- @function SSXlinePoint
--- @description
---   1. 遍历简单样条点集(simplePoints)
---   2. 对中间点计算倒角点(CalculateChamferPoint3D)
---   3. 添加Z轴偏移(+50单位)
---   4. 计算切线向量(TangentsAdd)
function M:SSXlinePoint()
    -- 清空特征点和切线集合
    self.points:Clear()
    self.tangents:Clear()

    -- 遍历所有简单样条点
    for i = 1, self.simplePoints:Num() do
        -- 中间点处理(非首尾点)
        if i > 1 and i < self.simplePoints:Num() then
            -- 计算前后倒角点
            local point1 = self:CalculateChamferPoint3D(
                self.simplePoints[i - 1], self.simplePoints[i], self.radius * 2)
            local point2 = self:CalculateChamferPoint3D(
                self.simplePoints[i + 1], self.simplePoints[i], self.radius * 2)

            -- 处理重合点情况
            if UE.UKismetMathLibrary.EqualEqual_VectorVector(point1, point2, 0.5) then
                self.points:Add(UE.FVector(point1.X, point1.Y, point1.Z + 50))
                self:TangentsAdd(self.simplePoints[i], self.simplePoints[i - 1], self.radius)
            else
                -- 添加两个倒角点
                self.points:Add(UE.FVector(point1.X, point1.Y, point1.Z + 50))
                self:TangentsAdd(self.simplePoints[i], self.simplePoints[i - 1], self.radius)
                self.points:Add(UE.FVector(point2.X, point2.Y, point2.Z + 50))
                self:TangentsAdd(self.simplePoints[i + 1], self.simplePoints[i], self.radius)
            end
        else
            -- 首尾点处理(直接添加Z偏移)
            self.points:Add(UE.FVector(self.simplePoints[i].X, self.simplePoints[i].Y, self.simplePoints[i].Z + 50))
            -- 首尾点切线计算
            if i == 1 then
                self:TangentsAdd(self.simplePoints[i + 1], self.simplePoints[i], self.radius)
            else
                self:TangentsAdd(self.simplePoints[i], self.simplePoints[i - 1], self.radius)
            end
        end
    end
end

--- 计算切线向量并添加到集合
--- @function TangentsAdd
--- @param A FVector 起点
--- @param B FVector 终点
--- @param angleRadius number 角度半径
--- @description
---   1. 计算两点方向向量
---   2. 根据距离调整切线长度
function M:TangentsAdd(A, B, angleRadius)
    -- 计算方向向量并归一化
    local transform = UE.UKismetMathLibrary.Subtract_VectorVector(A, B)
    transform:Normalize()

    -- 根据距离调整切线长度
    local Distance = UE.UKismetMathLibrary.Vector_Distance(A, B)
    if Distance > angleRadius then
        transform = transform * angleRadius * 6
    else
        transform = transform * angleRadius * 2
    end

    -- 添加到切线集合
    self.tangents:Add(transform)
end

--- 生成复杂样条线
--- @function ComplexSplineGeneration
--- @description
---   1. 清空现有样条点
---   2. 添加所有特征点(设置点类型为4=自定义)
---   3. 设置每个点的切线
---   4. 创建输送带和支柱
function M:ComplexSplineGeneration()
    -- 清空样条线
    self.SplineAsPath:ClearSplinePoints()

    -- 添加所有特征点
    for i = 1, self.points:Num() do
        self.SplineAsPath:AddSplinePointAtIndex(self.points[i], i - 1, 1, false)
        self.SplineAsPath:SetSplinePointType(i - 1, 4, false) -- 设置点类型为自定义
        self.SplineAsPath:SetTangentAtSplinePoint(i - 1, self.tangents[i], 1, false)
    end
    self.SplineAsPath:UpdateSpline()

    -- 防止重复创建
    if self.bWait then
        return
    end

    -- 创建输送带和支柱
    self:CreateSSD(LoadObject('/Game/SandBox/SSX/Geometries/CSD333.CSD333'))
    self:CreateZZ()

    -- 设置延迟标记
    self.bWait = true
    coroutine.resume(
        coroutine.create(
            function()
                UE.UKismetSystemLibrary.Delay(self, 0.05)
                self.bWait = false
            end
        ),
        self
    )
end

--- 计算3D倒角点
--- @function CalculateChamferPoint3D
--- @param point0 FVector 起点
--- @param point1 FVector 终点
--- @param radius number 倒角半径
--- @return FVector 倒角点坐标
--- @description
---   1. 计算两点距离和方向
---   2. 根据半径调整倒角点位置
function M:CalculateChamferPoint3D(point0, point1, radius)
    local distance = UE.UKismetMathLibrary.Vector_Distance(point0, point1)
    local direction = UE.UKismetMathLibrary.GetDirectionUnitVector(point0, point1)
    local chamferPoint = UE.FVector(0, 0, 0)

    -- 距离足够时计算倒角点
    if radius < distance then
        chamferPoint = point0 + direction * (distance - radius * 2)
    else
        chamferPoint = point0
    end
    return chamferPoint
end

--- 创建输送带模型
--- @function CreateSSD
--- @param ssd UStaticMesh 输送带静态网格
--- @description
---   1. 清理现有输送带组件
---   2. 根据样条分段创建多个输送带段
---   3. 设置每段的起始/结束位置和缩放
function M:CreateSSD(ssd)
    -- 清理现有组件
    for key, value in pairs(self.SPMCs) do
        if value then
            local O = value:GetOwner()
            value:K2_DestroyComponent(O)
        end
        self.SPMCs:Remove(value)
    end

    -- 获取样条信息
    local num = self.SplineAsPath:GetNumberOfSplinePoints()
    local bounds = ssd:GetBounds()
    local scale = UE.FVector2D(1, 1)
    scale.X = self.ssdWitch / (bounds.BoxExtent.Y * 2) -- 计算宽度缩放

    -- 分段创建输送带
    for i = 1, num - 1 do
        local lineDistance = self.SplineAsPath:GetDistanceAlongSplineAtSplinePoint(i) -
            self.SplineAsPath:GetDistanceAlongSplineAtSplinePoint(i - 1)
        local multiple = math.ceil(lineDistance / (10 * self.radius)) -- 计算分段数

        -- 创建每小段输送带
        for j = 1, multiple do
            local key1 = (i - 1) + ((j - 1) / multiple)
            local key2 = (i - 1) + (j / multiple)

            -- 获取样条位置和切线
            local l1, t1 = self:GetLocationAndTangentSplineInputKey(key1)
            local l2, t2 = self:GetLocationAndTangentSplineInputKey(key2)

            -- 创建并设置输送带组件
            local spmc = self:CreateSPMC(ssd)
            spmc:SetStartAndEnd(l1, t1, l2, t2, true)
            spmc:SetStartScale(scale)
            spmc:SetEndScale(scale)
            spmc:SetMaterial(1, LoadObject(self.STT[self.ssdType]))
            self.SPMCs:Add(spmc)
        end
    end
end

--- 获取样条线上指定点的位置和切线向量
--- @function GetLocationAndTangentSplineInputKey
--- @param Inputkey number 样条输入键值(0~1)
--- @return FVector 位置坐标
--- @return FVector 切线向量
--- @description
---   1. 获取样条线上指定点的位置和切线
---   2. 对切线长度进行限制(不超过半径6倍)
function M:GetLocationAndTangentSplineInputKey(Inputkey)
    local location = self.SplineAsPath:GetLocationAtSplineInputKey(Inputkey, 1)
    local transform = self.SplineAsPath:GetTangentAtSplineInputKey(Inputkey, 1)
    if UE.UKismetMathLibrary.VSize(transform) > self.radius * 6 then
        transform:Normalize()
        transform = transform * 10 * self.radius
    end
    -- print(location, transform)
    return location, transform
end

--- 在样条线上绘制垂直线段
--- @function DrawVerticalLineOnSpline
--- @param spline userdata 样条组件
--- @param inputKey number 样条输入键值
--- @return FVector 线段起点
--- @return FVector 线段终点
--- @description
---   1. 获取样条点位置和切线
---   2. 计算垂直于切线的方向
---   3. 根据宽度参数计算线段起止点
function M:DrawVerticalLineOnSpline(spline, inputKey)
    local splineLocation = spline:GetLocationAtSplineInputKey(inputKey, 0)
    local splineTangent = spline:GetTangentAtSplineInputKey(inputKey, 0)
    splineTangent = UE.UKismetMathLibrary.Normal(splineTangent, 1)
    -- 水平垂直
    local perpendicularDirection = UE.UKismetMathLibrary.GreaterGreater_VectorRotator(
        splineTangent, UE.FRotator(0, 90, 0))
    perpendicularDirection = UE.FVector(perpendicularDirection.X, perpendicularDirection.Y, 0)

    local lineLength = self.ssdWitch - 3 * self.zzSize.Y

    local lineStart = splineLocation - perpendicularDirection * (lineLength * 0.5)
    local lineEnd = splineLocation + perpendicularDirection * (lineLength * 0.5)
    -- print(splineTangent, PerpendicularDirection, lineStart, lineEnd)
    return lineStart, lineEnd
end

--- 创建支柱模型
--- @function CreateZZ
--- @description
---   1. 清理现有支柱组件
---   2. 沿样条线分段创建支柱
---   3. 根据高度参数生成垂直支柱
---   4. 设置支柱材质和位置
function M:CreateZZ()
    -- 清理现有支柱组件
    for key, value in pairs(self.STMCs) do
        if value then
            local O = value:GetOwner()
            value:K2_DestroyComponent(O)
        end
        self.STMCs:Remove(value)
    end

    local Num = self.SplineAsPath:GetNumberOfSplinePoints()
    local Basic = self:K2_GetActorLocation()
    -- 遍历样条线段
    for i = 1, Num - 1 do
        local D1 = self.SplineAsPath:GetDistanceAlongSplineAtSplinePoint(i - 1)
        local D2 = self.SplineAsPath:GetDistanceAlongSplineAtSplinePoint(i)

        -- 计算分段数
        local segments = (D2 - D1) / self.zzinterval
        segments = DFL.integrate(segments)
        local jmax = segments
        -- print(segments)
        if i == Num - 1 then
            jmax = segments - 1
        end

        if segments > 0 then
            -- 每段创建支柱
            for j = 1, jmax do
                local key = i - 1 + j / segments
                local location = self.SplineAsPath:GetLocationAtSplineInputKey(key, 1)
                local h = location.Z - Basic.Z
                if h > 0 then
                    -- 获取垂直线段端点
                    local l1, l2 = self:DrawVerticalLineOnSpline(self.SplineAsPath, key)

                    -- 设置支柱旋转
                    local r = self.SplineAsPath:GetRotationAtSplineInputKey(key, 1)
                    r = UE.FRotator(r.Pith, r.Yaw, 0)
                    local t1 = UE.UKismetMathLibrary.Conv_RotatorToTransform(r)
                    t1.Translation = l1
                    local t2 = UE.UKismetMathLibrary.Conv_RotatorToTransform(r)
                    t2.Translation = l2

                    -- 创建支柱网格组件
                    local stmc1 = self:AddComponentByClass(UE.UProceduralMeshComponent, false, t1, false)
                    local stmc2 = self:AddComponentByClass(UE.UProceduralMeshComponent, false, t2, false)

                    -- 生成支柱网格
                    local vertices = UE.TArray(UE.FVector)
                    local triangles = UE.TArray(0)
                    local normals = UE.TArray(UE.FVector)
                    local uvs = UE.TArray(UE.FVector2D)
                    local vertexColors = UE.TArray(UE.FColor)
                    local tangents = UE.TArray(UE.FVector)

                    UE.UKismetProceduralMeshLibrary.GenerateBoxMesh(
                        UE.FVector(self.zzSize.X, self.zzSize.Y, (h + 4) / 2),
                        vertices,
                        triangles,
                        normals,
                        uvs,
                        tangents
                    )

                    -- 偏移柱子位置
                    for key, value in pairs(vertices) do
                        value = value + UE.FVector(0, 0, -((h - 4) / 2))
                        vertices:Set(key, value)
                    end
                    stmc1:CreateMeshSection(0, vertices, triangles, normals, uvs, vertexColors, tangents, true)
                    stmc2:CreateMeshSection(0, vertices, triangles, normals, uvs, vertexColors, tangents, true)
                    stmc1:SetMaterial(0, LoadObject('/Game/SandBox/SSX/Materials/007baitie.007baitie'))
                    stmc2:SetMaterial(0, LoadObject('/Game/SandBox/SSX/Materials/007baitie.007baitie'))
                    self.STMCs:Add(stmc1)
                    self.STMCs:Add(stmc2)

                    -- 创建中间横梁
                    local kmax = math.floor(h / self.zzinterval)
                    -- print(h, kmax)
                    if kmax > 0 then
                        local transform = UE.UKismetMathLibrary.Conv_RotatorToTransform(r)
                        transform.Translation = UE.FVector(location.X, location.Y, self.zzinterval / 2)
                        local STMC = self:AddComponentByClass(UE.UProceduralMeshComponent, true, transform, false)
                        UE.UKismetProceduralMeshLibrary.GenerateBoxMesh(
                            UE.FVector(self.zzSize.X, (self.ssdWitch - 5 * self.zzSize.Y) / 2, self.zzSize.X),
                            vertices,
                            triangles,
                            normals,
                            uvs,
                            tangents
                        )
                        for k = 1, kmax do
                            local V = UE.TArray(UE.FVector)
                            for key, value in pairs(vertices) do
                                value.Z = value.Z + (k - 1) * self.zzinterval
                            end
                            STMC:CreateMeshSection(k, vertices, triangles, normals, uvs, nil, tangents, true)
                            STMC:SetMaterial(k, LoadObject('/Game/SandBox/SSX/Materials/007baitie.007baitie'))
                            self.STMCs:Add(STMC)
                        end
                    end
                end
            end
        end
    end
end

--- 获取动画配置数据
--- @function GetAnimeData
--- @return table 包含动画参数的Lua表
--- @description
---   返回当前动画配置参数：
---   1. showName - 显示名称
---   2. modelCreateSpace - 模型创建间隔
---   3. modelCreateNumber - 模型创建数量
---   4. modelSpeed - 移动速度
---   5. animationDirectionr - 移动方向标识
function M:GetAnimeData()
    local animeTable = {
        showName            = self:GetAttachParentActor().showName,
        modelCreateSpace    = self.modelCreateSpace,
        modelCreateNumber   = self.modelCreateNumber,
        modelSpeed          = self.modelSpeed,
        animationDirectionr = self.animationDirectionr,
    }
    return animeTable
end

--- 设置动画参数并启动动画
--- @function SetAnimeData
--- @param animeTable table 包含动画参数的Lua表
--- @description
---   1. 更新动画参数
---   2. 清除现有计时器
---   3. 停止当前动画
---   4. 设置bSet标记为true
---   5. 启动新动画
function M:SetAnimeData(animeTable)
    self.modelCreateSpace    = animeTable.modelCreateSpace
    self.modelCreateNumber   = animeTable.modelCreateNumber
    self.modelSpeed          = animeTable.modelSpeed
    self.animationDirectionr = animeTable.animationDirectionr
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

--- 启动动画播放
--- @function PlayAnime
--- @description
---   1. 计算样条线总长度
---   2. 计算最大动画计数(maxCount)
---   3. 初始化播放表(playT)和计数器(count)
---   4. 创建动画盒子
---   5. 设置计时器(每秒触发RunAnime)
function M:PlayAnime()
    local location = self.SplineAsPath:GetSplineLength()
    self.maxCount  = math.floor(location / self.modelSpeed) + self.modelCreateNumber
        + (self.modelCreateNumber - 1) * self.modelCreateSpace
    self.playT     = {}
    self.count     = 0
    self:CreateAnimeBox()
    self.playTimer = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.RunAnime }, 1, false)
end

--- 创建动画盒子
--- @function CreateAnimeBox
--- @description
---   1. 检查当前动画盒子数量
---   2. 当数量不足且满足创建间隔时：
---     - 计算盒子尺寸(x/y)
---     - 创建新动画盒子对象
---     - 添加到播放表(playT)
function M:CreateAnimeBox()
    local num = #self.playT
    if num < self.modelCreateNumber and (self.count % (self.modelCreateSpace + 1)) == 0 then
        local x = self.ssdWitch / 2 * 0.8
        local y = self.ssdWitch / 2 * 0.6
        local transform = {
            object = self:CreateBox(x, y),
            bRun = true,
            bVisible = false
        }
        table.insert(self.playT, transform)
    end
end

--- 运行动画帧逻辑
--- @function RunAnime
--- @param alpha number 动画进度(0-1)
--- @description
---   1. 遍历所有动画盒子：
---     - 计算当前移动距离(distance)
---     - 根据方向标识调整位置(current)
---     - 获取样条线上的位置和旋转
---     - 设置盒子位置和旋转
---     - 超过样条长度时销毁盒子
function M:RunAnime(alpha)
    if not alpha then
        return
    end
    for k, v in pairs(self.playT) do
        if v.bRun then
            local distance = (self.count - (k - 1) - (k - 1) * self.modelCreateSpace + alpha) * self.modelSpeed
            local length = self.SplineAsPath:GetSplineLength()

            local current = distance
            if self.animationDirectionr == "2" then
                current = length - distance
            end

            local location = self.SplineAsPath:GetLocationAtDistanceAlongSpline(current, 1, false)
            local rotation = self.SplineAsPath:GetRotationAtDistanceAlongSpline(current, 1, false)
            location.Z = location.Z + 20
            rotation.Roll = 0
            v.object:K2_SetWorldLocation(location, false, nil, false)
            v.object:K2_SetWorldRotation(rotation, false, nil, false)
            if v.bVisible ~= self.RootComponent.bVisible then
                v.object:SetVisibility(self.RootComponent.bVisible, false)
            end

            if distance > length then
                v.bRun = false
                v.object:K2_DestroyComponent(self)
                v.object = nil
            end
        end
    end
end

--- 停止动画播放
--- @function StopAnime
--- @description
---   1. 清除计时器
---   2. 销毁所有动画盒子对象
---   3. 清空播放表(playT)
function M:StopAnime()
    UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.playTimer)
    self.playTimer = nil
    for k, v in pairs(self.playT) do
        if v.object then
            v.object:K2_DestroyComponent(self)
            v.object = nil
        end
    end
    self.playT = {}
end

--- 控制动画播放状态
--- @function PlayAnimation
--- @param bLoop boolean 是否循环播放
--- @description
---   1. 如果已有动画则停止
---   2. 设置循环标记(bLoop)
---   3. 启动动画播放
function M:PlayAnimation(bLoop)
    if self.bSet then
        self:StopAnime()
        self.bSet = false
    end
    self.bLoop = bLoop
    self:PlayAnime()
end

--- 停止动画播放
--- @function StopAnimation
--- @description
---   1. 设置循环标记为false
---   2. 调用StopAnime停止动画
function M:StopAnimation()
    self.bLoop = false
    self:StopAnime()
end

return M
