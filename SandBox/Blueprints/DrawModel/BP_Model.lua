--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_Model_C
local M = UnLua.Class()
local DFL = require("SandBox.DataFunction")
local MatT = require("SandBox.MatTable")
local Screen = require("SandBox.Screen")


--[[
BP_Model.lua - 3D模型蓝图类

功能描述:
该类用于处理3D模型的基本操作,包括初始化、保存/加载数据、变换和材质设置等功能。

主要方法:
- Initialize: 初始化模型属性
- GetBox: 获取模型包围盒
- ModelSave: 保存模型数据到表格
- ModelLoad: 从表格加载模型数据
- TraceOtherModel: 检测与其他模型的重叠
- SetData: 设置模型变换数据
- GetData: 获取模型当前数据
- GetMaterialData: 获取材质数据
- SetDynamicMaterial: 设置动态材质

属性:
- modelType: 模型类型
- clickType: 点击类型
- modelCode: 模型代码
- size: 当前大小
- originalSize: 原始大小
- bBasic: 是否为基础模型
- materialCode: 材质代码
- matColor: 材质颜色
- materialRatio: 材质比例
]]
--- 模型初始化方法
--- @function Initialize
--- @param Initializer table 初始化参数表（当前版本未使用，保留参数）
--- @description
---   初始化模型基础属性：
---   - 设置默认模型类型(modelType=0)
---   - 设置默认交互类型(clickType=1)
---   - 初始化模型代码为空字符串
---   - 模型管理器引用置空
---   - 启用移动标记(bMove=true)
function M:Initialize(Initializer)
    self.modelType      = 0    -- 模型类型标识（0=默认类型）
    self.clickType      = 1    -- 交互响应类型（1=可点击）
    self.modelCode      = ""   -- 模型唯一标识码
    self.modelManage    = nil  -- 关联的模型管理器
    -- self.showName = ""    -- 已注释的模型显示名称功能
    self.bMove          = true -- 是否允许移动标记
    self.holeType       = 0
    self.holeModelCodes = {
        ["door"] = 1,
        ["door2"] = 1,
        ["window"] = 1,
        ["dong"] = 2,
    }
    self.holeModels     = UE.TArray(UE.AActor)
    self.holeMatTable   = {
        '/Game/SandBox/Materials/M_Hole.M_Hole',
        '/Game/SandBox/Materials/M_Hole_Inst.M_Hole_Inst'
    }
end

--- 计算模型包围盒尺寸
--- @function GetBox
--- @param Type number 模型分类标识（3=特殊类型）
--- @description
---   通过引擎接口获取模型包围盒：
---   - 计算原始尺寸(originalSize)
---   - 设置当前显示尺寸(size)
---   - 根据Type判断是否基础模型(bBasic)
---   - 同步更新模型类型和交互类型
function M:GetBox(Type)
    local _, boxExtent = self:GetActorBounds(false) -- 调用引擎API获取包围盒
    self.originalSize = boxExtent * 2               -- 原始尺寸（包围盒对角线*2）
    self.size = self.originalSize                   -- 初始化显示尺寸
    self.bBasic = Type ~= 3                         -- 类型3为非基础模型
    self.modelType = Type                           -- 同步模型类型
    self.clickType = 1
    self:SetHole()
end

