--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_BZ_C
local M = UnLua.Class()
local DFL = require("SandBox.DataFunction")
local Class = require("SandBox.Class")
--- 尺寸标注组件初始化
--- @function Initialize
--- @param Initializer any 初始化参数
--- @description
---   初始化尺寸标注组件的基本属性:
---   1. endVetor - 终点向量(初始化为空FVector)
---   2. modelType - 模型类型标识(8=尺寸标注)
---   3. clickType - 点击类型标识(3=?)
---   4. matTable - 材质路径表(包含3个默认材质)
---   5. bMove - 可移动标记(true=可移动)
---   6. showName - 显示名称("尺寸标注")
---   7. selectColor - 选中颜色(红色)
---   8. lineColor - 线条颜色(黄色)
function M:Initialize(Initializer)
    self.endVetor    = UE.FVector
    self.modelType   = 8
    self.clickType   = 3
    self.matTable    = {
        '/Game/SandBox/Materials/M_Point_2.M_Point_2',
        '/Game/SandBox/Materials/M_Point2_Inst.M_Point2_Inst',
        '/Game/SandBox/Materials/M_Point2_Inst2.M_Point2_Inst2',
    }
    -- self.showName = ""
    self.bMove       = true

    self.showName    = "尺寸标注"

    self.selectColor = UE.FLinearColor(1, 0, 0.01, 1)
    self.lineColor   = UE.FLinearColor(1, 1, 0.1, 1)
end

--- 游戏开始事件处理
--- @function ReceiveBeginPlay
--- @description
---   1. 获取UI组件引用
---   2. 绑定选择按钮点击事件
---   3. 设置文本输入框可见
---   4. 初始化颜色设置
---   5. 设置初始材质状态(1=选中状态)
function M:ReceiveBeginPlay()
    self.widgetUI = self.Widget:GetWidget()
    self.widgetUI.BT_Sel.OnClicked:Add(self, self.Select)
    self.widgetUI.EText:SetVisibility(1)
    self:SetColor()
    self:SetM(1)
end

--- 模型数据序列化
--- @function ModelSave
--- @return table 包含序列化数据的Lua表
--- @description
---   输出当前模型状态数据:
---   1. CType - 点击类型
---   2. EndVetor - 终点位置向量
---   3. selectColor - 选中颜色
---   4. LineColor - 线条颜色
function M:ModelSave()
    local table = {
        ["CType"] = self.clickType,
        ["EndVetor"] = DFL.fromVector(self.EndPoint:K2_GetComponentLocation()),
        ["selectColor"] = DFL.fromVector(self.selectColor),
        ["LineColor"] = DFL.fromColor(self.lineColor)
    }
    return table
end

--- 模型数据反序列化
--- @function ModelLoad
--- @param table table 包含反序列化数据的Lua表
--- @description
---   加载模型状态数据:
---   1. 恢复选中颜色和线条颜色
---   2. 更新点击类型和模型类型
---   3. 恢复终点位置向量
---   4. 调用SetBZ更新标注位置
---   5. 更新颜色设置
---   6. 设置材质状态(1=选中状态)
function M:ModelLoad(table)
    self.selectColor = DFL.toColor(table["selectColor"])
    self.lineColor   = DFL.toColor(table["LineColor"])

    self.clickType   = table["CType"] ~= 0 and table["CType"] or self.clickType
    self.modelType   = table["Type"]
    self.endVetor    = UE.UJsonLibraryHelpers.ToVector(UE.UJsonLibraryHelpers.Parse(table["EndVetor"]))
    self:SetBZ()
    self:SetColor()
    self:SetM(1)
end

--- 创建尺寸标注
--- @function SetBZ
--- @description
---   根据当前位置和终点位置创建尺寸标注:
---   1. 计算相对位置差作为线缆终点
---   2. 设置终点位置
---   3. 设置UI控件居中位置
---   4. 计算两点距离并显示
---   5. 计算旋转角度并设置起点/终点旋转
---   6. 调用SetBZM设置材质状态
function M:SetBZ()
    local location = self:K2_GetActorLocation()
    -- print(self.endVetor,L)
    self.Cable.EndLocation = UE.UKismetMathLibrary.Subtract_VectorVector(self.endVetor, location)
    -- local SweepHitResult = UE.FHitResult()
    self.EndPoint:K2_SetWorldLocation(self.endVetor, false, nil, false)
    self.Widget:K2_SetWorldLocation(UE.UKismetMathLibrary.Add_VectorVector(self.endVetor, location) / 2,
        false, nil, false)
    local distance = UE.UKismetMathLibrary.Vector_Distance(location, self.endVetor)
    local radians = UE.UKismetMathLibrary.FindLookAtRotation(location, self.endVetor)
    self.StartPoint:K2_SetWorldRotation(radians, false, UE.FHitResult(), false)
    self.EndPoint:K2_SetWorldRotation(radians, false, UE.FHitResult(), false)
    self.widgetUI.Text:SetText(tostring(DFL.integrate(distance)))
    -- print(self.endVetor)
    self:SetBZM()
end

--- 设置尺寸标注材质状态
--- @function SetBZM
--- @description
---   根据线缆方向设置不同材质状态:
---   1. 当线缆在XZ/YZ/XY平面时设置状态3
---   2. 其他情况设置状态1
function M:SetBZM()
    if self.Cable.EndLocation.X == 0 and self.Cable.EndLocation.Z == 0 then
        self:SetM(3)
    elseif self.Cable.EndLocation.Y == 0 and self.Cable.EndLocation.Z == 0 then
        self:SetM(3)
    elseif self.Cable.EndLocation.X == 0 and self.Cable.EndLocation.Y == 0 then
        self:SetM(3)
    else
        self:SetM(1)
    end
end

