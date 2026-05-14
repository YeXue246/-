--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class HoleDiggingLib
local M = {}
local Screen = require("SandBox.Screen")

--- 检测并处理与当前模型相交的孔洞模型
--- @param self table 调用对象
function M.TrackHoleModel(self)
    if self.bDestroy or self.bLoadPlan then
        return
    end

    -- 若网格数据为空则直接返回
    if self.MeshData.Verts:Num() == 0 then
        return
    end

    -- 若已在创建孔洞流程中，则重置标志并退出；否则开始收集孔洞数据
    if self.bCreateHole then
        self.bCreateHole = false
        return
    else
        self:CreatHoleData()
    end
end

--- 收集所有相交的孔洞模型数据，为后续布尔运算做准备
--- @param self table 调用对象
--- @param traceType UE.ETraceTypeQuery 碰撞检测类型
--- @param filterFunc function 筛选actor的函数
function M.CreatHoleData(self, traceType, filterFunc)
    Screen.Print("创建孔")
    -- 清空上一次收集的网格数据
    self.MeshDatas:Clear()

    -- 获取自身组件的世界变换，用于后续坐标转换
    local pTransform = self.PMesh:K2_GetComponentToWorld()
    local outHits = UE.TArray(UE.FHitResult())
    local ignoreActors = UE.TArray(UE.AActor)
    ignoreActors:Add(self)
    local o, b = self:GetActorBounds(true)

    -- 执行盒体碰撞检测
    UE.UKismetSystemLibrary.BoxTraceMulti(
        self:GetWorld(), o, o, b, UE.FRotator(0, 0, 0),
        traceType or UE.ETraceTypeQuery.Model, true, ignoreActors, 0, outHits, true
    )
    local num     = outHits:Num()
    local holeNum = 0
    print("检测到" .. num .. "个相交模型", self)

    -- 再次清空，确保数据干净
    self.MeshDatas:Clear()

    if self.holeNum ~= 0 then
        self:CreateBooleanMesh(self.MeshData, false)
    end
    -- 遍历检测结果，筛选出符合条件的孔洞模型
    for i = 1, num do
        local actor = outHits[i].HitObjectHandle.Actor
        if filterFunc(actor) then
            self.holes:AddUnique(actor)
        end
    end
    -- 从后往前遍历，避免删除元素时影响后续元素的索引
    local holeCount = self.holes:Num()
    for i = holeCount, 1, -1 do
        local hole = self.holes:Get(i)

        if not UE.UKismetSystemLibrary.IsValid(hole) then
            self.holes:Remove(i)
            goto continue
        end
        local bSuccess, newStrMesh = hole:GetModelMeshData(self)

        if bSuccess then
            holeNum = holeNum + 1
            -- 将孔洞网格数据及变换信息存入临时结构，供后续布尔运算使用
            newStrMesh.ta = pTransform
            self.MeshDatas:Add(newStrMesh)
        else
            self.holes:Remove(i)
        end
        ::continue::
    end
    -- 获取孔洞模型的网格数据及其世界变换

    -- 显示提示：告知用户当前模型有多少个孔洞
    local showName = self:GetAttachParentActor().showName
    self.control.ui:ShowModelTip("当前" .. showName .. "有" .. holeNum .. "个孔", "请等待生成完成")
    print("当前" .. showName .. "有" .. holeNum .. "个相交模型", self)
    self.bCreateHole = true

    -- 根据孔洞数量决定后续流程
    if holeNum > 0 then
        print(holeNum, 123123)
        -- 存在孔洞，进入网格数据等待与布尔运算流程
        self:WaitMeshData(self.MeshData, 0)
    else
        -- 无孔洞且之前也无孔洞，直接隐藏提示
        self.bCreateHole = false
        self.control.ui:ModelTipHide()
    end
    -- 更新当前孔洞数量记录
    self.holeNum = holeNum
end

--- 处理布尔运算完成
--- @param self table 调用对象
function M.BooleanMeshOver(self)
    self.bCreateHole = false
    -- 添加协程延迟
    coroutine.resume(
        coroutine.create(
            function()
                UE.UKismetSystemLibrary.Delay(self, 1) -- 1秒延迟
                self.control.ui:ModelTipHide()
            end
        ),
        self
    )
end

--- 模型销毁时还原洞模型效果
--- @param self table 调用对象
function M.OnDestroy(self)
    -- 设置销毁标志
    self.bDestroy = true

    -- 遍历所有相关的洞模型，还原其效果
    if self.holes then
        -- 从后往前遍历，避免删除元素时影响后续元素的索引
        local holeCount = self.holes:Num()
        for i = holeCount, 1, -1 do
            local holeActor = self.holes:Get(i)
            if holeActor and UE.UKismetSystemLibrary.IsValid(holeActor) then
                -- 从洞模型的关联模型列表中移除当前模型
                if holeActor.holeModels then
                    local index = holeActor.holeModels:Find(self)
                    if index > 0 then
                        holeActor.holeModels:Remove(index)
                    end
                end

                -- 更新洞模型的状态，可能需要重新生成其外观
                if holeActor.holeType == 2 then
                    -- 对于类型为2的洞模型，更新其材质
                    if holeActor.holeModels:Num() <= 0 then
                        -- 如果没有关联模型，使用未开孔材质
                        holeActor.StaticMeshComponent:SetMaterial(0, LoadObject(holeActor.holeMatTable[1]))
                    else
                        -- 如果还有其他关联模型，使用已开孔材质
                        holeActor.StaticMeshComponent:SetMaterial(0, LoadObject(holeActor.holeMatTable[2]))
                    end
                end
            end
        end

        -- 清空当前模型的洞模型列表
        self.holes:Clear()
    end

    -- 取消所有正在进行的孔洞创建操作
    self.bCreateHole = false
end

return M
