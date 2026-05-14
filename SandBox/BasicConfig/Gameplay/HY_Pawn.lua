--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class HY_Pawn_C
local M = UnLua.Class()

-- 模块依赖
local Screen = require("Screen") -- 屏幕输出工具
local Class = require("SandBox.Class")

-- 曲线资源加载（大驼峰命名全局资源）
local ZoomCurve = UE.UObject.Load("/Game/SandBox/BasicConfig/Curves/Zoom_Intensity_Curve.Zoom_Intensity_Curve")
local PanCurve = UE.UObject.Load("/Game/SandBox/BasicConfig/Curves/Pan_Intensity_Curve.Pan_Intensity_Curve")


function M:Initialize(Initializer)
    -- 缩放参数
    self.height = 0                  -- 当前高度基准值
    self.springArmLengthMin = 0      -- 弹簧臂最小长度
    self.springArmLengthMax = 100000 -- 弹簧臂最大长度
    self.targetArmLengthNew = 1000   -- 目标弹簧臂长度
    self.zoomSpeedMouse = 5000       -- 鼠标滚轮缩放速度

    -- 平移参数
    self.panIntensityMouse = 0.1 -- 鼠标平移强度系数
    -- self.PanIntensityCurve = PanCurve -- 平移强度曲线

    -- 旋转参数
    self.rotationSpeedMouse = 2  -- 鼠标旋转速度
    self.pitchLimitMin = -75     -- 俯仰角下限
    self.pitchLimitMax = 5       -- 俯仰角上限
    self.pitchCurrent = -117.202 -- 当前俯仰角
    self.yawCurrent = 5.463      -- 当前偏航角
    self.pitchNew = 0            -- 目标俯仰角
    self.yawNew = 0              -- 目标偏航角

    -- 输入状态
    self.mouseHoldLeft = false  -- 左键按下状态
    self.mouseHoldRight = false -- 右键按下状态

    -- 位置参数
    self.locationCurrent = UE.FVector() -- 当前世界坐标
    self.locationNew = UE.FVector()     -- 目标世界坐标

    -- 视角动画参数
    self.focusAnimationPlayRate = 0.75 -- 视角切换动画速率
    self.jszoom = 100                  -- 前端缩放比例

    -- 运动参数
    self.pcInt = -1          -- 分屏控制器索引
    self.moveSpeedMouse = 10 -- 鼠标移动速度系数

    -- 视口参数
    self.viewportPanning = 50 -- 视口平移灵敏度
    self.viewportScaling = 50 -- 视口缩放灵敏度

    -- 从外部配置加载参数
    self.zoomSpeedMouse = tonumber(UE.UMyBFL.GetExeURL("Zoom")) or self.zoomSpeedMouse
    self.rotationSpeedMouse = tonumber(UE.UMyBFL.GetExeURL("Rotation")) or self.rotationSpeedMouse
    self.moveSpeedMouse = tonumber(UE.UMyBFL.GetExeURL("Move")) or self.moveSpeedMouse
end

function M:ReceiveBeginPlay()
    -- 楼层基准高度
    self.currentFloor = 0

    -- 加载并获取辅助摄像机实例
    -- @warning 路径硬编码，若调整蓝图位置需同步修改
    local smallerCameraclass = LoadClass(Class.smallerCamera)
    self.smallerCamera = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(), smallerCameraclass) -- @type AActor

    -- 初始化弹簧臂长度（组件变量小驼峰）
    self.targetArmLengthNew = self.SpringArm.targetArmLength -- @type number

    -- 构建视角数据集
    -- @param ViewDataStrClass UObject 视角数据结构体类
    local viewDataStrClass = UE.UObject.Load("/Game/SandBox/BasicConfig/Data/Str_View.Str_View")
    self.viewData = UE.TMap("", viewDataStrClass)

    -- 获取玩家控制器实例（全局变量大驼峰）
    local pcClass = LoadClass(Class.hyPC)
    self.pc = UE.UGameplayStatics.GetPlayerController(self:GetWorld(), 0):Cast(pcClass) -- @type PC_C

    --视角预设配置
    -- @warning 重复使用ViewData变量会导致引用覆盖，应每次创建新实例
    local viewData = viewDataStrClass()
    viewData.Location = UE.FVector(0, 0, 500) -- 世界坐标（单位：厘米）
    viewData.Pitch = 5                        -- 俯仰角（度）
    viewData.Yaw = -90                        -- 偏航角（度）
    viewData.ArmLength = 5000                 -- 弹簧臂长度（厘米）
    self.viewData:Add("北", viewData)

    viewData.Location = UE.FVector(0, 0, 500)
    viewData.Pitch = 5
    viewData.Yaw = -90
    viewData.ArmLength = 5000
    self.viewData:Add("北", viewData)

    viewData.Location = UE.FVector(0, 0, 500)
    viewData.Pitch = 5
    viewData.Yaw = 180
    viewData.ArmLength = 5000
    self.viewData:Add("西", viewData)

    viewData.Location = UE.FVector(0, 0, 500)
    viewData.Pitch = 5
    viewData.Yaw = 0
    viewData.ArmLength = 5000
    self.viewData:Add("东", viewData)

    viewData.Location = UE.FVector(0, 0, 500)
    viewData.Pitch = 5
    viewData.Yaw = 90
    viewData.ArmLength = 5000
    self.viewData:Add("南", viewData)

    viewData.Location = UE.FVector(0, 0, 3000)
    viewData.Pitch = -85
    viewData.Yaw = -90
    viewData.ArmLength = 5000
    self.viewData:Add("平面", viewData)

    viewData.Location = UE.FVector(0, 0, 3000)
    viewData.Pitch = -85
    viewData.Yaw = -90
    viewData.ArmLength = 5000
    self.viewData:Add("顶面", viewData)

    viewData.Location = UE.FVector(0, 0, 500)
    viewData.Pitch = 5
    viewData.Yaw = -90
    viewData.ArmLength = 5000
    self.viewData:Add("立面", viewData)

    viewData.Location = UE.FVector(200, 0, 0)
    viewData.Pitch = -45
    viewData.Yaw = -90
    viewData.ArmLength = 5000
    self.viewData:Add("3d", viewData)

    viewData.Location = UE.FVector(0, 0, 0)
    viewData.Pitch = -85
    viewData.Yaw = -90
    viewData.ArmLength = 5000
    self.viewData:Add("2d", viewData)

    -- 调试输出视角数据量
    Screen.Print("viewData Length: " .. self.viewData:Length(), 50) -- 开发环境调试信息

    -- 设置初始视角
    -- @see ChooseViewData 视角切换逻辑
    self:ChooseViewData("3d") -- 默认使用3D视角