--- 选择标注
--- @function Select
--- @description
---   1. 获取控制actor
---   2. 当不在建造模式时:
---     - 调用模型管理器的选择方法
---   3. 更新视图数据
function M:Select()
    local control = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(),
        LoadClass(Class.control))
    if not control.bBuild then
        control.modelManage.ModelSelect[self.modelType](self, control)
    end

    control:ModelDataToView(true)
end

--- 设置材质状态
--- @function SetM
--- @param Nub number 状态标识(1=普通状态, 2=选中状态, 3=特殊状态)
--- @description
---   根据状态设置标注材质:
---   1. 检查垂直颜色材质是否有效
---   2. Nub=1时: 应用普通状态材质
---   3. Nub=2时: 应用选中状态材质
---   4. Nub=3时: 应用特殊状态材质
---   5. 如果颜色材质无效则重新初始化颜色
function M:SetM(Nub)
    if UE.UKismetSystemLibrary.IsValid(self.vertacalLineColor) and UE.UKismetSystemLibrary.IsValid(self.vertacalselectColor) then
        if Nub == 1 then
            self.StartPoint:SetMaterial(0, self.vertacalLineColor)
            self.EndPoint:SetMaterial(0, self.vertacalLineColor)
            self.Cable:SetMaterial(0, self.vertacalLineColor)
        elseif Nub == 2 then
            self.StartPoint:SetMaterial(0, self.vertacalselectColor)
            self.EndPoint:SetMaterial(0, self.vertacalselectColor)
            self.Cable:SetMaterial(0, self.vertacalselectColor)
        elseif Nub == 3 then
            self.StartPoint:SetMaterial(0, self.vertacalLineColor)
            self.EndPoint:SetMaterial(0, self.vertacalLineColor)
            self.Cable:SetMaterial(0, self.vertacalLineColor)
        end
    else
        self.vertacalselectColor = nil
        self.vertacalLineColor = nil
        self:SetColor()
        self:SetM(Nub)
    end
end

--- 获取颜色配置数据
--- @function GetData
--- @return table 包含颜色数据的表
--- @description
---   将当前颜色配置转换为可序列化的数据格式:
---   1. 选中颜色(sr/sg/sb/sa) - 转换为0-255范围的整数值
---   2. 线条颜色(lr/lg/lb/la) - 转换为0-255范围的整数值
---   3. 使用DFL.integrate函数确保数值格式统一
function M:GetData()
    -- print("self.selectColor")
    local PDT =
    {
        sr = DFL.integrate(self.selectColor.R * 255),
        sg = DFL.integrate(self.selectColor.G * 255),
        sb = DFL.integrate(self.selectColor.B * 255),
        sa = DFL.integrate(self.selectColor.A * 100),
        lr = DFL.integrate(self.lineColor.R * 255),
        lg = DFL.integrate(self.lineColor.G * 255),
        lb = DFL.integrate(self.lineColor.B * 255),
        la = DFL.integrate(self.lineColor.A * 100),
    }
    return PDT
end

--- 设置颜色配置数据
--- @function SetData
--- @param table table 包含颜色数据的表
--- @description
---   从外部数据更新颜色配置:
---   1. 解析线条颜色(lr/lg/lb/la) - 将0-255值转换回0-1范围
---   2. 解析选中颜色(sr/sg/sb/sa) - 将0-255值转换回0-1范围
---   3. 使用UE.UKismetMathLibrary比较颜色差异(容差0.01)
---   4. 当颜色有变化时更新内部颜色值
---   5. 调用SetColor应用新颜色
function M:SetData(table)
    -- print("table")
    local LineColor = UE.FLinearColor(table.lr / 255, table.lg / 255, table.lb / 255, table.la / 100)
    if not UE.UKismetMathLibrary.LinearColor_IsNearEqual(LineColor, self.color, 0.01) then
        self.lineColor = LineColor
    end

    local selectColor = UE.FLinearColor(table.sr / 255, table.sg / 255, table.sb / 255, table.sa / 100)
    if not UE.UKismetMathLibrary.LinearColor_IsNearEqual(selectColor, self.color, 0.01) then
        self.selectColor = selectColor
    end
    self:SetColor()
end

--- 创建/更新动态材质实例
--- @function SetColor
--- @description
---   为标注线创建或更新动态材质实例:
---   1. 检查线条材质实例是否存在
---     - 不存在: 创建新实例并设置参数
---     - 存在: 更新现有实例参数
---   2. 检查选中状态材质实例是否存在
---     - 不存在: 创建新实例并设置参数
---     - 存在: 更新现有实例参数
---   3. 使用/Game/SandBox/Materials/M_Point2_Inst2作为基础材质
---   4. 设置"Param"参数为对应的颜色值
function M:SetColor()
    -- print(self.lineColor)
    if self.vertacalLineColor == nil then
        self.vertacalLineColor = UE.UKismetMaterialLibrary.CreateDynamicMaterialInstance(self:GetWorld(),
            LoadObject("/Game/SandBox/Materials/M_Point2_Inst2.M_Point2_Inst2"), "", 0)
        self.vertacalLineColor:SetVectorParameterValue("Param", self.lineColor)
    else
        self.vertacalLineColor:SetVectorParameterValue("Param", self.lineColor)
    end
    if self.vertacalselectColor == nil then
        self.vertacalselectColor = UE.UKismetMaterialLibrary.CreateDynamicMaterialInstance(self:GetWorld(),
            LoadObject("/Game/SandBox/Materials/M_Point2_Inst2.M_Point2_Inst2"), "", 0)
        self.vertacalselectColor:SetVectorParameterValue("Param", self.selectColor)
    else
        self.vertacalselectColor:SetVectorParameterValue("Param", self.selectColor)
    end
end

return M