--- 模型数据序列化方法
--- @function ModelSave
--- @description
---   将模型对象的核心属性序列化为Lua表结构：
---   主要处理流程：
---   1. 尺寸自动初始化：当检测到零尺寸模型时，自动通过UE4引擎API获取包围盒尺寸
---   2. 数据类型转换：使用DFL工具类处理特殊数据类型（向量/颜色→JSON可序列化格式）
---   3. 条件字段处理：对可能为nil的字段（如材质颜色）进行安全转换
--- @return table 返回包含以下字段的结构化数据表：
---   - ModelCode : string 模型在系统中的唯一标识码（必填字段）
---   - OriginalSize : table 模型原始包围盒尺寸（经过DFL.fromVector转换）
---   - BSize : table 模型当前显示尺寸（可能经过自动计算）
---   - bBasic : boolean 标识是否为基础模型（影响渲染层级）
---   - CType : number 交互响应类型（1=默认可点击交互）
---   - MaterialCode : string 关联的材质资源ID（来自材质管理系统）
---   - MaterialRatio : number 材质UV贴图缩放比例（默认1.0）
---   - MColor : table|nil 材质着色颜色（经过DFL.fromColor转换，可能为nil）
--- @note 重要实现细节：
---   - 包围盒尺寸计算：BoxExtent * 2 表示将半尺寸转为全尺寸
---   - 历史遗留：注释掉的旋转检测逻辑曾在v2.3版本使用
---   - 数据安全：所有关键字段都有默认值处理（如clickType默认为1）
function M:ModelSave()
    -- 零尺寸自动修正（常见于新建模型未初始化的情况）
    if self.size == UE.FVector(0, 0, 0) then
        local Origin, BoxExtent = self:GetActorBounds(false) -- 调用UE4原生获取包围盒
        self.size = BoxExtent * 2                            -- 包围盒半尺寸→全尺寸转换（对角线长度）
    end

    -- 结构化输出表（字段顺序保持与文档一致）
    local table = {
        ["ModelCode"] = self.modelCode,                                     -- 必须存在的业务标识字段
        ["OriginalSize"] = DFL.fromVector(self.originalSize),               -- 向量转JSON兼容格式
        ["BSize"] = DFL.fromVector(self.size),                              -- 当前可能被缩放的尺寸
        ["bBasic"] = self.bBasic,                                           -- 影响碰撞检测层级
        ["CType"] = self.clickType,                                         -- 1=可点击 2=可拖拽 3=只读
        ["MaterialCode"] = self.materialCode,                               -- 指向材质库的索引
        ["MaterialRatio"] = self.materialRatio,                             -- 控制UV重复率
        ["MColor"] = self.matColor and DFL.fromColor(self.matColor) or nil, -- 安全转换颜色数据
        ["holeType"] = self.holeType,
    }
    return table
end

--- 模型数据加载方法
--- @function ModelLoad
--- @param table table 包含模型数据的Lua表
--- @description
---   从数据表加载模型属性：
---   1. 处理基础几何数据（尺寸/原始尺寸）
---   2. 转换特殊数据类型（JSON→向量/颜色）
---   3. 设置模型业务属性（编码/类型/材质等）
--- @note 关键字段说明：
---   - BSize : 当前显示尺寸（经过DFL.toVector转换）
---   - OriginalSize : 模型原始包围盒尺寸
---   - MColor : 可选字段，材质颜色（需DFL.toColor转换）
---   - CType : 交互类型（0表示保持原值）
function M:ModelLoad(table)
    -- 几何数据转换
    local boxSize      = DFL.toVector(table["BSize"])                            -- 当前显示尺寸（可能经过缩放）
    local origin       = DFL.toVector(table["OriginalSize"])                     -- 原始包围盒尺寸
    local matColor     = table["MColor"] and DFL.toColor(table["MColor"]) or nil -- 可选颜色字段

    -- 核心业务属性设置
    self.modelCode     = table["ModelCode"]                                       -- 模型唯一标识码（必填）
    self.bBasic        = table["bBasic"]                                          -- 是否基础模型标识
    self.clickType     = table["CType"] ~= 0 and table["CType"] or self.clickType -- 交互类型（0保持原值）
    self.modelType     = table["Type"]                                            -- 模型分类标识
    self.materialCode  = table["MaterialCode"]                                    -- 关联材质资源ID
    self.materialRatio = table["MaterialRatio"]                                   -- 材质UV缩放比例
    self.holeType      = table["holeType"]                                        -- 是否为孔模型
    self:SetHole()
    -- 几何数据应用
    self.size         = boxSize  -- 应用显示尺寸
    self.originalSize = origin   -- 记录原始尺寸
    self.matColor     = matColor -- 设置材质颜色
    self:HoleTraceModel(true)    -- 模型加载后刷新孔洞状态
end