end

--- 根据预设名称切换视角
--- @param viewName string 视角配置名称（需存在于ViewData中）
--- @throws 当找不到对应视角配置时抛出中文警告
function M:ChooseViewData(viewName)
    local value = self.viewData:Find(viewName)
    if not value then
        error(string.format("未找到视角配置：%s，请检查ViewData初始化", viewName), 2)
    end

    -- 应用楼层高度偏移
    local location = UE.FVector(value.Location.X, value.Location.Y, value.Location.Z + self.currentFloor)
    self:Focus(location, value.Pitch, value.Yaw, value.ArmLength)
end

--- 调整楼层基准高度
--- @param floorHeight number 新的楼层高度（单位：厘米）
--- @warning 高度变化会同步影响辅助摄像机位置
function M:Hoist(floorHeight)
    -- 参数有效性校验
    if type(floorHeight) ~= "number" then
        error("楼层高度参数必须为数字类型", 2)
    end

    -- 获取当前状态（变量名小驼峰）
    local currentLoc = self:K2_GetActorLocation()
    local currentRot = self:GetControlRotation()
    local currentArmLength = self.targetArmLength -- 成员变量同步修改为小驼峰

    -- 计算新位置（保持XY坐标，仅改变Z轴）
    local newLocation = UE.FVector(currentLoc.X, currentLoc.Y, floorHeight)
    self:Focus(newLocation, currentRot.Pitch, currentRot.Yaw, currentArmLength)

    -- 同步调整辅助摄像机（局部变量小驼峰）
    local cameraLoc = self.camera1:K2_GetActorLocation()
    local cameraOffset = 960 -- 常量使用小驼峰
    local targetCameraPos = UE.FVector(cameraLoc.X, cameraLoc.Y, floorHeight + cameraOffset)
    local sweepResult = UE.FHitResult()
    self.camera1:K2_SetActorLocation(targetCameraPos, false, sweepResult, false)

    self.currentFloor = floorHeight -- 成员变量小驼峰
end

--- 每帧更新逻辑（引擎自动调用）
--- @param DeltaSeconds number 帧间隔时间（单位：秒）
function M:ReceiveTick(DeltaSeconds)
    -- 仅在被控制时执行逻辑
    if self:IsPawnControlled() then
        -- [调试信息]
        local currentLocation = tostring(self:K2_GetActorLocation()) -- 当前世界坐标
        local currentRotation = tostring(self:GetControlRotation())  -- 当前控制旋转
        local currentArmLength = tostring(self.targetArmLengthNew)   -- 当前弹簧臂长度
        Screen.Print(string.format("%s %s + %s", currentLocation, currentRotation, currentArmLength), 0)

        -- [弹簧臂长度插值]
        -- 使用浮点近似比较判断是否需要更新
        local isEqual = UE.UKismetMathLibrary.NearlyEqual_FloatFloat(
            self.SpringArm.TargetArmLength,
            self.targetArmLengthNew, -- 优化后的成员变量名
            0.0                      -- 允许误差范围
        )

        if not isEqual then
            -- 动态计算插值系数（基于标准化长度）
            local alpha = UE.UKismetMathLibrary.Lerp(
                3.0,                             -- 快速接近阶段的插值速度
                1.0,                             -- 慢速微调阶段的插值速度
                self:SpringArmLengthNormalized() -- 标准化后的弹簧臂长度
            )

            -- 应用帧间插值计算
            self.SpringArm.TargetArmLength = UE.UKismetMathLibrary.FInterpTo(
                self.SpringArm.TargetArmLength, -- 当前值
                self.targetArmLengthNew,        -- 目标值
                DeltaSeconds,                   -- 帧时间
                alpha                           -- 动态插值系数
            )
        end
    end

    -- [输入状态重置]
    -- 当鼠标移出视口时自动释放按键状态
    if not self.pc:GetMousePosition(0, 0) then
        self.mouseHoldLeft = false  -- 左键状态重置
        self.mouseHoldRight = false -- 右键状态重置
    end
