--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_VerticalBZ_C
local M = UnLua.Class()
local DFL = require("SandBox.DataFunction")
local Class = require("SandBox.Class")
--- 垂直标注组件初始化
--- @function Initialize
--- @param Initializer any 初始化参数
--- @description
---   初始化垂直标注组件的基本属性:
---   1. size - 尺寸向量(初始化为空FVector)
---   2. modelType - 模型类型标识(9=垂直标注)
---   3. clickType - 点击类型标识(3=?)
---   4. matTable - 材质路径表(包含2个默认材质)
---   5. showName - 显示名称("水平标注")
---   6. bMove - 可移动标记(true=可移动)
---   7. selectColor - 选中颜色(红色)
---   8. lineColor - 线条颜色(绿色)
---   9. vertacalLineColor - 垂直线颜色(初始nil)
---   10. vertacalselectColor - 垂直选中颜色(初始nil)
function M:Initialize(Initializer)
    self.size = UE.FVector
    self.modelType = 9
    self.clickType = 3
    self.matTable = {
        "/Game/SandBox/Materials/M_Point2_Inst.M_Point2_Inst",
        "/Game/SandBox/Materials/M_Point2_Inst2.M_Point2_Inst2"
    }
    -- self.showName = ""
    self.bMove = true
    self.showName = "水平标注"

    self.selectColor = UE.FLinearColor(1, 0, 0.01, 1)
    self.lineColor = UE.FLinearColor(0, 0.95, 0.04, 1)
    self.vertacalLineColor = nil
    self.vertacalselectColor = nil
end

--- 游戏开始事件处理
--- @function ReceiveBeginPlay
--- @description
---   1. 获取UI组件引用
---   2. 绑定选择按钮点击事件
---   3. 设置文本输入框可见
function M:ReceiveBeginPlay()
    self.widgetUI = self.Widget:GetWidget()
    self.widgetUI.BT_Sel.OnClicked:Add(self, self.Select)
    self.widgetUI.EText:SetVisibility(1)
end

--- 模型数据序列化
--- @function ModelSave
--- @return table 包含序列化数据的Lua表
--- @description
---   输出当前模型状态数据:
---   1. CType - 点击类型
---   2. Cable2 - 第二条线位置(JSON序列化)
---   3. EV1 - 第一条线终点位置
---   4. EV2 - 第二条线终点位置
---   5. selectColor - 选中颜色(JSON序列化)
---   6. LineColor - 线条颜色(JSON序列化)
function M:ModelSave()
    local table = {
        ["CType"] = self.clickType,
        ["Cable2"] = DFL.fromVector(self.Cable2:K2_GetComponentLocation()),
        ["EV1"] = DFL.fromVector(self.Cable1.EndLocation),
        ["EV2"] = DFL.fromVector(self.Cable2.EndLocation),
        ["selectColor"] = UE.UJsonLibraryHelpers.JsonValue_Stringify(
            UE.UJsonLibraryHelpers.FromLinearColor(self.selectColor)
        ),
        ["LineColor"] = UE.UJsonLibraryHelpers.JsonValue_Stringify(
            UE.UJsonLibraryHelpers.FromLinearColor(self.lineColor)
        )
    }
    return table
end

--- 模型数据反序列化
--- @function ModelLoad
--- @param table table 包含反序列化数据的Lua表
--- @description
---   加载模型状态数据:
---   1. 更新点击类型和模型类型
---   2. 从JSON恢复颜色值
---   3. 设置线缆位置
---   4. 设置形状和颜色
---   5. 设置材质状态(2=普通状态)
function M:ModelLoad(table)
    self.clickType = table["CType"] ~= 0 and table["CType"] or self.clickType
    self.modelType = table["Type"]

    self.selectColor = DFL.toColor(table["selectColor"])
    self.lineColor = DFL.toColor(table["LineColor"])

    local c2 = DFL.toVector(table["Cable2"])
    local l1 = DFL.toVector(table["EV1"])
    local l2 = DFL.toVector(table["EV2"])
    self.Cable2:K2_SetWorldLocation(c2, false, UE.FHitResult(), false)
    self.DefaultSceneRoot:SetVisibility(true, true)
    self:SetShape(l1, l2)
    self:SetColor()
    self:SetM(2)
end

--- 设置尺寸位置
--- @function SetSize
--- @param inputLocation FVector 输入位置
--- @description
---   根据输入位置设置第三条线的终点位置:
---   1. 获取当前actor位置
---   2. 计算相对位置差
---   3. 设置为第三条线的终点位置
function M:SetSize(inputLocation)
    local location = self:K2_GetActorLocation()
    self.Cable3.EndLocation = UE.UKismetMathLibrary.Subtract_VectorVector(inputLocation, location)
end

--- 确认尺寸位置
--- @function EnterSize
--- @description
---   1. 设置默认场景根可见
---   2. 将第三条线的终点位置应用到第二条线
---   3. 记录当前尺寸
function M:EnterSize()
    self.DefaultSceneRoot:SetVisibility(true, true)
    self.Cable2:K2_SetRelativeLocation(self.Cable3.EndLocation, false, UE.FHitResult(), false)
    self.size = self.Cable2:GetRelativeTransform().Translation
end