--- 模型碰撞检测方法
--- @function TraceOtherModel
--- @description
---   检测当前模型与其他静态模型的碰撞：
---   1. 获取模型包围盒范围
---   2. 设置碰撞检测参数（忽略自身）
---   3. 调用UE4碰撞检测API
--- @return boolean 是否存在碰撞
---   - true: 检测到碰撞
---   - false: 无碰撞
function M:TraceOtherModel(bBuild)
    -- 获取模型包围盒参数
    local origin, boxExtent = self:GetActorBounds(false)

    -- 配置碰撞检测参数
    local objectTypes = UE.TArray(UE.EObjectTypeQuery)
    objectTypes:Add(UE.EObjectTypeQuery.WorldStatic) -- 仅检测静态物体
    local actorsToIgnore = UE.TArray(UE.AActor)
    actorsToIgnore:Add(self)                         -- 忽略自身碰撞
    local hitActors = UE.TArray(UE.AActor)

    -- 执行盒型碰撞检测
    local bTrace    = UE.UKismetSystemLibrary.BoxOverlapActors(
        self:GetWorld(), origin, boxExtent,
        objectTypes, UE.AStaticMeshActor, actorsToIgnore, hitActors)

    if self.holeType == 1 and bBuild then
        self.bBuildRotate = false
        print(hitActors:Num())
        if hitActors:Num() == 0 then
            self.bBuildRotate = false
            goto rotate
        end
        for _, actor in pairs(hitActors) do
            if actor.modelType == 5 then
                bTrace = false
                self.bBuildRotate = true
                local curLoc = self:K2_GetActorLocation()
                local loc = actor.SplineAsPath:FindLocationClosestToWorldLocation(curLoc, 1)
                local rotate = actor:GetNearbyWallRotation(origin)
                self:K2_SetActorLocation(loc, false, nil, false)
                self:K2_SetActorRotation(rotate, false, nil, false)
                break
            end
        end
        ::rotate::
        if not self.bBuildRotate then
            self:K2_SetActorRotation(UE.FRotator(0, 0, 0), false, nil, false)
        end
    elseif self.holeType == 2 then
        bTrace = true
    end
    return bTrace
end

--- 模型数据设置方法
--- @function SetData
--- @param table table 包含变换数据的Lua表
--- @description
---   设置模型空间变换数据：
---   1. 更新模型显示尺寸
---   2. 计算并应用缩放变换
---   3. 同步父Actor显示名称
--- @note 特殊处理：
---   - table.T : 包含完整变换数据（位置/旋转/缩放）
---   - table.Size : 目标显示尺寸（自动计算缩放比例）
function M:SetData(table)
    self.size = table.Size                                            -- 更新当前尺寸
    table.T.Scale3D = table.Size / self.originalSize                  -- 计算相对缩放比例
    -- self.showName = table.showname  -- 已注释的本地名称存储
    self:GetAttachParentActor().showName = table.showname             -- 同步到父Actor
    self:K2_SetActorTransform(table.T, false, UE.FHitResult(), false) -- 应用变换
    self:HoleTraceModel(true)                                         -- 模型变换时刷新孔洞状态
end