end

--- 计算弹簧臂长度的标准化值
--- 将当前弹簧臂长度映射到[0,1]范围，基于配置的最小/最大长度
--- @return number 0~1 范围的标准化长度，用于插值计算和动画曲线
function M:SpringArmLengthNormalized()
    -- 参数说明：
    -- self.SpringArm.TargetArmLength : 当前弹簧臂实际长度（单位：厘米）
    -- self.springArmLengthMin        : 弹簧臂最小允许长度（配置参数）
    -- self.springArmLengthMax        : 弹簧臂最大允许长度（配置参数）
    --
    -- 计算公式：
    -- (当前长度 - 最小长度) / (最大长度 - 最小长度)
    return UE.UKismetMathLibrary.NormalizeToRange(
        self.SpringArm.TargetArmLength,
        self.springArmLengthMin,
        self.springArmLengthMax
    )
end

--- 执行视角切换动画
--- 通过时间轴驱动摄像机位置和旋转的平滑过渡
--- @param locationNew FVector 目标位置（单位：厘米）
--- @param pitchNew number 目标俯仰角（单位：度，范围[-90,90]）
--- @param yawNew number 目标偏航角（单位：度，无范围限制）
--- @param targetArmLengthNew number 目标弹簧臂长度（单位：厘米）
--- @note 实际弹簧臂长度变化在Tick中通过插值实现
function M:Focus(locationNew, pitchNew, yawNew, targetArmLengthNew)
    -- [参数预设置]
    -- 存储目标弹簧臂长度（后续在Tick中进行插值变化）
    self.targetArmLengthNew = targetArmLengthNew -- 需优化为小驼峰命名


    -- [当前状态捕获]
    -- 获取并存储当前摄像机状态（用于插值计算）
    self.locationCurrent = self:K2_GetActorLocation() -- 当前世界坐标
    local currentRotation = self:GetControlRotation() -- 当前控制器旋转
    self.pitchCurrent = currentRotation.Pitch         -- 当前俯仰角
    self.yawCurrent = currentRotation.Yaw             -- 当前偏航角


    -- [目标状态设置]
    -- 配置新视角参数（需做有效性校验）
    self.locationNew = locationNew                                      -- 目标坐标（建议添加Z轴范围约束）
    self.pitchNew = UE.UKismetMathLibrary.ClampAngle(pitchNew, -90, 90) -- 俯仰角安全限制
    self.yawNew = yawNew % 360                                          -- 偏航角归一化处理


    -- [动画控制]
    -- 配置时间轴动画参数（需确保TimelineFocusAnimation已初始化）
    self.TimelineFocusAnimation:SetPlayRate(self.focusAnimationPlayRate) -- 播放速率
    self.TimelineFocusAnimation:PlayFromStart()                          -- 从头开始播放动画曲线
end

--- 时间轴动画更新回调（每帧执行）
--- @param alpha number 动画进度值[0,1]，0=起始状态，1=目标状态
function M:TimelineUpdate(alpha)
    -- [位置插值计算]
    -- 基于Alpha在起始位置和目标位置之间线性插值
    -- @note 使用矢量线性插值确保平滑移动轨迹
    local interpolatedLocation = UE.UKismetMathLibrary.VLerp(
        self.locationCurrent, -- 动画起始位置（世界坐标系）
        self.locationNew,     -- 动画目标位置
        alpha                 -- 标准化进度值
    )

    -- 更新Actor位置（关闭碰撞检测）
    local sweepHitResult = UE.FHitResult() -- 碰撞结果（暂未使用）
    self:K2_SetActorLocation(
        interpolatedLocation,              -- 插值后的位置
        false,                             -- 不进行碰撞检测
        sweepHitResult,                    -- 碰撞结果容器
        false                              -- 不保持移动速度
    )


    --[旋转插值计算]
    -- 使用四元数球面插值实现平滑旋转过渡
    -- @note 强制Roll=0保持摄像机水平稳定
    local startRotator = UE.FRotator(
        self.pitchCurrent, -- 起始俯仰角
        self.yawCurrent,   -- 起始偏航角
        0                  -- 固定Roll轴为0
    )

    local targetRotator = UE.FRotator(
        self.pitchNew, -- 目标俯仰角
        self.yawNew,   -- 目标偏航角
        0              -- 固定Roll轴为0
    )

    -- 执行旋转插值（启用最短路径插值）
    local interpolatedRotator = UE.UKismetMathLibrary.RLerp(
        startRotator,
        targetRotator,
        alpha, -- 标准化进度值
        true   -- 启用最短路径插值
    )

    -- 更新控制器旋转（保持Roll=0）
    self.pc:SetControlRotation(UE.FRotator(
        interpolatedRotator.Pitch,
        interpolatedRotator.Yaw,
        0 -- 确保最终Roll值为0
    ))
