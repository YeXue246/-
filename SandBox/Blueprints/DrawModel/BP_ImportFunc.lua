---
-- 模块: BP_ImportFunc
-- 描述: FBX模型导入功能模块
-- 功能: 异步加载FBX文件并生成模型组件
-- 依赖: AssimpSpawnManager (FBX导入管理器), InActor (目标Actor)
---

---@type BP_ImportFunc_C
local M = UnLua.Class()

-- 导入队列: 存储待加载的 {filePath, inActor} 数据
M.importQueue = nil

--[[
    生命周期函数: 初始化
    调用时机: 对象创建时调用
    参数: initializer - 初始化参数
]]
function M:Initialize(initializer)
    -- 初始化队列
    self.importQueue = {}
end

--[[
    生命周期函数: 开始游戏
    调用时机: Actor开始游戏时调用
    功能: 订阅网格体生成完成事件，用于在所有模型加载完成后执行回调
]]
function M:ReceiveBeginPlay()
    self.OnAllMeshSpawnFinished:Add(self, self.LoadFinished)
end

--[[
    生命周期函数: 结束游戏
    调用时机: Actor销毁或游戏结束时调用
    功能: 清理资源，取消事件订阅
]]
function M:ReceiveEndPlay()
    -- 清理资源
    self.importQueue = {}
    self.bIsLoading = false
    self.CurrentLoadingFilePath = nil
    self.CurrentInActor = nil
    self.bExecute = false
end

--[[
    核心函数: 取消指定Actor的模型生成
    功能: 检查并取消指定Actor的模型生成任务
    参数: inActor - 目标Actor
    流程:
        1. 检查当前正在加载的任务是否属于该Actor
        2. 如果是，取消当前加载
        3. 从队列中移除属于该Actor的任务
        4. 如果当前任务被取消，处理队列中的下一个任务
]]
function M:CancelImportForActor(inActor)
    -- 检查当前是否正在为该Actor加载
    local bCancelCurrent = false
    if self.bIsLoading and self.CurrentInActor == inActor then
        -- 取消当前加载
        self.bExecute = false
        -- 清理当前加载信息
        self.CurrentLoadingFilePath = nil
        self.CurrentInActor = nil
        bCancelCurrent = true
    end
    
    -- 从队列中移除该Actor的任务
    local newQueue = {}
    for _, task in ipairs(self.importQueue) do
        if task.inActor ~= inActor then
            table.insert(newQueue, task)
        end
    end
    self.importQueue = newQueue
    
    -- 如果取消了当前任务，处理下一个
    if bCancelCurrent then
        self.bIsLoading = false
        self:ProcessNextInQueue()
    end
end

--[[
    核心函数: 异步加载FBX文件
    功能: 使用Assimp插件异步导入FBX场景，支持进度回调和完成回调
    参数:
        filePath - FBX文件路径
        inActor - 目标Actor
    队列机制:
        - 如果当前正在加载，将任务加入队列等待
        - 如果队列为空，立即开始加载
        - 加载完成后自动处理队列中的下一个任务
]]
function M:LoadNewFBX(filePath, inActor)
    -- 将任务加入队列
    local task = { filePath = filePath, inActor = inActor }
    table.insert(self.importQueue, task)

    -- 如果当前没有正在加载的任务，开始处理
    if not self.bIsLoading then
        self:ProcessNextInQueue()
    end
end