--- 模型数据获取方法
--- @function GetData
--- @param height number 可选高度参数（当前未使用）
--- @return table 包含模型空间数据的Lua表
--- @description
---   获取模型当前空间状态：
---   1. 转换几何数据（单位化处理）
---   2. 组织业务属性数据
---   3. 处理可选颜色数据
--- @note 输出字段说明：
---   - length/width/height : 模型三轴尺寸（经过DFL.integrate处理）
---   - angle : 模型Yaw旋转角度（单位：度）
---   - x/y/z : 模型世界坐标（单位化处理）
---   - r/g/b : 材质颜色分量（0-255整型，可选）
function M:GetData(height)
    local transform = self:GetTransform() -- 获取当前变换

    -- 构建输出数据表
    local outTable = {
        length        = DFL.integrate(self.size.X),                                                -- X轴长度（单位化）
        width         = DFL.integrate(self.size.Y),                                                -- Y轴宽度
        height        = DFL.integrate(self.size.Z),                                                -- Z轴高度
        -- top           = CH - DFL.integrate(self.size.Z),  -- 已注释的顶部坐标计算
        angle         = DFL.integrate(UE.UKismetMathLibrary.Quat_Rotator(transform.Rotation).Yaw), -- 旋转角度
        x             = DFL.integrate(transform.Translation.X),                                    -- 世界坐标X
        y             = DFL.integrate(transform.Translation.Y),                                    -- 世界坐标Y
        z             = DFL.integrate(transform.Translation.Z),                                    -- 世界坐标Z
        bBasic        = self.bBasic,                                                               -- 基础模型标识
        -- showname      = self.showName,  -- 已注释的本地名称
        showname      = self:GetAttachParentActor().showName,                                      -- 父Actor名称
        bMove         = self.bMove,                                                                -- 可移动标识
        materialCode  = self.materialCode,                                                         -- 材质资源ID
        r             = self.matColor and DFL.integrate(self.matColor.r * 255) or nil,             -- 红色分量
        g             = self.matColor and DFL.integrate(self.matColor.g * 255) or nil,             -- 绿色分量
        b             = self.matColor and DFL.integrate(self.matColor.b * 255) or nil,             -- 蓝色分量
        materialRatio = self.materialRatio,                                                        -- 材质缩放比例
    }
    return outTable
end

--- 材质数据更新方法
--- @function GetMaterialData
--- @param JSONT table 包含材质参数的Lua表
--- @description
---   更新模型材质属性：
---   1. 转换颜色数据（RGB 0-255→0-1）
---   2. 检查材质变更（颜色/编码/比例）
---   3. 触发材质重载
--- @note 触发条件：
---   - 颜色值变化 或 材质编码变化 或 缩放比例变化
function M:GetMaterialData(JSONT)
    -- 颜色空间转换（0-255→0-1）
    local matColor = UE.FLinearColor(JSONT.r / 255, JSONT.g / 255, JSONT.b / 255, 1)

    -- 检查材质变更条件
    if matColor ~= self.matColor or JSONT.materialCode ~= self.materialCode or self.materialRatio ~= JSONT.materialRatio then
        self.matColor = matColor                 -- 更新颜色
        self.materialCode = JSONT.materialCode   -- 更新材质ID
        self.materialRatio = JSONT.materialRatio -- 更新缩放比例
        self:SetDynamicMaterial()                -- 触发材质重载
    end
end

function M:SetDynamicMaterial()
    local matPath = MatT[self.materialCode]
    if not matPath then
        print(self.materialCode)
        return
    end
    local mat = LoadObject(matPath)
    local num = self.StaticMeshComponent:GetNumMaterials()
    for i = 1, num do
        self.StaticMeshComponent:SetMaterial(i - 1, mat)
    end
end

-- 挖洞选项
--- 根据 modelCode 设置 holeType
--- 若 modelCode 在 holeModelCodes 表中存在，则取对应值，否则为 0
function M:SetHole()
    self.holeType = self.holeModelCodes[self.modelCode] or 0
end

