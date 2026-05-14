--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_Passage_C
local M = UnLua.Class()
local DFL = require("SandBox.DataFunction")

--- 通道模型初始化方法
--- @function Initialize
--- @param Initializer any 初始化参数
--- @description
---   初始化通道模型基础属性：
---   1. 设置默认尺寸参数（宽度/长度）
---   2. 初始化样条点容器
---   3. 配置模型类型/交互类型/移动权限
---   4. 预设颜色参数（A/B双色模式）
function M:Initialize(Initializer)
    -- 几何参数
    self.width          = 100                               -- 通道默认宽度（单位：厘米）
    self.length         = 500                               -- 通道默认长度
    -- 样条数据
    self.simplePoints   = UE.TArray(UE.FVector)             -- 样条点坐标容器
    self.currentPoint   = 1                                 -- 当前操作点索引
    -- 模型标识
    self.modelType      = 14                                -- 模型分类ID（14表示通道类）
    self.clickType      = 2                                 -- 交互模式（2=可拖拽）
    self.modelCode      = "Passage"                         -- 模型资源编码
    -- 状态标记
    self.bMove          = true                              -- 允许移动
    self.bBuild         = true                              -- 允许构建
    -- 外观参数
    self.passageType    = 1                                 -- 通道类型（1/2/3）
    self.passageTexture = 0                                 -- 纹理索引（0/1/2）
    self.colorA         = UE.FLinearColor(1, 1, 1, 1)       -- 主色（RGBA）
    self.colorB         = UE.FLinearColor(0.1, 0.1, 0.1, 1) -- 辅色

    self.frameWidth     = 10
    self.passageWidth   = 80
end

--- 游戏开始回调
--- @function ReceiveBeginPlay
--- @description
---   1. 初始化构建状态
---   2. 创建动态材质实例
function M:ReceiveBeginPlay()
    -- 初始化状态
    self.distance = 0                    -- 距离计量
    self.bBuild = false                  -- 构建完成标记
    self.mat = self:SetDynamicMaterial() -- 创建动态材质
end

--- 模型数据序列化方法
--- @function ModelSave
--- @return table 包含模型状态的Lua表
--- @description
---   导出模型关键数据：
---   1. 几何参数（宽度/长度）
---   2. 样条点坐标集合（JSON序列化）
---   3. 外观配置（类型/纹理/颜色）
function M:ModelSave()
    -- 序列化样条点坐标
    local pointLocations = {}
    for key, value in pairs(self.simplePoints) do
        pointLocations[key] = DFL.fromVector(value) -- 使用DataFunction库转换
    end

    -- 组织输出数据表
    local table = {
        ["Width"]          = self.width,
        ["FrameWidth"]     = self.frameWidth,
        ["PassageWidth"]   = self.passageWidth,
        ["Length"]         = self.length,         -- 通道长度
        ["CType"]          = self.clickType,      -- 交互类型
        ["PointLocations"] = pointLocations,      -- 样条点数组
        ["passageType"]    = self.passageType,    -- 通道类型
        ["passageTexture"] = self.passageTexture, -- 纹理索引
        ["Colora"]         = DFL.fromColor(self.colorA),
        ["Colorb"]         = DFL.fromColor(self.colorB),
    }
    return table
end

--- 模型数据反序列化方法
--- @function ModelLoad
--- @param table table 包含模型数据的Lua表
--- @description
---   1. 加载基础参数（尺寸/交互类型）
---   2. 解析样条点坐标数据
---   3. 重建样条模型
---   4. 应用外观配置
function M:ModelLoad(table)
    -- 加载基础参数
    self.width           = table["Width"]
    self.frameWidth      = table["FrameWidth"]
    self.passageWidth    = table["PassageWidth"]
    self.length          = table["Length"]
    self.clickType       = table["CType"] ~= 0 and table["CType"] or self.clickType
    self.modelType       = table["Type"]

    -- 解析外观参数
    local passageType    = table["passageType"]
    local passageTexture = table["passageTexture"]
    local colorA         = DFL.toColor(table["Colora"])
    local colorB         = DFL.toColor(table["Colorb"])

    -- 重建样条点集合
    self.simplePoints:Clear()
    local lStrs = table["PointLocations"]
    for key, value in pairs(lStrs) do
        local l = DFL.toVector(value)
        self.simplePoints:Add(l)
    end

    -- 重建模型
    self:SetSplineModel()
    self:SetM(passageType, passageTexture, colorA, colorB)