--[[
    队列处理函数: 处理队列中的下一个任务
    功能: 从队列中取出下一个加载任务并执行
    注意: 此函数在当前任务完成后由Complete回调调用
]]
function M:ProcessNextInQueue()
    -- 检查队列是否为空
    if #self.importQueue == 0 then
        self.bIsLoading = false
        return
    end

    -- 取出一个任务
    local task = table.remove(self.importQueue, 1)
    local filePath = task.filePath
    local inActor = task.inActor

    filePath = self:NormalizeSceneCachePath(filePath)

    -- 保存当前加载信息
    self.CurrentLoadingFilePath = filePath
    self.CurrentInActor = inActor
    self.bIsLoading = true

    if self:IsSceneCached(filePath) then
        self:SpawnCachedSceneByPath(filePath, inActor)
        return
    end



    -- 构建文件路径数组
    local inFilenames = UE.TArray(UE.FString)
    inFilenames:Add(filePath)


    -- 异步导入FBX场景
    local importContext = self:ImportScenesAsync(
        inFilenames,
        0,                       -- Flags: 默认导入标志
        false,                   -- DisableAutoSpaceChange: 不禁用自动空间变换
        0,                       -- MaxConcurrentTasks: 最大并发任务数(0为默认)
        { self, self.Progress }, -- 进度回调委托
        { self, self.Complete }  -- 完成回调委托
    )

    -- 检查导入上下文是否有效
    self.bExecute = UE.UKismetSystemLibrary.IsValid(importContext)
end

--[[
    回调函数: 导入进度回调
    功能: 当导入过程有进度更新时调用
    参数:
        Progress - 当前进度值(0-1)
        Scene - 当前处理的场景对象
    说明: 蓝图中的对应节点未连接后续逻辑，需自行扩展
]]
function M:Progress(Progress, Scene)
    -- 蓝图中该节点未连接后续逻辑
end

--[[
    回调函数: 导入完成回调
    功能: 当FBX文件导入完成后调用，初始化并生成模型Actor，加载队列中的下一个任务
    参数: Scenes - 导入的场景数组
    流程:
        1. 检查场景数组是否有效
        2. 有效则初始化并生成Actor
        3. 无效则删除临时文件
        4. 处理队列中的下一个任务
]]
function M:Complete(Scenes)
    if Scenes and Scenes:Length() > 0 then
        -- 使用场景数据初始化Actor
        self:InitializeAndStartWithActor(self, Scenes, self.CurrentInActor)
    else
        -- 导入失败，隐藏加载框
        self.CurrentInActor:HideCollisionBox()
        -- 清理临时文件
        UE.UMyBFL.DeleteFile(self.CurrentLoadingFilePath)
        -- 处理队列中的下一个任务
        self:ProcessNextInQueue()
    end
end

--[[
    回调函数: 网格体生成完成回调
    功能: 所有模型网格体生成完成后调用，将网格体附加到父组件
    参数: MeshComponents - 生成的网格体组件数组
    流程:
        1. 保存网格体数组到Actor
        2. 遍历所有网格体
        3. 将每个网格体附加到父级静态网格组件
        4. 计算模型尺寸
]]
function M:LoadFinished(MeshComponents)
    -- 保存生成的网格体引用
    self.CurrentInActor.Meshs = MeshComponents

    -- 遍历并附加所有网格体
    local meshLength = MeshComponents:Length()
    for i = 1, meshLength do
        local meshComp = MeshComponents[i]
        if UE.UKismetSystemLibrary.IsValid(meshComp) then
            -- 附加到父级网格，保持相对变换
            meshComp:K2_AttachToComponent(
                self.CurrentInActor.PMesh,       -- Parent: 父级组件
                "None",                          -- SocketName: 插槽名称(无)
                UE.EAttachmentRule.KeepRelative, -- LocationRule: 位置规则-保持相对
                UE.EAttachmentRule.KeepRelative, -- RotationRule: 旋转规则-保持相对
                UE.EAttachmentRule.KeepRelative, -- ScaleRule: 缩放规则-保持相对
                true                             -- bWeldSimulatedBodies: 焊接物理体
            )
        end
    end

    -- 任务完成时隐藏加载框
    self.CurrentInActor:HideCollisionBox()

    -- 计算模型尺寸(包围盒等)
    self.CurrentInActor:GetModelSize()
    -- 处理队列中的下一个任务
    self:ProcessNextInQueue()
end

return M