end

--- 鼠标按键状态管理器
--- 处理左右键的按下/释放状态切换及输入互斥逻辑

-- [左键输入处理]
--- 鼠标左键事件处理器（包含拼写错误需修复）
--- @param press boolean 按键状态 true=按下 false=释放
function M:LeftMoustBtn(press)
    -- 存在拼写错误：Moust → Mouse
    -- 当非框选模式时更新输入状态
    -- if not self.boxSelection then
    self.mouseHoldLeft = press  -- 左键状态标记
    self.mouseHoldRight = false -- 强制关闭右键状态
    self.pcInt = -1             -- 操作中断标识（需明确文档说明）
    -- end
end

-- [右键输入处理]
--- 鼠标右键事件处理器
--- @param press boolean 按键状态 true=按下 false=释放
function M:RightMouseBtn(press)
    -- 输入互斥逻辑：右键按下时强制关闭左键状态
    self.mouseHoldRight = press -- 右键状态标记
    self.mouseHoldLeft = false  -- 强制关闭左键状态
    self.pcInt = -1             -- 操作中断标识（建议枚举化）
end

--- 处理鼠标水平轴输入（左右平移）
--- @param axisValue number 原始输入值（范围[-3,3]，经过死区过滤）
function M:MouseX(axisValue)
    -- [输入预处理]
    -- 输入有效性校验（建议添加非空校验）
    if axisValue == 0 then
        return -- 零输入优化
        -- 输入值安全限制（建议提取3为配置参数）
    elseif axisValue > 3 then
        axisValue = 3
    elseif axisValue < -3 then
        axisValue = -3
    end

    -- 输入状态机检测
    if self.mouseHoldRight then -- 仅在右键按住时响应
        -- [分屏逻辑处理]
        self:CheckSplitScreen() -- 分屏状态检查（需确保线程安全）

        -- 子Pawn处理链（建议添加超时保护）
        local childConsumed = self:PawnChildRun("MouseX", axisValue)
        if childConsumed then
            return -- 子对象已消费输入事件
        end

        -- [移动强度计算]
        -- 基于弹簧臂长度的动态灵敏度（需考虑曲线有效性）
        local normalizedLength = self:SpringArmLengthNormalized()
        local intensity = self.PanIntensityCurve:GetFloatValue(normalizedLength) -- 曲线查询

        -- 复合灵敏度计算（建议分离各系数计算）
        local scaledValue = axisValue
            * (-1)                                -- 坐标系修正
            * intensity
            * self.panIntensityMouse              -- 鼠标系数
            * self.moveSpeedMouse                 -- 基础速度
            * self:MapRange(self.viewportPanning) -- 视口映射系数


        --  [移动方向计算]
        -- 基于控制器Yaw的右方向向量（需验证旋转坐标系）
        local yawRotation = UE.FRotator(0, self:GetControlRotation().Yaw, 0)
        local rightVector = UE.UKismetMathLibrary.GetRightVector(yawRotation) -- 世界空间右方向

        -- 调试日志（建议使用条件编译）
        --[[ DEBUG
        Screen.Print(string.format("MoveDir: X=%.2f Y=%.2f Z=%.2f",
            rightVector.X, rightVector.Y, rightVector.Z), 0)
        ]]

        --  [移动执行]
        self:AddMovementInput(
            rightVector, -- 标准化方向向量
            scaledValue, -- 缩放后的输入量
            false        -- 是否力控制（建议配置化）
        )
    end
end

--- 处理鼠标垂直轴输入（上下平移）
--- @param axisValue number 原始输入值[-3,3]，正值表示上移
function M:MouseY(axisValue)
    -- 输入过滤和安全限制（建议提取3为MouseClampValue配置）
    if axisValue == 0 then
        return -- 零输入优化
        -- 输入值安全限制（建议提取3为配置参数）
    elseif axisValue > 3 then
        axisValue = 3
    elseif axisValue < -3 then
        axisValue = -3
    end

    -- 右键按住时生效（需与右键状态管理逻辑同步）
    if self.mouseHoldRight then
        -- 分屏检测和子对象输入处理（注意执行顺序依赖）
        self:CheckSplitScreen()
        local childConsumed = self:PawnChildRun("MouseY", axisValue)
        if childConsumed then
            return -- 子对象已消费输入事件
        end

        -- [移动强度计算]
        -- 基于弹簧臂长度的动态灵敏度（需考虑曲线有效性）
        local normalizedLength = self:SpringArmLengthNormalized()
        local intensity = self.PanIntensityCurve:GetFloatValue(normalizedLength)

        -- 复合移动系数计算（注意坐标系取反逻辑）
        local moveScale = axisValue * (-1) * intensity * self.panIntensityMouse
        moveScale = moveScale * self.moveSpeedMouse * self:MapRange(self.viewportPanning)
        print(moveScale)
        -- 获取基于控制器Yaw的前方向量（保持水平面移动）
        local yawRotation = UE.FRotator(0, self:GetControlRotation().Yaw, 0)
        local forwardDir = UE.UKismetMathLibrary.GetForwardVector(yawRotation)

        -- 垂直轴向移动执行（建议添加阈值过滤）
        self:AddMovementInput(forwardDir, moveScale, false)
    end
