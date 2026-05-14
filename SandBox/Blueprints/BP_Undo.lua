--[[
    撤销重做管理器
    负责处理场景中物体的操作历史记录，支持撤销和重做功能

    @作者 **
    @创建时间 2024-01-17
    @最后修改 2024-01-17
]]

---@class BP_Undo_C 撤销重做管理器类
---@field undoStack table 撤销操作栈
---@field redoStack table 重做操作栈
---@field maxTableSize number 历史记录最大数量
---@field bUndo boolean 是否处于撤销状态
---@field ui UI_SandBox_C UI引用
---@field control Control 控制器引用
---@field bClear boolean 是否清空状态
local M = UnLua.Class()

-- 引入依赖模块
local Model = require("SandBox.ModelNameInitialize")
local json = require("dkjson")

local function stringifyTransform(sizeString)
    local sizeObj = UE.UJsonLibraryHelpers.Parse(sizeString)
    local size = UE.UJsonLibraryHelpers.ToTransform(sizeObj)
    if math.abs(size.Translation.X) > 1e+16 then
        size.Translation = UE.FVector(0, 0, 0)
    end
    return size
end
local function parseTransform(size)
    local sizeObj = UE.UJsonLibraryHelpers.Parse(size)
    local size = UE.UJsonLibraryHelpers.ToTransform(sizeObj)
    if math.abs(size.Translation.X) > 1e+16 then
        size.Translation = UE.FVector(0, 0, 0)
    end
    return UE.UJsonLibraryHelpers.JsonValue_Stringify(UE.UJsonLibraryHelpers.FromTransform(size))
end
---初始化函数
---@param Initializer any 初始化器
function M:Initialize(Initializer)
    -- 初始化历史记录栈
    self.undoStack = {} -- 撤销栈
    self.redoStack = {} -- 重做栈

    -- 设置配置参数
    self.maxTableSize = 10 -- 最大历史记录数
    self.bUndo = false     -- 撤销状态标记
    self.ui = nil          -- UI引用
end

---游戏开始时调用
function M:ReceiveBeginPlay()
    self.bClear = false
end