--- 设置垂直标注形状
--- @function SetVBZ
--- @param inputLocation FVector 输入位置
--- @description
---   根据输入位置创建垂直标注:
---   1. 计算相对位置差
---   2. 计算相对位置差减去一半尺寸
---   3. 当Z坐标为0时:
---     - 根据X/Y绝对值大小决定水平/垂直标注
---     - 设置两条线的终点位置
function M:SetVBZ(inputLocation)
    local location = self:K2_GetActorLocation()
    local subLocation = UE.UKismetMathLibrary.Subtract_VectorVector(inputLocation, location)
    local DRL = subLocation - self.size / 2
    local l1 = UE.FVector
    local l2 = UE.FVector
    -- if DRL.Z == 0 then
    if math.abs(DRL.X) > math.abs(DRL.Y) then
        l1 = UE.FVector(subLocation.X, 0, 0)
        l2 = UE.FVector(subLocation.X, self.size.Y, 0)
    else
        l1 = UE.FVector(0, subLocation.Y, 0)
        l2 = UE.FVector(self.size.X, subLocation.Y, 0)
    end
    self:SetShape(l1, l2)
    -- end
    -- print(self.size, "SetVBZ")
end

--- 设置标注形状
--- @function SetShape
--- @param l1 FVector 第一条线终点
--- @param l2 FVector 第二条线终点
--- @description
---   设置标注的完整形状:
---   1. 设置两条线的终点位置
---   2. 设置第三条线的位置和终点
---   3. 设置两个球体标记的位置
---   4. 设置UI控件居中位置
---   5. 更新显示文本为两条线距离
function M:SetShape(l1, l2)
    self.Cable1.EndLocation = l1
    self.Cable2.EndLocation = l2
    self.Cable3:K2_SetRelativeLocation(l1, false, UE.FHitResult(), false)
    self.Cable3.EndLocation = l2

    self.Sphere:K2_SetRelativeLocation(l1, false, UE.FHitResult(), false)
    self.Sphere1:K2_SetRelativeLocation(l2, false, UE.FHitResult(), false)

    self.Widget:K2_SetRelativeLocation((l1 + l2) / 2, false, UE.FHitResult(), false)
    self.widgetUI.Text:SetText(DFL.integrate(UE.UKismetMathLibrary.Vector_Distance(l1, l2)))
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
--- @param Nub number 状态标识(1=选中状态, 2=普通状态)
--- @description
---   根据状态设置垂直标注线的材质:
---   1. 检查垂直颜色材质是否有效
---   2. Nub=1时: 应用选中状态材质(红色)
---   3. Nub=2时: 应用普通状态材质(绿色)
---   4. 如果颜色材质无效则重新初始化颜色
function M:SetM(Nub)
    if UE.UKismetSystemLibrary.IsValid(self.vertacalLineColor) and UE.UKismetSystemLibrary.IsValid(self.vertacalselectColor) then
        if Nub == 1 then
            self.Cable1:SetMaterial(0, self.vertacalselectColor)
            self.Cable2:SetMaterial(0, self.vertacalselectColor)
            self.Cable3:SetMaterial(0, self.vertacalselectColor)
        else
            self.Cable1:SetMaterial(0, self.vertacalLineColor)
            self.Cable2:SetMaterial(0, self.vertacalLineColor)
            self.Cable3:SetMaterial(0, self.vertacalLineColor)
        end
    else
        self.vertacalselectColor = nil
        self.vertacalLineColor = nil
        self:SetColor()
        self:SetM(Nub)
    end
end

--- 获取颜色数据
--- @function GetData
--- @return table 包含颜色数据的表
--- @description
---   输出当前颜色配置:
---   1. 选中颜色(sr/sg/sb/sa)
---   2. 线条颜色(lr/lg/lb/la)
---   所有颜色值都转换为0-255范围
function M:GetData()
    print("self.selectColor")
    local PDT = {
        sr = DFL.integrate(self.selectColor.R * 255),
        sg = DFL.integrate(self.selectColor.G * 255),
        sb = DFL.integrate(self.selectColor.B * 255),
        sa = DFL.integrate(self.selectColor.A * 100),
        lr = DFL.integrate(self.lineColor.R * 255),
        lg = DFL.integrate(self.lineColor.G * 255),
        lb = DFL.integrate(self.lineColor.B * 255),
        la = DFL.integrate(self.lineColor.A * 100),
        -- showname = self.showName
    }
    return PDT
end

--- 设置颜色数据
--- @function SetData
--- @param table table 包含颜色数据的表
--- @description
---   从外部数据更新颜色配置:
---   1. 解析线条颜色(lr/lg/lb/la)
---   2. 解析选中颜色(sr/sg/sb/sa)
---   3. 当颜色有变化时更新内部颜色值
---   4. 调用SetColor应用新颜色
function M:SetData(table)
    print("SetDatavbz")
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

--- 创建动态材质实例
--- @function SetColor
--- @description
---   创建或更新动态材质实例:
---   1. 为线条颜色创建动态材质实例(如果不存在)
---   2. 为选中颜色创建动态材质实例(如果不存在)
---   3. 设置材质参数"Param"为对应颜色值
function M:SetColor()
    print("self.lineColor")
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
