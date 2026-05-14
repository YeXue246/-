--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--
---@class BP_Control_C
local M = UnLua.Class()
local Screen = require("SandBox.Screen")
local Model = require("SandBox.ModelNameInitialize")
local Json = require("dkjson")
local Class = require("SandBox.Class")
local DFL = require("SandBox.DataFunction")
local RegionAreaAlgo = require("SandBox.Blueprints.RegionAreaAlgo")
local BindKey = UnLua.Input.BindKey
-- local Data = require("Data")

local BFL = UE.UMyBFL

M.DrawMode = {
    Default = "Default",         -- 默认模型绘制模式（全场景）
    RegionArea = "RegionArea",   -- 协作区域绘制模式（绘制 / 编辑协作区域）
    RegionInner = "RegionInner", -- 区域内绘制模型模式（仅在选中协作区域内可操作）
}

BindKey(M, "N", "Pressed", function(self, Key)
    if UE.UMyBFL.GetExeURL("Mode") == "testImport" then
        self.bBuild = true
        self:CreateDownActor("importModel", "导入模型", "/model/test.FBX")
    end
end
)

BindKey(M, "M", "Pressed", function(self, Key)
    if self.pc.bDevMode then
        self.ui.CP:SetVisibility(1)
        Screen.Print("网页是否在加载" .. tostring(self.ui.WebSandBox:IsLoading()))
        Screen.Print("加载地址" .. tostring(self.ui.WebSandBox:GetURL()))
    end
end
)

----------------------------- 我是主流程 -----------------------------
function M:Initialize(Initializer)
    self.bSplineMenuTF                      = false
    self.bBuild                             = false
    self.bBlock                             = nil
    self.bAlign                             = false
    self.clickType                          = 1
    self.oldTransform                       = UE.FTransform()
    self.currentFloor                       = 1
    self.CurrentCH                          = 500
    self.MaxFloor, self.MinFloor            = 1, 1
    self.bX, self.bY, self.bZ, self.IsSpace = false, false, false, false

    self.copyNum                            = 1000 -- 复制数量
    self.copyNumToPlan                      = 500  -- 跨方案复制数量

    self.tickTrack                          = 0
    self.bCatch                             = false
    self.bAndroid                           = false

    -- self.STActors = UE.TArray(UE.AActor) -- 蓝图
    -- self.BatchActors = UE.TArray(UE.AActor) -- 蓝图
    self.bArrayCopy                         = false

    self.bzCatchs                           = UE.TArray(UE.AActor)
    self.animationData                      = {
        type = 0,
        isPlay = false,
        dataArray = {}
    }
    self.playOne                            = {}

    -- RegionArea / RegionInner 相关状态（详见文件末尾 RegionArea 专属逻辑区段）
    self.curReg                             = nil                -- 当前选中 / 绘制中的协作区域 Actor
    self.regionMode                         = false              -- 是否处于“区域视图”模式（仅对当前区域做约束）
    self.drawMode                           = M.DrawMode.Default -- Default | RegionArea | RegionInner
    self.bTrackRegionEdge                   = false              -- 是否检测 Region 边缘碰撞
    self.bPreviewFirstPoint                 = false              -- 是否处于预览第一个点的状态
    self.previewFirstPointLocation          = nil                -- 预览第一个点的位置

    -- RegionInner 调试开关：
    -- 通过启动参数开启（例如：ExeURL 参数 RIDebug=1），避免默认刷屏
    self.bRegionInnerDebug                  = (UE.UMyBFL.GetExeURL("RIDebug") == "1")
    self.regionInnerDebugMax                = 120 -- 单次 TreeDataOut/递归最多打印条数
    self._riLogCount                        = 0

    -- self.IDs = UE.TArray("")
    -- self.OutActors = UE.TArray(UE.AActor)
    -- 第一层级Ctype 第二层级actor
    self.ModelTip                           = {
        [1] = { "放置模型", "鼠标移动选择位置，右键点击放置模型，当前处于放置功能下需要通过中键进行视角移动" },
        [2] = {
            ["LineWall"] = {
                "绘制墙体",
                "左键点击确认点，右键点击取消绘制" ..
                " 按下“v”，闭合或打开墙体" .. " 当前处于绘制功能下需要通过空格+左/中键进行视角旋转或移动" ..
                " 按下回车键，可使用曲线设置面板"
            },
            ["PlasticPipe"] = {
                "绘制管道",
                "左键点击确认点，右键点击取消绘制" ..
                " 当前处于绘制功能下需要通过空格+左/中键进行视角旋转或移动" ..
                " 按下回车键，可使用曲线设置面板"
            },
            ["Tubing"] = {
                "绘制管道", "左键点击确认点，右键点击取消绘制," ..
            " 当前处于绘制功能下需要通过空格+左/中键进行视角旋转或移动" ..
            " 按下回车键，可使用曲线设置面板"
            },
            ["Area"] = {
                "绘制地板",
                "请按特定逆时针绘制，左键点击确认点,右键点击取消绘制" ..
                " 当前处于绘制功能下需要通过空格+左/中键进行视角旋转或移动" ..
                " 按下回车键，可使用曲线设置面板"
            },
            ["diyssx"] = {
                "绘制输送线",
                "左键点击确认点，右键点击取消绘制" ..
                " 当前处于绘制功能下需要通过空格+左/中键进行视角旋转或移动" ..
                " 按下回车键，可使用曲线设置面板"
            },
            ["DashedLine"] = {
                "绘制虚线标注",
                "左键点击确认点，右键点击取消绘制" ..
                " 当前处于绘制功能下需要通过空格+左/中键进行视角旋转或移动" ..
                " 按下回车键，可使用曲线设置面板"
            },
            ["Passage"] = {
                "绘制通道",
                "左键点击确认点，右键点击取消绘制" ..
                " 当前处于绘制功能下需要通过空格+左/中键进行视角旋转或移动" ..
                " 按下回车键，可使用曲线设置面板"
            },
            ["Path"] = {
                "绘制路径",
                "左键点击确认点，右键点击取消绘制" ..
                " 当前处于绘制功能下需要通过空格+左/中键进行视角旋转或移动" ..
                " 按下回车键，可使用曲线设置面板"
            },
        },
        [3] = {
            ["bz"] = {
                "绘制尺寸标注",
                "左键选择需要测量的点，确定尺寸界线长度后右键放下标注并常驻显示" ..
                " 当前处于绘制功能下需要通过空格+左/中键进行视角旋转或移动"
            },
            ["VerticalBZ"] = {
                "绘制水平标注",
                "左键选择需要测量的点，确定后垂直或横向拖出尺寸界线右键放下标注并常驻显示" ..
                " 当前处于绘制功能下需要通过空格+左/中键进行视角旋转或移动"
            }
        }
    }
end

--- RegionInner 调试打印（带限流）
function M:_RIDbg(msg)
    self._riLogCount = (self._riLogCount or 0) + 1
    local maxN = self.regionInnerDebugMax or 120
    if self._riLogCount <= maxN then
        print("[RegionInner] " .. tostring(msg))
    elseif self._riLogCount == maxN + 1 then
        print("[RegionInner] ... log suppressed (max=" .. tostring(maxN) .. ")")
    end
end

function M:ReceiveTick(DeltaSeconds)
    -- Screen.Print(tostring(self.IsSpace), 0, false)

    -- 预览第一个点状态：实时更新预览点位置
    if self.bPreviewFirstPoint then
        self:UpdatePreviewFirstPoint()
    end

    if self.drawMode == "RegionArea" and self.curReg and not self.bBuild then
        -- 根据玩家位置距离调整墙上的点位缩放
        if self.modelManage.NubPoints:Num() > 0 then
            local D = self.curReg:GetDistanceTo(self.pc.PlayerCameraManager)
            if D ~= self.Distance then
                self.Distance = D
                local S = self.Distance / 6000
                for key, value in pairs(self.modelManage.NubPoints) do
                    value:SetActorScale3D(UE.FVector(S, S, S))
                end
            end
        end
        if self.modelManage.gizmo then
            if self.gizmoActor == self.modelManage.gizmo.ParentActor then
                self.gizmoActor        = self.modelManage.gizmo.ParentActor
                local currentTransform = self.gizmoActor:GetTransform()
                local bEqual           = UE.UKismetMathLibrary.NearlyEqual_TransformTransform(self.oldTransform,
                    currentTransform, 1, 1, 1)
                if not bEqual then
                    -- 拖拽开始时缓存起始状态
                    if not self.bMove and self.curReg then
                        self._regionAreaMoveStartTransform = self.oldTransform
                    end

                    self.oldTransform = currentTransform
                    self.bMove = true
                elseif not self.modelManage.gizmo.WasMouseDown and self.bMove then
                    self.bMove = false
                    -- 先同步点集（由 gizmo 影响到样条/点位后，Update 会把 spline 结果写回 simplePoints）
                    self.curReg:Update()

                    -- 松手落地时做一次硬校验：区域不得与其它区域重叠；若重叠则回滚移动
                    local hasOverlap = false
                    local pts = self.curReg.simplePoints
                    if pts and pts:Num() >= 3 and self.modelManage.Regions then
                        local num = self.modelManage.Regions:Num()
                        if num > 0 then
                            for i = 1, num do
                                local otherReg = self.modelManage.Regions:GetByIndex(i - 1)
                                if otherReg ~= self.curReg then
                                    local otherPts = otherReg.simplePoints
                                    if otherPts and otherPts:Num() >= 3 then
                                        if RegionAreaAlgo.DoPolygonsOverlap(pts, otherPts) then
                                            hasOverlap = true
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end

                    if hasOverlap then
                        -- 移动无效，回滚到起始 Transform（不记录 undo，让用户可以撤销更早的操作）
                        if self.gizmoActor and self._regionAreaMoveStartTransform then
                            self.modelManage.gizmo:K2_SetActorLocation(self._regionAreaMoveStartTransform.Translation,
                                false, UE.FHitResult(), false)
                            self.gizmoActor:K2_SetActorTransform(self._regionAreaMoveStartTransform, false,
                                UE.FHitResult(), false)
                        end
                        self.oldTransform = self._regionAreaMoveStartTransform

                        -- 提示：移动失败（区域重叠）
                        if self.ui and self.ui.UECallWeb then
                            self.ui:UECallWeb("ShowMessage", { Type = 2, Text = "无法移动，区域重叠" })
                        end
                    else
                        -- 合法：刷新样条显示并记录 undo
                        self.curReg:SetSplineModel()
                        self.undo:AddNewSize(self.curReg)
                    end

                    -- 清理缓存
                    self._regionAreaMoveStartTransform = nil
                end
            else
                self.gizmoActor = self.modelManage.gizmo.ParentActor
                self.oldTransform = self.gizmoActor:GetTransform()
            end
        end
    end

    if self.buildActor and self.buildActor:IsValid() then
        -- print(Model.GetActorAccurateDisplayName(self.buildActor))
        if self.buildActor.clickType == 1 then
            if self.buildActor.modelType ~= "Group" then
                -- print("123123")
                if self.bBuild then
                    local bEqual = UE.UKismetMathLibrary.NearlyEqual_TransformTransform(self.oldTransform,
                        self.buildActor:GetTransform(), 1, 1, 1)
                    if not bEqual then
                        self.bAlign = self.modelManage:BuildAllAroundLine(self.buildActor)
                        self.oldTransform = self.buildActor:GetTransform()
                        self.tickTrack = 0
                    else
                        if self.tickTrack < 2 then
                            self.bAlign = self.modelManage:BuildAllAroundLine(self.buildActor)
                            self.oldTransform = self.buildActor:GetTransform()
                            self.tickTrack = self.tickTrack + 1
                        end
                    end
                end

                if self.modelManage.gizmo and self.CType ~= "Array" then
                    local bEqual = UE.UKismetMathLibrary.NearlyEqual_TransformTransform(self.oldTransform,
                        self.buildActor:GetTransform(), 1, 1, 1)
                    if not bEqual then
                        self.oldTransform = self.buildActor:GetTransform()
                        self.modelManage:BuildAllAroundLine(self.buildActor)
                        self.bMove = true
                        if self.modelManage.catch then
                            local o, b = self.buildActor:GetActorBounds()
                            o.Z = o.Z - b.Z
                            self.modelManage.catch:K2_SetActorLocation(o, false, nil, false)
                        end
                    elseif not self.modelManage.gizmo.WasMouseDown and self.bMove then
                        self.bMove = false
                        self.undo:AddNewSize(self.buildActor)
                        self:ModelDataToView(true)
                    end
                end
            elseif self.buildActor.modelType == "Group" then
                if self.modelManage.gizmo then
                    local bEqual = UE.UKismetMathLibrary.NearlyEqual_TransformTransform(self.oldTransform,
                        self.buildActor:GetTransform(), 1, 1, 1)
                    if not bEqual then
                        self.oldTransform = self.buildActor:GetTransform()
                        self.bMove = true
                    elseif not self.modelManage.gizmo.WasMouseDown and self.bMove then
                        self.bMove = false
                        self.buildActor:Move()
                        self.undo:AddNewSize(self.buildActor)
                        self:ModelDataToView(true)
                    end
                end
            end
        elseif self.buildActor.clickType == 2 then
            -- 根据玩家位置距离调整墙上的点位缩放
            if self.modelManage.NubPoints:Num() > 0 then
                local D = self.buildActor:GetDistanceTo(self.pc.PlayerCameraManager)
                if D ~= self.Distance then
                    self.Distance = D
                    local S = self.Distance / 6000
                    for key, value in pairs(self.modelManage.NubPoints) do
                        value:SetActorScale3D(UE.FVector(S, S, S))
                    end
                end

                if self.bBuild then
                    self.bAlign = self.modelManage:BuildAllAroundLine(self.modelManage.NubPoints:Find(self.modelManage
                        .NubPoints:Num()))
                end

                -- else
                -- self.bAlign = self.modelManage:BuildAllAroundLine(self.buildActor)
            end

            if self.modelManage.gizmo then
                if self.gizmoActor == self.modelManage.gizmo.ParentActor then
                    self.gizmoActor        = self.modelManage.gizmo.ParentActor
                    local currentTransform = self.gizmoActor:GetTransform()
                    local bEqual           = UE.UKismetMathLibrary.NearlyEqual_TransformTransform(self.oldTransform,
                        currentTransform, 1, 1, 1)
                    if not bEqual then
                        self.oldTransform = currentTransform
                        self.modelManage:BuildAllAroundLine(self.gizmoActor)
                        self.bMove = true
                    elseif not self.modelManage.gizmo.WasMouseDown and self.bMove then
                        self.bMove = false
                        self.buildActor:UpdatePoint()
                        self.buildActor:SetSplineModel()
                        self.modelManage:BuildShowArea(self.buildActor)
                        self.undo:AddNewSize(self.buildActor)
                        self:ModelDataToView(true)
                    end
                else
                    self.gizmoActor = self.modelManage.gizmo.ParentActor
                    self.oldTransform = self.gizmoActor:GetTransform()
                end
            end
        end
    end

    if self.bMoveCad and self.modelManage.cad then
        local t = self.modelManage.cad:GetTransform()
        local bEqual = UE.UKismetMathLibrary.NearlyEqual_TransformTransform(self.oldTransform,
            t, 1, 1, 1)
        if not bEqual then
            self.oldTransform = t
            self.bMove = true
        elseif self.bMove then
            self.bMove = false
            self.ui:UECallWeb("RealTimeData",
                { x = self.oldTransform.Translation.X, y = self.oldTransform.Translation.Y })
        end
    end
end

function M:CommunicationCleanup(functionName)
    if self.bBuild then
        if self.curReg then
            self:StopMoveRegionArea()
            self:RemoveTip()
            self.bBuild = false
        end

        if self.buildActor and not (functionName == "DrawModel" or functionName == "StopCrossCopy") then
            if self.buildActor.clickType == 1 then
                self:StopMove()
            elseif self.buildActor.clickType == 2 then
                self:StopMovePoint()
                self:ShutdownSplineMenu()
            elseif self.buildActor.clickType == 3 then
                self:StopMoveTwoPoint()
            end
            self:RemoveTip()
            self.bBuild = false
        end
    end
end

-- -- ===========================================================================
-- -- RegionInner（区域内编辑）专属：Gizmo 移动约束（防止坐标轴拖拽将模型移出协作区域）
-- -- ===========================================================================

-- --- 获取 RegionInner 下当前 Gizmo 约束目标（优先使用 gizmo.ParentActor，避免 buildActor 偶发不同步）
-- --- @return AActor|nil
-- function M:_GetRegionInnerGizmoTargetActor()
--     if self.modelManage and self.modelManage.gizmo and self.modelManage.gizmo.ParentActor and
--         UE.UKismetSystemLibrary.IsValid(self.modelManage.gizmo.ParentActor) then
--         return self.modelManage.gizmo.ParentActor
--     end

--     if self.buildActor and UE.UKismetSystemLibrary.IsValid(self.buildActor) then
--         return self.buildActor
--     end

--     return nil
-- end

-- --- 获取当前 Gizmo 拖拽应被约束的一组 Actor（支持 Multi/单选）
-- --- @return table|nil actorsMap 以 actor 为 key 的 map（value 暂不使用）
-- function M:_GetRegionInnerMoveActors()
--     local target = self:_GetRegionInnerGizmoTargetActor()
--     if not target then
--         return nil
--     end

--     local actors = {}
--     -- Multi：约束每一个子 Actor（Multi 本体通常无网格，bounds 可能为 0）
--     if target.modelType == "Multi" and target.MultiActors then
--         local num = target.MultiActors:Num()
--         for i = 1, num do
--             local a = target.MultiActors[i]
--             if a and UE.UKismetSystemLibrary.IsValid(a) then
--                 actors[a] = true
--             end
--         end

--         return actors
--     end

--     -- 单选/Group：直接约束 target
--     actors[target] = true
--     return actors
-- end

-- --- RegionInner：将当前选择回滚到“最后一次合法位置”
-- function M:_RestoreRegionInnerLastValidTransforms()
--     if not self._regionInnerLastValidTransforms then
--         return
--     end

--     -- 回滚每一个参与约束的 Actor
--     for actor, t in pairs(self._regionInnerLastValidTransforms) do
--         if actor and UE.UKismetSystemLibrary.IsValid(actor) and t then
--             actor:K2_SetActorTransform(t, false, UE.FHitResult(), false)
--         end
--     end

--     -- 同步 gizmo 到当前目标 Actor（避免 gizmo 残留在越界位置）
--     local target = self:_GetRegionInnerGizmoTargetActor()
--     if self.modelManage and self.modelManage.gizmo and target and UE.UKismetSystemLibrary.IsValid(target) then
--         self.modelManage.gizmo:K2_SetActorLocation(target:K2_GetActorLocation(), false, UE.FHitResult(), false)
--     end

--     -- 本次回滚结束后，把“最后一次合法 Transform”刷新为当前值，避免下一次拖拽还引用更早的一步
--     local actors = self:_GetRegionInnerMoveActors()
--     if actors then
--         for actor, _ in pairs(actors) do
--             if actor and UE.UKismetSystemLibrary.IsValid(actor) then
--                 self._regionInnerLastValidTransforms[actor] = actor:GetTransform()
--             end
--         end
--     end
-- end

-- --- RegionInner 下：判断当前选择（单选 / Multi）是否仍完全位于当前区域内
-- function M:_IsCurrentSelectionInsideRegionInner()
--     local actors = self:_GetRegionInnerMoveActors()
--     if not actors then
--         return true
--     end

--     for actor, _ in pairs(actors) do
--         if not self:IsActorInsideCurrentRegion(actor) then
--             return false
--         end
--     end

--     return true
-- end

-- --- Tick：RegionInner + gizmo 移动时，只记录“最后一次合法 Transform”
-- --- 说明：参考其它地方的 gizmo 处理，**只在 WasMouseDown 为 true（按住鼠标拖拽）时参与逻辑**，
-- ---       并且一旦拖出区域，就立刻回滚到“最后一次合法 Transform”，不额外改动撤销栈
-- function M:TickRegionInnerGizmoConstraint()
--     -- 仅在 RegionInner 模式且已进入区域视图后才启用
--     if self.drawMode ~= M.DrawMode.RegionInner then
--         self._regionInnerLastValidKey = nil
--         self._regionInnerLastValidTransforms = nil
--         return
--     end

--     if self.IsRegionInnerLocked and self:IsRegionInnerLocked() then
--         self._regionInnerLastValidKey = nil
--         self._regionInnerLastValidTransforms = nil
--         return
--     end

--     if not (self.modelManage and self.modelManage.gizmo) then
--         self._regionInnerLastValidKey = nil
--         self._regionInnerLastValidTransforms = nil
--         return
--     end

--     local gizmo = self.modelManage.gizmo

--     -- 只在鼠标按下（gizmo 被拖拽）期间做 RegionInner 约束
--     if not gizmo.WasMouseDown then
--         -- 鼠标抬起：清一次缓存，等下一次拖拽重新记录
--         self._regionInnerLastValidKey = nil
--         self._regionInnerLastValidTransforms = nil
--         self._regionInnerGizmoRejected = false
--         return
--     end

--     local actors = self:_GetRegionInnerMoveActors()
--     if not actors then
--         self._regionInnerLastValidKey = nil
--         self._regionInnerLastValidTransforms = nil
--         return
--     end

--     -- 选择对象变化时：重建缓存（避免 buildActor 与 gizmo.ParentActor 偶发不同步导致缓存失效）
--     local key = self:_GetRegionInnerGizmoTargetActor()
--     if key ~= self._regionInnerLastValidKey then
--         self._regionInnerLastValidKey = key
--         self._regionInnerLastValidTransforms = {}
--         self._regionInnerGizmoRejected = false
--     end

--     -- 只要当前选择仍合法：持续刷新“最后一次合法 Transform”
--     if self:_IsCurrentSelectionInsideRegionInner() then
--         for actor, _ in pairs(actors) do
--             self._regionInnerLastValidTransforms[actor] = actor:GetTransform()
--         end

--         self._regionInnerGizmoRejected = false
--         return
--     end

--     -- 一旦越界：立即回滚到“最后一次合法 Transform”，并保持 gizmo 拖拽，效果类似“拖不出边界”
--     if self._regionInnerLastValidTransforms and next(self._regionInnerLastValidTransforms) then
--         self:_RestoreRegionInnerLastValidTransforms()
--     end

--     -- 提示只交给 UI 一次（可按需保留 / 去掉）
--     if self.ui and self.ui.UECallWeb then
--         self.ui:UECallWeb("ShowMessage", {
--             Type = 2,
--             Text = "模型不能移出协作区域"
--         })
--     end
-- end

function M:ReceiveBeginPlay()
    local pcClass = LoadClass(Class.hyPC)
    self.pc = UE.UGameplayStatics.GetPlayerController(self:GetWorld(), 0):Cast(pcClass)
    local mmClass = LoadClass(Class.modelManage)
    self.modelManage = self:GetWorld():SpawnActor(mmClass, UE.FTransform(),
        UE.ESpawnActorCollisionHandlingMethod.Default,
        self, self, "")
    -- 让 ModelManage 能在任意时刻访问 control 的状态（例如 drawMode），避免 early-load nil 崩溃
    self.modelManage.control = self

    local InputClass = LoadClass("/Game/SandBox/Blueprints/BP_Input.BP_Input_C")
    local InputClass2 = LoadClass("/Game/SandBox/Blueprints/BP_Input2.BP_Input2_C")

    self.BPI = self:GetWorld():SpawnActor(InputClass, UE.FTransform(), UE.ESpawnActorCollisionHandlingMethod.Default,
        self, self, "")
    self.BPI2 = self:GetWorld():SpawnActor(InputClass2, UE.FTransform(), UE.ESpawnActorCollisionHandlingMethod.Default,
        self, self, "")

    self.BPI.control = self
    self.BPI2.control = self

    self:CheckInput(false)

    self.SEHUD = self.pc:GetHUD():Cast(LoadClass('/Game/SandBox/UI/zlq/TopHUD.TopHUD_C'))
end

function M:CheckInput(bfangzhen)
    if bfangzhen then
        self.BPI:DisableInput(self.pc)
        self.BPI2:EnableInput(self.pc)
    else
        self.BPI:EnableInput(self.pc)
        self.BPI2:DisableInput(self.pc)
    end
end

----------------------------- 新增方案 -----------------------------
function M:NullPlan(bool)
    if self.buildActor then
        self.modelManage.ModelCancelSelect[self.buildActor.modelType](self)
    end

    if self.modelManage.gizmo then
        self.modelManage:DestroyGizmo()
    end

    if self.modelManage.cad then
        local cads = UE.UGameplayStatics.GetAllActorsOfClass(self:GetWorld(), LoadClass(self.modelManage.class["CAD"]))
        for k, v in pairs(cads) do
            v:K2_DestroyActor()
        end

        self.modelManage.cad = nil
    end

    self.bMoveCad = false
    self.order = 1000
    self.animationData = {
        type = 0,
        isPlay = false,
        dataArray = {}
    }
    if self.modelManage.catch then
        self.modelManage:ClearCatch(true)
    end

    if self.bBuild then
        -- if self.buildActor then
        --     RClick[self.clickType](self)
        -- end
        self:RemoveTip()
        self.bBuild = false
        -- 重置绘制模式为默认模式
        self.drawMode = M.DrawMode.Default
    end

    if self.ui.isTeamScheme then
        self.bRegionEdit = true
    end

    -- self.STActors:Clear()
    self:RemoveMenu()
    self:RemoveRename()
    self:ShutdownSplineMenu()
    self.PasteActors = nil

    -- for key, value in pairs(self.modelManage.Actors) do
    --     if UE.UKismetSystemLibrary.IsValid(value) then
    --         value:K2_DestroyActor()
    --     end
    local num = self.modelManage.Actors:Num()
    local keys = self.modelManage.Actors:Keys()
    if num > 0 then
        for i = 1, num do
            local key = keys[i]
            local value = self.modelManage.Actors:Find(key)
            if UE.UKismetSystemLibrary.IsValid(value) then
                value:K2_DestroyActor()
            end

            self.modelManage.Actors:Remove(key)
        end
    end

    self.modelManage:ClearAllRegions()

    self.modelManage.ShowNames:Clear()
    self.modelManage.ModelCreate["DIY"]()
    local F = self.modelManage.ModelCreate[1](1, self, nil, UE.FTransform(), "画布")
    local FT = {
        High = 500,
        FName = ""
    }
    self.modelManage.SetData["default"](F, FT)
    self.MaxFloor, self.MinFloor = 1, 1
    if not (self.currentFloor == nil and bool == nil) then
        self.currentFloor = 1
        self:FloorDataToView()
    end

    self:TreeDataOut()
end

----------------------------- 地板的交互 -----------------------------

function M:FloorDataToView()
    if self.currentFloor then
        local F = self.modelManage:FindActor(self.currentFloor .. "Floor-s")
        if F then
            -- local FT = self.modelManage.GetData[F.modelType](F, self.currentFloor)
            -- print(FT["height"], 33)
            local T = {
                Model = 1
            }
            self.ui:ShowBoard(T)
            -- self.ui:PassFloorData(FT)
            self:ShowSel()
            self:UpdateAnimeList()
        end
    end
end

function M:FloorDataToModel(FDT)
    self.MaxFloor = FDT.max
    self.MinFloor = FDT.min
    if FDT.allFlag then
        if self.currentFloor then
            self.modelManage:FindActor(self.currentFloor .. "Floor-s"):ClearFloor()
            for key, value in pairs(self.modelManage.Actors) do
                value:SetActorEnableCollision(false)
            end

            local ChildActors = UE.TArray(UE.AActor)
            self.modelManage.DIY:GetAttachedActors(ChildActors, true)
            for key, value in pairs(ChildActors) do
                value.RootComponent:SetVisibility(true, true)
            end
        end

        self.modelManage.ModelSelect[1](self.buildActor, self)
        self.currentFloor = nil
    else
        -- 如果楼层与当前楼层相同
        local FT = {
            High = FDT.height,
            FName = FDT.floorName
        }
        if FDT.floor == self.currentFloor then
            self.CurrentCH = FDT.height
            -- 获取当前楼层的 Floor-s Actor 并更新其数据
            local F = self.modelManage:FindActor(self.currentFloor .. "Floor-s")
            if FT.High ~= F.High then
                local OffestZ = FT.High - F.High
                self:UpdateFloorsSize(OffestZ, FDT.floor)
            end

            self.modelManage.SetData["default"](F, FT)
        elseif self.modelManage:FindActor(FDT.floor) then
            -- 如果新楼层已存在，隐藏当前楼层并显示新楼层，更新当前楼层为新楼层
            for key, value in pairs(self.modelManage.Actors) do
                value:SetActorEnableCollision(false)
            end

            local ChildActors = UE.TArray(UE.AActor)
            self.modelManage.DIY:GetAttachedActors(ChildActors, true)
            for key, value in pairs(ChildActors) do
                value.RootComponent:SetVisibility(false, true)
            end

            -- 销毁当前绘制平面
            if self.currentFloor then
                self.modelManage:FindActor(self.currentFloor .. "Floor-s"):ClearFloor()
            end

            -- 生成新的绘制平面
            self.currentFloor = FDT.floor
            self.modelManage:FindActor(FDT.floor).RootComponent:SetVisibility(true, true)
            self:SetCollision(self.modelManage:FindActor(FDT.floor), true)
            local F = self.modelManage:FindActor(self.currentFloor .. "Floor-s")
            -- if FT.High ~= F.High then
            --     local OffestZ = FT.High - F.High
            --     self:UpdateFloorsSize(OffestZ, FDT.floor)
            -- end
            -- self.modelManage.SetData[1](F, FT)
            F:CreateFloor()
            self.ui.pawn:Hoist(F:K2_GetActorLocation().Z)
            if self.buildActor then
                self.modelManage.ModelCancelSelect[self.buildActor.modelType](self.control)
            end

            -- QCJL
            self.undo:ClearStack()
        else
            self.CurrentCH = FDT.height
            -- 如果新楼层不存在
            self.modelManage:FindActor(self.currentFloor .. "Floor-s"):ClearFloor()
            -- 隐藏当前楼层
            for key, value in pairs(self.modelManage.Actors) do
                value:SetActorEnableCollision(false)
            end

            local ChildActors = UE.TArray(UE.AActor)
            self.modelManage.DIY:GetAttachedActors(ChildActors, true)
            for key, value in pairs(ChildActors) do
                value.RootComponent:SetVisibility(false, true)
            end

            local Transform = UE.FTransform()

            -- 如果楼层大于等于 2，生成新楼层并更新当前楼层为新楼层
            if FDT.floor >= 2 then
                local F = self.modelManage:FindActor((FDT.floor - 1) .. "Floor-s")
                local L = F:K2_GetActorLocation()
                Transform.Translation = UE.FVector(L.X, L.Y, L.Z + F.High)
            else
                -- 如果楼层小于 2，生成新楼层并更新当前楼层为新楼层
                local F = nil
                if self.modelManage:FindActor(FDT.floor + 1) then
                    F = self.modelManage:FindActor((FDT.floor + 1) .. "Floor-s")
                else
                    F = self.modelManage:FindActor((FDT.floor + 2) .. "Floor-s")
                end

                local L = F:K2_GetActorLocation()
                Transform.Translation = UE.FVector(L.X, L.Y, L.Z - F.High)
            end

            self.ui.pawn:Hoist(Transform.Translation.Z)
            self.currentFloor = FDT.floor
            local F = self.modelManage.ModelCreate[1](self.currentFloor, self, nil, Transform, "画布")
            self.modelManage.SetData["default"](F, FT)
            if self.buildActor then
                self.modelManage.ModelCancelSelect[self.buildActor.modelType](self)
            end

            self.undo:ClearStack()
        end

        self:FloorDataToView()
    end
