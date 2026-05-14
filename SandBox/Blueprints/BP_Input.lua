--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--
---@class BP_Input_C
local M = UnLua.Class()
local BindKey = UnLua.Input.BindKey
local Screen = require("SandBox.Screen")
local Model = require("SandBox.ModelNameInitialize")
local Class = require("SandBox.Class")

-- 区域内绘制模式锁定判断简化访问（存在对应接口时才调用）
local function IsRegionInnerLocked(self)
    return self.control.IsRegionInnerLocked and self.control:IsRegionInnerLocked()
end

---------------------------------按键事件--------------------------------
local LClick = {
    function(self)
        if self.control.bCatch and not self.control.bBuild then
            self.control:TrackCatch()
        end
    end,
    function(self)
        if self.control.splineMenuUi == nil then
            if self.control.bBuild then
                self.control:CreateLine()
            else
                self.control:SplinePointSelect()
            end
        end
    end,
    function(self)
        if self.control.bBuild then
            self.control:CreateTwoPoint()
        end
    end,
    ["Array"] = function(self)
    end
}

local RClick = {
    function(self)
        if self.control.buildActor then
            self.control:StopMove()
        end
    end,
    function(self)
        if self.control.buildActor then
            self.control:StopMovePoint()
        end
    end,
    function(self)
        if self.control.buildActor then
            self.control:StopMoveTwoPoint()
        else
            self.control:CancelBuild()
        end
    end,
    ["Array"] = function(self)
    end
}

-- 添加防抖功能变量
M.DebounceTimers = M.DebounceTimers or {}
-- 防抖函数
local function debounce(func, delay, key, self)
    if M.DebounceTimers[key] then
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), M.DebounceTimers[key])
    end
    M.DebounceTimers[key] = UE.UKismetSystemLibrary.K2_SetTimerDelegate(func, delay, false)
end

BindKey(M, "LeftMouseButton", "Pressed", function(self, Key)
    -- 50毫秒防抖处理
    debounce({ self, self.LeftMousePress }, 0.05, "LeftMouseButton", self)
end, {
    ConsumeInput = false
})

function M:LeftMousePress()
    if self.control.drawMode == "RegionArea" then
        -- 协作区域模式下：逻辑归口到 BP_Control
        if self.control.curReg then
            if self.control.bBuild then
                self.control:CreateRegionArea()
            else
                self.control:SplinePointSelect()
            end
        elseif self.control.bPreviewFirstPoint and not self.control.bBuild then
            self.control:StartCreateRegionWithFirstPoint()
        end
        return
    end
    -- 区域内绘制模式，且尚未选中协作区域时：左键点击无效
    if IsRegionInnerLocked(self) then
        return
    end
    if not self.control.IsSpace then
        LClick[self.control.clickType](self)
    end
end

-- ctrl+左键 框选多选
-- ture 为增加 ，false 为减少
BindKey(M, "LeftMouseButton", "Pressed", function(self, Key)
    if self.control.bBuild or self.control.drawMode == "RegionArea" then
        return
    end
    if IsRegionInnerLocked(self) then
        return
    end
    self.control.Changes = true
    self.control:StartSelection()
    -- self.control:MultipleChoicesAdd()
end, {
    ConsumeInput = false,
    Ctrl = true
})

BindKey(M, "LeftMouseButton", "Released", function(self, Key)
    if self.control.drawMode == "RegionArea" then
        return
    end
    if IsRegionInnerLocked(self) then
        return
    end
    self.control.Changes = true
    self.control:EndSelectionOver()
end, {
    ConsumeInput = false,
    Ctrl = true
})
-- 补漏洞
BindKey(M, "LeftControl", "Released", function(self, Key)
    if self.control.drawMode == "RegionArea" then
        return
    end
    if self.control.selStart ~= UE.FVector2D(0, 0) then
        self.control.Changes = true
        self.control:EndSelectionOver()
        self.control.selStart = UE.FVector2D(0, 0)
    end
end, {
    ConsumeInput = false
})