end

--- Q/E 垂直轴向移动处理
--- @param axisValue number 输入值[-1,1]，正值上升
function M:MoveUp(axisValue)
    -- 输入有效性校验（建议添加死区过滤）
    if math.abs(axisValue) < 0.01 then return end

    -- 分屏检测和子对象处理链
    self.pcInt = -1
    self:CheckSplitScreen()
    if self:PawnChildRun("MoveUp", axisValue) then return end

    -- 动态灵敏度计算（需校验曲线有效性）
    local intensity = self.PanIntensityCurve:GetFloatValue(
        self:SpringArmLengthNormalized()) * self.panIntensityMouse

    -- 垂直移动方向处理（保持世界坐标系Z轴）
    local worldUp = self:GetActorUpVector()
    self:AddMovementInput(
        UE.FVector(0, 0, worldUp.Z), -- 投影到世界Z轴
        intensity * axisValue,       -- 带符号的移动量
        false                        -- 非强制移动
    )
end

--- W/S 前后轴向移动处理
--- @param axisValue number 输入值[-1,1]，正值前进
function M:MoveForward(axisValue)
    if math.abs(axisValue) < 0.01 then return end
    self.pcInt = -1
    self:CheckSplitScreen()
    if self:PawnChildRun("MoveForward", axisValue) then return end

    -- 复合灵敏度计算
    local moveScale = self.PanIntensityCurve:GetFloatValue(
            self:SpringArmLengthNormalized())
        * self.panIntensityMouse

    -- 基于控制器的前方向量（X/Y方向取反）
    local controllerForward = UE.UKismetMathLibrary.GetForwardVector(
        self:GetControlRotation())

    -- 水平面移动向量（忽略Z轴分量）
    self:AddMovementInput(
        UE.FVector(-controllerForward.X, -controllerForward.Y, 0),
        moveScale * axisValue,
        false
    )
end

--- A/D 水平横向移动处理
--- @param axisValue number 输入值[-1,1]，正值右移
function M:MoveRight(axisValue)
    if math.abs(axisValue) < 0.01 then return end
    self.pcInt = -1
    self:CheckSplitScreen()
    if self:PawnChildRun("MoveRight", axisValue) then return end

    -- 复合灵敏度计算
    local moveScale = self.PanIntensityCurve:GetFloatValue(
            self:SpringArmLengthNormalized())
        * self.panIntensityMouse

    -- 基于控制器的右方向量（X/Y方向取反）
    local controllerRight = UE.UKismetMathLibrary.GetRightVector(
        self:GetControlRotation())

    -- 水平面移动执行（建议缓存方向向量）
    self:AddMovementInput(
        UE.FVector(-controllerRight.X, -controllerRight.Y, 0),
        moveScale * axisValue,
        false
    )
end

--- 水平轴向旋转处理（鼠标左键按住时）
--- @param axisValue number 旋转输入值[-1,1]，正值右转
function M:TurnRate(axisValue)
    -- 输入状态校验与子对象处理
    if self.mouseHoldLeft then
        self:CheckSplitScreen()
        if self:PawnChildRun("TurnRate", axisValue) then return end
    end

    -- 仅透视模式下生效（0=Perspective，建议使用枚举替代）
    if self.mouseHoldLeft and self.Camera.ProjectionMode == UE.ECameraProjectionMode.Perspective then
        -- 控制器旋转更新（注意玩家索引硬编码问题）
        local pc = UE.UGameplayStatics.GetPlayerController(self:GetWorld(), 0)
        local pcRot = pc:GetControlRotation()

        -- Yaw轴旋转计算（需要角度包装处理）
        local NewRotYaw = pcRot.Yaw + (self.rotationSpeedMouse * axisValue)
        -- Pitch角度约束（需注意ClampAngle的范围限制）
        local NewRotPitch = UE.UKismetMathLibrary.ClampAngle(
            pcRot.Pitch,
            self.pitchLimitMin,
            self.pitchLimitMax
        )

        pc:SetControlRotation(UE.FRotator(NewRotPitch, NewRotYaw, 0))
    end
end

--- 垂直轴向旋转处理（鼠标左键按住时）
--- @param axisValue number 旋转输入值[-1,1]，正值上仰
function M:LookUpRate(axisValue)
    -- 输入过滤与子对象处理链
    if self.mouseHoldLeft then
        self:CheckSplitScreen()
        if self:PawnChildRun("LookUpRate", axisValue) then return end
    end

    -- 透视模式专属逻辑
    if self.mouseHoldLeft and self.Camera.ProjectionMode == UE.ECameraProjectionMode.Perspective then
        local pc = UE.UGameplayStatics.GetPlayerController(self:GetWorld(), 0)
        local pcRot = pc:GetControlRotation()

        -- Pitch轴增量计算（注意角度溢出风险）
        local NewRotPitch = UE.UKismetMathLibrary.ClampAngle(
            pcRot.Pitch + (self.rotationSpeedMouse * axisValue),
            self.pitchLimitMin,
            self.pitchLimitMax
        )

        pc:SetControlRotation(UE.FRotator(NewRotPitch, pcRot.Yaw, 0))
    end