end

function M:GetChilds(F)
    local ChildActors = UE.TArray(UE.AActor)
    local AllActors = UE.TArray(UE.AActor)
    F:GetAttachedActors(ChildActors, true)
    if ChildActors:Num() > 0 then
        Model.ModelFor(ChildActors, AllActors)
    end

    -- print(AllActors:Num(), 3333)
    return AllActors
end

function M:UpdateFloorsSize(Offest, floorInt)
    if floorInt > 0 and self.MaxFloor - floorInt ~= 0 then
        for i = floorInt + 1, self.MaxFloor do
            local F = self.modelManage:FindActor(i)
            local AllActors = self:GetChilds(F)
            for key, value in pairs(AllActors) do
                if value:Cast(UE.AStaticMeshActor) then
                    value:K2_AddActorWorldOffset(UE.FVector(0, 0, Offest), false, UE.FHitResult(), false)
                end
            end
        end
    elseif floorInt < 0 then
        for i = self.MinFloor, floorInt do
            local F = self.modelManage:FindActor(i)
            local AllActors = self:GetChilds(F)
            for key, value in pairs(AllActors) do
                if value:Cast(UE.AStaticMeshActor) then
                    value:K2_AddActorWorldOffset(UE.FVector(0, 0, -Offest), false, UE.FHitResult(), false)
                end
            end
        end
    end
end

function M:SetCollision(F, bCollision)
    local AllActors = self:GetChilds(F)
    for key, value in pairs(AllActors) do
        value:SetActorEnableCollision(bCollision)
    end
end

----------------------------- 构建CAD -----------------------------
function M:CreateCAD(jsonTable, cadName, cadTime)
    local bSuccess = false
    local cad = self.modelManage.ModelCreate["CAD"](self.currentFloor, self, nil, UE.FTransform(), "CAD")
    if cad then
        -- 先写入名称/时间，便于 BP_CAD:SetCAD 在创建时自动落盘 bin
        cad.cadName = cadName
        cad.cadTime = cadTime
        bSuccess = cad:SetCAD(jsonTable, true)
        if not bSuccess then
            self.modelManage.cad:K2_DestroyActor()
            self.modelManage.cad = nil
        end
    end

    return bSuccess
end

function M:CreateCADFromBin(binPath, cadName, cadTime)
    local cad = self.modelManage.ModelCreate["CAD"](self.currentFloor, self, nil, UE.FTransform(), "CAD")
    if cad then
        cad.cadName = cadName
        cad.cadTime = cadTime
        cad:SetCADFromBin(binPath, true)
    end
end

function M:GetCadData()
    if self.bBuild then
        return
    end

    local t = {}
    if self.modelManage.cad then
        local l = self.modelManage.cad:K2_GetActorLocation()
        t = {
            x = DFL.integrate(l.X),
            y = DFL.integrate(l.Y),
            bHaveCad = true,
            CADName = self.modelManage.cad.cadName,
            CADTime = self.modelManage.cad.cadTime,
        }
        if self.buildActor then
            self.modelManage.ModelCancelSelect[self.buildActor.modelType](self)
        end

        self.modelManage:CreateGizmo(self.modelManage.cad)
        self.modelManage.gizmo:CloseZ()
        self.clickType = 1
        self.bBuild = true
        self.bMoveCad = true
    else
        t = { x = 0, y = 0, bHaveCad = false }
    end

    return t
end

function M:SetCadData(jsonTable)
    local l = UE.FVector(jsonTable.x, jsonTable.y, 2)
    self.modelManage.cad:K2_SetActorLocation(l, false, nil, false)
    self.modelManage.gizmo:K2_SetActorLocation(l, false, nil, false)
end

function M:IsShowCad(jsonTable)
    self.modelManage.cad:IsShowCad(jsonTable.bShow)
end

function M:CloseCadWindow(jsonTable)
    self.bBuild = false
    self.modelManage:DestroyGizmo()
    if jsonTable.category == 2 then
        self.modelManage.cad:K2_DestroyActor()
        self.modelManage.cad = nil
    end
end

function M:ExportPlanDataToCad()
    return self.modelManage:ExportPlanDataToCad()
end

----------------------------- 模型的操作 -----------------------------

function M:CreateModel(modelCode, showName, downloadPath, modelCategory, bAnime)
    if self.drawMode == M.DrawMode.RegionArea then
        return
    end



    self:CancelGroupsTime()
    if self.Timer then
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.Timer)
    end

    if self.currentFloor then
        local meshLoad = self.modelManage.MeshDatas:Find(modelCode)
        if self.buildActor then
            if self.bBuild then
                self.modelManage.ModelDelete[self.buildActor.modelType](self.buildActor, self)
            else
                self.modelManage.ModelCancelSelect[self.buildActor.modelType](self)
            end
        end

        self.bBuild = true
        if meshLoad then
            if meshLoad.CType == 1 then
                self.ui:ShowModelTip(self.ModelTip[meshLoad.CType][1], self.ModelTip[meshLoad.CType][2])
                self:CreateBuildActor(modelCode, meshLoad, showName, modelCategory, bAnime)
            elseif meshLoad.CType == 2 then
                self.ui:ShowModelTip(self.ModelTip[meshLoad.CType][modelCode][1],
                    self.ModelTip[meshLoad.CType][modelCode][2])
                self:CreateLineTip(modelCode, meshLoad, showName, modelCategory)
            elseif meshLoad.CType == 3 then
                self:TimeMove()
                self.ui:ShowModelTip(self.ModelTip[meshLoad.CType][modelCode][1],
                    self.ModelTip[meshLoad.CType][modelCode][2])
                self:CreateLineTip(modelCode, meshLoad, showName, modelCategory)
            end
        elseif downloadPath and downloadPath ~= "" then
            local DownSavePath = UE.UBlueprintPathsLibrary.ProjectDir() .. "model/" ..
                string.match(downloadPath, "^.+/(.+)$")
            local bExists = UE.UBlueprintPathsLibrary.FileExists(DownSavePath)
            if bExists then
                self.ui:ShowModelTip(self.ModelTip[1][1], self.ModelTip[1][2])
                self:CreateDownActor(modelCode, showName, DownSavePath)
            else
                self:DownloadModel(DownSavePath, downloadPath, true)
                return "UnDownload"
            end
        end
    else
        -- self.ui.B_Tip:SetVisibility(3)
        -- self.ui.Tip:SetText("当前在所有楼层视图，请选择楼层绘制")
    end
end

-- 定时移动函数
function M:TimeMove()
    if self.Timer then
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.Timer)
    end

    if self.buildActor then
        if self.buildActor.clickType == 1 then
            self.Timer = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.MoveActor }, DFL.timerSec, true)
        elseif self.buildActor.clickType == 2 then
            if self.bRec then
                self.Timer = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.MoveRec }, DFL.timerSec, true)
            else
                self.Timer = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.MovePoint }, DFL.timerSec, true)
            end
        elseif self.buildActor.clickType == 3 then
            self.Timer = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.MoveTwoPoint }, DFL.timerSec, true)
        end
    else
        self.Timer = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.PointTip }, DFL.timerSec, true)
    end
end

function M:DeleteModel()
    if self.buildActor then
        -- RegionInner 模式：仅允许删除当前协作区域内的模型
        -- 说明：这里采用几何区域判定（IsActorInsideCurrentRegion），避免过度依赖 RegionInnerActors 映射
        if self.drawMode == M.DrawMode.RegionInner and self.buildActor.modelType ~= "Multi"
            and not self:IsActorInsideCurrentRegion(self.buildActor) then
            if self.ui and self.ui.UECallWeb then
                self.ui:UECallWeb("ShowMessage", {
                    Type = 2,
                    Text = "当前模式下只能删除区域内的模型"
                })
            end

            return
        end

        if self.buildActor.bMove then
            if self.buildActor.modelType == "Multi" then
                self.undo:AddAction(8, self.buildActor)
            else
                self.undo:AddAction(3, self.buildActor)
            end

            print("DeleteModel")
            self.modelManage.ModelDelete[self.buildActor.modelType](self.buildActor, self)
            self:ShowSel()
            self:UpdateAnimeList(true)
            self:TreeDataOut()
        end
    end
end

------------------------拖出来的模型
-- 创建BuildActor函数
function M:CreateBuildActor(modelCode, meshLoad, showName, modelCategory, bAnime)
    self.clickType = meshLoad.CType
    -- LClick[self.clickType](self)
    local floor = self.modelManage:FindActor(self.currentFloor)
    if floor then
        local start, endP = Model.GetLineValue(self.pc)
        -- local bHave, Location = self:GetCreateLocation(start, endP)
        local hitRes = UE.FHitResult()
        UE.UKismetSystemLibrary.LineTraceSingle(self:GetWorld(), start, endP, UE.ETraceTypeQuery.Floor, false, nil, 0,
            hitRes, true)
        if hitRes.bBlockingHit or self.pc.gi.showMode == 1 then
            -- self.bBuild = true
            local newName = self:NameCheck(modelCode)
            local newShowName = self:ShowNameCheck(showName)
            if self.buildActor then
                self.modelManage.ModelCancelSelect[self.buildActor.modelType](self)
            end

            -- 在世界中生成Actor，并设置位置
            local modelType = meshLoad.MType
            if bAnime then
                modelType = 12
            end

            self.buildActor = self.modelManage.ModelCreate[modelType](newName, self, LoadObject(meshLoad.Mesh), nil,
                newShowName,
                modelCategory)
            self.buildActor.modelCode = modelCode
            self.buildActor:GetBox(meshLoad.MType)

            if meshLoad.bDefaultSetting then
                local sx = meshLoad.Size.X / self.buildActor.originalSize.X
                local sy = meshLoad.size.y / self.buildActor.originalSize.y
                local sz = 0

                if meshLoad.Size.Z == 0 then
                    sz = self.CurrentCH / self.buildActor.originalSize.Z
                    self.buildActor.size = UE.FVector(meshLoad.Size.X, meshLoad.Size.Y, self.CurrentCH)
                else
                    sz = meshLoad.Size.Z / self.buildActor.originalSize.Z
                    self.buildActor.size = UE.FVector(meshLoad.Size.X, meshLoad.Size.Y, meshLoad.Size.Z)
                end

                self.buildActor:SetActorScale3D(UE.FVector(sx, sy, sz))
            end

            self.start = start
            self:MoveActor()
            self:TimeMove()
        else
            -- Screen.Print("点击角度不对" .. "\n" .. tostring(start) .. "\n" .. tostring(endP))
        end
    end
end

-- 创建DownActor函数
function M:CreateDownActor(ModelCode, showName, DownSavePath, bBasic, ModelCategory)
    self.clickType = 1
    -- LClick[self.clickType](self)
    local F = self.modelManage:FindActor(self.currentFloor)
    if F then
        local start, endP = Model.GetLineValue(self.pc)
        -- local bHave, Location = self:GetCreateLocation(start, endP)
        local hitRes = UE.FHitResult()
        UE.UKismetSystemLibrary.LineTraceSingle(self:GetWorld(), start, endP, UE.ETraceTypeQuery.Floor, false, nil, 0,
            hitRes, true)
        if hitRes.bBlockingHit or self.pc.gi.showMode == 1 then
            -- self.bBuild = true
            local AName = self:NameCheck(ModelCode)
            local showName = self:ShowNameCheck(showName)
            if self.buildActor then
                self.modelManage.ModelCancelSelect[self.buildActor.modelType](self)
            end

            -- 在世界中生成Actor，并设置位置
            self.buildActor = self.modelManage.ModelCreate[10](AName, self, nil, nil, showName, ModelCategory)
            self.buildActor.modelCode = ModelCode
            self.buildActor.path = DownSavePath
            self.buildActor:GetBox(bBasic)
            self.buildActor:LoadModel()

            self.start = start
            self:MoveActor()
            self:TimeMove()
        else
            Screen.Print("点击角度不对")
        end
    end
end

--- Actor移动控制逻辑（含碰撞检测和状态反馈）
--- @warning 会修改模型位置和材质颜色状态
function M:MoveActor()
    -- RegionInner 模式：对“已存在模型”的移动施加区域几何约束
    -- 新建预览阶段（self.bBuild == true）仅依赖 IsActorInsideCurrentRegion 由 StopMove/StopMovePoint 统一校验
    if self.drawMode == M.DrawMode.RegionInner and self.buildActor and not self.bBuild then
        if not self:IsActorInsideCurrentRegion(self.buildActor) then
            return
        end
    end

    --- @type FVector2D 当前帧鼠标屏幕坐标
    local mouse2D = UE.UWidgetLayoutLibrary.GetMousePositionOnViewport(self:GetWorld())

    -- 仅当鼠标位置变化时执行移动逻辑
    if self.mouse2D ~= mouse2D then
        self.mouse2D = mouse2D

        -- 获取射线参数（起点/终点）
        --- @type FVector,FVector
        local start, endP = Model.GetLineValue(self.pc)

        -- 特殊起点位置处理（防止零向量错误）
        if UE.UKismetMathLibrary.EqualEqual_VectorVector(self.start, start, 0.01) then
            start = UE.FVector(0, 0, 0)
        else
            self.start = UE.FVector(0, 0, 0)
        end

        --- @type FHitResult 射线命中结果
        local hitRes = UE.FHitResult()

        -- 地板层射线检测 --------------------------------------------------
        UE.UKismetSystemLibrary.LineTraceSingle(
            self:GetWorld(),
            start,
            endP,
            UE.ETraceTypeQuery.Floor, -- 仅检测地板层
            false,
            nil,
            0,
            hitRes,
            true
        )

        -- 有效命中处理 ---------------------------------------------------
        if hitRes.bBlockingHit then
            --- @type boolean 实际移动标记
            local bMove = true

            -- 对齐模式检测（防止微小抖动）
            if self.bAlign then
                bMove = not UE.UKismetMathLibrary.EqualEqual_VectorVector(
                    hitRes.Location,
                    self.buildActor:K2_GetActorLocation(),
                    50 -- 50单位距离阈值
                )
            end

            -- 执行实际位移操作 -------------------------------------------
            if bMove then
                --- @type FHitResult 物理碰撞检测结果
                local SweepHitResult = UE.FHitResult()

                -- 应用坐标离散化处理（防止浮点误差）
                local location = DFL.integrateVector(hitRes.Location)
                self.buildActor:K2_SetActorLocation(location, false, SweepHitResult, false)

                -- 模型碰撞检测及颜色反馈 --------------------------------


                if self.buildActor.holeType ~= 2 and self.buildActor.modelType ~= 10 then
                    local bBox = self.buildActor:TraceOtherModel(true)

                    if self.bBlock ~= (hitRes.bBlockingHit and not bBox) then
                        self.bBlock = (hitRes.bBlockingHit and not bBox)
                        --- @type FLinearColor 反馈颜色（绿:可放置/红:碰撞）
                        local feedbackColor = self.bBlock and UE.FLinearColor(0, 1, 0, 0) or
                            UE.FLinearColor(1, 0, 0, 0)
                        self.modelManage.BPM:SetCreateM(self.buildActor, feedbackColor, self.buildActor.bBuildRotate)
                    end

                    if self.bHoleRotate ~= self.buildActor.bBuildRotate then
                        if self.buildActor.bBuildRotate then
                            self.modelManage.BPM:SetCreateM(self.buildActor, UE.FLinearColor(1, 0.2, 0, 0), true)
                        else
                            self.modelManage.BPM:SetCreateM(self.buildActor, UE.FLinearColor(0, 1, 0, 0), false)
                        end
                    end
                elseif self.buildActor.modelType == 10 then
                    local bBox = self.buildActor:TraceOtherModel(true)
                    if self.bBlock ~= (hitRes.bBlockingHit and not bBox) then
                        self.bBlock = (hitRes.bBlockingHit and not bBox)
                        self.buildActor:UpdateCollisionStatus(bBox)
                    end
                else
                    self.bBlock = true
                end
            end
        end
    end
end

-- 停止物体移动
function M:StopMove()
    if self.Timer then
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.Timer)
    end

    if self.bBuild then
        -- RegionInner 模式：禁止在当前协作区域外放置模型（统一的几何区域校验）
        -- 注意：在设置 bBuild = false 之前检查，以便 IsActorInsideCurrentRegion 能识别这是构建阶段
        if self.drawMode == M.DrawMode.RegionInner and self.buildActor and not self:IsActorInsideCurrentRegion(self.buildActor) then
            if self.ui and self.ui.UECallWeb then
                self.ui:UECallWeb("ShowMessage", {
                    Type = 2,
                    Text = "当前模式下只能在选中协作区域内放置模型"
                })
            end

            -- 删除非法放置的预览模型
            self.modelManage.ModelDelete[self.buildActor.modelType](self.buildActor, self)
            self.buildActor = nil
            self.bBlock = nil
            self.bBuild = false
            return
        end

        self.bBuild = false
        if self.bBlock then
            self.modelManage.BPM:StoreM(self.buildActor)
            self:ModelDataToView()
            self.modelManage.ModelSelect[self.buildActor.modelType](self.buildActor, self)
            -- JL
            self.undo:AddAction(1, self.buildActor)
            if self.buildActor.holeType ~= 0 and self.buildActor.modelType == 2 then
                self.buildActor:HoleTraceModel(true)
            end

            -- 隐藏碰撞盒
            if self.buildActor.modelType == 10 and self.buildActor.Meshs:Num() > 0 then
                self.buildActor:HideCollisionBox()
            end
        else
            if self.buildActor then
                self.modelManage.ModelDelete[self.buildActor.modelType](self.buildActor, self)
                self:TreeDataOut()
            end
        end

        self.bBlock = nil
    end
end

-- 计算射线和平面的交点
function M:GetCreateLocation(start, endP)
    local Fs = self.modelManage:FindActor(self.currentFloor .. "Floor-s")
    local origin, boxExtent = Fs:GetActorBounds(false)
    local Z = origin.Z + boxExtent.Z
    local Plane = UE.UKismetMathLibrary.MakePlaneFromPointAndNormal(UE.FVector(0, 0, Z), UE.FVector(0, 0, 1))
    local bHave, T, Location = UE.UKismetMathLibrary.LinePlaneIntersection(start, endP, Plane)
    -- print(Plane, "\n", bHave, "\n", Location)
    return bHave, Location
end

-- 生成提示
function M:CreateLineTip(ModelCode, MeshLoad, showName, ModelCategory)
    if self.buildActor then
        self.modelManage.ModelCancelSelect[self.buildActor.modelType](self)
    end

    --  self.buildActor = self:GetWorld():SpawnActor
    self.ModelCategory = ModelCategory
    self.clickType = MeshLoad.CType
    self.showName = showName
    self.modelCode, self.MeshLoad = ModelCode, MeshLoad
end

------------------------点出来的模型
-- 生成墙和管道
function M:CreateLine()
    if self.Timer then
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.Timer)
    end

    local start, endP = Model.GetLineValue(self.pc)
    local hitRes = UE.FHitResult()
    self.bSplineMenuTF = true
    if self.buildActor then
        -- self.buildActor.simplePoints:Add(self.buildActor.simplePoints(self.buildActor.simplePoints:Num()))
        if self.buildActor.simplePoints[self.buildActor.simplePoints:Num()] ~= UE.FVector(0, 0, 0) then
            self.buildActor.simplePoints:Add(UE.FVector(0, 0, 0))
        end

        self:TimeMove()
    else
        local Trace = nil
        if self.modelCode == "LineWall" or self.modelCode == "DashedLine" then
            Trace = UE.ETraceTypeQuery.Floor
        else
            Trace = UE.ETraceTypeQuery.Visibility
        end

        -- 执行射线检测
        UE.UKismetSystemLibrary.LineTraceSingle(self:GetWorld(), start, endP, Trace, false, nil, 0, hitRes, true)

        if hitRes.bBlockingHit then
            local LName = self:NameCheck(self.modelCode)
            self.showName = self:ShowNameCheck(self.showName)
            self.buildActor = self.modelManage.ModelCreate[self.MeshLoad.MType](LName, self, nil, nil, self.showName,
                self.ModelCategory)
            self.buildActor.simplePoints:Clear()
            local location = DFL.integrateVector(hitRes.Location)
            self.buildActor.simplePoints:Add(location)
            self.buildActor.simplePoints:Add(location)
            if self.modelCode == "LineWall" then
                self.buildActor:SetSplineModel()
            elseif self.modelCode == "Area" then
                self.buildActor:SetSplineModel()
            elseif self.modelCode == "diyssx" then
                self.buildActor:SetSplineModel()
            elseif self.modelCode == "Passage" then
                self.buildActor:SetSplineModel()
            else
                if self.modelCode == "DashedLine" then
                    self.buildActor.SimpleSpline:SetClosedLoop(false, true)
                end

                self.buildActor:SetSplineModel()
                self.buildActor:SetSplineModelMaterial(self.modelCode)
            end

            self.modelManage:BuildPoint(self.buildActor.simplePoints)
            self:TimeMove()
        end
    end
end

function M:MovePoint()
    -- RegionInner 模式：对“已存在模型”的移动施加几何区域约束
    -- 说明：新建预览阶段（self.bBuild == true）仅依赖 IsActorInsideCurrentRegion 由 StopMove/StopMovePoint 统一校验
    if self.drawMode == M.DrawMode.RegionInner and self.buildActor and not self.bBuild
        and not self:IsActorInsideCurrentRegion(self.buildActor) then
        return
    end

    local start, endP, WorldDirection = Model.GetLineValue(self.pc)
    local hitRes = UE.FHitResult()
    local num = self.buildActor.simplePoints:Num()
    if self.modelCode == "LineWall" or self.modelCode == "Passage" then
        local ActorsToIgnore = UE.TArray(UE.AActor)
        ActorsToIgnore:Add(self.buildActor)

        -- 执行射线检测
        UE.UKismetSystemLibrary.LineTraceSingle(self:GetWorld(), start, endP, UE.ETraceTypeQuery.Floor, false,
            ActorsToIgnore, 0, hitRes, true)

        if hitRes.bBlockingHit then
            local LQ = self.buildActor.simplePoints[num - 1]
            local L = DFL.integrateVector(hitRes.Location)
            -- print(UE.UKismetSystemLibrary.GetObjectName(hitRes.HitObjectHandle.Actor))
            if self.bX then
                L = UE.FVector(L.X, LQ.Y, LQ.Z)
            elseif self.bY then
                L = UE.FVector(LQ.X, L.Y, LQ.Z)
            else
                L = self:VerticalPoint(num, self.buildActor, L)
            end

            self.buildActor.simplePoints[num] = L

            self.buildActor:SetSplineModel()
        end

        self.modelManage:BuildPoint(self.buildActor.simplePoints)
    else
        -- print(num)
        local Direction = UE.FVector
        if self.bZ or not self.modelCode == "Area" then
            Direction = UE.FVector(WorldDirection.Y, WorldDirection.X, 0)
        else
            Direction = UE.FVector(0, 0, WorldDirection.Z)
        end

        Direction:Normalize()
        local LQ = self.buildActor.simplePoints[num - 1]
        local Plane = UE.UKismetMathLibrary.MakePlaneFromPointAndNormal(LQ, Direction)
        local bHave, T, Location = UE.UKismetMathLibrary.LinePlaneIntersection(start, endP, Plane)
        Location = DFL.integrateVector(Location)
        -- print(Plane, bHave, T, Location)
        if bHave then
            if self.bX then
                Location = UE.FVector(Location.X, LQ.Y, LQ.Z)
            elseif self.bY then
                Location = UE.FVector(LQ.X, Location.Y, LQ.Z)
            elseif self.bZ then
                Location = UE.FVector(LQ.X, LQ.Y, Location.Z)
            else
                Location = self:VerticalPoint(num, self.buildActor, Location)
            end

            self.buildActor.simplePoints[num] = Location
            self.buildActor:SetSplineModel()
            self.SplineMenuLoaction = Location
        else
            Screen.Print("点击角度不对")
        end

        self.modelManage:BuildPoint(self.buildActor.simplePoints)
    end
end

function M:VerticalPoint(num, actor, location)
    for k, v in pairs(actor.simplePoints) do
        if UE.UKismetMathLibrary.Vector_Distance(v, location) < 50 then
            return v
        end
    end

    local difference = 0.005
    if num == 2 then
        local a = actor.simplePoints[1]
        local al = UE.UKismetMathLibrary.Subtract_VectorVector(a, location)
        al:Normalize()
        if math.abs(math.abs(al.X) - 1) < difference then
            location.Y = a.Y
        elseif math.abs(math.abs(al.Y) - 1) < difference then
            location.X = a.X
        end
    elseif num > 2 then
        local a = actor.simplePoints[1]
        local b = actor.simplePoints[num - 1]
        local al = UE.UKismetMathLibrary.Subtract_VectorVector(a, location)
        al:Normalize()
        if math.abs(math.abs(al.X) - 1) < difference then
            location.Y = a.Y
        elseif math.abs(math.abs(al.Y) - 1) < difference then
            location.X = a.X
        end

        local bl = UE.UKismetMathLibrary.Subtract_VectorVector(b, location)
        bl:Normalize()
        if math.abs(math.abs(bl.X) - 1) < difference then
            location.Y = b.Y
        elseif math.abs(math.abs(bl.Y) - 1) < difference then
            location.X = b.X
        end
    end

    return location
end

function M:MoveRec()
    -- RegionInner 模式：对“已存在模型”的移动施加几何区域约束
    if self.drawMode == M.DrawMode.RegionInner and self.buildActor and not self.bBuild
        and not self:IsActorInsideCurrentRegion(self.buildActor) then
        return
    end

    local start, endP, WorldDirection = Model.GetLineValue(self.pc)

    local Direction = UE.FVector(0, 0, 1)
    Direction:Normalize()
    local LQ = self.buildActor.simplePoints[self.buildActor.simplePoints:Num() - 1]
    local Plane = UE.UKismetMathLibrary.MakePlaneFromPointAndNormal(LQ, Direction)
    local bHave, T, Location = UE.UKismetMathLibrary.LinePlaneIntersection(start, endP, Plane)
    Location = DFL.integrateVector(Location)
    if bHave then
        local pa = self.buildActor.simplePoints[1]
        local pc = Location
        local pb = UE.FVector(pa.X, pc.Y, pa.Z)
        local pd = UE.FVector(pc.X, pa.Y, pa.Z)
        self.buildActor.simplePoints:Clear()
        self.buildActor.simplePoints:Add(pa)
        self.buildActor.simplePoints:Add(pb)
        self.buildActor.simplePoints:Add(pc)
        self.buildActor.simplePoints:Add(pd)
        self.buildActor:SetSplineModel()
        self.buildActor.bRec = true
    else
        Screen.Print("点击角度不对")
    end

    self.modelManage:BuildPoint(self.buildActor.simplePoints)
end