BindKey(M, "LeftMouseButton", "Pressed", function(self, Key)
    if self.control.bBuild or self.control.drawMode == "RegionArea" then
        return
    end
    if IsRegionInnerLocked(self) then
        return
    end
    self.control.Changes = false
    self.control:StartSelection()
    self.control:MultipleChoicesAdd()
end, {
    ConsumeInput = false,
    Alt = true
})

BindKey(M, "LeftMouseButton", "Released", function(self, Key)
    if self.control.drawMode == "RegionArea" then
        return
    end
    if IsRegionInnerLocked(self) then
        return
    end
    if self.control.selStart ~= UE.FVector2D(0, 0) then
        self.control.Changes = false
        self.control:EndSelectionOver()
        self.control.selStart = UE.FVector2D(0, 0)
    end
end, {
    ConsumeInput = false,
    Alt = true
})

function M:ClearPressRTimer()
    self.bPressR = false
    print(self.bPressR)
    self.PressRTimerHandle = nil
end

BindKey(M, "RightMouseButton", "Pressed", function(self, Key)
    if self.control.bAndroid then
        self.bPressR = true
        -- 使用定时器替代协程延迟实现
        if self.PressRTimerHandle then
            UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.PressRTimerHandle)
        end
        self.PressRTimerHandle = UE.UKismetSystemLibrary.K2_SetTimerDelegate(
            { self, self.ClearPressRTimer },
            1,    -- 延迟时间(秒)
            false -- 不循环
        )
    end
    -- 区域内绘制模式且尚未选中协作区域时：右键无效
    if IsRegionInnerLocked(self) then
        return
    end
    if self.control.drawMode == "RegionArea" then
        -- 协作区域绘制模式：右键用于结束绘制
        if self.control.curReg and self.control.bBuild then
            self.control:StopMoveRegionArea()
        end
        return
    end
    if self.control.bBuild then
        if not self.control.IsSpace then
            if not self.control.modelManage.gizmo then
                self:StopBuildModel()
            end
        end
    elseif self.control.BatchPasteActors then
        if not self.control.IsSpace then
            self.control:GroupsTimeOver()
        end
    elseif self.control.bCatchPoint then
        self.control:CatchStop()
    elseif self.control.buildActor then
        self.control:ShowMenu()
    end
    self.control.bSplineMenuTF = false
end, {
    ConsumeInput = false
})

BindKey(M, "RightMouseButton", "DoubleClick", function(self, Key)
    if self.control.drawMode == "RegionArea" then
        return
    end

    -- RegionInner 模式下：尚未进入区域视图时，双击用于尝试进入自己的协作区域
    if self.control.drawMode == "RegionInner" and IsRegionInnerLocked(self) then
        if self.control.TryEnterRegionByDoubleClick then
            self.control:TryEnterRegionByDoubleClick()
        end
        return
    end

    -- 仍处于锁定状态时，其它双击逻辑无效
    if IsRegionInnerLocked(self) then
        return
    end
    if not self.control.bBuild and self.control.bAndroid then
        self.control:AdvancedOver()
        self.control:DeleteModel()
        self.control:RemoveMenu()
    end
end, {
    ConsumeInput = false
})

function M:StopBuildModel()
    if self.control.drawMode == "RegionArea" then
        return
    end
    self.control:RemoveTip()
    RClick[self.control.clickType](self)
    self.control.bBuild = false
end

BindKey(M, "LeftMouseButton", "DoubleClick", function(self, Key)
    print(self.bPressR)
    if self.control.bAndroid and self.bPressR then
        return
    end
    if self.control.drawMode == "RegionArea" then
        if self.control.bBuild then
            self.control:CreateRegionArea()
        else
            if not self.control:HandleRegionAreaDoubleClick() and not self.control.curReg then
                self.control:CreateRegionArea()
            end
        end
        return
    end

    -- RegionInner 模式下：尚未进入区域视图时，双击用于尝试进入自己的协作区域
    if self.control.drawMode == "RegionInner" and IsRegionInnerLocked(self) then
        if self.control.TryEnterRegionByDoubleClick then
            self.control:TryEnterRegionByDoubleClick()
        end
        return
    end

    -- 区域内模式仍锁定时，其它双击逻辑无效
    if IsRegionInnerLocked(self) then
        return
    end
    if not self.control.bBuild and not self.control.bCatchPoint then
        if self.control.ui.Tip1:GetText() ~= "阵列" then
            self.control.ui:ModelTipHide()
        end
        self.control:SelectionModel()
    end
end, {
    ConsumeInput = false
})