end

-- 创建通道
function M:SetSplineModel()
    self:UpdateLS()
    if self.frameWidth ~= nil and self.passageWidth ~= nil then
        self:CreateLinePlane(DFL.integrate(self.frameWidth * 2 + self.passageWidth), DFL.integrate(self.length), 2)
        self.mat:SetScalarParameterValue("bWidth", self.frameWidth * 2 / (self.frameWidth * 2 + self.passageWidth))
    else
        self:CreateLinePlane(DFL.integrate(self.width), DFL.integrate(self.length), 2)
        self.frameWidth = 0.1 * self.width
        self.passageWidth = 0.8 * self.width
    end
    self.PMesh:SetMaterial(0, self.mat)
end

--- 样条模型更新方法
--- @function UpdateLS
--- @description
---   根据simplePoints重建样条路径：
---   1. 清空现有样条点
---   2. 逐个添加新坐标点
---   3. 设置曲线类型为线性（0=线性）
function M:UpdateLS()
    self.SplineAsPath:ClearSplinePoints()
    for i = 1, self.simplePoints:Num() do
        local l = self.simplePoints[i]
        -- 添加样条点（索引从0开始）
        self.SplineAsPath:AddSplinePointAtIndex(l, i - 1, 1, false)
        -- 设置曲线类型为线性
        self.SplineAsPath:SetSplinePointType(i - 1, 0, false)
    end
    self.SplineAsPath:UpdateSpline() -- 提交更新
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
    if not self.modelManage then
        self.modelManage = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(),
            LoadClass("/Game/SandBox/Blueprints/BP_ModelManage.BP_ModelManage_C"))
    end
    local L = self:DataSetSplineModel(table)
    return L
end

-- 外部数据设置管道
function M:DataSetSplineModel(table)
    local pointsNum, frameWidth, passageWidth, length, currentPoint =
        table.int, table.FrameWidth, table.PassageWidth, table.Length, table.cp
    local location                                                  = UE.FVector(table.x, table.y, table.z)
    local bUpdate                                                   = false
    -- self.showName = table.showname
    self:GetAttachParentActor().showName                            = table.showname
    local returnL


    if frameWidth ~= self.FrameWidth or length ~= self.Length or passageWidth ~= self.PassageWidth then
        self.frameWidth = frameWidth
        self.passageWidth = passageWidth
        self.Width = self.frameWidth * 2 + self.passageWidth
        self.Length = length
        bUpdate = true
        self.mat:SetScalarParameterValue("bWidth", self.frameWidth * 2 / (self.frameWidth * 2 + self.passageWidth))
    end

    if currentPoint ~= self.currentPoint then
        self.currentPoint = currentPoint
        returnL = self.SplineAsPath:GetLocationAtSplinePoint(currentPoint - 1, 1)
        self.modelManage:CreateGizmo(self.modelManage.NubPoints:Find(self.currentPoint))
    else
        local L = self.SplineAsPath:GetLocationAtSplinePoint(self.currentPoint - 1, 1)
        if not UE.UKismetMathLibrary.EqualEqual_VectorVector(location, L, 0.5) then
            self.SplineAsPath:SetLocationAtSplinePoint(self.currentPoint - 1, location, 1, true)
            bUpdate = true
        end
    end
    local Int = self.SplineAsPath:GetNumberOfSplinePoints()

    if pointsNum > Int then
        local Vector = self.SplineAsPath:GetLocationAtSplineInputKey(self.currentPoint - 0.5, 1)
        self.SplineAsPath:AddSplinePointAtIndex(Vector, self.currentPoint, 1, true)

        bUpdate = true
    elseif pointsNum < Int then
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

    local passageType, passageTexture = table.passageType, table.passageTexture
    local colorA = UE.FLinearColor(table.ra / 255, table.ga / 255, table.ba / 255, 1)
    local colorB = UE.FLinearColor(table.rb / 255, table.gb / 255, table.bb / 255, 1)

    self:SetM(passageType, passageTexture, colorA, colorB)
    return returnL
end