-- 停止生成墙和管道
function M:StopMovePoint()
    if self.Timer then
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.Timer)
    end

    self.bBuild = false
    if not self.bRec then
        if self.buildActor.bWait then
            self.buildActor.bWait = false
        end

        -- 点位少自动删除
        local isA = self.buildActor.simplePoints:Num() < 2
        local isB = self.buildActor.simplePoints:Num() < 3 and
            (self.modelCode == "DashedLine" or self.modelCode == "Area")
        if isA or isB then
            if self.buildActor then
                self.modelManage.ModelDelete[self.buildActor.modelType](self.buildActor, self)
                self:TreeDataOut()
            end

            return
        end

        if self.modelCode == "DashedLine" or self.modelCode == "Area" then
            if self.buildActor.simplePoints:Num() > 3 then
                self.buildActor.simplePoints:Remove(self.buildActor.simplePoints:Num())
            end
        else
            if self.buildActor.simplePoints:Num() > 2 and not self.bRec then
                self.buildActor.simplePoints:Remove(self.buildActor.simplePoints:Num())
            end
        end

        if self.modelCode == "DashedLine" then
            self.buildActor.SimpleSpline:SetClosedLoop(true, true)
            self.buildActor:SetSplineModel()
            self.buildActor:UpdateOrigin()
        end

        if self.modelCode == "LineWall" and self.buildActor.bClosed then
            self.buildActor = self:WallBuildArea(self.buildActor)
        end

        self.buildActor:SetSplineModel()
    end

    -- RegionInner 模式：禁止在当前协作区域外生成线体 / 区域模型
    if self.drawMode == M.DrawMode.RegionInner and self.buildActor and not self:IsActorInsideCurrentRegion(self.buildActor) then
        if self.ui and self.ui.UECallWeb then
            self.ui:UECallWeb("ShowMessage", {
                Type = 1,
                Text = "当前模式下只能在选中协作区域内绘制模型"
            })
        end

        self.modelManage.ModelDelete[self.buildActor.modelType](self.buildActor, self)
        self.buildActor = nil
        self.clickType = 1
        self.bRec = false
        self.bBlock = nil
        return
    end

    -- if self.buildActor.SaveModelData then
    --     self.buildActor:SaveModelData()
    -- end
    self.clickType = 1
    self.modelManage.ModelSelect[self.buildActor.modelType](self.buildActor, self)
    self.bRec = false
    self:ModelDataToView()
    self.undo:AddAction(1, self.buildActor)
end

function M:WallBuildArea(actor)
    if actor.modelType ~= 5 then
        return
    end

    local codeName = self:NameCheck("Area")
    local showName = self:ShowNameCheck("区域")
    local area = self.modelManage.ModelCreate[6](codeName, self, nil, nil, showName,
        nil)
    actor.associativeModel = codeName .. "-s"
    area.associativeModel = Model.GetActorAccurateDisplayName(actor)
    return actor
end

------------------------划出来的模型
-- 生成标注吸附动态提示点
function M:PointTip()
    local start, endP = Model.GetLineValue(self.pc)
    local hitRes = UE.FHitResult()
    self.modelManage:ClearPointTip()
    local ObjectTypes = UE.TArray(UE.EObjectTypeQuery)
    ObjectTypes:Add(UE.EObjectTypeQuery.WorldStatic)

    if self.modelManage.border then
        local l = self.modelManage.border:Trace(start, endP)
        if l then
            self.Location = l
            self.modelManage:CreatePointTip(self.Location, 1)
            return
        else
            self.modelManage:ClearBorder()
        end
    end

    -- 执行射线检测
    UE.UKismetSystemLibrary.LineTraceSingle(self:GetWorld(), start, endP, UE.ETraceTypeQuery.Model, false, nil, 0,
        hitRes, true)
    self.Location = DFL.integrateVector(hitRes.Location)

    if hitRes.HitObjectHandle.Actor then
        self.modelManage:CreatePointTip(self.Location, 1)

        self.modelManage:ClearCatch(true)
        self.modelManage:CreateCatch(hitRes.HitObjectHandle.Actor, false, self, self.Location.Z)
        if hitRes.HitObjectHandle.Actor.modelType ~= 6 then
            self.modelManage:CreateBorder(hitRes.HitObjectHandle.Actor, hitRes)
        end
    else
        local hitResP = UE.FHitResult()
        UE.UKismetSystemLibrary.SphereTraceSingle(self:GetWorld(), start, endP, 50, UE.ETraceTypeQuery.Point,
            false, nil, 0, hitResP, true)
        local component = UE.UMyBFL.GetHitComp(hitResP)
        if component then
            if component:Cast(UE.UInstancedStaticMeshComponent) then
                local t = UE.FTransform()
                component:GetInstanceTransform(hitResP.Item, t, true)
                local l = DFL.integrateVector(t.Translation)
                self.modelManage:CreatePointTip(l, 2)
                self.Location = l
            elseif component:Cast(UE.UStaticMeshComponent) then
                local l = component:K2_GetComponentLocation()
                l = DFL.integrateVector(l)
                self.modelManage:CreatePointTip(l, 2)
                self.Location = l
            end
        end
    end

    if self.Location == UE.FVector(0, 0, 0) then
        UE.UKismetSystemLibrary.LineTraceSingle(self:GetWorld(), start, endP, UE.ETraceTypeQuery.Visibility, false, nil,
            0,
            hitRes, true)
        self.Location = DFL.integrateVector(hitRes.Location)
    end
end

-- 生成两点类模型
function M:CreateTwoPoint()
    local draw = true
    self.modelManage:ClearPointTip()
    if self.buildActor then
        -- draw = not self.buildActor:Cast(LoadClass(self.modelManage.class[8]))
        if self.buildActor:Cast(LoadClass(self.modelManage.class[8])) then
            draw = false
        elseif self.buildActor:Cast(LoadClass(self.modelManage.class[9])) then
            if not self.buildActor.Widget.bVisible then
                UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.Timer)
                self.buildActor:EnterSize()
                self.Timer = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.MoveSide }, DFL.timerSec, true)
            end

            draw = false
        end
    end

    if draw then
        local LName = self:NameCheck(self.modelCode)
        self.showName = self:ShowNameCheck(self.showName)
        local T = UE.FTransform()
        T.Translation = self.Location
        self.buildActor = self.modelManage.ModelCreate[self.MeshLoad.MType](LName, self, nil, T, self.showName)
        self:TimeMove()
    end
end

-- 生成两点类模型
-- 功能：处理两点之间的移动和模型创建逻辑
function M:MoveTwoPoint()
    -- RegionInner 模式：对“已存在模型”的移动施加几何区域约束
    if self.drawMode == M.DrawMode.RegionInner and self.buildActor and not self.bBuild
        and not self:IsActorInsideCurrentRegion(self.buildActor) then
        return
    end

    -- 获取射线起点、终点和世界方向
    local startPoint, endPoint, worldDirection = Model.GetLineValue(self.pc)
    local hitResult = UE.FHitResult()
    local direction = UE.FVector(0, 0, 0)
    -- 清除点位提示
    self.modelManage:ClearPointTip()
    -- 获取平面法线，提取嵌套条件逻辑
    if self.buildActor:Cast(LoadClass(self.modelManage.class[8])) then
        if self.bZ then
            direction = math.abs(worldDirection.Z) > 0.2
                and UE.FVector(worldDirection.Y, worldDirection.X, 0)
                or UE.FVector(worldDirection.X, worldDirection.Y, 0)
        else
            direction = math.abs(worldDirection.Z) > 0.2
                and UE.FVector(0, 0, worldDirection.Z)
                or UE.FVector(worldDirection.X, worldDirection.Y, 0)
        end
    else
        direction = UE.FVector(0, 0, worldDirection.Z)
    end

    -- 归一化方向向量
    direction:Normalize()
    -- print(worldDirection, direction)
    -- 获取平面内相接的点
    -- 获取当前构建Actor的位置
    local actorLocation = self.buildActor:K2_GetActorLocation()
    -- 根据点和法线创建平面
    local plane = UE.UKismetMathLibrary.MakePlaneFromPointAndNormal(actorLocation, direction)
    -- 计算射线与平面的交点
    local hasIntersection, _, intersectionLocation = UE.UKismetMathLibrary.LinePlaneIntersection(startPoint, endPoint,
        plane)
    -- print(plane, hasIntersection, intersectionLocation)

    if hasIntersection then
        local newLocation = self.modelManage.border and self.modelManage.border:Trace(startPoint, endPoint)

        if newLocation then
            intersectionLocation = newLocation
        else
            -- 清除边界
            self.modelManage:ClearBorder()
            local traceStart, traceEnd
            if DFL.integrate(worldDirection.Z) ~= 0 then
                traceStart, traceEnd = intersectionLocation, intersectionLocation
            else
                traceStart, traceEnd = startPoint, endPoint
            end

            UE.UKismetSystemLibrary.SphereTraceSingle(self:GetWorld(), traceStart, traceEnd, 30,
                UE.ETraceTypeQuery.Model, false, nil, 0, hitResult, true)

            if hitResult.HitObjectHandle.Actor then
                local hitActor = hitResult.HitObjectHandle.Actor:Cast(UE.AStaticMeshActor)
                if hitActor then
                    if hitActor.modelType ~= 6 then
                        -- 创建边界
                        self.modelManage:CreateBorder(hitActor, hitResult)
                        intersectionLocation = hitResult.Location
                    end

                    if self.bzCatchs:Find(hitActor) <= 0 then
                        -- 添加捕捉对象
                        self.bzCatchs:Add(hitActor)
                        self.modelManage:CreateCatch(hitActor, false)
                    end

                    -- 创建点位提示
                    self.modelManage:CreatePointTip(intersectionLocation, 1)
                end
            else
                UE.UKismetSystemLibrary.SphereTraceSingle(self:GetWorld(), startPoint, endPoint, 50,
                    UE.ETraceTypeQuery.Point, false, nil, 0, hitResult, true)
                local component = UE.UMyBFL.GetHitComp(hitResult)
                if component then
                    if component:Cast(UE.UInstancedStaticMeshComponent) then
                        local t = UE.FTransform()
                        component:GetInstanceTransform(hitResult.Item, t, true)
                        intersectionLocation = DFL.integrateVector(t.Translation)
                        self.modelManage:CreatePointTip(intersectionLocation, 2)
                    elseif component:Cast(UE.UStaticMeshComponent) then
                        intersectionLocation = component:K2_GetComponentLocation()
                        intersectionLocation = DFL.integrateVector(intersectionLocation)
                        self.modelManage:CreatePointTip(intersectionLocation, 2)
                    end
                end
            end
        end

        -- 根据不同轴锁定条件更新交点位置
        if self.bX then
            intersectionLocation = UE.FVector(intersectionLocation.X, actorLocation.Y, actorLocation.Z)
        elseif self.bY then
            intersectionLocation = UE.FVector(actorLocation.X, intersectionLocation.Y, actorLocation.Z)
        elseif self.bZ then
            intersectionLocation = UE.FVector(actorLocation.X, actorLocation.Y, intersectionLocation.Z)
        end

        if self.buildActor:Cast(LoadClass(self.modelManage.class[8])) then
            self.buildActor.endVetor = intersectionLocation
            self.buildActor:SetBZ()
        else
            intersectionLocation.Z = actorLocation.Z
            self.buildActor:SetSize(intersectionLocation)
        end

        -- Screen.Print("点击角度不对")
    end
end

-- 生成两点类模型
function M:MoveSide()
    -- RegionInner 模式：对“已存在模型”的移动施加几何区域约束
    if self.drawMode == M.DrawMode.RegionInner and self.buildActor and not self.bBuild
        and not self:IsActorInsideCurrentRegion(self.buildActor) then
        return
    end

    local start, endP, WorldDirection = Model.GetLineValue(self.pc)
    local hitRes = UE.FHitResult()
    local Direction = UE.FVector
    local ObjectTypes = UE.TArray(UE.EObjectTypeQuery)
    ObjectTypes:Add(UE.EObjectTypeQuery.WorldStatic)
    self.modelManage:ClearPointTip()
    if self.bZ then
        if DFL.integrate(WorldDirection.Z) ~= 0 then
            Direction = UE.FVector(WorldDirection.Y, WorldDirection.X, 0)
        else
            Direction = UE.FVector(WorldDirection.X, WorldDirection.Y, 0)
        end
    else
        -- print(WorldDirection.Z)
        if DFL.integrate(WorldDirection.Z) ~= 0 then
            Direction = UE.FVector(0, 0, WorldDirection.Z)
        else
            Direction = UE.FVector(0, 0, 1)
        end
    end

    Direction:Normalize()
    -- print(WorldDirection, Direction)
    local LQ = self.buildActor:K2_GetActorLocation()
    local Plane = UE.UKismetMathLibrary.MakePlaneFromPointAndNormal(LQ, Direction)
    local bHave, T, Location = UE.UKismetMathLibrary.LinePlaneIntersection(start, endP, Plane)

    -- print(Plane, bHave, T, Location)
    if bHave then
        -- if DFL.integrate(WorldDirection.Z) ~= 0 then
        --     UE.UKismetSystemLibrary.SphereTraceSingleForObjects(self:GetWorld(), Location, Location, 30, ObjectTypes,
        --         false, nil, 0, hitRes, true)
        -- else
        --     UE.UKismetSystemLibrary.SphereTraceSingleForObjects(self:GetWorld(), start, endP, 20, ObjectTypes, false,
        --         nil, 0, hitRes, true)
        -- end
        -- if hitRes.HitObjectHandle.Actor then
        --     if hitRes.HitObjectHandle.Actor:Cast(UE.AStaticMeshActor) then
        --         Location = hitRes.ImpactPoint
        --         -- self.modelManage:CreatePointTip(Location, 2)
        --     end
        -- end
        -- if Direction.Z ~= 0 then
        --     Location = UE.FVector(Location.X, Location.Y, LQ.Z)
        -- elseif Direction.Y ~= 0 then
        --     Location = UE.FVector(Location.X, LQ.Y, Location.Z)
        -- else
        --     Location = UE.FVector(LQ.X, Location.Y, Location.Z)
        -- end
        self.buildActor:SetVBZ(Location)
    end
end

-- 停止生成墙和管道
function M:StopMoveTwoPoint()
    if self.Timer then
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.Timer)
    end

    self:CancelBuild()
    if self.buildActor:Cast(LoadClass(self.modelManage.class[9])) then
        if not self.buildActor.Widget.bVisible then
            self.buildActor:EnterSize()
            self:MoveSide()
        end
    end

    self.clickType = 1
    self.modelManage.ModelSelect[self.buildActor.modelType](self.buildActor, self)
    self.undo:AddAction(1, self.buildActor)
    self:ModelDataToView(true)
end

function M:CancelBuild()
    self.bBuild = false
    -- 重置绘制模式为默认模式
    self.modelManage:ClearCatch(false)
    self.bzCatchs:Clear()
    self.modelManage:ClearBorder()
end

---------------- 信息标注
function M:MessageData(jsonTable)
    if jsonTable.bCreate then
        self:ModelDataToModel(jsonTable)
        -- self.modelManage.SetData[11](self.buildActor, jsonTable)
        -- self:ModelDataToView()
    else
        local T = UE.FTransform()
        if self.buildActor then
            if self.buildActor.modelType == "Multi" then
                -- print(self.buildActor.STCActors:Num())
                local O, B = UE.UGameplayStatics.GetActorArrayBounds(self.buildActor.STCActors, true)
                T.Translation = UE.FVector(O.X, O.Y, O.Z + B.Z + 50)
            elseif self.buildActor.modelType == "Group" then
                local Actors, Childs = UE.TArray(UE.AActor), UE.TArray(UE.AActor)
                self.buildActor:GetAttachedActors(Childs, true)
                for key, value in pairs(Childs) do
                    local CChilds = UE.TArray(UE.AActor)
                    value:GetAttachedActors(CChilds, true)
                    Actors:Append(CChilds)
                end

                local O, B = UE.UGameplayStatics.GetActorArrayBounds(Actors, true)
                T.Translation = UE.FVector(O.X, O.Y, O.Z + B.Z + 50)
            else
                local O, B = self.buildActor:GetActorBounds(true)
                T.Translation = UE.FVector(O.X, O.Y, O.Z + B.Z + 50)
            end
        end

        local Name = self:NameCheck("MessageBZ")
        local showName = self:ShowNameCheck("信息标注")
        local M = self.modelManage.ModelCreate[11](Name, self, self.modelManage.class[11], T, showName)
        self.modelManage.SetData["default"](M, jsonTable)
        self.modelManage.ModelSelect[11](M, self)
        self.undo:AddAction(1, self.buildActor)
        self:ModelDataToView()
        self.ui:ModelTipHide()
    end
end

----------------------------------------- 组模型 ---------------------------
function M:GroupTogether()
    local Actors = UE.TArray(UE.AActor)
    -- local Groups = UE.TArray(UE.AActor)
    if not self.buildActor.modelType == "Multi" then
        return
    end

    for key, value in pairs(self.buildActor.STCActors) do
        local P = value:GetAttachParentActor()
        Actors:Add(P)
    end

    if Actors:Num() > 0 then
        local Childs = UE.TArray(UE.AActor)
        for key, value in pairs(Actors) do
            local ChildActors = UE.TArray(UE.AActor)
            value:GetAttachedActors(ChildActors, true)
            Childs:Append(ChildActors)
        end

        local O, B = UE.UGameplayStatics.GetActorArrayBounds(Childs, true)
        local T = UE.FTransform()
        T.Translation = O
        local P = self.modelManage:FindActor("1")
        local ParentName = self:NameCheck("Group")
        local showName = self:ShowNameCheck("组合")
        local Group = self.modelManage.ModelCreate["Group"](ParentName, showName, T)
        Group.bGroup = true
        Group:K2_AttachToActor(P, "", 1, 1, 1, true)
        self.undo:AddAction(4, Group, Actors)
        local oldParents = UE.TArray(UE.AActor)
        for key, value in pairs(Actors) do
            value:K2_AttachToActor(Group, "", 1, 1, 1, true)
        end

        local Gs = UE.TArray(UE.AActor)
        P:GetAttachedActors(Gs, true)
        for key, value in pairs(Gs) do
            local CGs = UE.TArray(UE.AActor)
            value:GetAttachedActors(CGs, true)
            if CGs:Num() == 0 then
                self.undo:DeleteGroup(value)
                self.modelManage:ActorOutMap(value)
            end
        end

        self.modelManage.ModelSelect[Group.modelType](Group, self)
        self:ModelDataToView()
    end
end

function M:GroupSplit(jsonTable)
    local Group = self.modelManage:FindActor(jsonTable.ID)
    local Childs = UE.TArray(UE.AActor)
    self.undo:AddAction(5, Group)
    Group:GetAttachedActors(Childs, true)
    local P = self.modelManage:FindActor("1")

    for key, value in pairs(Childs) do
        value:K2_AttachToActor(P, "", 1, 1, 1, true)
    end

    self.modelManage.ModelDelete["Group"](Group, self)
    self:TreeDataOut()
end

------------------------辅助操作函数

-- 名称查重
function M:NameCheck(Name, Nub)
    local I = Nub and Nub + 1 or 1
    if self.modelManage:FindActor(Name, true) then
        local i = string.find(Name, "-")
        if i then
            Name = string.sub(Name, 1, i - 1)
        end

        local N = Name .. "-" .. I
        Name = self:NameCheck(N, I)
        -- print(Name)
        return Name
    end

    return Name, I
end

-- 名称查重
function M:ShowNameCheck(ShowName, Nub)
    if not ShowName then
        return
    end

    local I = Nub and Nub + 1 or 1
    if self.modelManage.ShowNames:Find(ShowName) > 0 then
        local i = string.find(ShowName, "-")
        if i then
            ShowName = string.sub(ShowName, 1, i - 1)
        end

        local N = ShowName .. "-" .. I
        ShowName = self:ShowNameCheck(N, I)
        -- print(Name)
        return ShowName
    end

    return ShowName, I
end

--- 模型选择三级优先级逻辑（射线->球形->画布）

--- @warning 会修改UI状态和模型选择状态
function M:SelectionModel()
    --[[
        选择优先级：
        1. 直接射线命中模型
        2. 球形范围最近模型
        3. 画布下方模型
        4. 默认选择地板
    ]]

    -- UI状态初始化
    self.ui.B_Area:SetVisibility(1) -- 激活区域选择按钮

    --- @type number,number 射线起点和终点坐标
    local start, endP = Model.GetLineValue(self.pc)

    --- @type FHitResult 射线命中结果容器
    local hitRes = UE.FHitResult()

    --- @type boolean 选择状态标记
    local bNoSel = true -- true表示尚未成功选择

    -- 小工具：在 RegionInner 模式下，只允许选择当前协作区域内的模型
    -- 返回：
    --   true  - 可以正常选中
    --   false - 不允许选中（并在需要时给出提示）
    local function _IsSelectableActorInRegionInner(self, actor, bFromClick)
        -- 非 RegionInner 模式，或当前还处于锁定状态，直接放行原有逻辑
        if self.drawMode ~= M.DrawMode.RegionInner or self:IsRegionInnerLocked() then
            return true
        end

        -- 检查 Actor 是否位于任意一个协作区域内
        if not self.polygons or not next(self.polygons) then
            return false
        end

        -- 遍历所有区域，检查 Actor 是否完全位于某个区域内
        local isInsideAnyRegion = false
        for regionActor, polygon in pairs(self.polygons) do
            local ok, inside = pcall(self.modelManage.IsActorFullyInsideRegion,
                self.modelManage,
                regionActor,
                actor,
                polygon)
            if ok and inside == true then
                isInsideAnyRegion = true
                break
            end
        end

        if not isInsideAnyRegion then
            -- 如果是“鼠标直接点击”的来源，则给出一次提示
            if bFromClick and self.ui then
                self.ui:UECallWeb("ShowMessage", { Type = 2, Text = "只能选择协作区域内的模型" })
            end

            return false
        end

        return true
    end

    -- 阶段1：直接射线检测 --------------------------------------------------
    UE.UKismetSystemLibrary.LineTraceSingle(
        self:GetWorld(),
        start,
        endP,
        UE.ETraceTypeQuery.Visibility, -- 可见性检测通道
        false,                         -- 是否使用复杂碰撞
        nil,
        0,                             -- 忽略特定对象
        hitRes,
        true
    )
    self.Location = hitRes.Location -- 记录命中点坐标
    self.ui.bWebSel = false         -- 关闭网页选择标记

    -- 处理静态网格体命中
    if hitRes.HitObjectHandle.Actor then
        --- @type AStaticMeshActor
        local hitActor = hitRes.HitObjectHandle.Actor:Cast(UE.AStaticMeshActor)
        if hitActor and _IsSelectableActorInRegionInner(self, hitActor, true) then
            self.modelManage.ModelSelect[hitActor.modelType](hitActor, self)
            self:ModelDataToView(false)
            bNoSel = false -- 标记已成功选择
        end
    end

    -- 阶段2：球形范围检测 --------------------------------------------------
    if bNoSel and hitRes.Location then
        --- @type TArray<FHitResult> 多重命中结果容器
        local HitRess = UE.TArray(UE.FHitResult())

        UE.UKismetSystemLibrary.SphereTraceMulti(
            self:GetWorld(),
            hitRes.Location,          -- 球心起点
            hitRes.Location,          -- 球心终点
            100,                      -- 球体半径
            UE.ETraceTypeQuery.Model, -- 模型检测通道
            false,
            nil,
            0,
            HitRess,
            true
        )

        if HitRess:Num() > 0 then
            --- @type table 候选模型容器 {距离, 模型对象}
            local candidates = {}

            -- 收集有效候选模型
            for i = 1, HitRess:Num() do
                local value = HitRess[i]
                if value.HitObjectHandle.Actor and _IsSelectableActorInRegionInner(self, value.HitObjectHandle.Actor, false) then
                    --- @type number 碰撞点与目标点的距离
                    local distance = UE.UKismetMathLibrary.Vector_Distance(value.ImpactPoint, hitRes.Location)
                    table.insert(candidates, {
                        d = distance,
                        a = value.HitObjectHandle.Actor
                    })
                end
            end

            -- 按距离升序排序
            table.sort(candidates, function(a, b)
                return a.d < b.d
            end)

            -- 选择最近模型（注意：可能 HitRess 有命中，但没有任何可选模型）
            if #candidates > 0 then
                local actor = candidates[1].a
                local key = actor and actor.modelType
                local fn = key and self.modelManage and self.modelManage.ModelSelect and
                    self.modelManage.ModelSelect[key]
                if fn then
                    fn(actor, self)
                    self:ModelDataToView(false)
                    bNoSel = false
                end
            end
        end
    end

    -- 阶段3：画布下方模型检测 -----------------------------------------------
    if bNoSel then
        UE.UKismetSystemLibrary.LineTraceSingle(
            self:GetWorld(),
            start,
            endP,
            UE.ETraceTypeQuery.Model, -- 模型检测通道
            false,
            nil,
            0,
            hitRes,
            true
        )
        self.Location = hitRes.Location

        if hitRes.HitObjectHandle.Actor and _IsSelectableActorInRegionInner(self, hitRes.HitObjectHandle.Actor, false) then
            self.modelManage.ModelSelect[hitRes.HitObjectHandle.Actor.modelType](hitRes.HitObjectHandle.Actor, self)
            self:ModelDataToView(false)
            bNoSel = false
        end
    end

    -- 默认选择：地板模型 ---------------------------------------------------
    if bNoSel then
        self.modelManage.ModelSelect[1](self.buildActor, self)
        self:FloorDataToView()
    end
end

-- 检测坐标轴 (坐标轴触发)
function M:TrackGizmo()
    if self.curReg then
        self.undo:AddAction(2, self.curReg)
    end

    if self.buildActor then
        if self.buildActor.modelType == "Multi" then
            self.undo:AddAction(7, self.buildActor)
        else
            self.undo:AddAction(2, self.buildActor)
        end
    end
end

---------------------------------------- 捕捉点位 ---------------------------
function M:IsCatch(bool)
    if self.bCatchPoint then
        return true
    end

    self.bCatch = bool
    -- print(bool)
    if self.buildActor then
        if self.bBuild then
            self.BPI:StopBuildModel()
        else
            self.modelManage.ModelSelect[self.buildActor.modelType](self.buildActor, self)
        end
    end

    if self.modelManage.cad then
        self.modelManage.cad:IsShowPoints(self.bCatch)
    end
end

-- 检测捕捉点
function M:TrackCatch()
    if self.bCatchPoint then
        return
    end

    local start, endP = Model.GetLineValue(self.pc)
    local hitRes = UE.FHitResult()
    -- self.bCatchPoint = false
    -- 执行射线检测
    UE.UKismetSystemLibrary.LineTraceSingle(self:GetWorld(), start, endP, UE.ETraceTypeQuery.Point, false, nil, 0,
        hitRes, true)
    if hitRes.bBlockingHit then
        if hitRes.HitObjectHandle.Actor:Cast(LoadClass('/Game/SandBox/Blueprints/AuxiliaryModel/BP_Catch.BP_Catch_C')) then
            self.bCatchPoint = true
            local component = UE.UMyBFL.GetHitComp(hitRes)
            component:SetMaterial(0, LoadObject('/Game/SandBox/Materials/M_Point2_Inst.M_Point2_Inst'))
            self.CatchComponent = component
            self.CatchLocation = component:K2_GetComponentLocation()
            self:CatchTrackSphere()
            self.CatchTimer = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.CatchMove }, DFL.timerSec, true)
            self.undo:AddAction(2, self.buildActor)
            self.ui:ShowModelTip("点位捕捉", "靠近附近黄点快速吸附，右键放置模型")
        end
    end
end

function M:CatchMove()
    -- RegionInner 模式：检查模型是否在 RegionInnerActors 映射中
    if self.drawMode == M.DrawMode.RegionInner and self.buildActor and not self:_IsActorInRegionInner(self.buildActor) then
        return
    end

    local mouse2D = UE.UWidgetLayoutLibrary.GetMousePositionOnViewport(self:GetWorld())
    if self.mouse2D ~= mouse2D then
        self.mouse2D = mouse2D
        local start, endP = Model.GetLineValue(self.pc)
        local hitRes = UE.FHitResult()
        -- 如果有阻挡，将位置设置为射线命中的位置，否则为射线发射的位置
        UE.UKismetSystemLibrary.LineTraceSingle(self:GetWorld(), start, endP, UE.ETraceTypeQuery.Floor, false, nil, 0,
            hitRes, true)
        if hitRes.bBlockingHit then
            local RelativeLoction = UE.UKismetMathLibrary.Subtract_VectorVector(hitRes.Location, self.CatchLocation)
            self.modelManage.catch:K2_AddActorWorldOffset(RelativeLoction, false, nil, false)
            self.buildActor:K2_AddActorWorldOffset(RelativeLoction, false, nil, false)
            self.modelManage.gizmo:K2_AddActorWorldOffset(RelativeLoction, false, nil, false)
            self.CatchLocation = hitRes.Location
            self:CatchTrackSphere()
        end
    end
end

-- 捕捉检测
function M:CatchTrackSphere()
    self.modelManage:ClearCatch(false)
    local ignoreActors = UE.TArray(UE.AActor)
    if self.buildActor then
        ignoreActors:Add(self.buildActor)
    end

    local HitRess = UE.TArray(UE.FHitResult())
    UE.UKismetSystemLibrary.SphereTraceMulti(self:GetWorld(), self.CatchLocation, self.CatchLocation, 1000,
        UE.ETraceTypeQuery.Model, false, ignoreActors, 0, HitRess, true)
    if HitRess:Num() > 0 then
        local t = {}
        for key, value in pairs(HitRess) do
            if value.HitObjectHandle.Actor then
                local d = UE.UKismetMathLibrary.Vector_Distance(value.ImpactPoint, self.CatchLocation)
                table.insert(t, {
                    d = d,
                    o = value.HitObjectHandle.Actor
                })
            end
        end

        table.sort(t, function(a, b)
            return a.d < b.d
        end)
        for key, value in pairs(t) do
            if key <= 10 then
                self.modelManage:CreateCatch(value.o, false)
            end
        end
    end

    self:CatchTrackSpherePoint()
end