BindKey(M, "X", "Pressed", function(self, Key)
    -- RegionArea 模式下允许设置轴约束
    if self.control.drawMode == "RegionArea" then
        self.control.bX = true
    elseif self.control.buildActor and self.control.buildActor.modelType ~= 6 then
        self.control.bX = true
    end
end, {
    ConsumeInput = false
})

BindKey(M, "X", "Released", function(self, Key)
    -- RegionArea 模式下允许设置轴约束
    if self.control.drawMode == "RegionArea" then
        self.control.bX = false
    elseif self.control.buildActor and self.control.buildActor.modelType ~= 6 then
        self.control.bX = false
    end
end, {
    ConsumeInput = false
})

BindKey(M, "C", "Pressed", function(self, Key)
    -- RegionArea 模式下允许设置轴约束
    if self.control.drawMode == "RegionArea" then
        self.control.bY = true
    elseif self.control.buildActor and self.control.buildActor.modelType ~= 6 then
        self.control.bY = true
    end
end, {
    ConsumeInput = false
})

BindKey(M, "C", "Released", function(self, Key)
    -- RegionArea 模式下允许设置轴约束
    if self.control.drawMode == "RegionArea" then
        self.control.bY = false
    elseif self.control.buildActor and self.control.buildActor.modelType ~= 6 then
        self.control.bY = false
    end
end, {
    ConsumeInput = false
})

BindKey(M, "Z", "Pressed", function(self, Key)
    -- RegionArea 模式下不需要 Z 轴约束
    if self.control.buildActor and self.control.buildActor.modelType ~= 6 then
        self.control.bZ = true
    end
end, {
    ConsumeInput = false
})

BindKey(M, "Z", "Released", function(self, Key)
    -- RegionArea 模式下不需要 Z 轴约束
    if self.control.buildActor and self.control.buildActor.modelType ~= 6 then
        self.control.bZ = false
    end
end, {
    ConsumeInput = false
})

BindKey(M, "V", "Pressed", function(self, Key)
    if self.control.buildActor then
        if self.control.buildActor.modelType == 5 then
            self.control.buildActor:SetClosedWall()
        end
    end
end, {
    ConsumeInput = false
})
BindKey(M, "T", "Pressed", function(self, Key)
    if self.control.pawn then
        self.control.ui.UI_location:switch(false, 1, 1)
    end
end, {
    ConsumeInput = false
})

BindKey(M, "F", "Pressed", function(self, Key)
    if self.control.pawn then
        self.control.ui.UI_location:switch(false, 3, 1)
    end
end, {
    ConsumeInput = false
})

BindKey(M, "L", "Pressed", function(self, Key)
    if self.control.pawn then
        self.control.ui.UI_location:switch(false, 3, 1)
        self.control.pawn:ChooseViewData("西")
    end
end, {
    ConsumeInput = false
})

BindKey(M, "R", "Pressed", function(self, Key)
    if self.control.pawn then
        self.control.ui.UI_location:switch(false, 3, 1)
        self.control.pawn:ChooseViewData("东")
    end
end, {
    ConsumeInput = false
})

BindKey(M, "Zero", "Pressed", function(self, Key)
    if self.control.pawn then
        self.control.ui.UI_location:switch(true, 1, 1)
    end
end, {
    ConsumeInput = false
})

-- BindKey(M, "One", "Pressed", function(self, Key)
--     if self.control.pawn then
--         self.control.ui:ButtonVision()
--     end
-- end, {
--     ConsumeInput = false
-- })

BindKey(M, "SpaceBar", "Pressed", function(self, Key)
    self.control.IsSpace = true
end, {
    ConsumeInput = false
})