--- 设置通道材质参数
--- @function SetM
--- @param passageType number 通道类型标识
--- @param passageTexture number 纹理类型标识
--- @param colorA userdata 主色(FLinearColor)
--- @param colorB userdata 辅色(FLinearColor)
--- @description
---   更新通道材质参数：
---   1. 当类型或纹理变更时：
---     - 切换纹理显示模式(bTex参数)
---     - 加载新纹理并应用到材质实例
---   2. 当颜色变更时：
---     - 更新材质实例的Side(主色)和Interior(辅色)参数
function M:SetM(passageType, passageTexture, colorA, colorB)
    -- 检查类型/纹理变更
    if passageType ~= self.passageType or passageTexture ~= self.passageTexture then
        self.passageType = passageType
        self.passageTexture = passageTexture
        -- 根据纹理标识设置材质参数
        if self.passageTexture == 0 then
            self.mat:SetScalarParameterValue("bTex", 1) -- 启用基础纹理
        else
            self.mat:SetScalarParameterValue("bTex", 0) -- 禁用基础纹理
            -- 动态加载类型对应纹理
            local tName = "P" .. passageType .. "_" .. passageTexture
            local tex = LoadObject('/Game/SandBox/Textures/' .. tName .. "." .. tName)
            self.mat:SetTextureParameterValue("Tex", tex) -- 应用新纹理
        end
    end

    -- 检查颜色变更
    if colorA ~= self.colorA or colorB ~= self.colorB then
        self.colorA = colorA
        self.colorB = colorB
        -- 更新材质颜色参数
        self.mat:SetVectorParameterValue("Side", self.colorA)     -- 设置侧面颜色
        self.mat:SetVectorParameterValue("Interior", self.colorB) -- 设置内部颜色
    end
end

--- 更新通道状态
--- @function Update
--- @description
---   执行通道更新操作：
---   1. 更新控制点位置
---   2. 重建样条模型
function M:Update()
    self:UpdatePoint()    -- 更新控制点
    self:SetSplineModel() -- 重建样条
end

--- 获取通道数据
--- @function GetData
--- @return table 包含通道完整数据的Lua表
--- @description
---   输出通道当前状态数据：
---   1. 几何数据(宽度/长度/位置)
---   2. 外观参数(类型/纹理/颜色)
---   3. 状态标识(可移动性/显示名称)
---   4. 样条信息(控制点数量/总长度)
function M:GetData()
    -- 获取样条基本信息
    local int = self.SplineAsPath:GetNumberOfSplinePoints()
    local location = self.SplineAsPath:GetLocationAtSplinePoint(self.currentPoint - 1, 1)

    -- 组织输出数据表
    local outTable =
    {
        int            = int,               -- 样条点总数
        cp             = self.currentPoint, -- 当前控制点索引
        Width          = self.width,        -- 通道宽度
        FrameWidth     = self.frameWidth,
        PassageWidth   = self.passageWidth,
        Length         = self.length,                          -- 通道长度
        x              = DFL.integrate(location.X),            -- X坐标(取整)
        y              = DFL.integrate(location.Y),            -- Y坐标
        z              = DFL.integrate(location.Z),            -- Z坐标
        showname       = self:GetAttachParentActor().showName, -- 显示名称
        bMove          = self.bMove,                           -- 可移动标识
        passageType    = self.passageType,                     -- 通道类型
        passageTexture = self.passageTexture,                  -- 纹理类型
        -- 主色RGB分量(0-255)
        ra             = DFL.integrate(self.colorA.r * 255),
        ga             = DFL.integrate(self.colorA.g * 255),
        ba             = DFL.integrate(self.colorA.b * 255),
        -- 辅色RGB分量(0-255)
        rb             = DFL.integrate(self.colorB.r * 255),
        gb             = DFL.integrate(self.colorB.g * 255),
        bb             = DFL.integrate(self.colorB.b * 255),
        overallgh      = DFL.integrate(self.SplineAsPath:GetSplineLength()), -- 样条总长度
    }
    return outTable
end

--- 创建动态材质实例
--- @function SetDynamicMaterial
--- @return userdata 创建的动态材质实例
--- @description
---   从预设材质创建动态实例：
---   1. 加载基础材质资源(M_Passage)
---   2. 创建可运行时修改的材质实例
function M:SetDynamicMaterial()
    local mat = UE.UKismetMaterialLibrary.CreateDynamicMaterialInstance(self:GetWorld(),
        LoadObject('/Game/SandBox/Materials/M_Passage.M_Passage'), "", 0)
    return mat
end

return M