-- 捕捉面检测点位
function M:CatchTrackSpherePoint()
    -- 在 CatchLocation 周围做球形检测，找到最近的“点组件”，把 catch/buildActor/gizmo 整体吸附过去
    local ignoreActors = UE.TArray(UE.AActor)
    -- 忽略自身的 catch Actor，避免球形检测命中自己
    ignoreActors:Add(self.modelManage.catch)
    local HitRess = UE.TArray(UE.FHitResult())
    -- SphereTraceMulti：起点=终点时等价于“在该点做一个半径 200 的球形查询”，返回多个命中结果
    -- TraceTypeQuery.Point：使用工程里定义的 Point 通道/类型来做检测
    UE.UKismetSystemLibrary.SphereTraceMulti(self:GetWorld(), self.CatchLocation, self.CatchLocation, 200,
        UE.ETraceTypeQuery.Point, false, ignoreActors, 0, HitRess, true)
    if HitRess:Num() > 0 then
        -- 收集命中的有效组件，并计算它们到当前 CatchLocation 的距离
        local t = {}
        for key, value in pairs(HitRess) do
            -- 只处理能被 GetHitComp 解析出的目标组件（工程自定义的命中组件提取逻辑）
            local component = UE.UMyBFL.GetHitComp(value)
            if component then
                -- print(value.ImpactPoint, self.CatchLocation)
                -- 命中点到当前 CatchLocation 的距离
                local d = UE.UKismetMathLibrary.Vector_Distance(value.ImpactPoint, self.CatchLocation)
                table.insert(t, {
                    d = d,
                    o = component
                })
            end
        end

        -- 按距离从近到远排序，取最近的一个作为吸附目标
        table.sort(t, function(a, b)
            return a.d < b.d
        end)
        -- 最近目标组件的世界坐标
        local l = t[1].o:K2_GetComponentLocation()
        -- 需要平移的位移量 = 目标点 - 当前 CatchLocation
        local RelativeLoction = UE.UKismetMathLibrary.Subtract_VectorVector(l, self.CatchLocation)
        -- 将 catch / buildActor / gizmo 同步做世界偏移，保持三者相对关系不变
        self.modelManage.catch:K2_AddActorWorldOffset(RelativeLoction, false, nil, false)
        self.buildActor:K2_AddActorWorldOffset(RelativeLoction, false, nil, false)
        self.modelManage.gizmo:K2_AddActorWorldOffset(RelativeLoction, false, nil, false)
        -- 更新当前捕捉位置
        self.CatchLocation = l
    end
end

function M:CatchStop()
    if self.CatchTimer then
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.CatchTimer)
    end

    self.modelManage:ClearCatch(false)
    self.CatchComponent:SetMaterial(0, nil)
    self.bCatchPoint = false
    self.ui:ShowModelTip("", "点击黄点进入点位捕捉模式")
end

-- 移除提示
function M:RemoveTip()
    self.ui.B_Tip:SetVisibility(1)
    self.modelManage:ClearPointTip()
    if self.Timer then
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.Timer)
    end
end

-- 点的选择
function M:SplinePointSelect()
    local start, endP = Model.GetLineValue(self.pc)
    local hitRes = UE.FHitResult()
    local Fs = self.modelManage:FindActor("1Floor-s")
    local ignoreActors = UE.TArray(UE.AActor)
    ignoreActors:Add(Fs)

    -- 执行射线检测
    UE.UKismetSystemLibrary.LineTraceSingle(self:GetWorld(), start, endP, UE.ETraceTypeQuery.Visibility, false,
        ignoreActors, 0, hitRes, true)

    if hitRes.bBlockingHit then
        -- print(Model.GetActorAccurateDisplayName(hitRes.HitObjectHandle.Actor))
        if hitRes.HitObjectHandle.Actor:Cast(LoadClass(Class.point)) then
            if self.drawMode == M.DrawMode.RegionArea then
                self.curReg.currentPoint = hitRes.HitObjectHandle.Actor.KeyID
            else
                self.buildActor.currentPoint = hitRes.HitObjectHandle.Actor.KeyID
            end

            self.modelManage:CreateGizmo(hitRes.HitObjectHandle.Actor)
            if self.drawMode ~= M.DrawMode.RegionArea then
                self:ModelDataToView(true)
            end
        end
    end
end

----------------------------- 数据的交互 -----------------------------
-- 模型的数据
function M:ModelDataToView(bnottree)
    -- print(self.buildActor.modelType)
    local FH = 0
    if self.buildActor.modelType == 6 then
        local F = self.modelManage:FindActor(self.currentFloor .. "Floor-s")
        FH = F:K2_GetActorLocation().Z
    end

    -- 表修改 修改取值逻辑  2024-11-21
    local DTV = {}
    if self.modelManage.GetData[self.buildActor.modelType] then
        DTV = self.modelManage.GetData[self.buildActor.modelType](self.buildActor, self.CurrentCH, FH)
    else
        DTV = self.modelManage.GetData["default"](self.buildActor, self.CurrentCH, FH)
    end

    if self.buildActor.modelType ~= 10 and self.buildActor.modelType ~= 12 then
        local jsonTable = {
            Model = self.buildActor.modelType,
            Material = DFL.modelMaterial[self.buildActor.modelCode]
        }
        self.ui:ShowBoard(jsonTable)
    else
        local jsonTable = {
            Model = DTV.bBasic and 2 or 3
        }
        self.ui:ShowBoard(jsonTable)
    end

    self.ui:SetModelData(DTV)
    if not bnottree then
        self:TreeDataOut()
        self:ShowSel(self.buildActor)
        self:UpdateAnimeList()
    end
end

function M:ModelDataToModel(table)
    -- JL
    self.undo:AddAction(2, self.buildActor)
    local showName = self.buildActor.showName
    if not showName then
        showName = self.buildActor:GetAttachParentActor().showName
    end

    local L
    if self.modelManage.SetData[self.buildActor.modelType] then
        L = self.modelManage.SetData[self.buildActor.modelType](self.buildActor, table)
    else
        L = self.modelManage.SetData["default"](self.buildActor, table)
    end

    if table.showname ~= showName and table.showname then
        table.showname = self:ShowNameCheck(table.showname)
        self.modelManage:ActorShowNameChange(nil, table.showname, showName)
        self:ModelDataToView()
    end

    -- RegionInner 下：模型数据改动后必须用“完全落入”判定，不能用中心点宽松判定
    -- RegionInner 下：传入区域信息用于严格边界检测（"完全落入"判定）
    if self.drawMode == M.DrawMode.RegionInner and self.regionMode then
        self.undo:AddNewSize(self.buildActor)
    else
        self.undo:AddNewSize(self.buildActor)
    end

    return L
end

-- ===========================================================================
-- RegionArea（协作区域）专属逻辑
--
-- 状态字段（Initialize 中初始化）
--   self.drawMode        — 当前绘制模式（Default / RegionArea）
--   self.curReg          — 当前选中 / 正在绘制的协作区域 Actor
--   self.regionMode      — 是否处于区域视图
--
-- ReceiveTick 中的专属 Tick 块（见上方 ReceiveTick）：
--   条件：self.curReg 有效 且 not self.bBuild
--   功能：NubPoints 缩放 + gizmo 拖拽追踪（松手后回写 curReg）
--
-- 绘制流程
--   CreateRegionArea → TimeMoveRegionArea → MoveRegionAreaPoint
--   左键：HandleRegionAreaLeftClick（追加点 / 选中已有 RegionArea / 新建）
--   右键：HandleRegionAreaRightClick（结束绘制，点数不足自动删除）
--
-- 区域视图
--   EnterRegion / ExitRegion / GetActorsInRegion
--
-- BP_ModelManage 侧对应区段
--   RegSel / CreateRegion / DestroyRegion（见 BP_ModelManage.lua 末尾 RegionArea 区段）
-- ===========================================================================

------- 协作区域功能模块 ---------------------

------- 一、绘制模式切换 ---------------------

--- 切换绘制模式
--- @param mode string 模式名称（如"RegionArea"等）
--- 切换绘制模式时，清理当前构建的模型和协作区域，并清空撤销栈
function M:SwitchDrawMode(mode)
    self.drawMode = mode or self.drawMode
    self.modelManage.drawMode = self.drawMode

    -- RegionInner 模式：搜集区域内的静态模型和它们的父对象
    if mode == M.DrawMode.RegionInner then
        if self.bLoadPlan then
            coroutine.resume(coroutine.create(function()
                UE.UKismetSystemLibrary.Delay(self, 0.5)
                if self.drawMode == M.DrawMode.RegionInner then
                    self:SwitchDrawMode()
                end
            end), self)
            return
        end
        self:LoadRegionData(self.ui.contentValue)
        self.modelManage:GetAllRegionInnerActors()
    end

    self.regionMode = false
    self.polygons = nil


    if self.buildActor then
        self.modelManage:ModelClear(self)
    end

    if self.curReg then
        self.modelManage:RegionClear(self)
    end

    self.undo:ClearStack()
end

--- 区域内绘制模式是否被锁定
--- 仅当处于 RegionInner 模式，且尚未成功进入任何协作区域视图时返回 true
--- 用于在 BP_Input 中统一屏蔽除“双击选择协作区域”以外的所有交互
function M:IsRegionInnerLocked()
    if self.drawMode ~= M.DrawMode.RegionInner then
        return false
    end

    -- 未进入区域视图或没有有效的当前区域缓存，视为“尚未选中区域”
    if not self.regionMode then
        return true
    end

    -- 要求当前区域 Actor / 多边形均有效才视为“已选中区域”
    if not self.polygons or not next(self.polygons) then
        return true
    end

    return false
end

------- 二、绘制操作 ---------------------

--- 协作区域模式下的左键点击处理（选中协作区域 / 开始绘制）
--- 处理左键点击事件：如果正在绘制，则添加新的确认点；如果未开始绘制，则初始化新的协作区域并开始绘制
function M:CreateRegionArea()
    if self.Timer then
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.Timer)
    end

    -- 获取鼠标位置的世界坐标
    local start, endP = Model.GetLineValue(self.pc)
    local hitRes = UE.FHitResult()

    UE.UKismetSystemLibrary.LineTraceSingle(
        self:GetWorld(),
        start,
        endP,
        UE.ETraceTypeQuery.Floor,
        false,
        nil,
        0,
        hitRes,
        true
    )

    if hitRes.bBlockingHit then
        -- 鼠标原始落点（未做约束/吸附），用于“是否落在其它区域内部”的硬校验
        local rawLocation = DFL.integrateVector(hitRes.Location)

        if self.curReg then
            -- 简化规则：若鼠标点严格落在其它协作区域内部，则禁止放置（边界允许吸附）
            for _, otherReg in pairs(self.modelManage.Regions) do
                if otherReg ~= self.curReg then
                    local pts = otherReg.simplePoints
                    if pts and pts:Num() >= 3 then
                        -- 允许靠近边界吸附：若可吸附则不算“落在内部”
                        local snapPt = RegionAreaAlgo.GetSnapEdgePoint(rawLocation, pts,
                            RegionAreaAlgo.REGION_SNAP_THRESHOLD)
                        if not snapPt and RegionAreaAlgo.IsPointStrictlyInsidePolygon(rawLocation, pts, 1e-3) then
                            self.ui:UECallWeb("ShowMessage", {
                                Type = 2,
                                Text = "当前无法放置点位"
                            })
                            self:TimeMoveRegionArea()
                            return
                        end
                    end
                end
            end

            if UE.UKismetMathLibrary.Vector_Distance(
                    self.curReg.simplePoints[self.curReg.simplePoints:Num()],
                    self.curReg.simplePoints[self.curReg.simplePoints:Num() - 1]) < 5 then
                self:TimeMoveRegionArea()
                return
            end

            -- 确认点检测：检测当前区域（包含预览点）是否与其他区域重叠
            local num = self.curReg.simplePoints:Num()
            local currentPoint = self.curReg.simplePoints[num]
            if currentPoint and num >= 2 then
                -- 构建当前区域的多边形（排除临时点0,0,0）
                local tempPoints = UE.TArray(UE.FVector)
                local zeroVec = UE.FVector(0, 0, 0)
                for i = 1, num do
                    local pt = self.curReg.simplePoints[i]
                    -- 排除临时点（0,0,0）
                    if pt and (pt.X ~= 0 or pt.Y ~= 0 or pt.Z ~= 0) then
                        tempPoints:Add(pt)
                    end
                end

                -- 检测是否与其他区域重叠（至少3个点才形成有效多边形）
                if tempPoints:Num() >= 3 then
                    for _, otherReg in pairs(self.modelManage.Regions) do
                        if otherReg ~= self.curReg then
                            local otherPts = otherReg.simplePoints
                            if otherPts and otherPts:Num() >= 3 then
                                if RegionAreaAlgo.DoPolygonsOverlap(tempPoints, otherPts) then
                                    self.ui:UECallWeb("ShowMessage", {
                                        Type = 2,
                                        Text = "无法生成，区域重叠"
                                    })
                                    self:TimeMoveRegionArea()
                                    return
                                end
                            end
                        end
                    end
                end
            end

            if self.curReg.simplePoints[self.curReg.simplePoints:Num()] ~= UE.FVector(0, 0, 0) then
                self.curReg.simplePoints:Add(UE.FVector(0, 0, 0))
            end

            self:TimeMoveRegionArea()
        else
            -- 初始化首点：用两个相同点起步，后续由 MovePoint 实时拖拽第二个点
            local location = rawLocation

            -- 检测第一点是否在其他区域内
            for _, otherReg in pairs(self.modelManage.Regions) do
                local pts = otherReg.simplePoints
                if pts and pts:Num() >= 3 then
                    -- 允许靠近边界吸附：若可吸附则不算“落在内部”
                    local snapPt = RegionAreaAlgo.GetSnapEdgePoint(location, pts, RegionAreaAlgo.REGION_SNAP_THRESHOLD)
                    if not snapPt and RegionAreaAlgo.IsPointStrictlyInsidePolygon(location, pts, 1e-3) then
                        self.ui:UECallWeb("ShowMessage", {
                            Type = 2,
                            Text = "当前无法放置点位"
                        })
                        return
                    end
                end
            end

            self.bBuild = true
            local modelName = self:RegionNameCheck("RegionArea")
            local showName = self:RegionShowNameCheck("协作区域")
            self.curReg = self.modelManage:CreateRegion(modelName, self, showName)

            -- 模型构建完：初始化点位并进入绘制（专用逻辑，不依赖 CreateLine/StopMovePoint）
            -- 对第一个点也应用边界吸附（prevPoint 为 nil，只进行区域内部检测和边界吸附检测）
            local finalLocation = self:CheckRegionConstraint(nil, location)

            self.curReg.simplePoints:Clear()
            self.curReg.simplePoints:Add(finalLocation)
            self.curReg.simplePoints:Add(finalLocation)

            -- 初始化颜色为绿色（合法状态）
            self.curReg.lineColor = UE.FLinearColor(0.1, 0.6, 0.07, 1)
            self.curReg:SetColor()
            self.curReg:SetSplineModel()

            -- 初始化合法点缓存（以起点作为首次合法参考）
            self.lastValidRegionPoint = finalLocation

            self.modelManage:BuildPoint(self.curReg.simplePoints)

            self:TimeMoveRegionArea()
        end
    end
end

--- 启动协作区域的定时移动更新
--- 清除已有定时器并设置新的定时器，用于实时更新协作区域的绘制点位
function M:TimeMoveRegionArea()
    if self.Timer then
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.Timer)
    end

    self.Timer = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.MoveRegionAreaPoint }, DFL.timerSec, true)
end

--- 协作区域专用的点位拖拽更新（不依赖 self.buildActor / self.modelCode）
--- 定时器回调函数，实时更新当前绘制点的位置，应用区域约束和轴约束，并更新模型显示
function M:MoveRegionAreaPoint()
    local start, endP = Model.GetLineValue(self.pc)
    local hitRes = UE.FHitResult()
    UE.UKismetSystemLibrary.LineTraceSingle(
        self:GetWorld(),
        start,
        endP,
        UE.ETraceTypeQuery.Floor,
        false,
        nil,
        0,
        hitRes,
        true
    )

    if hitRes.bBlockingHit and self.curReg then
        local num           = self.curReg.simplePoints:Num()
        local location      = DFL.integrateVector(hitRes.Location)

        -- 取上一个已确认点 / 第一个点，仅用于简单的对齐和轴约束（不再做区域优化算法）
        local prevPoint     = (num >= 2) and self.curReg.simplePoints[num - 1] or nil
        local firstPoint    = (num >= 3) and self.curReg.simplePoints[1] or nil

        -- 移动点位时不再做区域约束（不阻止移动），直接使用当前射线落点为基础
        local finalLocation = location

        -- 自动对齐：当与上一个点的 X 或 Y 坐标差值小于 20 时，自动对齐到上一个点的对应轴
        if prevPoint then
            if math.abs(prevPoint.X - finalLocation.X) < 20 then
                finalLocation = UE.FVector(prevPoint.X, finalLocation.Y, finalLocation.Z)
            elseif math.abs(prevPoint.Y - finalLocation.Y) < 20 then
                finalLocation = UE.FVector(finalLocation.X, prevPoint.Y, finalLocation.Z)
            end
        end

        -- 自动对齐：当点数 >= 3 时，检查与第一个点的对齐（用于闭合区域）
        if firstPoint then
            if math.abs(firstPoint.X - finalLocation.X) < 20 then
                finalLocation = UE.FVector(firstPoint.X, finalLocation.Y, finalLocation.Z)
            elseif math.abs(firstPoint.Y - finalLocation.Y) < 20 then
                finalLocation = UE.FVector(finalLocation.X, firstPoint.Y, finalLocation.Z)
            end
        end

        -- 轴约束：根据 bX、bY 标志进行强制约束（RegionArea 模式不支持 Z 轴约束）
        if prevPoint then
            if self.bX then
                finalLocation = UE.FVector(finalLocation.X, prevPoint.Y, prevPoint.Z)
            elseif self.bY then
                finalLocation = UE.FVector(prevPoint.X, finalLocation.Y, prevPoint.Z)
            end
        end

        ----------------------------------------------------------------------
        -- 边界吸附（移动态）：
        --   只做“吸附到其它区域边界”，不做“禁止进入”的强约束
        --   逻辑与 CheckRegionConstraint 中第②步保持一致，但不改 lastValidRegionPoint
        ----------------------------------------------------------------------
        do
            local bestSnapPt     = nil
            local bestSnapDistSq = math.huge

            for _, otherReg in pairs(self.modelManage.Regions) do
                if otherReg ~= self.curReg then
                    local pts = otherReg.simplePoints
                    if pts and pts:Num() >= 3 then
                        local snapPt = RegionAreaAlgo.GetSnapEdgePoint(
                            finalLocation,
                            pts,
                            RegionAreaAlgo.REGION_SNAP_THRESHOLD
                        )
                        if snapPt then
                            local dx = snapPt.X - finalLocation.X
                            local dy = snapPt.Y - finalLocation.Y
                            local distSq = dx * dx + dy * dy
                            if distSq < bestSnapDistSq then
                                bestSnapDistSq = distSq
                                bestSnapPt = snapPt
                            end
                        end
                    end
                end
            end

            if bestSnapPt then
                finalLocation = bestSnapPt
            end
        end

        ----------------------------------------------------------------------
        -- 移动时的重叠检测：只用于“高亮提示”，不再阻止点位移动
        -- 要求：
        --   1）当只有 2 个点时，也要做检测（线段 vs 其它区域）
        --   2）发生重叠时，只高亮当前正在绘制的区域（self.curReg）
        ----------------------------------------------------------------------
        local hasOverlap = false

        if num >= 2 then
            -- 构建当前区域的临时点集（已确认点 + 当前预览点，排除 0,0,0 的临时点）
            local tempPoints = UE.TArray(UE.FVector)
            local zeroVec = UE.FVector(0, 0, 0)

            for i = 1, num - 1 do
                local pt = self.curReg.simplePoints[i]
                if pt and (pt.X ~= 0 or pt.Y ~= 0 or pt.Z ~= 0) then
                    tempPoints:Add(pt)
                end
            end

            if finalLocation and (finalLocation.X ~= 0 or finalLocation.Y ~= 0 or finalLocation.Z ~= 0) then
                tempPoints:Add(finalLocation)
            end

            local count = tempPoints:Num()

            -- 情况一：只有一条边（2 个点），做“线段 vs 其它区域多边形”的检测
            if count == 2 then
                local p1 = tempPoints[1]
                local p2 = tempPoints[2]

                for _, otherReg in pairs(self.modelManage.Regions) do
                    if otherReg ~= self.curReg then
                        local otherPts = otherReg.simplePoints
                        if otherPts and otherPts:Num() >= 3 then
                            -- ① 线段与其它区域边界是否存在交点（排除仅在端点“贴边”的情况）
                            local crossPt, crossT = RegionAreaAlgo.GetEdgeCrossPoint(p1, p2, otherPts)
                            if crossPt then
                                -- 只要交点出现在线段内部 (0,1) 范围内，则视为真正“穿入”其它区域
                                if crossT > 1e-4 and crossT < 1 - 1e-4 then
                                    hasOverlap = true
                                    break
                                end
                            end

                            -- ② 线段终点是否严格落在其它区域内部（兜底）
                            if RegionAreaAlgo.IsPointStrictlyInsidePolygon(p2, otherPts, 1e-3) then
                                hasOverlap = true
                                break
                            end
                        end
                    end
                end

                -- 情况二：3 个及以上点，按多边形重叠逻辑检测
            elseif count >= 3 then
                for _, otherReg in pairs(self.modelManage.Regions) do
                    if otherReg ~= self.curReg then
                        local otherPts = otherReg.simplePoints
                        if otherPts and otherPts:Num() >= 3 then
                            if RegionAreaAlgo.DoPolygonsOverlap(tempPoints, otherPts) then
                                hasOverlap = true
                                break
                            end
                        end
                    end
                end
            end
        end

        -- 只根据重叠情况调整当前绘制区域的颜色：
        --   有重叠：当前区域 → 红色
        --   无重叠：当前区域 → 绿色
        local redColor   = UE.FLinearColor(1, 0, 0, 1)
        local greenColor = UE.FLinearColor(0.1, 0.6, 0.07, 1)

        if hasOverlap then
            self.curReg.lineColor = redColor
        else
            self.curReg.lineColor = greenColor
        end

        self.curReg:SetColor()

        -- 直接把当前点更新到最终位置（不再回退 lastValidRegionPoint）
        self.curReg.simplePoints[num] = finalLocation
        self.curReg:SetSplineModel()
        self.modelManage:BuildPoint(self.curReg.simplePoints)
    end
end

------- 三、区域约束检测 ---------------------

--- 检测当前点（及从上一确认点到当前点的边）相对于所有其他协作区域的约束，返回修正后的坐标。
--- 三轮遍历策略（保证跨多个区域时总选全局最近穿越点）：
---   轮①  遍历所有区域，收集绘制边与各区域边界的穿越点，取 t 最小（最靠近 prevPoint）的一个
---         → 若存在，夹紧到该点并返回（同时覆盖"线段进入区域内部"的情况）
---   轮②  遍历所有区域，检测 location 是否在区域内部
---         → 若在，回退到 lastValidRegionPoint（兜底，prevPoint 为 nil 或极端情形）
---   轮③  遍历所有区域，检测 location 是否在吸附范围内
---         → 若在，吸附到最近边界点
---   完全合法 → 更新合法点缓存，返回原坐标
--- @param prevPoint UE.FVector|nil 上一个已确认点（nil 时跳过边穿越检测）
--- @param location  UE.FVector     当前鼠标世界坐标（已取整）
--- @return UE.FVector 修正后的最终坐标
function M:CheckRegionConstraint(prevPoint, location)
    -- #region agent log
    do
        local logFile = io and io.open and io.open("d:\\UEPJ\\UE5.1\\huanying\\Content\\Script\\.cursor\\debug.log", "a")
        if logFile then
            local hasPrev = prevPoint ~= nil
            local lp = self.lastValidRegionPoint
            local lpX, lpY = 0, 0
            if lp then
                lpX, lpY = lp.X, lp.Y
            end

            logFile:write(string.format(
                '{"timestamp":%d,"location":"BP_Control.lua:2300","message":"CheckRegionConstraint entry","data":{"hasPrev":%s,"location":{"x":%.3f,"y":%.3f},"lastValid":{"x":%.3f,"y":%.3f}},"runId":"run2","hypothesisId":"D"}\n',
                os.time() * 1000,
                tostring(hasPrev),
                location and location.X or 0,
                location and location.Y or 0,
                lpX, lpY
            ))
            logFile:close()
        end
    end

    -- #endregion

    -- ① 全区域边穿越检测：收集所有穿越点，取全局最近（t 最小）
    --    这样无论有多少个区域，都能精确夹紧到离 prevPoint 最近的那条边界
    --    仅当 bTrackRegionEdge 为 true 时执行
    if prevPoint and self.bTrackRegionEdge then
        local globalBestT   = math.huge
        local globalCrossPt = nil
        for _, otherReg in pairs(self.modelManage.Regions) do
            if otherReg ~= self.curReg then
                local pts = otherReg.simplePoints
                if pts and pts:Num() >= 3 then
                    local crossPt, crossT = RegionAreaAlgo.GetEdgeCrossPoint(prevPoint, location, pts)
                    if crossPt and crossT < globalBestT then
                        globalBestT   = crossT
                        globalCrossPt = crossPt
                    end
                end
            end
        end

        if globalCrossPt then
            -- #region agent log
            do
                local logFile = io and io.open and
                    io.open("d:\\UEPJ\\UE5.1\\huanying\\Content\\Script\\.cursor\\debug.log", "a")
                if logFile then
                    logFile:write(string.format(
                        '{"timestamp":%d,"location":"BP_Control.lua:2318","message":"CheckRegionConstraint crossReturn","data":{"cross":{"x":%.3f,"y":%.3f},"t":%.6f},"runId":"run2","hypothesisId":"D"}\n',
                        os.time() * 1000,
                        globalCrossPt.X, globalCrossPt.Y,
                        globalBestT
                    ))
                    logFile:close()
                end
            end

            -- #endregion
            -- 交点在边界上，属于合法位置，更新缓存
            self.lastValidRegionPoint = globalCrossPt
            return globalCrossPt
        end
    end

    -- ② location 是否在某个区域边界的吸附范围内（优先于“内部禁止”）
    --    这样即便鼠标点略微进入其它区域，只要靠近边界，也会被吸附到边界上（边界允许放置）
    local bestSnapPt = nil
    local bestSnapDistSq = math.huge
    for _, otherReg in pairs(self.modelManage.Regions) do
        if otherReg ~= self.curReg then
            local pts = otherReg.simplePoints
            if pts and pts:Num() >= 3 then
                local snapPt = RegionAreaAlgo.GetSnapEdgePoint(location, pts, RegionAreaAlgo.REGION_SNAP_THRESHOLD)
                if snapPt then
                    local dx = snapPt.X - location.X
                    local dy = snapPt.Y - location.Y
                    local distSq = dx * dx + dy * dy
                    if distSq < bestSnapDistSq then
                        bestSnapDistSq = distSq
                        bestSnapPt = snapPt
                    end
                end
            end
        end
    end

    if bestSnapPt then
        self.lastValidRegionPoint = bestSnapPt
        return bestSnapPt
    end

    -- ③ location 是否落入某个区域严格内部（prevPoint 为 nil 或线段恰好未穿越边界的极端情况）
    --    注意：使用严格内部，边界点不算“内部”，避免边界放置被误判为非法
    for _, otherReg in pairs(self.modelManage.Regions) do
        if otherReg ~= self.curReg then
            local pts = otherReg.simplePoints
            if pts and pts:Num() >= 3 then
                if RegionAreaAlgo.IsPointStrictlyInsidePolygon(location, pts, 1e-3) then
                    return self.lastValidRegionPoint or location
                end
            end
        end
    end

    -- 完全合法 → 更新缓存并返回原坐标
    self.lastValidRegionPoint = location
    return location
end

--- 控制是否检测 Region 边缘碰撞
--- @param bTrack boolean 是否开启边缘检测
function M:TrackRegionEdge(bTrack)
    self.bTrackRegionEdge = bTrack
end

--- 开启预览第一个点的状态
function M:StartPreviewFirstPoint()
    self.bPreviewFirstPoint = true
    self.previewFirstPointLocation = nil
    -- 清除之前的预览点
    if self.modelManage and self.modelManage.ClearPointTip then
        self.modelManage:ClearPointTip()
    end
end

--- 停止预览第一个点的状态
function M:StopPreviewFirstPoint()
    self.bPreviewFirstPoint = false
    self.previewFirstPointLocation = nil
    -- 清除预览点
    if self.modelManage and self.modelManage.ClearPointTip then
        self.modelManage:ClearPointTip()
    end
end

--- 更新预览第一个点的位置（每帧调用）
function M:UpdatePreviewFirstPoint()
    local start, endP = Model.GetLineValue(self.pc)
    local hitRes = UE.FHitResult()
    UE.UKismetSystemLibrary.BoxTraceSingle(
        self:GetWorld(),
        start,
        endP,
        UE.FVector(40, 40, 40),
        UE.FRotator(0, 0, 0),
        UE.ETraceTypeQuery.Reg,
        false,
        nil,
        0,
        hitRes,
        true
    )

    if hitRes.bBlockingHit then
        local location = hitRes.Location
        local regActor = hitRes.HitObjectHandle.Actor
        if regActor then
            self.previewFirstPointLocation = regActor.SplineAsPath:FindLocationClosestToWorldLocation(location, 1)
            -- 显示预览点
            if self.modelManage and self.modelManage.CreatePointTip then
                self.modelManage:CreatePointTip(self.previewFirstPointLocation, 1)
            end
        end
    end
end