BindKey(M, "SpaceBar", "Released", function(self, Key)
    self.control.IsSpace = false
end, {
    ConsumeInput = false
})

BindKey(M, "Delete", "Pressed", function(self, Key)
    if self.control.drawMode == "RegionArea" then
        -- RegionArea 模式下：如果 curReg 存在且不在构建模式，删除当前选中的点
        if self.control.curReg and not self.control.bBuild then
            self.control:RemoveCurrentSplinePoint()
        end
        return
    end
    if IsRegionInnerLocked(self) then
        return
    end
    if not self.control.bBuild then
        self.control:AdvancedOver()
        self.control:DeleteModel()
    end
end, {
    ConsumeInput = false
})

-- BindKey(M, "NumPadOne", "Pressed", function(self, Key)
--     self.control.pawn:SplitScreen()
-- end, { ConsumeInput = false })

BindKey(M, "P", "Pressed", function(self, Key)
    local faces = UE.UMyBFL.GetAllStaticMeshFaceCounts(self:GetWorld())
    Screen.Print("场景模型面数" .. faces)
end, {
    ConsumeInput = false
})

-- 撤销快捷键
BindKey(M, "Z", "Pressed", function(self, Key)
    if self.control.undo then
        self.control:AdvancedOver()
        self.control.undo:Undo()
    end
end, {
    ConsumeInput = false,
    Ctrl = true
})
-- 前进快捷键
BindKey(M, "Z", "Pressed", function(self, Key)
    if self.control.undo then
        self.control:AdvancedOver()
        self.control.undo:Redo()
    end
end, {
    ConsumeInput = false,
    Ctrl = true,
    Shift = true
})

-- 复制快捷键
BindKey(M, "C", "Pressed", function(self, Key)
    if self.control.drawMode == "RegionArea" then
        return
    end
    if IsRegionInnerLocked(self) then
        return
    end
    -- self.control:CopyModel()
    -- self.control:StaCopy()
    self.control:AdvancedOver()
    self.control:CopyModelTable(self.control.BatchActors)
end, {
    ConsumeInput = false,
    Ctrl = true
})

-- 粘贴快捷键
BindKey(M, "V", "Pressed", function(self, Key)
    if self.control.drawMode == "RegionArea" then
        return
    end
    if IsRegionInnerLocked(self) then
        return
    end
    self.control:AdvancedOver()
    self.control:PasteModelTable()
end, {
    ConsumeInput = false,
    Ctrl = true
})

-- 跨方案复制快捷键
BindKey(M, "C", "Pressed", function(self, Key)
    if self.control.drawMode == "RegionArea" then
        return
    end
    if IsRegionInnerLocked(self) then
        return
    end
    self.control:AdvancedCpopy()
end, {
    ConsumeInput = false,
    Shift = true
})

-- 跨方案粘贴快捷键
BindKey(M, "V", "Pressed", function(self, Key)
    if self.control.drawMode == "RegionArea" then
        return
    end
    if IsRegionInnerLocked(self) then
        return
    end
    self.control:AdvancedPaste()
end, {
    ConsumeInput = false,
    Shift = true
})

BindKey(M, "AnyKey", "Pressed", function(self, Key)
    if Key.KeyName ~= "RightMouseButton" then
        self.control:RemoveMenu()
    end
    print(Key.KeyName)
    if string.find(Key.KeyName, "Shift") == nil then
        self.control:RemoveRename()
    end
end, {
    ConsumeInput = false,
    Ctrl = false
})

BindKey(M, "LeftAlt", "Pressed", function(self, Key)
    self.control.pawn.AmplificationRate = 1.5
end, {
    ConsumeInput = false
})

BindKey(M, "LeftAlt", "Released", function(self, Key)
    self.control.pawn.AmplificationRate = 1
end, {
    ConsumeInput = false
})

BindKey(M, "S", "Released", function(self, Key)
    self.control:AdvancedOver()
    self.control.ui:ButtonSave()
end, {
    ConsumeInput = true,
    Ctrl = true
})