---清空所有历史记录
function M:ClearStack()
    self.undoStack = {}
    self.redoStack = {}
    self.bClear = true

    -- 更新UI显示
    self.ui:UndoStep(#self.undoStack, #self.redoStack)
    print("已清空历史记录")
end

---区域视图下执行撤销并丢弃记录（公共方法）
---@param currentAction table 当前撤销动作数据
---@param tipText string 提示文本
function M:DoRegionUndo(currentAction, tipText)
    if currentAction then
        self:Core(currentAction, true)
        table.remove(self.undoStack, #self.undoStack)
        if self.ui and self.ui.UndoStep then
            self.ui:UndoStep(#self.undoStack, #self.redoStack)
        end
    end
    if self.control and self.control.ui and self.control.ui.UECallWeb then
        self.control.ui:UECallWeb("ShowMessage", {
            Type = 2,
            Text = tipText
        })
    end
end

---添加一个操作到历史记录
---@param actionType number 操作类型(1:生成 2:移动 3:删除 4:打组 5:拆组 6:批量复制 7:批量移动 8:批量删除)
---@param actor AActor 操作的Actor
---@param actors table<AActor> 批量操作的Actor列表
function M:AddAction(actionType, actor, actors)
    -- 如果处于撤销状态,清空历史记录
    if self.bUndo then
        self:ClearStack()
        self.bUndo = false
    end

    local actionData = {}
    if self.control.drawMode == "Default" or self.control.drawMode == "RegionInner" then
        -- 根据不同操作类型收集数据
        if actionType == 1 or actionType == 3 then
            -- 生成或删除操作
            local function ActionActor(actor, actionType)
                local data = {}
                local parentActor = actor:GetAttachParentActor()
                local parentName = Model.GetActorAccurateDisplayName(parentActor)
                data = self:ActionActorData(actor, parentName, actionType)
                self:ActionChild(actor, data, actionType)
                -- 记录父级数据
                local grandParent = parentActor:GetAttachParentActor()
                local grandParentName = ""
                if grandParent then
                    grandParentName = Model.GetActorAccurateDisplayName(grandParent)
                end
                data.parentData = self:ActionActorData(parentActor, grandParentName, actionType)
                return data
            end
            actionData = ActionActor(actor, actionType)
            if actionData.associativeModel and actionData.associativeModel ~= "" then
                local associativeModel = self.control.modelManage:FindActor(actionData.associativeModel)
                if associativeModel then
                    actionData.associativeModelData = ActionActor(associativeModel, actionType)
                end
            end
        elseif actionType == 2 then
            -- 移动操作
            actionData = self:ActionActorData(actor, "", actionType)
        elseif actionType == 4 then
            -- 打组操作
            actionData.Int = 4
            actionData.newParent = self:ActionActorData(actor, "", 4)
            actionData.Actors = {}
            actionData.DeleteGroups = {}

            for _, value in pairs(actors) do
                local groupData = {
                    modelName = Model.GetActorAccurateDisplayName(value),
                    oldParent = Model.GetActorAccurateDisplayName(value:GetAttachParentActor()),
                }
                table.insert(actionData.Actors, groupData)
            end
        elseif actionType == 5 then
            -- 拆组操作
            actionData = self:ActionActorData(actor, 1, actionType)
            self:ActionChild(actor, actionData, actionType)
        elseif actionType == 6 then
            -- 批量复制操作
            actionData.Int = 6
            actionData.Actors = {}

            for _, value in pairs(actors) do
                if UE.UKismetSystemLibrary.IsValid(value) then
                    local parentActor = value:GetAttachParentActor()
                    if not parentActor then
                        print("parentActor is nil", Model.GetActorAccurateDisplayName(value))
                        goto continue
                    end
                    local parentName = Model.GetActorAccurateDisplayName(parentActor)
                    local copyData = self:ActionActorData(value, parentName, actionType)
                    self:ActionChild(value, copyData, actionType)

                    local grandParent = parentActor:GetAttachParentActor()
                    local grandParentName = ""
                    if grandParent then
                        grandParentName = Model.GetActorAccurateDisplayName(grandParent)
                    end
                    copyData.parentData = self:ActionActorData(parentActor, grandParentName, actionType)
                    table.insert(actionData.Actors, copyData)
                    ::continue::
                end
            end
        elseif actionType == 7 then
            -- 批量移动操作
            actionData = self:ActionMulitData(actor, "", actionType)
            for _, value in pairs(actor.MultiActors) do
                if UE.UKismetSystemLibrary.IsValid(value) then
                    local moveData = self:ActionActorData(value, "", actionType)
                    table.insert(actionData.Childs, moveData)
                end
            end
        elseif actionType == 8 then
            -- 批量删除操作
            actionData = self:ActionMulitData(actor, "", actionType)
            actionData.Actors = {}

            local actorCount = actor.MultiActors:Num()
            for i = 1, actorCount do
                local value = actor.MultiActors[i]
                if UE.UKismetSystemLibrary.IsValid(value) then
                    local parentActor = value:GetAttachParentActor()
                    local parentName = Model.GetActorAccurateDisplayName(parentActor)
                    local deleteData = self:ActionActorData(value, parentName, actionType)
                    self:ActionChild(value, deleteData, actionType)

                    local grandParent = parentActor:GetAttachParentActor()
                    local grandParentName = ""
                    if grandParent then
                        grandParentName = Model.GetActorAccurateDisplayName(grandParent)
                    end
                    deleteData.parentData = self:ActionActorData(parentActor, grandParentName, actionType)
                    table.insert(actionData.Actors, deleteData)
                end
            end
        end
    elseif self.control.drawMode == "RegionArea" then
        -- 协作区域模式下，目前支持：1=生成、2=属性修改、3=删除
        -- RegionArea 独立于普通模型（存放在 modelManage.Regions 中），
        -- 因此这里额外打一个标记，方便 Core 中走专用的撤销/重做逻辑。
        actionData = self:ActionActorData(actor, "", actionType)
        actionData.isRegionArea = true
    end

    -- 添加到历史记录栈
    self:addToTableWithLimit(actionData, actionType)
    -- 更新UI显示
    self.ui:UndoStep(#self.undoStack, #self.redoStack)
end

---记录空组删除数据
---@param actor AActor 要删除的空组Actor
function M:DeleteGroup(actor)
    local deleteGroupData = self:ActionActorData(actor, "", 4)
    table.insert(self.undoStack[#self.undoStack].DeleteGroups, deleteGroupData)
end

---收集子Actor数据
---@param actor AActor 父Actor
---@param dataTable table 数据表
---@param actionType number 操作类型
function M:ActionChild(actor, dataTable, actionType)
    local childActors = UE.TArray(UE.AActor)
    actor:GetAttachedActors(childActors, true)
    local parentName = Model.GetActorAccurateDisplayName(actor)

    for _, child in pairs(childActors) do
        local childData = self:ActionActorData(child, parentName, actionType)
        -- 先保存数据,再递归处理子级
        table.insert(dataTable.Childs, childData)
        self:ActionChild(child, childData)
    end
end

---收集Actor基础数据
---@param actor AActor Actor对象
---@param parentName string 父级名称
---@param actionType number 操作类型
---@return table 收集的数据
function M:ActionActorData(actor, parentName, actionType)
    local modelName = Model.GetActorAccurateDisplayName(actor)
    local transform = actor:GetTransform()

    local actorData = {
        Int = actionType,
        size = UE.UJsonLibraryHelpers.JsonValue_Stringify(UE.UJsonLibraryHelpers.FromTransform(transform)),
        modelName = modelName,
        showName = actor.showName,
        handle = actor.bhandle,
        Move = actor.bMove,
        Type = actor.modelType,
        relatedId = actor.relatedId,
        relatedCode = actor.relatedCode,
        modelCategoryCode = actor.ModelCategory,
        parent = parentName,
        Childs = {},
    }

    -- 保存模型特定数据
    self.control.modelManage.ModelSave(actor, actorData)

    if actorData.Type == 6 then
        actorData.bOverall = actor.bOverall
    end
    return actorData
end

---收集多选数据
---@param actor AActor 多选Actor
---@param parentName string 父级名称
---@param actionType number 操作类型
---@param actorType string 类型
---@return table 收集的数据
function M:ActionMulitData(actor, parentName, actionType, actorType)
    local transform = actor:GetTransform()
    local multiData = {
        Int = actionType,
        size = UE.UJsonLibraryHelpers.JsonValue_Stringify(UE.UJsonLibraryHelpers.FromTransform(transform)),
        Type = actor.modelType,
        Childs = {}
    }
    return multiData
end

---添加新的变换数据
---@param actor AActor Actor对象
---@param areaActor? AActor 可选的区域 Actor，用于严格边界检测
---@param polygon? table 可选的多边形顶点，用于严格边界检测
function M:AddNewSize(actor, areaActor, polygon)
    local currentAction = self.undoStack[#self.undoStack]

    -- 无有效记录或当前处于撤销/重做过程中，直接退出
    if not currentAction or self.bUndo then
        return
    end

    ----------------------------------------------------------------
    -- 区域视图下的移动约束：移动结束时若已离开协作区域，则回退位置并丢弃本次撤销记录
    -- 说明：这里需要“整步撤回”当前操作，保证线模型的控制点等内部数据一并恢复
    ----------------------------------------------------------------
    local control = self.control
    if control and control.regionMode and actor and actor.modelType ~= "Multi" then
        -- 在“区域视图”模式下，检查当前 Actor 是否仍位于选中协作区域内
        if not control:IsActorInsideCurrentRegion(actor) then
            -- 使用 Core 执行一次“局部撤销”，恢复到当前操作前的完整状态
            --（包括 Transform + 线模型控制点等通过 ModelSave/ModelLoad 记录的数据）
            -- 执行撤销并丢弃记录，同时显示提示
            self:DoRegionUndo(currentAction, "模型不能移出协作区域")

            -- 回退后同步属性面板等数据
            if control.ModelDataToView and control.buildActor then
                control:ModelDataToView(true)
            end

            return
        end
    end

    ----------------------------------------------------------------
    -- 区域视图下的严格边界检测：ModelDataToModel 等场景下使用"完全落入"判定
    -- 若超出边界则执行撤销（不显示撤销提示），允许用户后续取消撤销
    ----------------------------------------------------------------
    if control and control.regionMode and areaActor and UE.UKismetSystemLibrary.IsValid(areaActor) and
        polygon and polygon:Num() >= 3 and actor then
        local ok, fullyInside = pcall(control.modelManage.IsActorFullyInsideRegion, control.modelManage,
            areaActor, actor, polygon)
        if not (ok and fullyInside) then
            -- 执行撤销并丢弃记录，提示"模型大小超出协作区域边界"
            self:DoRegionUndo(currentAction, "模型大小超出协作区域边界")
            return false
        end
    end

    ----------------------------------------------------------------
    -- 正常记录“移动结束”的新 Transform，用于撤销/重做
    ----------------------------------------------------------------
    if actor.modelType == "Multi" then
        currentAction.NewSizeT = self:ActionMulitData(actor, "", 7)

        -- RegionInner 模式：检查所有子模型是否完全在区域内
        if control and control.drawMode == "RegionInner" and control.regionMode and control.polygons then
            local allInside = true
            -- 遍历所有子模型检查是否完全在区域内
            for i = 1, actor.STCActors:Num() do
                local subActor = actor.STCActors[i]
                if subActor and UE.UKismetSystemLibrary.IsValid(subActor) then
                    local isInside = false
                    for regionActor, polygon in pairs(control.polygons) do
                        local ok, inside = pcall(control.modelManage.IsActorFullyInsideRegion,
                            control.modelManage, regionActor, subActor, polygon)
                        if ok and inside then
                            isInside = true
                            break
                        end
                    end
                    if not isInside then
                        allInside = false
                        break
                    end
                end
            end

            if not allInside then
                -- 执行撤销并丢弃记录
                self:DoRegionUndo(currentAction, "模型不能移出协作区域")
                return
            end
        end
    else
        if currentAction.modelName == Model.GetActorAccurateDisplayName(actor) and currentAction.Int == 2 then
            currentAction.NewSizeT = self:ActionActorData(actor, "", 2)
        end
        if actor.modelType == 2 and actor.holeType ~= 0 then
            actor:HoleTraceModel(true)
        end
    end
end

---执行撤销操作
function M:Undo()
    if self.control and self.control.bBuild then
        self.control.ui:UECallWeb("ShowMessage", {
            Type = 3,
            Text = "搭建过程中，禁止使用撤销操作"
        })
        return
    end

    local actionData = self.undoStack[#self.undoStack - #self.redoStack]

    if actionData then
        print(actionData.Int .. "撤销")
        self.bUndo = true
        local success, msg = pcall(self.Core, self, actionData, true)
        if success then
            table.insert(self.redoStack, actionData)
            print("撤销栈数量:" .. #self.redoStack)
            self.ui:UndoStep(#self.undoStack - #self.redoStack, #self.redoStack)
            self.ui:UECallWeb("ShowMessage", {
                Type = 1,
                Text = "撤销成功"
            })
        else
            self.ui:UECallWeb("ShowMessage", {
                Type = 3,
                Text = "撤销失败"
            })
            print("撤销失败", msg)
            self:ClearStack()
        end
    else
        -- if #self.undoStack < self.maxTableSize then
        self.ui:UndoStep(0, #self.redoStack)
        self.ui:UECallWeb("ShowMessage", {
            Type = 3,
            Text = #self.undoStack < self.maxTableSize and "无法继续撤销" or ("最多可撤销" .. self.maxTableSize .. "步，无法继续撤销")
        })
        -- end
    end
end

---执行重做操作
function M:Redo()
    local actionData = self.redoStack[#self.redoStack]
    if actionData then
        print(actionData.Int .. "重做")
        local success, msg = pcall(self.Core, self, actionData, false)
        if success then
            table.remove(self.redoStack, #self.redoStack)

            self.ui:UndoStep(#self.undoStack - #self.redoStack, #self.redoStack)
            self.ui:UECallWeb("ShowMessage", {
                Type = 1,
                Text = "恢复成功"
            })

            if #self.redoStack == 0 then
                print("重做栈数量:" .. #self.redoStack)
                self.bUndo = false
            end
        else
            self.ui:UECallWeb("ShowMessage", {
                Type = 3,
                Text = "恢复失败"
            })
            print("恢复失败", msg)
            self:ClearStack()
        end
    else
        self.ui:UndoStep(#self.undoStack, #self.redoStack)
        self.ui:UECallWeb("ShowMessage", {
            Type = 3,
            Text = #self.undoStack < self.maxTableSize and "无法继续恢复" or ("最多可恢复" .. self.maxTableSize .. "步，无法继续恢复")
        })
    end
end

---核心处理逻辑
---@param actionData table 操作数据
---@param isUndo boolean 是否是撤销操作
function M:Core(actionData, isUndo)
    local redoCount = #self.redoStack + 1
    local actionType = actionData.Int

    if not isUndo then
        redoCount = #self.redoStack - 1
        -- 转换生成/删除操作: 重做时，生成和删除操作需要互换
        if actionData.Int == 1 then
            actionType = 3 -- 1表示生成，重做时需要变为删除
        elseif actionData.Int == 3 then
            actionType = 1 -- 3表示删除，重做时需要变为生成
        end
    end

    -- 更新UI显示：传递撤销栈数量、重做栈数量和清除标志
    -- self.ui:RedoStep(#self.undoStack, redoCount, self.bClear)
    -- 如果设置了清除标志，执行完后重置标志
    if self.bClear then
        self.bClear = false
    end

    -- 根据操作类型执行相应逻辑
    if actionType == 1 then
        -- 操作类型1: 删除模型 / 删除协作区域
        if actionData.isRegionArea then
            -- 协作区域：存在于 modelManage.Regions，而非 Actors 表
            local mm = self.control.modelManage
            local reg = mm.Regions and mm.Regions:Find(actionData.modelName) or nil
            if reg and UE.UKismetSystemLibrary.IsValid(reg) then
                mm:DestroyRegion(reg, self.control)
                -- 同步区域数据到前端
                if self.control.OutRegionData then
                    self.control:OutRegionData()
                end
            end
        else
            -- 普通模型：走通用删除逻辑
            self.control.modelManage.ModelDelete[actionData.Type](
                self.control.modelManage:FindActor(actionData.modelName),
                self.control
            )
            -- 更新地板数据显示
            self.control:FloorDataToView()
        end
    elseif actionType == 2 then
        -- 操作类型2: 移动模型 / 修改属性
        if actionData.isRegionArea then
            -- 协作区域：仅属性修改（名称 / 拥有者等），使用 ModelLoad 还原
            local mm = self.control.modelManage
            local reg = mm.Regions and mm.Regions:Find(actionData.modelName) or nil
            if reg and UE.UKismetSystemLibrary.IsValid(reg) then
                -- 目前未专门保存“新数据”，因此 Undo/Redo 均以记录时快照为准，
                -- 至少保证不会报错，并且可以撤回到当时状态。
                local data = (not isUndo and actionData.NewSizeT) or actionData
                mm.ModelLoad(reg, data, true)
                mm:RegionSelcet(reg, self.control)
                self.control:OutRegionData()
            end
        else
            -- 普通模型：通用移动逻辑
            local actor = self.control.modelManage:FindActor(actionData.modelName)
            if not actor or not UE.UKismetSystemLibrary.IsValid(actor) then
                return
            end
            if isUndo then
                actor:K2_SetActorTransform(stringifyTransform(actionData.size), false, UE.FHitResult(), false)
                self.control.modelManage.ModelLoad(actor, actionData, true)
            else
                actor:K2_SetActorTransform(stringifyTransform(actionData.NewSizeT.size), false, UE.FHitResult(), false)
                self.control.modelManage.ModelLoad(actor, actionData.NewSizeT, true)
            end
            if actor.modelType == 2 and actor.holeType ~= 0 and actor.HoleTraceModel then
                actor:HoleTraceModel(true)
            end

            -- 选中移动后的模型并更新Gizmo位置
            self.control.modelManage.ModelSelect[actionData.Type](actor, self.control)
            -- 根据模型的点击类型和整体属性，更新Gizmo位置
            if actor.clickType == 2 then
                if actor.bOverall then
                    if actor.UpdateOrigin then
                        actor:UpdateOrigin()
                    end
                    self.control.modelManage.gizmo:K2_SetActorLocation(actor:K2_GetActorLocation(), false,
                        UE.FHitResult(),
                        false)
                end
            else
                self.control.modelManage.gizmo:K2_SetActorLocation(actor:K2_GetActorLocation(), false, UE.FHitResult(),
                    false)
            end
            -- 更新模型数据显示
            self.control:ModelDataToView()
        end
    elseif actionType == 3 then
        -- 创建模型 / 创建协作区域
        if actionData.isRegionArea then
            -- 协作区域：使用 CreateRegion + ModelLoad 还原
            local mm = self.control.modelManage
            local reg = mm.Regions and mm.Regions:Find(actionData.modelName) or nil
            if not reg or not UE.UKismetSystemLibrary.IsValid(reg) then
                reg = mm:CreateRegion(actionData.modelName, self.control, actionData.showName or actionData.modelName)
            end
            if reg and UE.UKismetSystemLibrary.IsValid(reg) then
                mm.ModelLoad(reg, actionData, true)
                mm:RegionSelcet(reg, self.control)
                self.control:OutRegionData()
            end
        else
            -- 普通模型：通用创建逻辑
            local actor = self.control.modelManage:DataCreateModel(actionData)
            self:RebulidChilds(actionData)
            if actor.associativeModel and actor.associativeModel ~= "" then
                local associativeActor = self.control.modelManage:DataCreateModel(actionData.associativeModelData)
                self:RebulidChilds(actionData.associativeModelData)
                actor.associativeModel = Model.GetActorAccurateDisplayName(associativeActor)
                associativeActor.associativeModel = Model.GetActorAccurateDisplayName(actor)
            end
            self.control.modelManage.ModelSelect[actionData.Type](actor, self.control)
            self.control:ModelDataToView()
            if actor.modelType == 2 and actor.holeType ~= 0 and actor.HoleTraceModel then
                actor:HoleTraceModel(true)
            end
        end
    elseif actionType == 4 then
        -- 打组/拆组
        if self.control.buildActor then
            self.control.modelManage.ModelCancelSelect[self.control.buildActor.modelType](self.control)
        end
        self.control.modelManage:DestroyGizmo()
        self.control:FloorDataToView()

        local newParent = self.control.modelManage:FindActor(actionData.newParent.modelName)
        local rootParent = self.control.modelManage:FindActor("1")

        if isUndo then
            -- 撤销打组
            if newParent then
                self.control.modelManage:ActorOutMap(newParent)
            end
            for _, groupData in pairs(actionData.DeleteGroups) do
                if not self.control.modelManage:FindActor(groupData.modelName) then
                    local group = self.control.modelManage.ModelCreate["Group"](
                        groupData.modelName,
                        groupData.showName,
                        stringifyTransform(groupData.size)
                    )
                    group.bGroup = true
                    group:K2_AttachToActor(rootParent, "", 1, 1, 1, true)
                end
            end
        else
            -- 重做打组
            for _, groupData in pairs(actionData.DeleteGroups) do
                local group = self.control.modelManage:FindActor(groupData.modelName)
                if not group then
                    self.control.modelManage:ActorOutMap(group)
                end
            end
            if not newParent then
                newParent = self.control.modelManage.ModelCreate["Group"](
                    actionData.newParent.modelName,
                    actionData.newParent.showName,
                    stringifyTransform(actionData.newParent.size)
                )
                newParent.bGroup = true
                newParent:K2_AttachToActor(rootParent, "", 1, 1, 1, true)
            end
        end

        -- 处理组内Actor
        for _, actorData in pairs(actionData.Actors) do
            local actor = self.control.modelManage:FindActor(actorData.modelName)
            if actor then
                local parent
                if isUndo then
                    parent = self.control.modelManage:FindActor(actorData.oldParent)
                else
                    parent = newParent
                end
                actor:K2_AttachToActor(parent, "", 1, 1, 1, true)
            end
        end
    elseif actionType == 5 then
        -- 拆组
        local rootParent = self.control.modelManage:FindActor("1")

        if isUndo then
            -- 撤销拆组
            local group = self.control.modelManage.ModelCreate["Group"](
                actionData.modelName,
                actionData.showName,
                stringifyTransform(actionData.size)
            )
            group.bGroup = true
            group:K2_AttachToActor(rootParent, "", 1, 1, 1, true)

            for _, childData in pairs(actionData.Childs) do
                local child = self.control.modelManage:FindActor(childData.modelName)
                if child then
                    child:K2_AttachToActor(group, "", 1, 1, 1, true)
                end
            end
        else
            -- 重做拆组
            local group = self.control.modelManage:FindActor(actionData.modelName)
            local children = UE.TArray(UE.AActor)
            group:GetAttachedActors(children, true)

            for _, child in pairs(children) do
                child:K2_AttachToActor(rootParent, "", 1, 1, 1, true)
            end
            self.control.modelManage:ActorOutMap(group)
        end
    elseif actionType == 6 then
        -- 批量复制
        if isUndo then
            -- 撤销复制
            for _, actorData in pairs(actionData.Actors) do
                self.control.modelManage.ModelDelete[actorData.Type](
                    self.control.modelManage:FindActor(actorData.modelName),
                    self.control
                )
            end
        else
            -- 重做复制
            for _, actorData in pairs(actionData.Actors) do
                local actor = self.control.modelManage:DataCreateModel(actorData)
                self:RebulidChilds(actorData)
            end
        end
        self.control:FloorDataToView()
    elseif actionType == 7 then
        -- 批量移动
        self.control.modelManage:ModelClear(self.control)
        local multiActor = self.control.modelManage.ModelCreate["Multi"]()

        for _, childData in pairs(actionData.Childs) do
            local actor = self.control.modelManage:FindActor(childData.modelName)
            if actor then
                multiActor.MultiActors:Add(actor)
            end
        end

        if isUndo then
            multiActor:K2_SetActorTransform(stringifyTransform(actionData.size), false, UE.FHitResult(), false)
            multiActor:Move(stringifyTransform(actionData.size).Translation -
                stringifyTransform(actionData.NewSizeT.size).Translation)
            multiActor.Location = stringifyTransform(actionData.size).Translation
        else
            multiActor:K2_SetActorTransform(stringifyTransform(actionData.NewSizeT.size), false, UE.FHitResult(), false)
            multiActor:Move(stringifyTransform(actionData.NewSizeT.size).Translation -
                stringifyTransform(actionData.size).Translation)
            multiActor.Location = stringifyTransform(actionData.Translation).Translation
        end
        self.control.modelManage.ModelSelect[multiActor.modelType](multiActor, self.control)
    elseif actionType == 8 then
        -- 批量删除
        self.control.modelManage:ModelClear(self.control)

        if isUndo then
            -- 撤销删除
            for _, actorData in pairs(actionData.Actors) do
                local actor = self.control.modelManage:DataCreateModel(actorData)
                self:RebulidChilds(actorData)
            end
        else
            -- 重做删除
            for _, actorData in pairs(actionData.Actors) do
                self.control.modelManage.ModelDelete[actorData.Type](
                    self.control.modelManage:FindActor(actorData.modelName),
                    self.control
                )
            end
        end
    end

    -- 更新UI显示
    self.control:TreeDataOut()
    self.control:ShowSel(self.control.buildActor)
end

---重建子对象
---@param data table 数据表
function M:RebulidChilds(data)
    if #data.Childs > 0 then
        for _, childData in pairs(data.Childs) do
            self.control.modelManage:DataCreateModel(childData)
            self:RebulidChilds(childData)
        end
    end
end

---添加数据到历史记录栈
---@param newData table 新数据
function M:addToTableWithLimit(newData)
    -- 添加新数据
    table.insert(self.undoStack, newData)

    -- 检查是否超出最大限制
    if #self.undoStack > self.maxTableSize then
        table.remove(self.undoStack, 1)
    end
end

return M