--- 使用已确认的第一个点开始创建协作区域
--- @param firstPointLocation UE.FVector 第一个点的位置
function M:StartCreateRegionWithFirstPoint(firstPointLocation)
    if not (self.modelManage.P and self.modelManage.P:IsValid()) then
        self.ui:UECallWeb("ShowMessage", {
            Type = 2,
            Text = "当前无预览点位，无法放下第一个点"
        })
        return
    end
    self.bBuild = true
    local modelName = self:RegionNameCheck("RegionArea")
    local showName = self:RegionShowNameCheck("协作区域")
    self.curReg = self.modelManage:CreateRegion(modelName, self, showName)

    self.curReg.simplePoints:Clear()
    self.curReg.simplePoints:Add(self.previewFirstPointLocation)
    self.curReg.simplePoints:Add(self.previewFirstPointLocation)

    -- 初始化颜色为绿色（合法状态）
    self.curReg.lineColor = UE.FLinearColor(0.1, 0.6, 0.07, 1)
    self.curReg:SetColor()
    self.curReg:SetSplineModel()

    -- 初始化合法点缓存（以起点作为首次合法参考）
    self.lastValidRegionPoint = self.previewFirstPointLocation

    self.modelManage:BuildPoint(self.curReg.simplePoints)
    -- 停止预览状态
    self:StopPreviewFirstPoint()
    self:TimeMoveRegionArea()
end

--- 协作区域模式下的右键点击：结束绘制（校验点数并收尾）
--- 结束协作区域的绘制流程：检查自交情况，验证点数是否足够，清理定时器，生成最终模型并设置为选中状态
function M:StopMoveRegionArea()
    -- 结束绘制：清理计时器与状态（专用逻辑，不调用 StopMovePoint）
    -- 图形自交且存在交叉面积：视为非法绘制，自动销毁
    if self.Timer then
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.Timer)
    end

    self.bBuild = false

    local pts = self.curReg and self.curReg.simplePoints or nil

    -- 点位不足：自动删除
    if not pts or pts:Num() <= 3 then
        self.ui:UECallWeb("ShowMessage", {
            Type = 2,
            Text = "当前协作区域点位不足，"
        })
        self.modelManage:DestroyRegion(self.curReg, self)
        self:OutRegionData()
        self.curReg = nil
        return
    end

    local points = UE.TArray(UE.FVector)
    for i = 1, self.curReg.simplePoints:Num() - 1 do
        points:Add(self.curReg.simplePoints[i])
    end

    if RegionAreaAlgo.HasSelfIntersectionArea(points) then
        self.ui:UECallWeb("ShowMessage", {
            Type = 2,
            Text = "当前协作区域重叠其它区域或自交，无法生成"
        })
        self.modelManage:DestroyRegion(self.curReg, self)
        self:OutRegionData()
        self.curReg = nil
        return
    end



    self.curReg.simplePoints:Remove(pts:Num())

    -- 最终生成模型并切到选中态（将绘制过程中的红/绿提示色恢复为默认绿色）
    self.curReg.lineColor = UE.FLinearColor(0.1, 0.6, 0.07, 1)
    self.curReg:SetColor()
    self.curReg:SetSplineModel()
    self.curReg:SetMessage()
    self.modelManage:RegionSelcet(self.curReg, self)
    self.undo:AddAction(1, self.curReg)
    self:OutRegionData()
end

--- 跟踪协作区域的鼠标悬停状态
--- 检测鼠标是否悬停在协作区域上，如果悬停在当前绘制区域则添加点，否则选中其他区域或清除选中状态
function M:TrackRegionArea()
    local start, endP = Model.GetLineValue(self.pc)
    local hitRes = UE.FHitResult()
    UE.UKismetSystemLibrary.LineTraceSingle(
        self:GetWorld(),
        start,
        endP,
        UE.ETraceTypeQuery.Reg,
        false,
        nil,
        0,
        hitRes,
        true
    )
    if hitRes.bBlockingHit then
        if hitRes.HitObjectHandle.Actor == self.curReg then
            self.curReg:AddSplinePoint(hitRes.Location)
            self.modelManage:RegionSelcet(self.curReg, self)
        else
            self.modelManage:RegionSelcet(hitRes.HitObjectHandle.Actor, self)
        end
    else
        if self.curReg then
            self.modelManage:RegionClear(self)
        end
    end
end

--- 处理 RegionArea 模式下的双击事件

--- 先检测是否点击到点，如果没有则检测区域，在 curReg 上添加点或选择其他区域
function M:HandleRegionAreaDoubleClick()
    local start, endP = Model.GetLineValue(self.pc)
    local regionHitRes = UE.FHitResult()
    UE.UKismetSystemLibrary.BoxTraceSingle(
        self:GetWorld(),
        start,
        endP,
        UE.FVector(40, 40, 40),
        UE.FRotator(0, 0, 0),
        UE.ETraceTypeQuery.Reg,
        false,
        nil,
        0,
        regionHitRes,
        true
    )

    local bClickRegion = false
    if regionHitRes.bBlockingHit and regionHitRes.HitObjectHandle.Actor then
        local regionActor = regionHitRes.HitObjectHandle.Actor

        if self.curReg and not self.bBuild then
            if regionActor == self.curReg then
                -- 点击到当前选中的区域，在样条线位置添加点
                self.curReg:AddSplinePoint(regionHitRes.Location)
            else
                -- 点击到其他区域，选择该区域
                self.modelManage:RegionSelcet(regionActor, self)
            end
        else
            -- 如果没有 curReg，选择点击到的区域
            self.modelManage:RegionSelcet(regionActor, self)
        end

        bClickRegion = true
    else
        -- 双击空白区域，清除选中状态
        if self.curReg and not self.bBuild then
            self.modelManage:RegionClear(self)
            self:OutRegionData()
            bClickRegion = true
        end
    end

    return bClickRegion
end

--- 删除当前选中的样条线点（RegionArea 模式）
function M:RemoveCurrentSplinePoint()
    local bSuccess = self.curReg:RemoveSplinePoint()
    local message = {
        Type = bSuccess and 1 or 2,
        Text = bSuccess and "删除点位成功" or "点位不足,删除失败"
    }
    self.ui:UECallWeb("ShowMessage", message)
end

------- 四、区域名称管理 ---------------------

--- 检查并生成唯一的区域模型名称
--- @param modelName string 基础模型名称
--- @param nub number|nil 当前序号（递归参数，外部调用时可不传）
--- @return string 返回唯一的模型名称（如果名称已存在，会自动添加序号后缀，如"RegionArea-1"）
function M:RegionNameCheck(modelName, nub)
    local i = nub and nub + 1 or 1
    if self.modelManage:FindRegionAreaActorByRegionName(modelName) then
        local bFind = string.find(modelName, "-")
        if bFind then
            modelName = string.sub(modelName, 1, i - 1)
        end

        local newName = modelName .. "-" .. i
        modelName = self:RegionNameCheck(newName, i)
        return modelName
    end

    return modelName
end

--- 检查并生成唯一的区域显示名称
--- @param showName string 基础显示名称
--- @param nub number|nil 当前序号（递归参数，外部调用时可不传）
--- @return string 返回唯一的显示名称（如果名称已存在，会自动添加序号后缀，如"协作区域-1"）
function M:RegionShowNameCheck(showName, nub)
    local i = nub and nub + 1 or 1
    for key, value in pairs(self.modelManage.Regions) do
        if value.showName == showName then
            local bFind = string.find(showName, "-")
            if bFind then
                showName = string.sub(showName, 1, bFind - 1)
            end

            local newName = showName .. "-" .. i
            showName = self:RegionShowNameCheck(newName, i)
            return showName
        end
    end

    return showName
end

------- 五、区域数据管理 ---------------------

--- 输出所有协作区域的数据
--- @param bWeb boolean|nil 是否返回数据表（true时返回，false或nil时通过UI发送到Web端）
--- @return table|nil 当bWeb为true时返回区域数据表，否则返回nil
function M:OutRegionData(bWeb)
    local data = {}
    for key, value in pairs(self.modelManage.Regions) do
        local t = value:GetData()
        table.insert(data, t)
    end

    table.sort(data, function(a, b)
        return (a.time or 0) < (b.time or 0)
    end)

    if bWeb then
        return data
    else
        self.ui:UECallWeb("OutRegionData", data)
    end
end

--- 根据数据表选择指定的协作区域
--- @param dataTable table 区域数据表，包含modelName字段（区域模型名称）
--- 通过modelName查找对应的协作区域并设置为选中状态
function M:SelectRegion(dataTable)
    local reg = self.modelManage:FindRegionAreaActorByRegionName(dataTable.modelName)
    self.modelManage:RegionSelcet(reg, self)
end

function M:UpdateRegionData(dataTable)
    local reg = self.modelManage:FindRegionAreaActorByRegionName(dataTable.modelName)
    if reg then
        if dataTable.showName ~= reg.showName then
            reg.showName = ""
            self:RegionShowNameCheck(dataTable.showName)
        end

        self.undo:AddAction(2, reg)
        dataTable.userName = dataTable.ownerNickName
        reg:SetData(dataTable)
    end
end

--- 删除指定的协作区域
--- @param dataTable table 区域数据表，包含modelName字段（区域模型名称）
--- 清除当前选中状态，查找并删除指定的协作区域，同时记录撤销操作
function M:DeleteRegion(dataTable)
    self.modelManage:RegionClear(self)
    local reg = self.modelManage:FindRegionAreaActorByRegionName(dataTable.modelName)
    if reg then
        self.undo:AddAction(3, reg)
        self.modelManage:DestroyRegion(reg, self)
    end
end

-- 进入区域视图：只展示当前区域内模型
function M:EnterRegion(areaActor)
    if not areaActor or not UE.UKismetSystemLibrary.IsValid(areaActor) then
        return
    end

    -- 缓存当前所有区域 Actor / 多边形，供后续 RegionInner 模式统一几何判断使用

    -- RegionArea 的多边形几何由 ModelManage 维护，这里通过 modelManage 统一获取
    -- 存储结构：polygons[regionActor] = polygon（用于 IsActorFullyInsideRegion 调用）
    local polygons = {}
    for _, regionActor in pairs(self.modelManage.Regions) do
        local polygon = self.modelManage:GetRegionPolygon(regionActor)
        if polygon and polygon:Num() >= 3 then
            polygons[regionActor] = polygon
        end
    end
    self.polygons = polygons

    self.regionMode = true

    -- 通知前端进入区域内编辑模式（RegionInnerEdit）
    if self.ui and self.ui.UECallWeb then
        -- 这里可根据前端需要，后续扩展传递区域标识、名称等信息
        self.ui:UECallWeb("EditRegionInner", {
            -- 占位字段：后续若有需要可补充 areaId / areaName 等
        })
    end

    -- 视角聚焦到当前协作区域（进入区域后自动将镜头对准该区域）
    if self.pawn then
        local origin, extent = areaActor:GetActorBounds(true)
        if origin and extent then
            -- 使用统一的自动居中逻辑，保持与其它模块一致的视角体验
            self.pawn:Focus(origin, -30, -90, math.max(extent.X, extent.Y, extent.Z) * 2)
        end
    end

    -- 关闭协作提示 UI（如“请双击区域进行搭建”等），进入区域后不再遮挡视图
    if self.ui and self.ui.ModelTipHide then
        self.ui:ModelTipHide()
    end
    self.modelManage:GetAllRegionInnerActors()
    self.enterRegionName = Model.GetActorAccurateDisplayName(areaActor)
    self:TreeDataOut()
    self:HideRegionsMessage()
end

function M:HideRegionsMessage()
    -- 隐藏当前区域自身的文字标牌（SetMessage 显示的 Widget），避免进入区域内编辑时遮挡视图
    for _, regionActor in pairs(self.modelManage.Regions) do
        if regionActor and UE.UKismetSystemLibrary.IsValid(regionActor) then
            if regionActor.HideMessage then
                regionActor:HideMessage()
            elseif regionActor.Widget then
                regionActor.Widget:SetVisibility(false, false)
            end
        end
    end
end

function M:GetActorsInRegion(regModelName)
    if not self.modelManage or not self.modelManage.GetActorsInRegion then
        return UE.TArray(UE.AActor)
    end

    return self.modelManage:GetActorsInRegion(regModelName)
end

--- 判断指定 Actor 是否位于当前选中区域内部（在未进入区域视图时一律视为 true）
--- @param actor AActor
--- @return boolean
function M:IsActorInsideCurrentRegion(actor)
    -- 未进入区域视图时，不做限制
    if not self.regionMode then
        -- self:_RIDbg("IsActorInsideCurrentRegion: regionMode=false, 放行")
        return true
    end
    local branchActor
    if type(actor.modelType) ~= "number" then
        local childActors = UE.TArray(UE.AActor)
        actor:GetAttachedActors(childActors, true, true)
        if childActors:Num() == 1 then
            branchActor = childActors[1]
        elseif childActors:Num() > 1 then
            branchActor = actor
        end
    else
        branchActor = actor
    end


    -- 优先使用"完全落入"判定（包围盒四角都在区域内）
    for regionActor, polygon in pairs(self.polygons) do
        local ok, inside = pcall(self.modelManage.IsActorFullyInsideRegion, self.modelManage,
            regionActor, branchActor, polygon)
        if ok and inside then
            return true
        end
    end

    return false
end

--- 在“区域内绘制模型模式”(RegionInner) 下，通过双击 Reg 来尝试进入自己的协作区域
--- 仅在尚未进入任何区域视图时生效：成功后会调用 EnterRegion，并解锁其它正常功能
function M:TryEnterRegionByDoubleClick()
    -- 仅在 RegionInner 模式且尚未进入区域视图时生效
    if self.drawMode ~= M.DrawMode.RegionInner or not self:IsRegionInnerLocked() then
        return
    end

    local start, endP = Model.GetLineValue(self.pc)
    local hitRes = UE.FHitResult()
    UE.UKismetSystemLibrary.BoxTraceSingle(
        self:GetWorld(),
        start,
        endP,
        UE.FVector(40, 40, 40),
        UE.FRotator(0, 0, 0),
        UE.ETraceTypeQuery.Reg,
        false,
        nil,
        0,
        hitRes,
        true
    )

    if not hitRes.bBlockingHit or not hitRes.HitObjectHandle.Actor then
        return
    end

    local areaActor = hitRes.HitObjectHandle.Actor

    -- 用户 ID 校验（如果前端或区域 Actor 上提供了 userId / ownerId 字段则生效）
    local myUserId = self.ui and self.ui.userId or nil
    local ownerId = areaActor.userId or areaActor.ownerId or nil
    if myUserId and ownerId and tostring(myUserId) ~= tostring(ownerId) then
        if self.ui and self.ui.UECallWeb then
            self.ui:UECallWeb("ShowMessage", {
                Type = 1,
                Text = "只能选择与自己用户ID一致的协作区域"
            })
        end

        return
    end

    -- 进入该区域视图：只展示当前区域内完全落入的模型，并通知前端过滤模型树
    self:EnterRegion(areaActor)
end

----------------------------------------------------

-- RegionInner（协作区域内）本地缓存 + 一致性校验
-- 需求：
--  - ValidAssistorSave：保存当前用户区域内模型数据到本地；校验“当前用户所属区域”与“上次记录区域”是否一致
--    不一致返回 { bSaveVS=false }，一致返回 { bSaveVS=true }
--  - ApplyRegionInnerLocalCache：在前端重建方案后，将本地缓存的区域内模型数据回灌更新

--- RegionInner：拼接本地缓存目录（确保存在）
function M:_GetRegionInnerCacheDir()
    local dir = UE.UBlueprintPathsLibrary.ProjectDir() .. "autosave/regionInner/"
    -- 确保目录存在（UMyBFL.CreatFolder 会递归创建）
    if BFL and BFL.CreatFolder then
        BFL.CreatFolder(dir)
    end

    return dir
end

--- RegionInner：生成当前缓存文件路径（按 planId + userId + 时间命名）
function M:_GetRegionInnerCachePath(planId, userId)
    local p = tostring(planId or "nil")
    local u = tostring(userId or "nil")
    local ts = os.date("%Y%m%d_%H%M%S")
    return self:_GetRegionInnerCacheDir() .. string.format("cache_plan_%s_user_%s_%s.json", p, u, ts)
end