--- 执行孔洞碰撞检测，收集可挖洞的模型并更新材质
--- @param bActive boolean 是否触发被挖洞模型的 TrackHoleModel 回调
function M:HoleTraceModel(bActive)
    -- 非孔洞模型直接返回
    if self.holeType == 0 then
        return
    end

    -- 获取自身 StaticMesh 的边界框（最小 20cm 防止过薄）
    local o, b, bool = UE.UKismetSystemLibrary.GetComponentBounds(self.StaticMeshComponent)
    b.X = b.X > 20 and b.X or 20
    b.Y = b.Y > 20 and b.Y or 20

    -- 盒体射线检测：查找与自身重叠的模型
    local outHits = UE.TArray(UE.FHitResult())
    UE.UKismetSystemLibrary.BoxTraceMulti(
        self:GetWorld(), o, o, b, UE.FRotator(0, 0, 0),
        UE.ETraceTypeQuery.Model, true, nil, 0, outHits, true
    )

    -- 筛选符合挖洞规则的模型
    local holeModels = UE.TArray(UE.AActor)
    for _, value in pairs(outHits) do
        local actor = value.HitObjectHandle.Actor
        -- holeType == 1 仅允许 modelType == 5 的墙体
        if self.holeType == 1 and actor.modelType == 5 then
            holeModels:Add(actor)
            -- holeType == 2 仅允许 modelType == 6 的楼板（注释掉的 5 已移除）
        elseif self.holeType == 2 and actor.modelType == 6 then
            holeModels:Add(actor)
        end
    end

    -- 调试打印
    print(self.modelCode, bActive)

    -- 若激活，通知新旧模型更新洞口状态
    if bActive then
        -- 通知新检测到的模型
        print("New hole models:" .. holeModels:Num())
        for i = 1, holeModels:Num() do
            local v = holeModels[i]
            self.holeModels:AddUnique(v)
        end
        -- 通知旧列表中已脱落的模型
        Screen.Print("Old hole models:" .. self.holeModels:Num())
        for i = 1, self.holeModels:Num() do
            local v = self.holeModels[i]
            print("Remove hole model:", UE.UKismetSystemLibrary.GetObjectName(v))
            if v and v:IsValid() then
                v:TrackHoleModel()
            end
        end
        -- 更新当前洞口关联模型列表
        self.holeModels = holeModels
        Screen.Print("update hole models:" .. self.holeModels:Num())
    else
        for i = 1, holeModels:Num() do
            local v = holeModels[i]
            if v and v:IsValid() then
                self.holeModels:AddUnique(v)
            end
        end
    end

    -- 根据 holeType == 2 的检测结果切换材质
    if self.holeType == 2 then
        if self.holeModels:Num() <= 0 then
            -- 无关联模型，使用未开孔材质
            self.StaticMeshComponent:SetMaterial(0, LoadObject(self.holeMatTable[1]))
        else
            -- 有关联模型，使用已开孔材质
            self.StaticMeshComponent:SetMaterial(0, LoadObject(self.holeMatTable[2]))
        end
    end
end

-- 获取模型网格数据
--- @function GetModelMeshData
function M:GetModelMeshData(actor)
    if self.bDestroy then
        return false
    end
    -- local meshData = UE.FMeshData()
    self.StrMesh.tb = self:GetTransform()
    if self.holeType == 0 then
        return false
    elseif self.holeType == 1 then
        if actor.modelType ~= 5 then
            return false
        end
        self:HoleTraceModel(false)
        if self.holeModels:Find(actor) <= 0 then
            return false
        end
        local box = self.size / 2
        local val = actor.thickness
        box.y = box.y > val and box.y or val
        self.StrMesh.tb.Translation.Z = self.StrMesh.tb.Translation.Z + box.Z
        self.StrMesh.tb.Scale3D = UE.FVector(1, 1, 1)
        -- local vertices = UE.TArray(UE.FVector)
        -- local triangles = UE.TArray(0)
        -- local normals = UE.TArray(UE.FVector)
        -- local uvs = UE.TArray(UE.FVector2D)
        local tangents = UE.TArray(UE.FProcMeshTangent)
        -- UE.UKismetProceduralMeshLibrary.GenerateBoxMesh(box, vertices, triangles, uvs, normals, tangents)
        -- meshData.Verts = vertices
        -- meshData.Tris = triangles
        -- meshData.Normals = normals
        -- meshData.UVs = uvs
        UE.UKismetProceduralMeshLibrary.GenerateBoxMesh(box, self.StrMesh.data.Verts, self.StrMesh.data.Tris,
            self.StrMesh.data.UVs,
            self.StrMesh.data.Normals, tangents)
    elseif self.holeType == 2 then
        self:HoleTraceModel(false)
        if self.holeModels:Find(actor) <= 0 then
            return false
        end
        UE.UMeshOpsPluginBPLibrary.GetMeshDataFromStaticMesh(self.StaticMeshComponent.StaticMesh, self.StrMesh.data, 0, 0,
            false)
    end
    return true, self.StrMesh
end

function M:ReceiveEndPlay()
    self.bDestroy = true
    for _, v in pairs(self.holeModels) do
        if v and v:IsValid() then
            v:TrackHoleModel()
        end
    end
end

return M