end

--- 鼠标滚轮缩放控制
--- @param Up boolean 滚动方向（true=向上，false=向下）
function M:MouseWheelUpDown(Up)
    -- 分屏检测与子对象处理
    self.pcInt = -1
    self:CheckSplitScreen()
    if self:PawnChildRun("MouseWheelUpDown", Up) then
        return
    end

    -- 动态缩放强度计算（需校验曲线有效性）
    local normalizedLength = self:SpringArmLengthNormalized()
    local zoomIntensity = self.ZoomIntensityCurve:GetFloatValue(normalizedLength)
    local finalSpeed = zoomIntensity * self.zoomSpeedMouse * self:MapRange(self.viewportScaling)

    -- 投影模式差异化处理
    local newArmLen = 0
    if self.Camera.ProjectionMode == UE.ECameraProjectionMode.Perspective then
        -- 透视模式：同步调整弹簧臂长度和正交宽度
        newArmLen = Up and (self.SpringArm.TargetArmLength - finalSpeed)
            or (self.SpringArm.TargetArmLength + finalSpeed)
        self.Camera.OrthoWidth = Up and (self.Camera.OrthoWidth - finalSpeed)
            or (self.Camera.OrthoWidth + finalSpeed)
    elseif self.Camera.ProjectionMode == UE.ECameraProjectionMode.Orthographic then
        -- 正交模式：特殊长度限制（1800为魔数，建议配置化）
        newArmLen = Up and math.max(self.SpringArm.TargetArmLength - finalSpeed, 1800)
            or (self.SpringArm.TargetArmLength + finalSpeed)
        self.Camera.OrthoWidth = Up and (self.Camera.OrthoWidth - finalSpeed)
            or (self.Camera.OrthoWidth + finalSpeed)
    end

    -- 弹簧臂长度安全限制
    self.targetArmLengthNew = UE.UKismetMathLibrary.FClamp(
        newArmLen,
        self.springArmLengthMin,
        self.springArmLengthMax
    )
    self:CallJszoom() -- 调用外部缩放逻辑

    -- [测绘线动态缩放系统]
    -- 缩放比例计算（250为基准值，建议配置化）
    self.bzJsZoom = (self.Camera.ProjectionMode == UE.ECameraProjectionMode.Perspective)
        and (self.targetArmLengthNew / 250)
        or (self.Camera.OrthoWidth / 250)
    self.bzJsZoom = math.min(self.bzJsZoom, 30) -- 最大缩放限制

    -- 动态调整BZ测绘线（建议封装为独立方法）
    local bzClass = LoadClass("/Game/SandBox/Blueprints/DrawModel/BP_BZ.BP_BZ_C")
    self.bzs = UE.UGameplayStatics.GetAllActorsOfClass(self:GetWorld(), bzClass)
    for _, actor in pairs(self.bzs) do
        -- 起点缩放（0.1/0.6为比例系数，建议配置化）
        local startScale = UE.FVector(
            self.bzJsZoom / 10 * 0.1,
            self.bzJsZoom / 10 * 0.6,
            self.bzJsZoom / 10 * 0.1
        )
        local startTransform = actor.StartPoint:GetRelativeTransform()
        actor.StartPoint:K2_SetRelativeTransform(
            UE.FTransform(startTransform.Rotation,
                startTransform.Translation,
                startScale),
            false, nil, false
        )

        -- 终点缩放（保留原有位移）
        local endTransform = actor.EndPoint:GetRelativeTransform()
        actor.EndPoint:K2_SetRelativeTransform(
            UE.FTransform(endTransform.Rotation,
                endTransform.Translation,
                startScale),
            false, nil, false
        )

        -- 连接线统一缩放（0.6为特殊系数）
        local cableScale = UE.FVector(
            self.bzJsZoom / 10 * 0.6,
            self.bzJsZoom / 10 * 0.6,
            self.bzJsZoom / 10 * 0.6
        )
        actor.Cable:K2_SetRelativeTransform(
            UE.FTransform(actor.Cable:GetRelativeTransform().Rotation,
                actor.Cable:GetRelativeTransform().Translation,
                cableScale),
            false, nil, false
        )
    end

    -- 垂直测绘线处理（代码结构类似，建议复用逻辑）
    local verbzClass = LoadClass("/Game/SandBox/Blueprints/DrawModel/BP_VerticalBZ.BP_VerticalBZ_C")
    self.verBZs = UE.UGameplayStatics.GetAllActorsOfClass(self:GetWorld(), verbzClass)
    local verScale = UE.FVector(
        self.bzJsZoom / 15,
        self.bzJsZoom / 15,
        self.bzJsZoom / 15
    )
    for _, value in pairs(self.verBZs) do
        local StartTransform = value.Cable1:GetRelativeTransform()
        local StartT = UE.FTransform(StartTransform.Rotation, UE.FVector(0, 0, 0), verScale)
        value.Cable1:K2_SetRelativeTransform(StartT, false, UE.FHitResult(), false)
        local EndPointTransform = value.Cable2:GetRelativeTransform()
        local EndPointT = UE.FTransform(EndPointTransform.Rotation, EndPointTransform.Translation, verScale)
        value.Cable2:K2_SetRelativeTransform(EndPointT, false, UE.FHitResult(), false)
        local CableTransform = value.Cable3:GetRelativeTransform()
        local CableT = UE.FTransform(CableTransform.Rotation, CableTransform.Translation, verScale)
        value.Cable3:K2_SetRelativeTransform(CableT, false, UE.FHitResult(), false)
    end