--- RegionInner：读取当前用户的本地区域缓存
--- @param planId any|nil  可选，默认使用 self.ui.planId
--- @param userId any|nil  可选，默认使用 self.ui.userId
--- @return table|nil 缓存表结构，或在不存在/解析失败时返回 nil
function M:GetRegionInnerCache(planId, userId)
    planId = planId or (self.ui and self.ui.planId)
    userId = userId or (self.ui and self.ui.userId)

    if not planId or not userId then
        return nil
    end

    -- 新规则：文件名中包含时间戳（cache_plan_{planId}_user_{userId}_YYYYMMDD_HHMMSS.json）
    -- 这里需要在目录下查找该 planId + userId 的“最新一条”缓存
    local dir = self:_GetRegionInnerCacheDir()
    local p = tostring(planId)
    local u = tostring(userId)
    local prefix = string.format("cache_plan_%s_user_%s_", p, u)

    local files = BFL.GetFolderFiles(dir)
    if not files then
        return nil
    end

    local latestName = nil
    for _, name in pairs(files) do
        if type(name) == "string"
            and string.sub(name, 1, #prefix) == prefix
            and string.sub(name, -5) == ".json" then
            -- 由于时间戳使用 %Y%m%d_%H%M%S，字符串排序即时间排序
            if not latestName or name > latestName then
                latestName = name
            end
        end
    end

    if not latestName then
        return nil
    end

    local cachePath = dir .. latestName
    local content = BFL.ReadFile(cachePath)
    if not content or content == "" then
        return nil
    end

    local ok, cache = pcall(function()
        return Json.decode(content)
    end)

    if not ok or type(cache) ~= "table" then
        return nil
    end

    -- 正常解析成功时返回缓存表
    return cache
end

--- ValidAssistorSave：RegionInner 下保存区域内模型数据到本地并校验区域一致性
--- 主要功能（简要）：
---  - 获取 userId / planId，并确定当前用户所属 regModelName（优先 UE 侧同步信息；否则尝试从前端 contentValue 反推）
---  - 将“当前区域内模型相关数据”写入本地缓存（按 planId + userId 命名的 json）
---  - 读取并对比“上次区域记录”（同 userId + planId 维度）；若与本次 regModelName 不一致则 bSaveVS=false
---  - 无论是否一致，都更新 lastRegion 记录为本次 regModelName，供下次校验使用
--- @param dataTable table|nil { userId, sandboxSchemeId/planId, path:string|nil, contentValue:string|nil }
--- @return table { bSaveVS:boolean }
function M:ValidAssistorSave(dataTable)
    local userId = self.ui.userId
    local planId = self.ui.planId

    local actors = UE.TArray(UE.AActor)

    for _, value in pairs(self.modelManage.RegionInnerActors) do
        if value.modelType == "Group" then
            actors:Add(value)
        end
    end

    local saveTable = self:ActorsDataToTable(actors)

    -- 先把区域内模型数据落到本地（数据源以 RegionInnerActors 为准；regModelName 仅作为元信息）
    local cachePath = self:_GetRegionInnerCachePath(planId, userId)
    local cache = {
        timestamp = os.time(),
        modelRelated = saveTable,
        -- 前端传来的云端方案最新地址（用于排查/追踪，不参与逻辑）
        remotePath = dataTable and dataTable.path or nil,
    }
    BFL.WriteFile(Json.encode(cache), cachePath, 3)
    -- 再做一致性校验：按 userId + planId 维度记录“上次区域”
    local bSaveVS = true
    if not dataTable then
        print("[ValidAssistorSave] return | no dataTable -> skip VS, default true")
        return {
            bSaveVS = bSaveVS
        }
    end

    -- VS 数据源：优先 contentValue(JSON) → 再回落 dataTable 顶层（兼容不同调用方）
    local vsFT = Json.decode(dataTable.contentValue)
    local isRegOps = (vsFT and vsFT.isRegOps) == true
    local regionAreas = (vsFT and vsFT.regionAreas) or nil

    -- 在 UE 侧根据云端传来的标识找到对应区域 Actor（兼容：modelName 固定 / showName 匹配 / 仅 1 个区域兜底）
    local function _findRegionActor(area)
        if not (self.modelManage and self.modelManage.Regions) then
            return nil
        end

        local key = area and (area.regModelName or area.modelName) or nil
        local reg = self.modelManage:FindRegionAreaActorByRegionName(key)
        if reg and UE.UKismetSystemLibrary.IsValid(reg) then
            return reg
        end

        local showName = area and area.showName or nil
        if showName and showName ~= "" then
            for _, r in pairs(self.modelManage.Regions) do
                if r and UE.UKismetSystemLibrary.IsValid(r) and r.showName == showName then
                    return r
                end
            end
        end

        -- 兜底：场景里只有 1 个协作区域时，直接用它（云端 modelName 可能是固定值 "RegionArea"）
        if self.modelManage.Regions:Num() == 1 then
            for _, r in pairs(self.modelManage.Regions) do
                if r and UE.UKismetSystemLibrary.IsValid(r) then
                    return r
                end
            end
        end

        return nil
    end

    if isRegOps then
        print(string.format("[ValidAssistorSave] vs | isRegOps=true regionsInUE=%s",
            tostring(self.modelManage.Regions:Num())))
        if type(regionAreas) ~= "table" then
            print("[ValidAssistorSave] return | VS fail: regionAreas missing (from contentValue/dataTable)")
            return { bSaveVS = false }
        end

        local num = self.modelManage.Regions:Num()
        for _, value in pairs(regionAreas) do
            local reg = self.modelManage:FindRegionAreaActorByRegionName(value.modelName)
            if reg and UE.UKismetSystemLibrary.IsValid(reg) then
                num = num - 1
                if value.ownerUserId ~= nil and tostring(userId) ~= tostring(value.ownerUserId) then
                    print(string.format(
                        "[ValidAssistorSave] return | VS fail: ownerUserId mismatch userId=%s ownerUserId=%s modelName=%s",
                        tostring(userId), tostring(value.ownerUserId), tostring(value.modelName)))
                    return {
                        bSaveVS = false
                    }
                end

                if #value.PointLocations ~= reg.simplePoints:Num() then
                    print(string.format(
                        "[ValidAssistorSave] return | VS fail: points count mismatch modelName=%s cloud=%s ue=%s",
                        tostring(value.modelName), tostring(#value.PointLocations), tostring(reg.simplePoints:Num())))
                    return {
                        bSaveVS = false
                    }
                end

                for i, value in pairs(value.PointLocations) do
                    local point = DFL.toVector(value)
                    if UE.UKismetMathLibrary.Vector_Distance(point, reg.simplePoints[i]) > 1 then
                        print(string.format(
                            "[ValidAssistorSave] return | VS fail: point distance > 1 modelName=%s idx=%s",
                            tostring(value.modelName), tostring(i)))
                        return {
                            bSaveVS = false
                        }
                    end
                end
            end
        end

        if num ~= 0 then
            print(string.format("[ValidAssistorSave] vs | VS fail: region count mismatch leftover=%s", tostring(num)))
            bSaveVS = false
        end
    else
        print("[ValidAssistorSave] vs | isRegOps=false -> bSaveVS=false")
        bSaveVS = false
    end

    print(string.format("[ValidAssistorSave] return | bSaveVS=%s", tostring(bSaveVS)))
    return {
        bSaveVS = bSaveVS
    }
end

-- 存数据
function M:SaveData(PlanName, PlanID, UserID, url)
    -- 是否为团队方案：仅团队方案才保存协作区域数据
    local isTeamScheme = (self.ui and self.ui.isTeamScheme) == true

    local regionAreas = {}
    if isTeamScheme and self.drawMode ~= M.DrawMode.RegionInner then
        for key, value in pairs(self.modelManage.Regions) do
            local regT = value:ModelSave()
            regT.modelName = Model.GetActorAccurateDisplayName(value)
            table.insert(regionAreas, regT)
        end
    end

    local FT = {
        MaxFloor = self.MaxFloor,
        MinFloor = self.MinFloor,
        AnimeConfig = Json.encode(self.animationData),
        -- 仅在团队方案下写入协作区域相关字段，非团队方案则不落盘
        isRegOps = isTeamScheme and self.bRegionEdit or nil,
        regionAreas = isTeamScheme and regionAreas or nil
    }

    if self.drawMode == M.DrawMode.RegionInner then
        FT.regionAreas = self.regionsData
    end

    local FTs = Json.encode(FT)
    -- 定义局部表 SaveTable，其中包含以下字段：
    local SaveTable = {
        sandboxSchemeName = PlanName,
        sandboxSchemeId = PlanID,
        sandboxSchemeImage = url,
        contentValue = FTs,
        userId = UserID,
        version = DFL.version,
        modelRelated = {}
    }
    self.SortId = 1
    if self.modelManage.cad then
        local CADT = self:SaveActorData(self.modelManage.cad)
        table.insert(SaveTable.modelRelated, CADT)
    end

    local T = self:SaveActorData(self.modelManage.DIY)
    table.insert(SaveTable.modelRelated, T)
    self:SaveChild(self.modelManage.DIY, SaveTable)
    return SaveTable
end

function M:SaveChild(Actor, Table)
    local ChildActors = UE.TArray(UE.AActor)
    Actor:GetAttachedActors(ChildActors, true)
    local ParentName = Model.GetActorAccurateDisplayName(Actor)
    for key, value in pairs(ChildActors) do
        local ccActors = UE.TArray(UE.AActor)
        value:GetAttachedActors(ccActors, true)
        if value.modelType == "Group" and ccActors:Num() == 0 then
            goto continue
        end

        self.SortId = self.SortId + 1
        local T = self:SaveActorData(value, ParentName)
        -- 数据先入库 ，在计算子类数据 与treeChild 不同
        table.insert(Table.modelRelated, T)
        self:SaveChild(value, Table)
        ::continue::
    end
end

function M:SaveActorData(Actor, ParentName)
    local modelName = Model.GetActorAccurateDisplayName(Actor)
    local T = Actor:GetTransform()
    local MT = {
        size = UE.UJsonLibraryHelpers.JsonValue_Stringify(UE.UJsonLibraryHelpers.FromTransform(T)),
        modelName = modelName,
        showName = Actor.showName,
        Move = Actor.bMove,
        Type = Actor.modelType,
        parent = ParentName,
        time = Actor.time or 0,
    }
    self.modelManage.ModelSave(Actor, MT)
    local js1 = Json.encode(MT)
    local Table = {
        contentValue = js1,
        modelCode = "",
        relatedType = 0,
        relatedId = Actor.relatedId,
        relatedCode = Actor.relatedCode,
        modelCategoryCode = Actor.ModelCategory,
        sortId = self.SortId
    }
    -- print(self.SortId)
    return Table, MT
end

-- 读数据
function M:LoadData(jsonTable)
    if self.buildActor then
        self.modelManage.ModelCancelSelect[self.buildActor.modelType](self)
    end

    for key, value in pairs(self.modelManage.Actors) do
        value:K2_DestroyActor()
        self.modelManage.Actors:Remove(key)
    end

    for _, value in pairs(jsonTable) do
        local dataTable = Json.decode(value.contentValue)
        if not self.modelManage:FindActor(dataTable.modelName, true) then
            dataTable.bLoadPlan = true
            local Actor = self.modelManage:DataCreateModel(dataTable)
            Actor.ModelCategory = value.modelCategoryCode
            Actor.relatedId = value.relatedId
        end
    end

    self.modelManage.DIY = self.modelManage:FindActor("DIY")
    local walls = UE.UGameplayStatics.GetAllActorsOfClass(self:GetWorld(), LoadClass(self.modelManage.class[5]))
    for _, v in pairs(walls) do
        v.bLoadPlan = false
        v:TrackHoleModel()
    end

    local areas = UE.UGameplayStatics.GetAllActorsOfClass(self:GetWorld(), LoadClass(self.modelManage.class[6]))
    for _, v in pairs(areas) do
        v.bLoadPlan = false
        v:TrackHoleModel()
    end

    self.bLoadPlan = false
    self.undo:ClearStack()
    self.modelManage.ModelSelect[1](self.buildActor, self)
    self:TreeDataOut()
    self:FloorDataToView()
    self.ui:UECallWeb("SendCadData", self.ui:IsCadData())
end

function M:AnimationConfig(jsonTable)
    if not jsonTable.contentValue then
        return
    end

    local dataTable = Json.decode(jsonTable.contentValue)
    if dataTable.AnimeConfig then
        local data = Json.decode(dataTable.AnimeConfig)
        self.animationData.dataArray = data.dataArray
        self.animationData.isPlay = false
        self.animationData.modelType = 0
        for k, v in pairs(data.dataArray) do
            local a = self.modelManage:FindActor(v.id)
            a.animationName = v.animationName
            a.animationOrder = v.animationOrder
        end
    end
end

function M:LoadRegionData(data)
    self.modelManage:ClearAllRegions()

    if not data then
        print("LoadRegionData data is nil")
        self.bRegionEdit = true
        return
    end

    local dataTable = Json.decode(data)

    if self.drawMode == M.DrawMode.RegionInner then
        self.regionsData = dataTable.regionAreas
    end

    -- 仅在团队方案下才加载协作区域
    local isTeamScheme = (self.ui and self.ui.isTeamScheme) == true
    if isTeamScheme then
        self.bRegionEdit = dataTable.isRegOps ~= nil and dataTable.isRegOps or true
        -- 当前用户 ID（由 UI 层同步进来）
        local myUserId = self.ui and self.ui.userId or nil
        local isRegionInnerMode = (self.drawMode == M.DrawMode.RegionInner)
        if dataTable.regionAreas then
            for _, value in pairs(dataTable.regionAreas) do
                -- RegionInner 模式下：只生成 ownerUserId 与当前用户 ID 一致的协作框，其余忽略
                if isRegionInnerMode then
                    local ownerUserId = value.ownerUserId
                    if myUserId and ownerUserId and tostring(myUserId) ~= tostring(ownerUserId) then
                        goto continue
                    end
                end

                local reg = self.modelManage:CreateRegion(value.modelName, self, value.showName)
                if reg and reg.ModelLoad then
                    reg:ModelLoad(value)
                end

                ::continue::
            end
        end
    end
end

-- 清除区域内模型
function M:ClearRegionInModels()
    -- 先收集再删除，避免遍历时修改 Map
    self.modelManage:GetAllRegionInnerActors()

    for name, actor in pairs(self.modelManage.RegionInnerActors) do
        print(name)
        self.modelManage:ActorOutMap(actor)
    end
    self:TreeDataOut()
end

function M:ImportLocalRegionData()
    -- 仅针对“当前场景已存在的协作区域”导入：如果场景里没有区域则不导
    local cache = self:GetRegionInnerCache()
    local actors = UE.TArray(UE.AActor)
    self:RebulidChilds(cache.modelRelated, actors)

    local walls = UE.UGameplayStatics.GetAllActorsOfClass(self:GetWorld(), LoadClass(self.modelManage.class[5]))
    for _, v in pairs(walls) do
        v.bLoadPlan = false
        v:TrackHoleModel()
    end

    local areas = UE.UGameplayStatics.GetAllActorsOfClass(self:GetWorld(), LoadClass(self.modelManage.class[6]))
    for _, v in pairs(areas) do
        v.bLoadPlan = false
        v:TrackHoleModel()
    end

    self.undo:ClearStack()
    self:EnterRegion(self.modelManage:FindRegionAreaActorByRegionName(self.enterRegionName))
end

-- 方案导入合并操作
function M:MergePlan(planData)
    local parentName = ""
    local importedModelNames = {} -- 跟踪导入的模型名称
    for _, value in pairs(planData) do
        local dataTable = Json.decode(value.contentValue)
        if dataTable.Type == "DIY" or dataTable.Type == 1 then
            goto continue
        end

        if dataTable.showName and string.find(dataTable.showName, "画布") ~= nil then
            goto continue
        end

        print(dataTable.modelName)
        if string.find(dataTable.modelName, "1BZ") ~= nil then
            goto continue
        end

        if dataTable.Type ~= "Group" then
            dataTable.modelName = parentName .. "-s"
        else
            local modelName = string.match(dataTable.modelName, "[^-]+")
            dataTable.modelName = self:NameCheck(modelName)
            parentName = dataTable.modelName
            local showName = string.match(dataTable.showName, "[^-]+")
            dataTable.showName = self:ShowNameCheck(showName)
        end

        dataTable.time = os.time()
        dataTable.bLoadPlan = true
        local Actor = self.modelManage:DataCreateModel(dataTable)
        Actor.ModelCategory = value.modelCategoryCode
        Actor.relatedId = value.relatedId
        -- 记录导入的模型名称
        if Actor and Actor:IsValid() then
            local actorName = Actor.showName or UE.UKismetSystemLibrary.GetObjectName(Actor)
            importedModelNames[actorName] = true
        end

        ::continue::
    end

    local walls = UE.UGameplayStatics.GetAllActorsOfClass(self:GetWorld(), LoadClass(self.modelManage.class[5]))
    for _, v in pairs(walls) do
        v.bLoadPlan = false
        v:TrackHoleModel()
    end

    local areas = UE.UGameplayStatics.GetAllActorsOfClass(self:GetWorld(), LoadClass(self.modelManage.class[6]))
    for _, v in pairs(areas) do
        v.bLoadPlan = false
        v:TrackHoleModel()
    end

    local overlapResults = self.modelManage:DetectModelOverlapByType()
    if overlapResults then
        if type(overlapResults) == "table" and #overlapResults > 0 then
            Screen.Print("检测到 " .. #overlapResults .. " 个模型重叠冲突：")

            local overlapMap = {}
            for i, result in ipairs(overlapResults) do
                if result.modelName and result.overlappingModelName then
                    -- 只将导入的模型作为键
                    if importedModelNames[result.modelName] then
                        if not overlapMap[result.modelName] then
                            overlapMap[result.modelName] = {}
                        end

                        table.insert(overlapMap[result.modelName], result.overlappingModelName)
                    end
                end
            end

            -- 打印碰撞数据
            print("发送碰撞数据:")
            for modelName, overlapList in pairs(overlapMap) do
                local overlapStr = table.concat(overlapList, ", ")
                print(modelName .. " -> [" .. overlapStr .. "]")
            end

            -- 发送碰撞数据给前端
            self.ui:UECallWeb("SendCollisionData", overlapMap)
        else
            Screen.Print("未检测到模型重叠冲突")

            -- 发送空碰撞数据给前端
            self.ui:UECallWeb("SendCollisionData", {})
        end
    else
        Screen.Print("重叠检测函数执行完毕")

        -- 发送空碰撞数据给前端
        self.ui:UECallWeb("SendCollisionData", {})
    end

    self.undo:ClearStack()
    self.modelManage.ModelSelect[1](self.buildActor, self)
    self:TreeDataOut()
    self:FloorDataToView()
    self.ui:UECallWeb("SendCadData", self.ui:IsCadData())
end

-- 阵列
--------  {"type":1,"xNum":0,"yNum":0,"xInterval":0,"yInterval":0,"xBuildType":"1","yBuildType":"1","r":0,"cNum":0,"centerAngle":0}
function M:ModelArrayCopy(jsonTable)
    if not self.buildActor then
        return
    end

    self.bBuild = true
    self.clickType = "Array"
    local copyType = jsonTable.type
    -- 如果传参为空，则为0
    local xNum = jsonTable.xNum == "" and 0 or jsonTable.xNum
    local yNum = jsonTable.yNum == "" and 0 or jsonTable.yNum
    local zNum = jsonTable.zNum == "" and 0 or jsonTable.zNum
    local xInterval = jsonTable.xInterval == "" and 0 or jsonTable.xInterval
    local yInterval = jsonTable.yInterval == "" and 0 or jsonTable.yInterval
    local zInterval = jsonTable.zInterval == "" and 0 or jsonTable.zInterval
    local r = jsonTable.r == "" and 0 or jsonTable.r
    local cNum = jsonTable.xNum == "" and 0 or jsonTable.cNum
    local centerAngle = jsonTable.centerAngle == "" and 0 or jsonTable.centerAngle
    local xBuildType = jsonTable.xBuildType
    local yBuildType = jsonTable.yBuildType
    local zBuildType = jsonTable.zBuildType

    if self.PasteActors then
        for _, value in pairs(self.PasteActors) do
            if value then
                self.modelManage.ModelDelete[value.modelType](value, self)
            end
        end
    end
    self.PasteActors = UE.TArray(UE.AActor)
    self.bArrayCopy = true
    if copyType == 1 then
        local b1 = xNum > 0 and yNum > 0 and zNum > 0
        local b2 = xInterval > 0 or yInterval > 0 or zInterval > 0
        if b1 and b2 then
            local arrayActors = UE.TArray(UE.AActor)
            self:CopyModelTable(arrayActors)
            for x = 1, xNum do
                for y = 1, yNum do
                    for z = 1, zNum do
                        if x == 1 and y == 1 and z == 1 then
                            goto continue
                        end

                        local pasteActors = UE.TArray(UE.AActor)
                        for key, value in pairs(arrayActors) do
                            local Name, A = self:CopyPasteData(value, "1")
                            pasteActors:Add(A)
                            self:CopyPasteChildData(value, Name)
                        end

                        local intervalLoction = UE.FVector((x - 1) * xInterval, (y - 1) * yInterval, (z - 1) * zInterval)
                        if xBuildType == "2" then
                            intervalLoction.X = -intervalLoction.X
                        end

                        if yBuildType == "2" then
                            intervalLoction.Y = -intervalLoction.Y
                        end

                        if zBuildType == "2" then
                            intervalLoction.Z = -intervalLoction.Z
                        end

                        for key, value in pairs(pasteActors) do
                            value:K2_AddActorWorldOffset(intervalLoction, false, nil, false)
                            local ChildActors = UE.TArray(UE.AActor)
                            value:GetAttachedActors(ChildActors, true)
                            for k, v in pairs(ChildActors) do
                                v:K2_AddActorWorldRotation(UE.FRotator(-jsonTable.incline, jsonTable.revolve, 0), false,
                                    nil,
                                    false)
                            end
                        end

                        self.PasteActors:Append(pasteActors)
                        ::continue::
                    end
                end
            end
        end
    elseif copyType == 2 then
        if r > 0 and cNum > 0 and centerAngle > 0 then
            local arrayActors = UE.TArray(UE.AActor)
            self:CopyModelTable(arrayActors)
            local nub = centerAngle % 360 == 0 and cNum or cNum - 1
            local angle = centerAngle / nub
            for i = 1, cNum do
                local pasteActors = UE.TArray(UE.AActor)
                for key, value in pairs(arrayActors) do
                    local Name, A = self:CopyPasteData(value, "1")
                    pasteActors:Add(A)
                    self:CopyPasteChildData(value, Name)
                end

                local radians = (i - 1) * angle * math.pi / 180
                local intervalLoction = UE.FVector(math.cos(radians) * r, math.sin(radians) * r, 0)

                for key, value in pairs(pasteActors) do
                    value:K2_AddActorWorldOffset(intervalLoction, false, nil, false)
                end

                self.PasteActors:Append(pasteActors)
            end
        end
    end

    local PastrSTAs = UE.TArray(UE.AStaticMeshActor)
    Model.GetChildOfStaticMeshActors(self.PasteActors, PastrSTAs)
    for key, value in pairs(PastrSTAs) do
        if value.clickType == 2 then
            value:Update(false)
        end
    end

    self.buildActor:K2_AddActorWorldRotation(UE.FRotator(-jsonTable.incline, jsonTable.revolve, 0), false, nil, false)
    self.bBuild = false
end

-- 取消阵列复制
function M:CancelModelArray(bool)
    self.bBuild = false
    self.clickType = 1
    if bool then
        if self.PasteActors then
            if self.PasteActors:Num() > 0 then
                -- RegionInner 模式下检查所有复制的模型是否完全在区域内
                print("[DEBUG] CancelModelArray 执行: drawMode=" ..
                    tostring(self.drawMode) .. ", regionMode=" .. tostring(self.regionMode))
                if self.drawMode == M.DrawMode.RegionInner and self.regionMode then
                    print("[DEBUG] 进入区域检查分支")
                    local validActors = UE.TArray(UE.AActor)
                    local invalidActors = UE.TArray(UE.AActor)
                    for key, actor in pairs(self.PasteActors) do
                        if actor and UE.UKismetSystemLibrary.IsValid(actor) then
                            local isInside = self:IsActorInsideCurrentRegion(actor)
                            print("[DEBUG] 检测Actor: " .. tostring(actor:GetName()) .. ", IsInside=" .. tostring(isInside))
                            if isInside then
                                validActors:Add(actor)
                            else
                                invalidActors:Add(actor)
                            end
                        end
                    end

                    print("[DEBUG] Valid=" ..
                        tostring(validActors:Num()) .. ", Invalid=" .. tostring(invalidActors:Num()))

                    if invalidActors:Num() > 0 then
                        -- 删除超出边界的复制模型
                        for key, actor in pairs(invalidActors) do
                            if actor and UE.UKismetSystemLibrary.IsValid(actor) then
                                self.modelManage.ModelDelete[actor.modelType](actor, self)
                            end
                        end

                        -- 提示用户
                        if self.ui and self.ui.UECallWeb then
                            self.ui:UECallWeb("ShowMessage", {
                                Type = 2,
                                Text = "部分复制模型超出协作区域边界，已自动过滤"
                            })
                        end

                        -- 如果有效模型为空，则取消操作
                        if validActors:Num() == 0 then
                            self.PasteActors = nil
                            self.bBuild = false
                            self.clickType = 1
                            return
                        end

                        -- 继续使用有效模型
                        self.PasteActors = validActors
                    end
                end

                self.undo:AddAction(6, nil, self.PasteActors)
                self:TreeDataOut()
                self.Changes = true
                local Actor = self.buildActor
                self:MultiModels(self.PasteActors)
                self:AppendSelectActor(Actor)
                self.PasteActors = nil
                self.Changes = false
            end
        end
    else
        if self.PasteActors then
            for key, value in pairs(self.PasteActors) do
                if UE.UKismetSystemLibrary.IsValid(value) then
                    self.modelManage.ModelDelete[value.modelType](value, self)
                end
            end

            if self.buildActor and self.buildActor.clickType == 1 then
                self.modelManage:BuildAllAroundLine(self.buildActor)
            end

            self.PasteActors = nil
        end
    end
end

-- 复制升级处理 不走前端 直接获取场景选择的actor
function M:CopyModelTable(CopyActors)
    CopyActors:Clear()
    if self.buildActor then
        if self.buildActor.modelType == "Multi" then
            CopyActors:Append(self.buildActor.MultiActors)
        elseif self.buildActor.modelType == "Group" then
            CopyActors:Add(self.buildActor)
        else
            local P = self.buildActor:GetAttachParentActor()
            CopyActors:Add(P)
        end
    end

    if CopyActors:Num() > self.copyNum then
        CopyActors:Clear()
        self.ui:UECallWeb("ShowMessage", {
            Type = 3,
            Text = "复制数量超过" .. self.copyNum .. "，请减少选择"
        })
    end
end

function M:PasteModelTable()
    if self.BatchActors:Num() > 0 then
        if self.BatchPasteActors then
            -- UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.GroupsTimer)
            -- for key, value in pairs(self.BatchPasteActors) do
            --     self.modelManage.ModelDelete[value.modelType](value, self)
            -- end
            -- self.BatchPasteActors = nil
        else
            self:BatchPasteModel()
        end

        self.ui:ShowModelTip("粘贴模型", "请鼠标移动选择位置，按右键放置模型" .. " 当前处于粘贴功能下需要通过空格+右键进行视角移动")
        self.ui:StopOperate({
            bDisable = true
        })
    end
end

-- 通过Actor表中，批量复制生成
function M:BatchPasteModel()
    self.BatchPasteActors = UE.TArray(UE.AActor)
    -- self.CopyUndoActors = UE.TArray(UE.AActor)
    for i = 1, self.BatchActors:Num() do
        local value = self.BatchActors[i]
        if UE.UKismetSystemLibrary.IsValid(value) then
            local Name, A = self:CopyPasteData(value, "1")
            print(Name)
            self.BatchPasteActors:Add(A)
            self:CopyPasteChildData(value, Name)
        end
    end

    local STAs = UE.TArray(UE.AStaticMeshActor)
    Model.GetChildOfStaticMeshActors(self.BatchActors, STAs)

    self.PastrSTAs = UE.TArray(UE.AStaticMeshActor)
    Model.GetChildOfStaticMeshActors(self.BatchPasteActors, self.PastrSTAs)

    local O, B = UE.UGameplayStatics.GetActorArrayBounds(STAs, true)
    O.Z = O.Z - B.Z
    self.CopyLocation = O

    self.modelManage:ModelClear(self)

    self:TemporaryGroups()
    self:TemporaryGroupsTime()
end

-- 修改表的父类名称
function M:CopyPasteData(Actor, ParentName)
    local T, MT = self:SaveActorData(Actor, ParentName)
    MT.modelCategoryCode = T.modelCategoryCode
    -- print(Actor.ModelCategory, T.modelCategoryCode)
    if MT.Type ~= "Group" then
        MT.modelName = ParentName .. "-s"
    else
        -- print(MT.modelName)
        local modelName = string.match(MT.modelName, "[^-]+")
        MT.modelName = self:NameCheck(modelName)
        local showName = string.match(MT.showName, "[^-]+")
        MT.showName = self:ShowNameCheck(showName)
    end

    MT.time = os.time()
    local A = self.modelManage:DataCreateModel(MT)
    return MT.modelName, A
end

function M:CopyPasteChildData(Actor, ModelName)
    -- 复制粘贴时：递归处理挂接(Attached)层级
    -- 说明：
    -- - 这里依赖 UE 的 Attach 关系来还原“组/层级”结构
    -- - ModelName 作为父级名称传递给子级，子节点会在 CopyPasteData 内改写自身的 modelName/showName
    local Childs = UE.TArray(UE.AActor)
    Actor:GetAttachedActors(Childs, true)
    for i = 1, Childs:Num() do
        local value = Childs[i]
        local Name = self:CopyPasteData(value, ModelName)
        self:CopyPasteChildData(value, Name)
    end
end

-- 批量粘贴(含阵列)的“跟随鼠标”预览移动
-- 逻辑要点：
-- - 从相机/鼠标射线取得落点(地面通道)，用“本次落点 - 上次落点”的增量来平移整批预览 Actor
-- - 使用增量而非绝对坐标，是为了避免不同 Actor 初始相对位置被破坏
function M:TemporaryGroups()
    local start, endP = Model.GetLineValue(self.pc)
    local hitRes = UE.FHitResult()
    -- 如果有阻挡，将位置设置为射线命中的位置，否则为射线发射的位置
    UE.UKismetSystemLibrary.LineTraceSingle(self:GetWorld(), start, endP, UE.ETraceTypeQuery.Floor, false,
        self.PastrSTAs, 0, hitRes, true)
    if hitRes.bBlockingHit then
        local RelativeLoction = UE.UKismetMathLibrary.Subtract_VectorVector(hitRes.Location, self.CopyLocation)

        for key, value in pairs(self.BatchPasteActors) do
            -- print(Model.GetActorAccurateDisplayName(value))
            value:K2_AddActorWorldOffset(RelativeLoction, false, nil, false)
            -- self:ShowSel(value)
        end

        for key, value in pairs(self.PastrSTAs) do
            if value.clickType == 2 then
                value:Update(false)
            end
        end


        self.CopyLocation = hitRes.Location
    end
end

function M:CancelGroupsTime()
    -- 取消批量粘贴的预览态：
    -- - 停止定时跟随(TemporaryGroupsTime)
    -- - 删除本次用于预览的临时 Actor（注意：此处不应落库/入 Undo）
    -- - 还原 UI 操作锁定状态
    if self.BatchPasteActors then
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.GroupsTimer)
        for key, value in pairs(self.BatchPasteActors) do
            self.modelManage.ModelDelete[value.Type](value, self)
        end

        self.BatchPasteActors = nil
        -- 区分阵列复制和普通复制
        self.UI.B_Tip:SetVisibility(1)
        self.UI:StopOperate({
            bDisable = false
        })
    end
end

function M:TemporaryGroupsTime()
    -- 开启“跟随鼠标移动”的定时刷新
    -- DFL.timerSec 为刷新间隔；循环触发 TemporaryGroups 来驱动预览 Actor 的平移
    self.GroupsTimer = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.TemporaryGroups }, DFL.timerSec, true)
end

function M:GroupsTimeOver()
    if self.GroupsTimer then
        self.GroupsTimer = UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.GroupsTimer)
    end

    -- 区分阵列复制和普通复制
    self.ui.B_Tip:SetVisibility(1)
    self.ui:StopOperate({
        bDisable = false
    })

    -- RegionInner 模式下检查所有复制的模型是否完全在区域内
    if self.drawMode == M.DrawMode.RegionInner and self.regionMode and self.BatchPasteActors then
        local validActors = UE.TArray(UE.AActor)
        local invalidActors = UE.TArray(UE.AActor)
        for key, actor in pairs(self.BatchPasteActors) do
            if actor and UE.UKismetSystemLibrary.IsValid(actor) then
                if self:IsActorInsideCurrentRegion(actor) then
                    validActors:Add(actor)
                else
                    invalidActors:Add(actor)
                end
            end
        end

        if invalidActors:Num() > 0 then
            for key, actor in pairs(invalidActors) do
                if actor and UE.UKismetSystemLibrary.IsValid(actor) then
                    self.modelManage.ModelDelete[actor.modelType or actor.Type](actor, self)
                end
            end

            if self.ui and self.ui.UECallWeb then
                self.ui:UECallWeb("ShowMessage", {
                    Type = 2,
                    Text = "部分复制模型超出协作区域边界，已自动过滤"
                })
            end

            if validActors:Num() == 0 then
                self.BatchPasteActors = nil
                self:TreeDataOut()
                self:FloorDataToView()
                return
            end

            self.BatchPasteActors = validActors
        end
    end

    self.undo:AddAction(6, nil, self.BatchPasteActors)
    self.BatchPasteActors = nil
    self:TreeDataOut()
    self:FloorDataToView()
end

-- 跨场景复制
function M:AdvancedCpopy()
    local CopyActors = UE.TArray(UE.AActor)
    self:CopyModelTable(CopyActors)
    self.CopyTable = self:ActorsDataToTable(CopyActors)
    self.bAlign = true
    self.copyPlanId = self.ui.planId
    if self.CopyTable and self.CopyTable ~= {} then
        self.ui:UECallWeb("StartCrossCopy", { isCopy = true })
    end
end

-- 跨场景粘贴
function M:AdvancedPaste()
    if self.CopyTable and self.CopyTable ~= {} and self.copyPlanId ~= self.ui.planId then
        self:TableToActors(self.CopyTable)
        self:AdvancedOver()
    end
end

function M:AdvancedOver()
    self.ui:UECallWeb("StartCrossCopy", { isCopy = false })
    self.CopyTable = {}
end

------------------------- 动画
function M:AnimationList()
    self.animationData.dataArray = {}
    for k, v in pairs(self.modelManage.animeTypeTable) do
        print(k, v, "AnimationList,LoadClass")
        local animes = UE.UGameplayStatics.GetAllActorsOfClass(self:GetWorld(), LoadClass(v))
        for i = 1, animes:Num() do
            if UE.UKismetSystemLibrary.IsValid(animes[i]) then
                local mt = {}
                local value = animes[i]

                if k == "animeModel" then
                    mt = {
                        id = Model.GetActorAccurateDisplayName(value),
                        name = value:GetAttachParentActor().showName,
                        modelCode = value.modelCode or Json.null,
                        animationName = value.animationName or Json.null,
                        animationOrder = value.animationOrder or Json.null,
                        time = value.time or 0,
                    }
                    table.insert(self.animationData.dataArray, mt)
                elseif value.animationDirectionr then
                    mt = {
                        id = Model.GetActorAccurateDisplayName(value),
                        name = value:GetAttachParentActor().showName,
                        modelCode = Json.null,
                        animationName = value:GetAttachParentActor().showName,
                        animationOrder = value.animationOrder or Json.null,
                        time = value.time or 0,
                    }
                    table.insert(self.animationData.dataArray, mt)
                end
            end
        end
    end

    -- print(#self.animationData.dataArray)

    return self.animationData
end

function M:AnimationPlay(table)
    local actors = UE.TArray(UE.AActor)
    for key, value in pairs(table.dataArray) do
        local actor = self.modelManage:FindActor(value.id)
        if actor then
            actor.animationName = value.animationName
            actor.animationOrder = value.animationOrder
            actors:Add(actor)
        end
    end

    if self.animationData.isPlay ~= table.isPlay then
        self.animationData = table -- 不能拿走 要提前更新数据
        if table.isPlay then
            if table.type == 0 then
                for key, value in pairs(actors) do
                    value:PlayAnimation(true)
                    value.bPlaying = true
                end
            elseif table.type == 1 then
                self.order = 1
                self.playOne = {}
                self:PlayOrderAnimation()
            end
        else
            for key, value in pairs(actors) do
                value:StopAnimation()
                value.bPlaying = false
            end
        end
    else
        self.animationData = table
    end
end

function M:PlayOrderAnimation()
    -- for key, value in pairs(self.playOne) do
    --     local a = self.modelManage:FindActor(value.id)
    --     if a then
    --         a:PlayAnimation(true)
    --         a.bPlaying = true
    --         a.StopOutEvent:Clear()
    --     end
    -- end
    self.playOne = {}

    if self.order > #self.animationData.dataArray + 1 then
        return
    end

    for key, value in pairs(self.animationData.dataArray) do
        if value.animationOrder == self.order then
            table.insert(self.playOne, value)
        end
    end

    self.order = self.order + 1
    if #self.playOne == 0 then
        self:PlayOrderAnimation()
    else
        self.stopNum = 0
        for key, value in pairs(self.playOne) do
            local a = self.modelManage:FindActor(value.id)
            if a then
                a:PlayAnimation(false)
                a.bPlaying = true
                if a.modelType == 12 then
                    a:CheckStopTimer()
                end

                a.StopOutEvent:Add(self, self.StopOutEvent)
            end
        end
    end

    UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.CheckPlayOne }, 2, false)
end

function M:CheckPlayOne()
    if #self.playOne == 0 then
        self:PlayOrderAnimation()
    else
        for key, value in pairs(self.playOne) do
            local a = self.modelManage:FindActor(value.id)
            if not a then
                table.remove(self.playOne, key)
            end
        end

        if self.stopNum == #self.playOne then
            self:PlayOrderAnimation()
        elseif self.order <= #self.animationData.dataArray + 1 then
            UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.CheckPlayOne }, 2, false)
        end
    end
end

function M:StopOutEvent(name)
    for key, value in pairs(self.playOne) do
        if value.id == name then
            self.stopNum = self.stopNum + 1
            local a = self.modelManage:FindActor(value.id)
            if a then
                a:PlayAnimation(true)
                a.bPlaying = true
                a.StopOutEvent:Clear()
            end

            break
        end
    end

    if self.stopNum == #self.playOne then
        self:PlayOrderAnimation()
    end
end

function M:AnimationSinglePlay(table)
    self.buildActor:SetAnimeData(table)
    if table.isPlay then
        self.buildActor:PlayAnimation(table.isLoop, table.animationCode)
        if not table.isLoop and not self.buildActor.bPlaying then
            self.buildActor:CheckStopTimer()
            self.buildActor.StopOutWeb:Add(self, self.StopOutWeb)
        end
    else
        self.buildActor:StopAnimation(table.animationCode)
    end
end

function M:StopOutWeb(name)
    if name == Model.GetActorAccurateDisplayName(self.buildActor) then
        self.ui:AnimationStop()
    end

    self.buildActor.StopOutWeb:Clear()
end