BindKey(M, "S", "Released", function(self, Key)
    self.control:AdvancedOver()
    self.control.ui:ButtonSaveAs()
end, {
    ConsumeInput = true,
    Ctrl = true,
    Shift = true
})

-- BindKey(M, "E", "Released", function(self, Key)
--     self.control:AdvancedOver()
--     self.control.ui:DownloadImg()
-- end, {
--     ConsumeInput = false,
--     Ctrl = true,
--     Shift = true
-- })

-- BindKey(M, "Six", "Released", function(self, Key)
--     self.control:Test()
-- end, { ConsumeInput = false })

BindKey(M, "Hyphen", "Pressed", function(self, Key)
    self.control.pawn.viewportScaling = self.control.pawn.viewportScaling - 1 < 0 and 0 or
        self.control.pawn.viewportScaling - 1
    self.control.ui:SaveConfig()
    self.control.ui:UECallWeb("ShowMessage", {
        Type = 1,
        Text = "当前视角放大缩小速度为：" .. self.control.pawn.viewportScaling .. "%"
    })
end, {
    ConsumeInput = false,
    Ctrl = true
})

BindKey(M, "Equals", "Pressed", function(self, Key)
    self.control.pawn.viewportScaling = self.control.pawn.viewportScaling + 1 > 100 and 100 or
        self.control.pawn.viewportScaling + 1
    self.control.ui:SaveConfig()
    self.control.ui:UECallWeb("ShowMessage", {
        Type = 1,
        Text = "当前视角放大缩小速度为：" .. self.control.pawn.viewportScaling .. "%"
    })
end, {
    ConsumeInput = false,
    Ctrl = true
})

BindKey(M, "Hyphen", "Pressed", function(self, Key)
    self.control.pawn.viewportPanning = self.control.pawn.viewportPanning - 1 < 0 and 0 or
        self.control.pawn.viewportPanning - 1
    self.control.ui:SaveConfig()
    self.control.ui:UECallWeb("ShowMessage", {
        Type = 1,
        Text = "当前视角平移速度为：" .. self.control.pawn.viewportPanning .. "%"
    })
end, {
    ConsumeInput = false,
    Shift = true
})

BindKey(M, "Equals", "Pressed", function(self, Key)
    self.control.pawn.viewportPanning = self.control.pawn.viewportPanning + 1 > 100 and 100 or
        self.control.pawn.viewportPanning + 1
    self.control.ui:SaveConfig()
    self.control.ui:UECallWeb("ShowMessage", {
        Type = 1,
        Text = "当前视角平移速度为：" .. self.control.pawn.viewportPanning .. "%"
    })
end, {
    ConsumeInput = false,
    Shift = true
})

-- BindKey(M, "S", "Released", function(self, Key)
--     local bBack = self.control:IsCatch(not self.control.bCatch)
--     if not bBack then
--         self.control.ui:UECallWeb("ueIsOpenPointCap", {
--             pointCapture = self.control.bCatch
--         })
--     end
-- end, {
--     ConsumeInput = true
-- })

BindKey(M, "G", "Pressed", function(self, Key)
    if self.control.bBuild then
        if self.control.buildActor.modelType == 6 then
            self.control.bRec = true
            self.control:TimeMove()
        end
    end
end, {
    ConsumeInput = false
})

BindKey(M, "Enter", "Pressed", function(self, Key)
    if self.control.bBuild then
        if self.control.bSplineMenuTF then
            self.control:SplineMenu()
        end
    end
end, {
    ConsumeInput = false
})

BindKey(M, "A", "Pressed", function(self, Key)
    if self.control.drawMode == "RegionArea" then
        self.control:StartPreviewFirstPoint()
        self.control:TrackRegionEdge(true)
    end
end, {
    ConsumeInput = false
})


BindKey(M, "A", "Released", function(self, Key)
    if self.control.drawMode == "RegionArea" then
        self.control:TrackRegionEdge(false)
        self.control:StopPreviewFirstPoint()
    end
end, {
    ConsumeInput = false
})

return M