end

function M:CallJszoom()
    if self.Camera.ProjectionMode == 0 then
        self.jszoom = 5000 / self.targetArmLengthNew * 100
    else
        self.jszoom = 8000 / self.Camera.OrthoWidth * 100
    end
    -- 像素流送改造
    self.ui:UECallWeb("Jszoom", self.jszoom)
end

--- 根据jszoom值设置相机参数，与CallJszoom算法相反
--- @param jszoom number 从前端传入的缩放值
function M:SetZoomFromJs(jszoom)
    if self.Camera.ProjectionMode == 0 then
        -- 透视模式：逆运算公式 targetArmLengthNew = (5000 * 100) / jszoom
        self.targetArmLengthNew = 5000 / jszoom
    else
        -- 正交模式：逆运算公式 Camera.OrthoWidth = (8000 * 100) / jszoom
        self.Camera.OrthoWidth = 8000 / jszoom
    end
    -- 记录日志（可选）
    print(string.format("根据jszoom设置相机参数: jszoom=%.2f, 投影模式=%d", jszoom, self.Camera.ProjectionMode))
end

---M.ClickToCenter 居中模型
---@param ClickedActor        actor 被居中的模型
---@param CameraLocationBig   fvector 大件时调整的向量，可能不是居中在屏幕中间
---@param CameraLocationSmall fvector 小件时调整的向量，可能不是居中在屏幕中间
---@param BiggestSmaller      number 大小件的临界值
---@param BiggerDistance      number 大件的相机臂长
---@param SmallerDistance     number 小件的相机臂长
---@param Pitch_New           number 可选, 默认-17
---@param Yaw_New             number 可选, 默认90
---@return  Type Description
function M:ClickToCenter(ClickedActor, CameraLocationBig, CameraLocationSmall,
                         BiggestSmaller, BiggerDistance, SmallerDistance,
                         Pitch_New, Yaw_New)
    if ClickedActor then
        local origin, boxExtent = ClickedActor:GetActorBounds(false)
        local MaxBound = UE.UKismetMathLibrary.FMax(boxExtent.X, boxExtent.Y,
            boxExtent.Z)
        self.Pitch_New = Pitch_New or -17
        self.Yaw_New = Yaw_New or 90
        -- 判断是大件还是小件
        self.BiggestSmaller = 500
        if MaxBound > BiggestSmaller then
            print("大件")
            self.targetArmLengthNew = BiggerDistance
            -- print("新相机臂长： " .. self.targetArmLengthNew)
            self.Location_New = UE.FVector(CameraLocationBig.X + origin.X,
                CameraLocationBig.Y + origin.Y,
                CameraLocationBig.Z + origin.Z)
        else
            print("小件")
            self.targetArmLengthNew = MaxBound - SmallerDistance
            self.Location_New = UE.FVector(CameraLocationSmall.X + origin.X,
                CameraLocationSmall.Y + origin.Y,
                CameraLocationSmall.Z + origin.Z)
        end
        -- 相机动画
        self:Focus(self.Location_New, self.Pitch_New, self.Yaw_New,
            self.targetArmLengthNew)
    else
        print("居中模型不存在！")
    end
end

function M:SplitScreen(bclear)
    if self.PCPawnChilds:Num() == 0 and not bclear then
        self.bSplitScreen = true
        for i = 1, 3 do
            local pawnChild = self:GetWorld():SpawnActor(
                LoadClass('/Game/SandBox/BasicConfig/Gameplay/HY_PawnChild.HY_PawnChild_C'), UE.FTransform(),
                UE.ESpawnActorCollisionHandlingMethod.Default, self, self, "SandBox.BasicConfig.HY_PawnChild")
            pawnChild:SetStart(i)
            local pc = UE.UGameplayStatics.CreatePlayer(self:GetWorld(), i, true)
            pc:Possess(pawnChild)
            self.PCPawnChilds:Add(pc, pawnChild)
        end
        self.pc:Possess(self)
    else
        self.bSplitScreen = false
        for key, value in pairs(self.PCPawnChilds) do
            UE.UGameplayStatics.RemovePlayer(key, true)
        end
        self.PCPawnChilds:Clear()
        local Pawns = UE.UGameplayStatics.GetAllActorsOfClass(self:GetWorld(),
            LoadClass("/Game/SandBox/BasicConfig/Gameplay/Pawn.Pawn_C"))
        for key, value in pairs(Pawns) do
            if value ~= self then
                value:K2_DestroyActor()
            end
        end
    end
end