function M:GetAnimeModel(dataTable)
    local class = self.modelManage.animeTypeTable[dataTable.type]
    if class then
        local Animes = UE.UGameplayStatics.GetAllActorsOfClass(self:GetWorld(), LoadClass(class))
        local tables = {}
        for i = 1, Animes:Num() do
            local val = Animes[i]
            local t = val:GetAnimeData()
            t.ID = Model.GetActorAccurateDisplayName(val)
            -- print(#t)
            t.configState = t.animationDirectionr or true and false
            t.time = val.time
            t.isPlay = false
            if self.animationData.isPlay then
                for k, v in pairs(self.animationData.dataArray) do
                    if v.id == t.ID then
                        t.isPlay = true
                        break
                    end
                end
            end

            table.insert(tables, t)
        end

        self:UpdateAnimeList()
        return tables
    end
end

function M:SetAnimeData(dataTable)
    local name = Model.GetActorAccurateDisplayName(self.buildActor)
    if name ~= dataTable.ID then
        self:SelectAnime(dataTable)
    end

    self.buildActor:SetAnimeData(dataTable)
end

function M:SelectAnime(dataTable)
    local actor = self.modelManage:FindActor(dataTable.ID)
    self.modelManage.ModelSelect[actor.modelType](actor, self)
    self:ModelDataToView(false)
end

function M:UpdateAnimeList(bDel)
    if self.buildActor and self.buildActor:IsValid() then
        if type(self.buildActor.modelType) == "number" then
            self.ui:UECallWeb("animeMenuUpdate",
                {
                    id = Model.GetActorAccurateDisplayName(self.buildActor),
                    name = self.buildActor:GetAttachParentActor().showName,
                })
        end
    else
        self.ui:UECallWeb("animeMenuUpdate",
            {
                id = Json.null,
                bDel = bDel,
            })
    end
end

function M:CloseAnime(animeTable)
    if animeTable then
        for k, v in pairs(animeTable) do
            local a = self.modelManage:FindActor(v.ID)
            if a then
                a:StopAnime()
            end
        end
    end
end

-- 争对模型数组，放进跨方案表
function M:ActorsDataToTable(actors)
    local Table = {}
    for key, value in pairs(actors) do
        local parentActor = value:GetAttachParentActor()
        local pName = Model.GetActorAccurateDisplayName(parentActor)
        local T = self.undo:ActionActorData(value, pName, 6)
        self.undo:ActionChild(value, T, 6)
        local ppa = parentActor:GetAttachParentActor()
        local ppan = ""
        if ppa then
            ppan = Model.GetActorAccurateDisplayName(ppa)
        end

        T.parentData = self.undo:ActionActorData(parentActor, ppan, 6)
        table.insert(Table, T)
    end

    return Table
end

-- 跨方案粘贴
function M:TableToActors(table)
    local pasteActors = UE.TArray(UE.AActor)
    self:RebulidChilds(table, pasteActors)

    self.undo:AddAction(6, nil, pasteActors)
    self:TreeDataOut()
    self:MultiModels(pasteActors)
end

function M:RebulidChilds(table, actors, name)
    for key, value in pairs(table) do
        if self.modelManage:FindActor(value.modelName) then
            print("存在模型", value.modelName)
            -- 这里读的是输出数据 类型一定是value.Type 不是value.modelType
            if value.Type ~= "Group" then
                value.modelName = name .. "-s"
            else
                local modelName = string.match(value.modelName, "[^-]+")
                value.modelName = self:NameCheck(modelName)
                local showName = string.match(value.showName, "[^-]+")
                value.showName = self:ShowNameCheck(showName)
            end
        end

        if name then
            value.parent = name
        end

        local Actor = self.modelManage:DataCreateModel(value)
        if actors then
            actors:Add(Actor)
        end

        if value.Childs and #value.Childs > 0 then
            self:RebulidChilds(value.Childs, nil, value.modelName)
        end
    end
end

--- 多选模型管理系统
-- 提供框选、点选、多选模型管理功能

--- 开始框选操作
function M:StartSelection()
    -- 禁用玩家输入防止干扰
    self.pawn:DisableInput(self.pc)
    -- 获取当前鼠标位置作为选择起点
    -- local bool, x, y = UE.UWidgetLayoutLibrary.GetMousePositionScaledByDPI(self.pc)
    -- self.selStart = UE.FVector2D(x, y)
    self.selStart = UE.UWidgetLayoutLibrary.GetMousePositionOnViewport(self:GetWorld())
    -- 初始化选择状态
    self:EndSelection()
    self:SelectionTime()
end

--- 更新框选结束位置
function M:EndSelection()
    -- local bool, x, y = UE.UWidgetLayoutLibrary.GetMousePositionScaledByDPI(self.pc)
    -- self.selEnd = UE.FVector2D(x, y)
    self.selEnd = UE.UWidgetLayoutLibrary.GetMousePositionOnViewport(self:GetWorld())


    -- 更新UI选择框显示
    self.ui.StartPosition = self.selStart
    self.ui.EndPosition = self.selEnd
end

--- 启动选择定时器
function M:SelectionTime()
    local timerSec = 0.016 -- 约60FPS更新频率
    self.SelectionTimer = UE.UKismetSystemLibrary.K2_SetTimerDelegate(
        { self, self.EndSelection }, timerSec, true)
end

--- 结束选择操作并处理结果
function M:EndSelectionOver()
    -- 清理定时器
    if self.SelectionTimer then
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(
            self:GetWorld(), self.SelectionTimer)
        self.SelectionTimer = nil
    end

    -- 恢复玩家输入
    self.pawn:EnableInput(self.pc)

    -- 设置HUD选择参数
    self.SEHUD.SelectNewActor = true
    self.SEHUD.Start = self.selStart
    self.SEHUD.End = self.selEnd
    print(self.SEHUD.Start, self.SEHUD.End, "hud")
    print(self.ui.StartPosition, self.ui.EndPosition, "ui")

    -- 延迟处理选择结果
    coroutine.resume(coroutine.create(function()
        local wait = self:GetActorTickInterval()
        wait = wait > 0.05 and wait * 2 or wait + 0.3
        UE.UKismetSystemLibrary.Delay(self, wait)
        print(self.SEHUD.OutActors:Num(), "num")
        -- 处理选择结果
        if self.SEHUD.OutActors:Num() > 0 then
            if self.buildActor then
                self:AppendSelectActors(self.SEHUD.OutActors)
            else
                self:StructuralCarding(self.SEHUD.OutActors)
            end
        elseif self.AppendActor then
            self:AppendSelectActor(self.AppendActor)
        end

        -- 重置选择状态
        self.SEHUD.SelectNewActor = false
        self.SEHUD.Start = UE.FVector2D(0, 0)
        self.SEHUD.End = UE.FVector2D(0, 0)
        self.ui.StartPosition = UE.FVector2D(0, 0)
        self.ui.EndPosition = UE.FVector2D(0, 0)
    end), self)
end

--- 结构化处理选中的模型
function M:StructuralCarding(Actors)
    local OutActors = Actors
    if OutActors:Num() <= 0 then return end

    local bRemove = false
    for _, actor in pairs(OutActors) do
        if self.drawMode == M.DrawMode.RegionInner and not self:IsRegionInnerLocked() then
            local isInsideAnyRegion = false
            for regionActor, polygon in pairs(self.polygons) do
                local ok, inside = pcall(self.modelManage.IsActorFullyInsideRegion,
                    self.modelManage,
                    regionActor,
                    actor,
                    polygon)
                if ok and inside then
                    isInsideAnyRegion = true
                    break
                end
            end
            if not isInsideAnyRegion then
                OutActors:RemoveItem(actor)
                bRemove = true
            end
        end
        if not actor.bMove then
            OutActors:RemoveItem(actor)
        end
    end
    if bRemove then
        self.ui:UECallWeb("ShowMessage", { Type = 2, Text = "已剔除不在协作区域内的模型" })
    end

    -- 创建多选容器
    local Multi = self.modelManage.ModelCreate["Multi"]()

    -- 遍历所有选中的模型
    for _, actor in pairs(OutActors) do
        if actor.bMove then
            local parent = actor:GetAttachParentActor()

            if parent then
                -- 跳过已处理的父项
                if Multi.MultiActors:Find(parent) > 0 then
                    goto continue
                end

                local grandParent = parent:GetAttachParentActor()

                -- 处理不同层级的父项
                if Model.GetActorAccurateDisplayName(grandParent) == "1" then
                    Multi.MultiActors:Add(parent)
                elseif string.find(Model.GetActorAccurateDisplayName(grandParent), "Group") ~= nil then
                    if Multi.MultiActors:Find(grandParent) <= 0 then
                        Multi.MultiActors:Add(grandParent)
                    end
                elseif Model.GetActorAccurateDisplayName(grandParent) == "None" then
                    -- 检查同级模型是否全部被选中
                    if Multi.MultiActors:Find(grandParent) <= 0 then
                        local siblings = grandParent:GetAttachedActors()
                        local allSelected = true

                        for _, sibling in pairs(siblings) do
                            local child = sibling:GetAttachedActors()[1]
                            if OutActors:Find(child) <= 0 then
                                allSelected = false
                                break
                            end
                        end

                        if allSelected then
                            Multi.MultiActors:Add(grandParent)
                        else
                            Multi.MultiActors:Add(parent)
                        end
                    end
                end

                ::continue::
            end
        end
    end

    -- 处理选择结果
    if Multi.MultiActors:Num() > 0 then
        self.modelManage.ModelSelect[Multi.modelType](Multi, self)
        self:ShowSel(Multi)
    else
        Multi:K2_DestroyActor()
    end
end

--- 点选增加模型到多选
function M:MultipleChoicesAdd()
    self.AppendActor = nil
    local start, endP = Model.GetLineValue(self.pc)
    local hitRes = UE.FHitResult()

    -- 执行射线检测
    UE.UKismetSystemLibrary.LineTraceSingle(
        self:GetWorld(), start, endP,
        UE.ETraceTypeQuery.Model, false, nil, 0, hitRes, true)

    -- 处理命中结果
    if hitRes.HitObjectHandle.Actor and hitRes.HitObjectHandle.Actor.bMove then
        local actor = hitRes.HitObjectHandle.Actor
        -- RegionInner 模式下：仅允许追加协作区域内的模型（否则给出提示）
        if self.drawMode == M.DrawMode.RegionInner and not self:IsRegionInnerLocked() then
            local isInsideAnyRegion = false
            for regionActor, polygon in pairs(self.polygons) do
                local ok, inside = pcall(self.modelManage.IsActorFullyInsideRegion,
                    self.modelManage,
                    regionActor,
                    actor,
                    polygon)
                if ok and inside then
                    isInsideAnyRegion = true
                    break
                end
            end
            if isInsideAnyRegion then
                self.AppendActor = actor
            else
                if self.ui and self.ui.ShowModelTip then
                    self.ui:UECallWeb("ShowMessage", { Type = 2, Text = "只能选择协作区域内的模型" })
                end
            end
        else
            self.AppendActor = actor
        end
    end
end

--- 添加单个模型到选择集
function M:AppendSelectActor(actor)
    if not self.buildActor then
        if self.Changes then
            self.modelManage.ModelSelect[actor.modelType](actor, self)
            self:ModelDataToView(false)
            self:ShowSel(actor)
        end

        return
    end

    -- 处理不同类型的选择状态
    if self.buildActor.modelType == "Multi" then
        -- 多选容器处理
        if self.buildActor.STCActors:Find(actor) <= 0 and self.Changes then
            local actors = self.buildActor.STCActors
            actors:Add(actor)
            self:StructuralCarding(actors)
        elseif self.buildActor.STCActors:Find(actor) > 0 and not self.Changes then
            local actors = UE.TArray(UE.AActor)()
            actors:Append(self.buildActor.STCActors)
            actors:RemoveItem(actor)

            if actors:Num() == 0 then
                self.modelManage:ModelClear(self)
                self:FloorDataToView()
            elseif actors:Num() == 1 then
                self.modelManage.ModelSelect[actors[1].modelType](actors[1], self)
                self:ModelDataToView(false)
            else
                self:StructuralCarding(actors)
            end
        end
    else
        -- 单个模型处理
        if self.Changes and self.buildActor ~= actor then
            if self.buildActor.bMove then
                local actors = UE.TArray(UE.AActor)()
                actors:Add(actor)

                if self.buildActor.modelType == "Group" then
                    local children = UE.TArray(UE.AActor)()
                    self.buildActor:GetAttachedActors(children, true)
                    for _, child in pairs(children) do
                        local grandchildren = UE.TArray(UE.AActor)()
                        child:GetAttachedActors(grandchildren, true)
                        actors:Append(grandchildren)
                    end
                else
                    actors:Add(self.buildActor)
                end

                self:StructuralCarding(actors)
            else
                self.modelManage.ModelSelect[actor.modelType](actor, self)
                self:ShowSel(actor)
            end
        elseif not self.Changes and self.buildActor == actor then
            self.modelManage:ModelClear(self)
            self:FloorDataToView()
        end
    end
end

--- 添加多个模型到选择集
function M:AppendSelectActors(actors)
    -- 过滤锁定模型
    local filteredActors = actors
    local bRemove = false
    for _, actor in pairs(filteredActors) do
        if self.drawMode == M.DrawMode.RegionInner and not self:IsRegionInnerLocked() then
            local isInsideAnyRegion = false
            for regionActor, polygon in pairs(self.polygons) do
                local ok, inside = pcall(self.modelManage.IsActorFullyInsideRegion,
                    self.modelManage,
                    regionActor,
                    actor,
                    polygon)
                if ok and inside then
                    isInsideAnyRegion = true
                    break
                end
            end
            if not isInsideAnyRegion then
                filteredActors:RemoveItem(actor)
                bRemove = true
            end
        end
        if not actor.bMove then
            filteredActors:RemoveItem(actor)
        end
    end
    if bRemove then
        self.ui:UECallWeb("ShowMessage", { Type = 2, Text = "已剔除不在协作区域内的模型" })
    end

    if filteredActors:Num() <= 0 then return end

    -- 根据当前选择类型处理
    if self.buildActor.modelType == "Multi" then
        local newActors = UE.TArray(UE.AActor)
        newActors:Append(self.buildActor.STCActors)

        if self.Changes then
            newActors:Append(filteredActors)
        else
            for _, actor in pairs(filteredActors) do
                if newActors:Find(actor) > 0 then
                    newActors:RemoveItem(actor)
                    if newActors:Num() == 0 then
                        self.modelManage:ModelClear(self)
                        return
                    end
                end
            end
        end

        if newActors:Num() == 1 then
            self.modelManage.ModelSelect[newActors[1].modelType](newActors[1], self)
            self:ModelDataToView(false)
        else
            self:StructuralCarding(newActors)
        end
    elseif self.buildActor.modelType == "Group" then
        -- 组模型处理
        if not self.buildActor.bMove then
            self:StructuralCarding(filteredActors)
            return
        end

        local allActors = UE.TArray(UE.AActor)()
        local children = UE.TArray(UE.AActor)()
        self.buildActor:GetAttachedActors(children, true)

        for _, child in pairs(children) do
            local grandchildren = UE.TArray(UE.AActor)()
            child:GetAttachedActors(grandchildren, true)
            allActors:Append(grandchildren)
        end

        if self.Changes then
            allActors:Append(filteredActors)
        else
            for _, actor in pairs(filteredActors) do
                if allActors:Find(actor) > 0 then
                    allActors:RemoveItem(actor)
                end

                if allActors:Num() == 0 then
                    self.modelManage:ModelClear(self)
                    return
                end
            end
        end

        self:StructuralCarding(allActors)
    else
        -- 单个模型处理
        if self.buildActor.bMove then
            if self.Changes then
                filteredActors:Add(self.buildActor)
                self:StructuralCarding(filteredActors)
            else
                if filteredActors:Find(self.buildActor) > 0 then
                    self.modelManage:ModelClear(self)
                end
            end
        else
            self:StructuralCarding(filteredActors)
        end
    end
end

--- 创建多选模型容器
function M:MultiModels(actors)
    if actors:Num() > 0 then
        local multi = self.modelManage.ModelCreate["Multi"]()
        multi.MultiActors = actors
        self.modelManage.ModelSelect[multi.modelType](multi, self)
        self:ShowSel(multi)
    end
end

--- 模型树管理系统
-- 提供模型层级结构的遍历、搜索、选择和锁定功能

--- 获取 RegionInnerActors 映射表
--- @return table regionInnerMap Actor ID 到 Actor 的映射表
function M:_GetRegionInnerMap()
    if not self.modelManage or not self.modelManage.RegionInnerActors then
        return {}
    end

    local regionInnerMap = {}
    local total, validN, excludedId1N = 0, 0, 0
    -- for name, actor in pairs(self.modelManage.RegionInnerActors) do
    --     total = total + 1
    --     if actor and UE.UKismetSystemLibrary.IsValid(actor) then
    --         local actorID = Model.GetActorAccurateDisplayName(actor)
    --         -- 输出树时不需要 ID=1 的模型（actor 名称 "_" 前的前缀为 1）
    --         if actorID == "1" then
    --             excludedId1N = excludedId1N + 1
    --         else
    --             regionInnerMap[actorID] = actor
    --             validN = validN + 1
    local num = self.modelManage.RegionInnerActors:Num()
    local names = self.modelManage.RegionInnerActors:Keys()
    if num > 0 then
        for i = 1, num do
            total = total + 1
            local name = names[i]
            local actor = self.modelManage.RegionInnerActors:Find(name)
            if actor and UE.UKismetSystemLibrary.IsValid(actor) then
                local actorID = Model.GetActorAccurateDisplayName(actor)
                -- 输出树时不需要 ID=1 的模型（actor 名称 "_" 前的前缀为 1）
                if actorID == "1" then
                    excludedId1N = excludedId1N + 1
                else
                    regionInnerMap[actorID] = actor
                    validN = validN + 1
                end
            end
        end
    end

    local mapN = 0
    for _ in pairs(regionInnerMap) do
        mapN = mapN + 1
    end

    -- self:_RIDbg("_GetRegionInnerMap: RegionInnerActors pairs=" .. tostring(total) ..
    --     " valid=" .. tostring(validN) ..
    --     " excludedId1=" .. tostring(excludedId1N) ..
    --     " mapSize=" .. tostring(mapN))
    return regionInnerMap
end

--- 检查 Actor 是否在 RegionInnerActors 映射中
--- @param actor AActor 要检查的 Actor
--- @return boolean 是否在映射中
function M:_IsActorInRegionInner(actor)
    if self.drawMode ~= M.DrawMode.RegionInner then
        return true -- 非 RegionInner 模式，允许所有操作
    end

    if not actor or not UE.UKismetSystemLibrary.IsValid(actor) then
        return false
    end

    if not self.modelManage or not self.modelManage.RegionInnerActors then
        return false
    end

    local actorID = Model.GetActorAccurateDisplayName(actor)
    local regionInnerMap = self:_GetRegionInnerMap()
    return regionInnerMap[actorID] ~= nil
end

--- 导出树形结构数据
function M:TreeDataOut()
    -- RegionInner 模式：使用 RegionInnerActors 的数据构建树形结构
    if self.drawMode == M.DrawMode.RegionInner then
        self.treeT = {}
        self._riLogCount = 0
        -- 让 ModelManage 侧也能跟随输出调试信息（如果它有用到）
        if self.modelManage then
            self.modelManage.bRegionInnerDebug = self.bRegionInnerDebug
        end

        local riPairs = self.modelManage.RegionInnerActors:Num()

        -- self:_RIDbg("TreeDataOut enter: drawMode=RegionInner RegionInnerActorsPairs=" .. tostring(riPairs))

        -- 创建一个映射，用于快速查找 Actor 是否在 RegionInnerActors 中
        local regionInnerMap = self:_GetRegionInnerMap()

        -- 找出所有顶级节点（没有父对象在 RegionInnerActors 中的节点）
        local topLevelActors = {}
        local iterN, invalidN, nonGroupN, excludedFloorN, hasParentInMapN = 0, 0, 0, 0, 0
        -- for name, actor in pairs(self.modelManage.RegionInnerActors) do
        --     iterN = iterN + 1
        --     if actor and UE.UKismetSystemLibrary.IsValid(actor) then
        --         local parentActor = actor:GetAttachParentActor()
        --         local isTopLevel = true

        --         -- 检查父对象是否在 RegionInnerActors 中
        --         if parentActor and UE.UKismetSystemLibrary.IsValid(parentActor) then
        --             local parentID = Model.GetActorAccurateDisplayName(parentActor)
        --             if regionInnerMap[parentID] then
        --                 isTopLevel = false
        --                 hasParentInMapN = hasParentInMapN + 1
        --             end
        --         end

        local num = self.modelManage.RegionInnerActors:Num()
        local names = self.modelManage.RegionInnerActors:Keys()
        if num > 0 then
            for i = 1, num do
                iterN = iterN + 1
                local name = names[i]
                local actor = self.modelManage.RegionInnerActors:Find(name)


                -- if isTopLevel then
                --     local actorID = Model.GetActorAccurateDisplayName(actor)
                --     -- 输出时过滤 ID=1 的模型
                --     if actorID == "1" then
                --         -- continue
                --     else
                --         -- 只处理 Group 类型的节点
                --         local isGroup = actor:Cast(LoadClass(self.modelManage.class["Group"])) ~= nil
                --         if not isGroup then
                --             nonGroupN = nonGroupN + 1
                --         end

                --         local isExcluded = (actor == self.modelManage:FindActor("1Floor")) or
                --             (actor == self.modelManage:FindActor("1BZ"))
                --         if isExcluded then
                --             excludedFloorN = excludedFloorN + 1
                if actor and UE.UKismetSystemLibrary.IsValid(actor) then
                    local parentActor = actor:GetAttachParentActor()
                    local isTopLevel = true

                    -- 检查父对象是否在 RegionInnerActors 中
                    if parentActor and UE.UKismetSystemLibrary.IsValid(parentActor) then
                        local parentID = Model.GetActorAccurateDisplayName(parentActor)
                        if regionInnerMap[parentID] then
                            isTopLevel = false
                            hasParentInMapN = hasParentInMapN + 1
                        end
                    end

                    if isTopLevel then
                        local actorID = Model.GetActorAccurateDisplayName(actor)
                        -- 输出时过滤 ID=1 的模型
                        if actorID == "1" then
                            -- continue
                        else
                            -- 只处理 Group 类型的节点
                            local isGroup = actor:Cast(LoadClass(self.modelManage.class["Group"])) ~= nil
                            if not isGroup then
                                nonGroupN = nonGroupN + 1
                            end


                            -- if isGroup and (not isExcluded) then
                            --     table.insert(topLevelActors, actor)
                            --     self:_RIDbg("topLevel + " .. tostring(actorID))
                            local isExcluded = (actor == self.modelManage:FindActor("1Floor")) or
                                (actor == self.modelManage:FindActor("1BZ"))
                            if isExcluded then
                                excludedFloorN = excludedFloorN + 1
                            end

                            if isGroup and (not isExcluded) then
                                table.insert(topLevelActors, actor)
                                -- self:_RIDbg("topLevel + " .. tostring(actorID))
                            end
                        end
                    end
                else
                    invalidN = invalidN + 1
                end
                -- else
                --     invalidN = invalidN + 1
            end
        end

        -- self:_RIDbg("topLevel summary: iter=" .. tostring(iterN) ..
        --     " invalid=" .. tostring(invalidN) ..
        --     " nonGroup=" .. tostring(nonGroupN) ..
        --     " excluded(1Floor/1BZ)=" .. tostring(excludedFloorN) ..
        --     " hasParentInMap=" .. tostring(hasParentInMapN) ..
        --     " topLevelCount=" .. tostring(#topLevelActors))

        -- 为每个顶级节点构建树形结构
        -- for _, actor in pairs(topLevelActors) do
        --     local treeData = self:TreeData(actor)
        --     self:TreeChildRegionInner(actor, treeData, regionInnerMap)
        local topLevelNum = #topLevelActors
        if topLevelNum > 0 then
            for i = 1, topLevelNum do
                local actor = topLevelActors[i]
                local treeData = self:TreeData(actor)
                self:TreeChildRegionInner(actor, treeData, regionInnerMap)

                table.insert(self.treeT, treeData)
            end
        end

        -- 排序树节点(按时间降序)
        table.sort(self.treeT, function(a, b)
            return a.time > b.time
        end)
    else
        -- 默认模式：获取根节点并构建树结构
        local rootActor = self.modelManage:FindActor("1")
        local treeData = self:TreeData(rootActor)
        self:TreeChild(rootActor, treeData)

        -- 排序树节点(按时间降序)
        self.treeT = treeData.Childs
        table.sort(self.treeT, function(a, b)
            return a.time > b.time
        end)
    end

    -- 计算当前选中模型的分页位置
    local pageIndex = 0
    if self.buildActor then
        local targetActor = self.buildActor
        -- 处理不同类型模型的父节点获取
        if self.buildActor.modelType == "Multi" then
            targetActor = self.buildActor.MultiActors[1]
        elseif self.buildActor.modelType ~= "Group" then
            targetActor = self.buildActor:GetAttachParentActor()
        end

        local actorID = Model.GetActorAccurateDisplayName(targetActor)
        local position = self:TreeFind(actorID)
        pageIndex = math.ceil(position / 50) - 1
    end

    -- 发送分页数据到UI
    local pageData = self:TakeRange(pageIndex, true)
    self.ui:UECallWeb("OutTree", pageData)
    self.ui:UECallWeb("getPageSize", { size = pageIndex })
    self:OutModelNum()
end

function M:OutModelNum()
    self.ui:UECallWeb("OutModelNum", { modelNum = self.modelManage:GetModelNum() })
end

--- 在树结构中查找模型位置
function M:TreeFind(id)
    for k, v in pairs(self.treeT) do
        if v.ID == id then
            return k
        end

        -- 检查子节点
        for _, child in pairs(v.Childs) do
            if child.ID == id then
                return k
            end
        end
    end

    return 0
end

--- 获取分页范围内的数据
function M:TakeRange(rangeIndex, isNormal)
    rangeIndex = rangeIndex or 0
    local result = {}
    local startIdx = rangeIndex * 50 + 1
    local endIdx = rangeIndex * 50 + 50
    local sourceTable = isNormal and self.treeT or self.searchT

    if sourceTable then
        for i = startIdx, math.min(endIdx, #sourceTable) do
            result[i - startIdx + 1] = sourceTable[i]
        end
    end

    return result
end

--- 搜索模型树
function M:TreeSearch(searchStr)
    self.searchT = {}

    if searchStr == "" then
        self.searchT = self.treeT
    else
        -- 为中文字符匹配做优化：使用简单字符串匹配而非模式匹配
        for _, node in pairs(self.treeT) do
            -- 检查节点名称匹配
            if string.find(node.showName, searchStr, 1, true) then
                table.insert(self.searchT, node)
            else
                -- 检查子节点名称匹配
                for _, child in pairs(node.Childs) do
                    if string.find(child.showName, searchStr, 1, true) then
                        table.insert(self.searchT, node)
                        break
                    end
                end
            end
        end
    end

    return self:TakeRange(0, false)
end

--- 递归构建子节点树
function M:TreeChild(parentActor, parentTable)
    local children = UE.TArray(UE.AActor)
    parentActor:GetAttachedActors(children, true)

    for _, child in pairs(children) do
        -- 过滤特定类型的子节点
        if child:Cast(LoadClass(self.modelManage.class["Group"])) and
            not (child == self.modelManage:FindActor("1Floor")) and
            not (child == self.modelManage:FindActor("1BZ")) then
            local childData = self:TreeData(child)
            self:TreeChild(child, childData)
            table.insert(parentTable.Childs, childData)

            -- 更新节点状态
            childData = self:CheckTree(childData)
            child.bMove = childData.bMove
            child.RootComponent:SetVisibility(childData.bVisit, false)
        end
    end
end

--- RegionInner 模式：递归构建子节点树（只包含 RegionInnerActors 中的节点）
function M:TreeChildRegionInner(parentActor, parentTable, regionInnerMap)
    local children = UE.TArray(UE.AActor)
    parentActor:GetAttachedActors(children, true)

    for _, child in pairs(children) do
        -- 检查子节点是否在 RegionInnerActors 中
        local childID = Model.GetActorAccurateDisplayName(child)
        if regionInnerMap[childID] then
            -- 过滤特定类型的子节点
            if child:Cast(LoadClass(self.modelManage.class["Group"])) and
                not (child == self.modelManage:FindActor("1Floor")) and
                not (child == self.modelManage:FindActor("1BZ")) then
                local childData = self:TreeData(child)
                self:TreeChildRegionInner(child, childData, regionInnerMap)
                table.insert(parentTable.Childs, childData)
                -- self:_RIDbg("attach child Group + " .. tostring(childID) .. " -> parent=" ..
                --     tostring(Model.GetActorAccurateDisplayName(parentActor)))

                -- 更新节点状态
                childData = self:CheckTree(childData)
                child.bMove = childData.bMove
                child.RootComponent:SetVisibility(childData.bVisit, false)
            end
        else
            -- 这个 child 不在 RegionInnerActors 里：树不会挂它
            -- self:_RIDbg("skip child(not in map): " .. tostring(childID) .. " parent=" ..
            --     tostring(Model.GetActorAccurateDisplayName(parentActor)))
        end
    end
end

--- 创建树节点数据
function M:TreeData(actor)
    return {
        showName = actor.showName,
        handle = actor.bhandle == nil and true or actor.bhandle,
        ID = Model.GetActorAccurateDisplayName(actor),
        bMove = actor.bMove == nil and true or actor.bMove,
        bVisit = actor.RootComponent:IsVisible(),
        time = actor.time or 0,
        Childs = {}
    }
end

--- 检查并统一子树状态
function M:CheckTree(tree)
    local moveState, visitState
    local moveConsistent, visitConsistent = true, true

    for _, child in pairs(tree.Childs) do
        -- 检查状态一致性
        if moveState ~= child.bMove then
            if moveConsistent then
                moveState = moveState or child.bMove
                moveConsistent = false
            end
        end

        if visitState ~= child.bVisit then
            if visitConsistent then
                visitState = visitState or child.bVisit
                visitConsistent = false
            end
        end
    end

    -- 更新父节点状态
    if moveConsistent and moveState ~= nil then
        tree.bMove = moveState
    end

    if visitConsistent and visitState ~= nil then
        tree.bVisit = visitState
    end

    return tree
end

--- 处理UI选择的模型
function M:WebSelActor(selection)
    if not self.bBuild then
        self.modelManage:ModelClear(self)

        if selection then
            if #selection == 1 then
                -- 单个模型选择
                local actor = self.modelManage:FindActor(selection[1].ID)
                if not actor.bGroup then
                    actor = actor:GetAttachedActors()[1]
                end

                if actor ~= self.buildActor then
                    self.modelManage.ModelSelect[actor.modelType](actor, self)
                    self:ModelDataToView(true)
                    return actor
                end
            elseif #selection >= 2 then
                -- 多个模型选择
                local selectedActors = UE.TArray(UE.AActor)
                for _, item in pairs(selection) do
                    local actor = self.modelManage:FindActor(item.ID)

                    if string.find(item.ID, "Group") == nil then
                        -- 非组模型处理
                        local children = UE.TArray(UE.AActor)
                        actor:GetAttachedActors(children, true)
                        if selectedActors:Find(children[1]) <= 0 then
                            selectedActors:Append(children)
                        end
                    else
                        -- 组模型处理
                        local children = UE.TArray(UE.AActor)
                        actor:GetAttachedActors(children, true)
                        for _, child in pairs(children) do
                            local grandChildren = UE.TArray(UE.AActor)
                            child:GetAttachedActors(grandChildren, true)
                            if selectedActors:Find(grandChildren[1]) <= 0 then
                                selectedActors:Append(grandChildren)
                            end
                        end
                    end
                end

                self:StructuralCarding(selectedActors)
            end
        end
    end
end

--- 锁定/解锁模型
function M:WebLockActor(actorID, lockState)
    local actor = self.modelManage:FindActor(actorID)
    local parent = actor:GetAttachParentActor()
    local canProceed = true

    -- 检查父节点锁定状态
    if parent and parent.bMove == false and lockState == true then
        canProceed = false
    end

    if canProceed then
        actor.bMove = lockState
        self:RecursionLock(actor, lockState)
        self:TreeDataOut()

        if self.buildActor then
            self.modelManage.ModelSelect[self.buildActor.modelType](self.buildActor, self)
            self:ShowSel(self.buildActor)
            self:ModelDataToView(true)
        end
    else
        return { Masseage = "nochange" }
    end
end

--- 递归设置锁定状态
function M:RecursionLock(actor, lockState)
    local children = UE.TArray(UE.AActor)
    actor:GetAttachedActors(children, true)

    for _, child in pairs(children) do
        child.bMove = lockState
        if child == self.buildActor then
            self.modelManage.ModelSelect[child.modelType](child, self)
        end

        self:RecursionLock(child, lockState)
    end
end

--- 显示当前选中模型
function M:ShowSel(actor)
    local selectionData = {}

    if actor then
        if actor.modelType == "Multi" then
            -- 多选模型处理
            for _, subActor in pairs(actor.MultiActors) do
                local item = {}
                if subActor.modelType == "Group" then
                    item.id = Model.GetActorAccurateDisplayName(subActor)
                else
                    item.id = Model.GetActorAccurateDisplayName(subActor:GetAttachParentActor())
                end

                table.insert(selectionData, item)
            end
        elseif actor.modelType == "Group" then
            -- 组模型处理
            selectionData.id = Model.GetActorAccurateDisplayName(actor)
        else
            -- 单个模型处理
            selectionData.id = Model.GetActorAccurateDisplayName(actor:GetAttachParentActor())
        end
    else
        selectionData = { id = Json.null }
    end

    self.ui:ShowSel(selectionData)
end

--- 设置模型材质
function M:SetModelMaterial(materialData)
    if self.buildActor and DFL.modelMaterial[self.buildActor.modelCode] then
        self.buildActor:GetMaterialData(materialData)
    end
end

--- 相机背景与材质控制系统(老的自定义代码未使用)
-- 提供相机背景显示/隐藏、材质设置等功能

--- 显示或隐藏相机背景
-- @param bShow boolean 是否显示背景
function M:ShwoBG(bShow)
    -- 参数校验
    if not self.pawn:IsValid() or not self.pawn.BG:IsValid() then
        print("警告：无效的pawn或背景组件")
        return
    end

    -- 设置背景可见性
    self.pawn.BG:SetVisibility(bShow, true)

    -- 确保使用动态材质实例
    local mat = self.pawn.BG:GetMaterial(0)
    if not mat:Cast(UE.UMaterialInstanceDynamic) then
        local matInstance = self.pawn.BG:CreateDynamicMaterialInstance(0, mat)
        if matInstance then
            self.pawn.BG:SetMaterial(0, matInstance)
        else
            print("错误：创建动态材质实例失败")
        end
    end
end

--- 设置背景类型（颜色或纹理）
-- @param rgba FLinearColor 顶部颜色
-- @param rgbb FLinearColor 底部颜色
-- @param bT boolean 是否使用纹理
-- @param texUrl UTexture 背景纹理
function M:SetBGT(rgba, rgbb, bT, texUrl)
    -- 参数安全检查
    if not self.pawn:IsValid() or not self.pawn.BG:IsValid() then
        print("警告：无效的pawn或背景组件")
        return
    end

    local mat = self.pawn.BG:GetMaterial(0)
    local matInstance = mat:Cast(UE.UMaterialInstanceDynamic)
    if not matInstance then
        print("错误：无法获取动态材质实例")
        return
    end

    -- 设置材质参数
    matInstance:SetScalarParameterValue("bTex", bT and 1 or 0)

    if bT and texUrl then
        -- 纹理模式
        if texUrl:IsValid() then
            matInstance:SetTextureParameterValue("Tex", texUrl)
        else
            print("警告：无效的背景纹理")
        end
    else
        -- 颜色渐变模式
        if rgba and rgbb then
            matInstance:SetVectorParameterValue("CT", rgba)
            matInstance:SetVectorParameterValue("CB", rgbb)
        else
            print("警告：无效的颜色参数")
        end
    end
end

--- 设置建筑模型材质
-- @param material UMaterialInterface 要应用的材质
function M:SetBM(material)
    -- 参数和状态检查
    if not self.buildActor:IsValid() then return end

    if not material or not material:IsValid() then
        print("警告：无效的材质")
        return
    end

    -- 检查模型是否在可修改材质列表中
    if self.modelManage.BMMs:Find(self.buildActor.modelCode) then
        -- 根据建筑类型设置材质
        if self.buildActor.clickType == 2 then
            -- 处理复杂模型（双面材质）
            if self.buildActor.PMesh:IsValid() then
                self.buildActor.PMesh:SetMaterial(0, material)
                self.buildActor.PMesh:SetMaterial(1, material)
            end
        else
            -- 处理简单模型
            if self.buildActor.StaticMeshComponent:IsValid() then
                self.buildActor.StaticMeshComponent:SetMaterial(0, material)
            end
        end
    end
end

--- 区域使用率计算模块
-- 提供多边形区域内物体占用面积的计算功能

--- 计算并输出区域使用率
-- @return table 包含区域名称、总面积和使用率的表格
function M:AreaUsageRateOut()
    -- 检查当前建筑是否为区域类型(Type=6)
    if self.buildActor and (self.buildActor.modelType == 6 or self.buildActor.modelType == "RegionArea") then
        local areaActor = self.buildActor

        -- 获取样条线路径的所有顶点
        local num = areaActor.SplineAsPath:GetNumberOfSplinePoints()
        local vs = UE.TArray(UE.FVector)
        for i = 1, num do
            local pv = areaActor.SplineAsPath:GetLocationAtSplinePoint(i - 1, 0)
            vs:Add(pv)
        end

        -- 获取区域边界框
        local o, b = areaActor:GetActorBounds(true)
        b.Z = b.Z * 2 -- 扩展Z轴检测范围

        -- 执行盒体碰撞检测
        local outHits = UE.TArray(UE.FHitResult())
        local ignoreActors = UE.TArray(UE.AActor)
        ignoreActors:Add(areaActor)
        -- 增加关联模型到忽略列表
        local associativeModel = self.modelManage:FindActor(areaActor.associativeModel)
        if associativeModel then
            ignoreActors:Add(associativeModel)
        end

        UE.UKismetSystemLibrary.BoxTraceMulti(
            self:GetWorld(), o, o, b, UE.FRotator(0, 0, 0),
            UE.ETraceTypeQuery.Model, true, ignoreActors, 0, outHits, true
        )

        -- 收集碰撞到的物体
        local hAs = UE.TArray(UE.AActor)
        for _, value in pairs(outHits) do
            hAs:Add(value.HitObjectHandle.Actor)
        end

        -- 计算使用率
        local area, areaUsageRate = self:CalculatePolygonFloorAreaUsage(vs, hAs)

        -- 构造返回数据
        local result = {
            areaName = areaActor:GetAttachParentActor().showName,
            area = DFL.integrate(area),                          -- 格式化面积数值
            spaceRate = DFL.integrate(areaUsageRate * 1000) / 10 -- 计算百分比(保留1位小数)
        }

        -- 更新UI显示
        self.ui.B_Area:SetVisibility(4)
        self.ui.T_value:SetText(result.spaceRate .. "%")

        return result
    else
        -- 非区域类型时的UI提示
        self.ui.B_Area:SetVisibility(4)
        self.ui.T_value:SetText("请选择场地")
    end
end

-- 计算不规则多边形的面积
function M:CalculateIrregularPolygonArea(PolygonVertices)
    -- 初始化面积
    local Area = 0.0

    -- 获取多边形顶点数量
    local NumVertices = PolygonVertices:Num()

    -- 遍历多边形的每个顶点
    for i = 1, NumVertices do
        -- 获取当前顶点和下一个顶点的坐标
        local CurrentVertex = PolygonVertices[i]
        local NextVertex = PolygonVertices[(i % NumVertices) + 1] -- 如果是最后一个顶点，则下一个顶点是第一个顶点

        -- 计算当前顶点与下一个顶点的叉积并累加到面积中
        Area = Area + (NextVertex.x - CurrentVertex.x) * (NextVertex.y + CurrentVertex.y)
    end

    -- 最终面积为叉积的绝对值的一半
    Area = math.abs(Area) * 0.5

    -- 返回多边形的面积
    return Area
end

-- 计算多边形地板的面积使用率
function M:CalculatePolygonFloorAreaUsage(FloorVertices, CoveringObjects)
    -- 计算地板的总面积
    local TotalFloorArea = self:CalculateIrregularPolygonArea(FloorVertices)
    if TotalFloorArea <= 0 then
        return 0, 0
    end

    -- 获取所有覆盖物的矩形边界
    local rectangles = {}
    for _, value in pairs(CoveringObjects) do
        if value.clickType == 1 then
            local O, B = value:GetActorBounds(true)
            if B ~= UE.FVector(0, 0, 0) then
                table.insert(rectangles, {
                    left = O.X - B.X,
                    bottom = O.Y - B.Y,
                    right = O.X + B.X,
                    top = O.Y + B.Y
                })
            end
        end
    end

    -- 计算覆盖面积
    local CoveredFloorArea = self:CalculateUnionArea(rectangles)

    -- 计算面积使用率
    local AreaUsageRate = CoveredFloorArea / TotalFloorArea

    return TotalFloorArea, AreaUsageRate
end

function M:CalculateUnionArea(rectangles)
    -- 事件点：矩形的上下边界
    local events = {}
    for _, rect in ipairs(rectangles) do
        table.insert(events, { y = rect.bottom, type = "start", rect = rect })
        table.insert(events, { y = rect.top, type = "end", rect = rect })
    end

    -- 按 y 坐标排序事件点
    table.sort(events, function(a, b)
        return a.y < b.y
    end)

    -- 当前激活的矩形
    local activeRects = {}
    local totalArea = 0
    local prevY = nil

    -- 扫描线算法
    for _, event in ipairs(events) do
        local currY = event.y

        -- 计算当前激活矩形的覆盖宽度
        if prevY and currY > prevY then
            local width = self:CalculateCoveredWidth(activeRects)
            local height = currY - prevY
            totalArea = totalArea + width * height
        end

        -- 更新激活矩形列表
        if event.type == "start" then
            table.insert(activeRects, event.rect)
        else
            for i, rect in ipairs(activeRects) do
                if rect == event.rect then
                    table.remove(activeRects, i)
                    break
                end
            end
        end

        prevY = currY
    end

    return totalArea
end

-- 计算当前激活矩形的覆盖宽度
function M:CalculateCoveredWidth(activeRects)
    if #activeRects == 0 then
        return 0
    end

    -- 将矩形的左右边界作为事件点
    local events = {}
    for _, rect in ipairs(activeRects) do
        table.insert(events, { x = rect.left, type = "start" })
        table.insert(events, { x = rect.right, type = "end" })
    end

    -- 按 x 坐标排序事件点
    table.sort(events, function(a, b)
        return a.x < b.x
    end)

    -- 计算覆盖宽度
    local width = 0
    local prevX = nil
    local count = 0

    for _, event in ipairs(events) do
        if count > 0 and prevX and event.x > prevX then
            width = width + (event.x - prevX)
        end

        if event.type == "start" then
            count = count + 1
        else
            count = count - 1
        end

        prevX = event.x
    end

    return width
end

--- 模型下载管理器
-- 提供模型文件的下载、解压和状态跟踪功能

--- 检查模型文件是否存在
-- @param downModelName string 模型文件名（含扩展名）
-- @return boolean 文件是否存在
-- @return string 模型完整本地路径
function M:DownModelTrace(downModelName)
    local path = UE.UBlueprintPathsLibrary.ProjectDir() .. "model/" .. downModelName
    local bExists = UE.UBlueprintPathsLibrary.FileExists(path)
    return bExists, path
end

--- 批量检查并下载模型文件
-- @param Table table 模型信息表，每个元素需包含modelUrl字段
-- @return table 需要下载的模型列表
function M:DownloadTrace(Table)
    self.downT = {} -- 待下载队列

    -- 遍历模型列表检查本地是否存在
    for _, value in pairs(Table) do
        if value.modelUrl then
            -- 从URL提取文件名（支持复杂路径格式）
            local downModelName = string.match(value.modelUrl, ".-([^\\/]-%.?[^%.\\/]*)$")
            local bExists, path = self:DownModelTrace(downModelName)

            if not bExists then
                value.path = path -- 记录本地存储路径
                table.insert(self.downT, value)
            end
        end
    end

    -- 启动下载队列处理
    if #self.downT > 0 then
        self:DownloadModel(self.downT[1].path, self.downT[1].modelUrl, false)
    end

    return self.downT
end

--- 执行单个模型下载
-- @param path string 本地存储路径
-- @param partUrl string 模型相对URL
-- @param bActive boolean 是否为主动下载模式
function M:DownloadModel(path, partUrl, bActive)
    -- 构造完整下载URL
    local url = UE.UMyBFL.GetExeURL("RearIP") .. partUrl

    -- 根据模式选择下载配置
    if bActive then
        -- 主动下载模式（用户触发）
        self.activeSavePath = path
        self.activeDownloader = UE.UFileToStorageDownloader.DownloadFileToStorage(
            url, self.activeSavePath, 0, "", false,
            { self, self.ActiveProgress }, -- 进度回调
            { self, self.ActiveComplete }  -- 完成回调
        )
    else
        -- 被动下载模式（后台自动）
        self.passivitySavePath = path
        self.passivityDownloader = UE.UFileToStorageDownloader.DownloadFileToStorage(
            url, self.passivitySavePath, 0, "", false,
            { self, self.PassivityProgress },
            { self, self.PassivityComplete }
        )
    end
end

function M:CancelDownload(bActive)
    if bActive then
        if self.activeDownloader and self.activeDownloader:IsValid() then
            self.activeDownloader:CancelDownload()
            self.activeDownloader = nil
        end
    else
        if self.passivityDownloader and self.passivityDownloader:IsValid() then
            self.passivityDownloader:CancelDownload()
            self.passivityDownloader = nil
        end
    end
end

--- 主动下载进度回调（空实现）
function M:ActiveProgress(BytesReceived, ContentLength)
    -- 可扩展进度显示逻辑
end

--- 主动下载完成回调
-- @param Result number 下载结果（0为成功）
function M:ActiveComplete(Result)
    if Result == 0 then
        self:TrackFileExtension(true) -- 处理下载文件
    else
        -- 转换错误码并通知UI
        self.ui:DownloadFeedback(UE.UKismetMathLibrary.Conv_ByteToInt(Result))
    end
end

--- 被动下载进度回调（空实现）
function M:PassivityProgress(BytesReceived, ContentLength)
    -- 可扩展进度显示逻辑
end

--- 被动下载完成回调
-- @param Result number 下载结果（0为成功）
function M:PassivityComplete(Result)
    if not self.downT then return end

    if Result == 0 then
        self:TrackFileExtension(false)                             -- 处理下载文件
        self.modelManage:LoadDownloadModel(self.passivitySavePath) -- 加载模型
        self.ui:DownloadOver(self.downT[1])                        -- 通知UI完成
    else
        self.ui:DownloadFeedback(UE.UKismetMathLibrary.Conv_ByteToInt(Result))
    end

    -- 处理下载队列
    table.remove(self.downT, 1)
    if #self.downT > 0 then
        self:DownloadModel(self.downT[1].path, self.downT[1].modelUrl, false)
    end
end

--- 文件扩展名处理路由
-- @param bActive boolean 是否为主动下载模式
function M:TrackFileExtension(bActive)
    local path = bActive and self.activeSavePath or self.passivitySavePath
    local Extension = string.match(path, "^.+(%..+)$") -- 提取文件扩展名

    if Extension == ".zip" then
        local DirectoryPath = string.match(path, "(.*)(%.%w+)$") -- 去除扩展名的路径

        -- 创建解压任务
        local Unarchive = UE.URuntimeArchiverUnarchiveAsyncTask.UnarchiveDirectory(
            UE.URuntimeArchiverZip, path, nil, DirectoryPath, false, true)

        -- 绑定回调
        if bActive then
            Unarchive.OnSuccess:Add(self, self.ActiveUnarchive)
        else
            Unarchive.OnSuccess:Add(self, self.PassivityUnarchive)
        end

        Unarchive.OnFail:Add(self, self.UnarchiveFail)
        Unarchive:Activate()
    else
        self.ui:DownloadFeedback(6) -- 不支持的文件格式
    end
end

--- 主动解压成功回调
function M:ActiveUnarchive()
    self.ui:DownloadFeedback(0) -- 通知成功
end

--- 被动解压成功回调
function M:PassivityUnarchive()
    self.ui:DownloadFeedback(0) -- 通知成功
end

--- 解压失败回调
function M:UnarchiveFail()
    self.ui:DownloadFeedback(7) -- 解压失败错误码
end

---------------------------------右键菜单栏 ----------------------------------

function M:ShowMenu()
    local start, endP = Model.GetLineValue(self.pc)
    local outHits = UE.TArray(UE.FHitResult())
    local ignoreActors = UE.TArray(UE.AActor)
    if self.modelManage.gizmo then
        ignoreActors:Add(self.modelManage.gizmo)
    end

    UE.UKismetSystemLibrary.LineTraceMulti(self:GetWorld(), start, endP, UE.ETraceTypeQuery.Visibility, false,
        ignoreActors, 0, outHits, true)
    local bHave = false
    for key, value in pairs(outHits) do
        local hitActor = value.HitObjectHandle.Actor
        if hitActor then
            -- print(UE.UKismetSystemLibrary.GetObjectName(value.Actor))
            if self.buildActor == hitActor then
                bHave = true
            elseif self.buildActor.modelType == "Multi" then
                if self.buildActor.STCActors:Find(hitActor) > 0 then
                    bHave = true
                end

                break
            end
        end
    end

    if bHave then
        local bool, x, y = self.pc:GetMousePosition()
        if bool then
            if self.menuUi then
                self.menuUi:SetPositionInViewport(UE.FVector2D(x, y), true)
            else
                self.menuUi = UE.UWidgetBlueprintLibrary.Create(self:GetWorld(),
                    LoadClass(Class.menuUi), self.pc)
                self.menuUi.control = self
                self.menuUi:AddToViewport()
                -- self.menuUi:SetDesiredSizeInViewport(UE.FVector2D(200, 200))
                self.menuUi:SetPositionInViewport(UE.FVector2D(x, y), true)
            end
        end
    end
end

function M:RemoveMenu()
    if self.menuUi then
        self.menuUi:RemoveFromParent()
        self.menuUi = nil
    end
end

function M:RemoveRename()
    if self.RenameUI then
        self.RenameUI:RemoveFromParent()
        self.RenameUI = nil
    end
end

function M:RenameModels()
    self:RemoveMenu()
    local bool, x, y = self.pc:GetMousePosition()
    if bool then
        if self.RenameUI then
            self:RemoveRename()
        else
            self.RenameUI = UE.UWidgetBlueprintLibrary.Create(self:GetWorld(),
                LoadClass('/Game/SandBox/UI/UI_Rename.UI_Rename_C'), self.pc)
            self.RenameUI.EText.OnTextChanged:Add(self, self.CheckText)
            self.RenameUI.EText.OnTextCommitted:Add(self, self.ModelRename)
            self.RenameUI.EText:SetHintText("请输入新名称（1~8个字节）")
            self.RenameUI:AddToViewport()
            self.RenameUI:SetPositionInViewport(UE.FVector2D(x, y), true)
        end
    end
end

function M:CheckText(Text)
    -- -- 使用正则表达式检查输入是否仅包含中英文字符
    -- local pattern = "^[%u4E00-%u9FA5A-Za-z]+$"
    -- Text = string.match(Text, pattern) -- 仅保留英文字符、中文字符和连字符

    local Name = Text
    if #Text > 8 then
        Name = UE.UKismetStringLibrary.GetSubstring(Name, 0, 8)
        self.RenameUI.EText:SetText(Name)
    end
end

function M:ModelRename(Text)
    if Text == "" then
        return
    end

    if self.buildActor.modelType == "Multi" then
        for key, value in pairs(self.buildActor.MultiActors) do
            local Name = self:ShowNameCheck(Text)
            if value.modelType == "Group" then
                local modelName = Model.GetActorAccurateDisplayName(value)
                self.modelManage:ActorShowNameChange(value, Name)
                if string.find(modelName, "Group") ~= nil then
                    local ChildActors = UE.TArray(UE.AActor)
                    value:GetAttachedActors(ChildActors, true)
                    for ikey, ivalue in pairs(ChildActors) do
                        local showName = self:ShowNameCheck(Text)
                        self.modelManage:ActorShowNameChange(ivalue, showName)
                        -- local CChildActors = UE.TArray(UE.AActor)
                        -- ivalue:GetAttachedActors(CChildActors, true)
                        -- ivalue.showName = Name .. "-" .. ikey
                        -- CChildActors[1].showName = Name .. "-" .. ikey
                    end

                    -- else
                    --     local ChildActors = UE.TArray(UE.AActor)
                    --     value:GetAttachedActors(ChildActors, true)
                    --     ChildActors[1].showName = Name
                end
            else
                -- value.showName = Name
                local P = value:GetAttachParentActor()
                self.modelManage:ActorShowNameChange(P, Name)
            end
        end
    elseif self.buildActor.modelType == "Group" then
        local showName = self:ShowNameCheck(Text)
        self.modelManage:ActorShowNameChange(self.buildActor, showName)
        self:ModelDataToView(false)
    else
        -- self.buildActor.showName = Text
        local P = self.buildActor:GetAttachParentActor()
        local showName = self:ShowNameCheck(Text)
        self.modelManage:ActorShowNameChange(P, showName)
        self:ModelDataToView(false)
    end

    self:TreeDataOut()
    self:ShowSel(self.buildActor)

    self:RemoveRename()
end

function M:HideModels()
    if self.buildActor.modelType == "Multi" then
        for key, value in pairs(self.buildActor.MultiActors) do
            if value.modelType == "Group" then
                value.RootComponent:SetVisibility(false, true)
            else
                local P = value:GetAttachParentActor()
                P.RootComponent:SetVisibility(false, true)
            end
        end
    elseif self.buildActor.modelType == "Group" then
        self.buildActor.RootComponent:SetVisibility(false, true)
    else
        local P = self.buildActor:GetAttachParentActor()
        P.RootComponent:SetVisibility(false, true)
    end

    self.modelManage.ModelCancelSelect[self.buildActor.modelType](self)

    self:RemoveMenu()
    self:TreeDataOut()
end

function M:AllShowModels()
    for key, value in pairs(self.modelManage.Actors) do
        value.RootComponent:SetVisibility(true, true)
    end

    self:RemoveMenu()
    self:TreeDataOut()
end

function M:LockModels()
    self:bLockModels(false)
end

function M:UnlockModels()
    self:bLockModels(true)
end

function M:bLockModels(bMove)
    if self.buildActor.modelType == "Multi" then
        for key, value in pairs(self.buildActor.MultiActors) do
            if value.modelType == "Group" then
                value.bMove = bMove
                self:RecursionLock(value, bMove)
            else
                value.bMove = bMove
                local P = value:GetAttachParentActor()
                P.bMove = bMove
            end
        end

        self:TreeDataOut()
        if bMove then
            self.modelManage.ModelSelect[self.buildActor.modelType](self.buildActor, self)
        else
            self.modelManage.ModelCancelSelect[self.buildActor.modelType](self)
        end
    else
        local ID = Model.GetActorAccurateDisplayName(self.buildActor)
        if string.find(ID, "-s") then
            ID = Model.GetActorAccurateDisplayName(self.buildActor:GetAttachParentActor())
        end

        self:WebLockActor(ID, bMove)
    end

    self:RemoveMenu()
end

function M:WebHideActor(ID, bVisit)
    local A = self.modelManage:FindActor(ID)
    A.RootComponent:SetVisibility(bVisit, true)
    if tostring(ID) == "1" and not bVisit then
        local F = self.modelManage:FindActor("1Floor")
        F.RootComponent:SetVisibility(true, true)
    end

    self.modelManage:ModelClear(self)
    self:TreeDataOut()
end

-- 像素流送禁用
function M:DisableKeyBoard(bDisable)
    if bDisable then
        self.BPI:DisableInput(self.pc)
        self.Mouse_Hold_Left = false
        self.Mouse_Hold_Right = false
        if self.SelectionTimer then
            self:EndSelectionOver()
        end
    else
        self.BPI:EnableInput(self.pc)
    end
end

--- 样条线编辑菜单控制器
-- 提供样条线点位的精确参数化编辑功能

--- 显示样条线编辑菜单
function M:SplineMenu()
    -- 获取当前鼠标位置作为菜单显示位置
    local bool, x, y = self.pc:GetMousePosition()
    print(bool, x, y) -- 调试输出鼠标位置

    -- 创建或更新菜单UI
    if self.splineMenuUi then
        -- 已存在则更新位置
        self.splineMenuUi:SetPositionInViewport(UE.FVector2D(x, y), true)
    else
        -- 创建新菜单控件
        self.splineMenuUi = UE.UWidgetBlueprintLibrary.Create(
            self:GetWorld(),
            LoadClass(Class.splineMenuUi),
            self.pc
        )
        self.splineMenuUi.control = self -- 设置控制器引用
        self.splineMenuUi:AddToViewport()
        self.splineMenuUi:SetPositionInViewport(UE.FVector2D(x, y), true)
    end

    -- 清除可能存在的定时器
    if self.Timer then
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.Timer)
    end

    -- 计算并显示当前线段参数
    local num = self.buildActor.simplePoints:Num()
    local l1 = self.buildActor.simplePoints[num]     -- 最新点
    local l2 = self.buildActor.simplePoints[num - 1] -- 前一个点

    -- 设置高度差（Z轴）
    self.splineMenuUi.SpinBox2:SetText(DFL.integrate(l2.Z - l1.Z))
    l2.Z = l1.Z -- 临时对齐Z轴

    -- 设置两点间距离
    local distance = UE.UKismetMathLibrary.Vector_Distance(l1, l2)
    self.splineMenuUi.SpinBox1:SetText(DFL.integrate(distance))

    -- 计算并设置角度（基于X-Y平面）
    local angleRad = math.acos((l1.X - l2.X) / distance)
    local angleDeg = UE.UKismetMathLibrary.RadiansToDegrees(angleRad)
    if l1.Y <= l2.Y then
        self.splineMenuUi.SpinBox3:SetText(DFL.integrate(angleDeg))
    else
        self.splineMenuUi.SpinBox3:SetText(-DFL.integrate(angleDeg))
    end
end

--- 关闭样条线菜单（保留当前编辑）
function M:ShutdownSplineMenu()
    if self.splineMenuUi then
        -- 移除最后一个点（撤销操作）
        if self.buildActor then
            self.buildActor.simplePoints:Remove(self.buildActor.simplePoints:Num())
        end

        -- 根据模式执行后续操作
        if self.bBuild then
            self:CreateLine()        -- 构建模式下创建新线段
        else
            self:SplinePointSelect() -- 编辑模式下选择点
        end

        -- 清理UI
        self.splineMenuUi:RemoveFromParent()
        self.splineMenuUi = nil
    end
end

--- 直接移除样条线菜单（不保留编辑）
function M:RemoveSplineMenu()
    if self.splineMenuUi then
        self.splineMenuUi:RemoveFromParent()
        self.splineMenuUi = nil
    end
end

--- 应用参数确定新点位
function M:ParameterDetermination()
    -- 获取UI输入参数
    local num = self.buildActor.simplePoints:Num()
    local length = tonumber(self.splineMenuUi.SpinBox1:GetText())   -- 线段长度
    local degrees = tonumber(self.splineMenuUi.SpinBox3:GetText())  -- 角度（度）
    local radians = UE.UKismetMathLibrary.DegreesToRadians(degrees) -- 转为弧度

    -- 计算相对位移
    local LQ = self.buildActor.simplePoints[num - 1]                   -- 参考点
    local intervalLoction = UE.FVector(0, 0, 0)
    intervalLoction.Z = tonumber(self.splineMenuUi.SpinBox2:GetText()) -- 高度差
    local h = intervalLoction.Z - LQ.Z
    local r = math.sqrt(length ^ 2 - h ^ 2)                            -- 水平投影距离

    -- 计算XY平面位移
    intervalLoction.X = math.cos(radians) * r
    intervalLoction.Y = -math.sin(radians) * r

    -- 更新最新点位置
    self.buildActor.simplePoints[num] = intervalLoction + LQ
    self.buildActor:SetSplineModel() -- 更新样条线模型

    -- 根据模式执行后续操作
    if self.bBuild then
        self:CreateLine()
    else
        self:SplinePointSelect()
    end

    -- 关闭菜单
    self.splineMenuUi:RemoveFromParent()
    self.splineMenuUi = nil
end

function M:QuitSetModel()
    local walls = UE.UGameplayStatics.GetAllActorsOfClass(self:GetWorld(), LoadClass(self.modelManage.class[5]))
    for _, v in pairs(walls) do
        v.bDestroy = true
    end

    local areas = UE.UGameplayStatics.GetAllActorsOfClass(self:GetWorld(), LoadClass(self.modelManage.class[6]))
    for _, v in pairs(areas) do
        v.bDestroy = true
    end
end

----------------------------- test -----------------------------
-- local function func(key, self)
--     for i = 1, 500 do
--         local value = Data.jsonTable[i + key]
--         if value then
--             if value.modelType == "line" then
--                 local T = UE.FTransform()
--                 local L1 = UE.FVector(value.start[1] / 10 - 649462, value.start[2] / 10 + 1020837, 0)
--                 local l2 = UE.FVector(value["end"][1] / 10 - 649462, value["end"][2] / 10 + 1020837, 0)
--                 T.Translation = L1
--                 local name = tostring(i + key) .. "sss"
--                 local line = self.modelManage.ModelCreate[5](name, self, nil, T, name)
--                 line.simplePoints:Add(L1)
--                 line.simplePoints:Add(l2)
--                 line.Thickness = 3
--                 line.Height = 10
--                 line:SetSplineModel()
--             end
--         end
--     end
--     return key + 500
-- end

-- function M:Test(key)
--     local key = key or 0
--     key = func(key, self)
--     print(key)
--     coroutine.resume(coroutine.create(function()
--         UE.UKismetSystemLibrary.Delay(self, 1)
--         if key < #Data.jsonTable then
--             self:Test(key)
--         end
--     end), self)
-- end


return M