function M:PawnChildRun(FunctionName, Value)
    if self.pcInt > 0 then
        local screenPawn = self.PCPawnChilds:Values()[self.pcInt]
        screenPawn[FunctionName](screenPawn, Value)
        return true
    end
end

function M:CheckSplitScreen()
    -- print(self.pcInt, "self.pcInt ")
    if self.bSplitScreen and self.pcInt == -1 then
        local scale = UE.UWidgetLayoutLibrary.GetViewportScale(self:GetWorld())
        local view2d = UE.UWidgetLayoutLibrary.GetViewportSize(self:GetWorld())
        view2d = view2d / scale
        local bHave, x, y = UE.UWidgetLayoutLibrary.GetMousePositionScaledByDPI(self.pc)
        local mouse2d = UE.FVector2D(x, y)
        -- print(view2d, mouse2d)
        local int = 0
        if (view2d.X / 2) <= mouse2d.X then
            int = int + 1
        end
        if (view2d.Y / 2) <= mouse2d.Y then
            int = int + 2
        end
        self.pcInt = int
        print(self.pcInt, "self.pcInt ")
    end
end

-- 触屏
function M:move() --  一指触控旋转
    if self.Touch_F_Count == 1 then
        self.Mouse_Hold_02 = false
        local a = UE.AController.GetControlRotation(self.pc)
        local Pitch = a.Pitch
        local Yaw = a.Yaw
        local MOUSEX = self:GetInputAxisKeyValue(UE.EKeys.MouseX)
        local MOUSEY = self:GetInputAxisKeyValue(UE.EKeys.MouseY)
        local Y = Pitch + MOUSEY
        local X = Yaw + MOUSEX
        local ClampAngle = UE.UKismetMathLibrary.ClampAngle(Y,
            self.pitchLimitMin,
            self.pitchLimitMax)
        local FRotator = UE.FRotator(ClampAngle, X, 0.0)
        self.pc:SetControlRotation(FRotator)
    end
end

function M:Secondfinger(Zoom) -- 二指移动
    if self.Touch_F_Count == 2 then
        self.Mouse_Hold_01 = false
        local length = self.UTCPinchComponent.InitialLength
        local A = UE.UKismetMathLibrary
            .NearlyEqual_FloatFloat(Zoom, length, 5.0)
        if A then
            self.UTCPinchComponent.InitialLength = Zoom
        else
            if length > Zoom then
                self:XIAGUN()
                self.UTCPinchComponent.InitialLength = Zoom
            else
                self:SHANGUN()
                self.UTCPinchComponent.InitialLength = Zoom
            end
        end
    else
        if self.Touch_F_Count == 3 then -- 三指移动
            self.Mouse_Hold_02 = true
            self.Mouse_Hold_01 = false
        end
    end
end

function M:End() -- 触控停止
    self.Mouse_Hold_02 = false
    self.Mouse_Hold_01 = false
end

function M:onefinger() --  设置鼠标位置，防止旋转时出现旋转断触的情况
    local x = self.x
    local y = self.y
    local FTX = UE.UKismetMathLibrary.FTrunc(x)
    local FTy = UE.UKismetMathLibrary.FTrunc(y)
    UE.APlayerController.SetMouseLocation(self.pc, FTX, FTy)
    self.Mouse_Hold_02 = false
    print(self.Touch_F_Count)
end

function M:ToCenter(origin, boxExtent, Pitch, Yaw, Offset)
    Pitch = Pitch or -50
    Yaw = Yaw or -90
    Offset = Offset or UE.FVector2D(0, 0)

    local radius = math.max(math.sqrt(boxExtent.X ^ 2 + boxExtent.Y ^ 2 + boxExtent.Z ^ 2), 10)
    local resolution = UE.UWidgetLayoutLibrary.GetViewportSize(self:GetWorld())
    local aspectToUse = resolution.X / resolution.Y

    if boxExtent.Z / boxExtent.X > 2 then
        radius = boxExtent.Z * 2
    end

    if aspectToUse then
        radius = radius * aspectToUse
    end
    local halfFOVRadians = math.rad(self.camera.FieldOfView / 2)
    local distanceFromSphere = radius / math.tan(halfFOVRadians)

    local rotation = self.camera:K2_GetComponentRotation()
    -- local p = Pitch + rotation.Pitch
    -- local y = Yaw + rotation.Yaw

    local xMovement = (-Offset.X / resolution.X) * distanceFromSphere * math.tan(halfFOVRadians)
    local yMovement = (-Offset.Y / resolution.Y) * distanceFromSphere * math.tan(halfFOVRadians)
    local xDirection = UE.UKismetMathLibrary.GetRightVector(UE.FRotator(Pitch, Yaw, 0))
    local yDirection = UE.UKismetMathLibrary.GetUpVector(UE.FRotator(Pitch, Yaw, 0))
    print(xDirection, yDirection)
    origin = origin + xDirection * xMovement + yDirection * yMovement

    self:Focus(origin, Pitch, Yaw, distanceFromSphere * 0.5)
end

function M:MapRange(value)
    if value >= 50 then
        return value / 50
    else
        return value * (50 - 0.25) / 50 / 50 + 0.25
    end
end

return M
