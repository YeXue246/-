--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class HY_PawnChild_C
local M = UnLua.Class()

local Screen = require("SandBox.Screen")
local ZoomCurve = UE.UObject.Load("/Game/SandBox/BasicConfig/Curves/Zoom_Intensity_Curve.Zoom_Intensity_Curve")
local PanCurve = UE.UObject.Load("/Game/SandBox/BasicConfig/Curves/Pan_Intensity_Curve.Pan_Intensity_Curve")

function M:Initialize(Initializer)
    -- zoom
    self.height = 0
    self.springArmLengthMin = 1000
    self.springArmLengthMax = 10000
    self.targetArmLengthNew = 1000
    self.zoomSpeedMouse = 5000
    self.zoomIntensityCurve = ZoomCurve
    -- pan
    self.panIntensityMouse = 0.1
    self.panIntensityCurve = PanCurve
    -- rotate
    self.rotationSpeedMouse = 2
    self.pitchLimitMin = -75
    self.pitchLimitMax = 5
    self.pitchCurrent = -117.202034
    self.yawCurrent = 5.463144
    self.pitchNew = 0
    self.yawNew = 0
    -- mouse
    self.mouseHoldLeft = false
    self.mouseHoldRight = false
    -- location
    self.locationCurrent = UE.FVector()
    self.locationNew = UE.FVector()
    -- focus factor
    self.focusAnimationPlayRate = 0.75
    self.jsZoom = 100

    -- self.BoxSelection = false
    self.amplificationRate = 1
    self.pcInt = 1
end

function M:ReceiveBeginPlay()
    local viewDataStrClass = UE.UObject.Load("/Game/SandBox/BasicConfig/Data/Str_View.Str_View")
    self.viewData = UE.TMap("", viewDataStrClass)
    local viewData = viewDataStrClass()
    viewData.Location = UE.FVector(0, 0, 1000)
    viewData.Pitch = 5
    viewData.Yaw = -90
    viewData.ArmLength = 8000
    self.viewData:Add("北", viewData)
    viewData.Location = UE.FVector(0, 0, 1000)
    viewData.Pitch = 5
    viewData.Yaw = 180
    viewData.ArmLength = 8000
    self.viewData:Add("西", viewData)
    viewData.Location = UE.FVector(0, 0, 1000)
    viewData.Pitch = 5
    viewData.Yaw = 0
    viewData.ArmLength = 8000
    self.viewData:Add("东", viewData)
    viewData.Location = UE.FVector(0, 0, 1000)
    viewData.Pitch = 5
    viewData.Yaw = 90
    viewData.ArmLength = 8000
    self.viewData:Add("南", viewData)

    viewData.Location = UE.FVector(0, 0, 3000)
    viewData.Pitch = -85
    viewData.Yaw = -90
    viewData.ArmLength = 8000
    self.viewData:Add("平面", viewData)
    local viewData = viewDataStrClass()
    viewData.Location = UE.FVector(0, 0, 3000)
    viewData.Pitch = -85
    viewData.Yaw = -90
    viewData.ArmLength = 8000
    self.viewData:Add("顶面", viewData)
    viewData.Location = UE.FVector(0, 0, 1000)
    viewData.Pitch = 5
    viewData.Yaw = -90
    viewData.ArmLength = 8000
    self.viewData:Add("立面", viewData)
    viewData.Location = UE.FVector(0, 0, 0)
    viewData.Pitch = -45
    viewData.Yaw = -90
    viewData.ArmLength = 5000
    self.viewData:Add("3d", viewData)
    viewData.Location = UE.FVector(0, 0, 0)
    viewData.Pitch = -85
    viewData.Yaw = -90
    viewData.ArmLength = 5000
    self.viewData:Add("2d", viewData)

    Screen.Print("viewData Length: " .. self.viewData:Length(), 50)
    -- 初始化视角
    self:ChooseViewData("3d")
end

function M:ChooseViewData(viewName)
    local value = self.viewData:Find(viewName)
    local l = UE.FVector(value.Location.X, value.Location.Y, value.Location.Z)
    self:Focus(l, value.Pitch, value.Yaw, value.ArmLength)
end

function M:ReceiveTick(deltaSeconds)
    if self:IsPawnControlled() then
        -- debug
        local LocStr = tostring(self:K2_GetActorLocation())
        local RotStr = tostring(self:GetControlRotation())
        local armLenStr = tostring(self.targetArmLengthNew)
        Screen.Print(LocStr .. " " .. RotStr .. " + " .. armLenStr .. "\n" .. self.Camera.OrthoWidth, 0)
        -- change spring arm length every frame
        local IsEqual = UE.UKismetMathLibrary.NearlyEqual_FloatFloat(
            self.SpringArm.TargetArmLength,
            self.targetArmLengthNew, 0)
        if not IsEqual then
            local Alpha = UE.UKismetMathLibrary.Lerp(3, 1,
                self:SpringArmLengthNormalized())
            self.SpringArm.TargetArmLength =
                UE.UKismetMathLibrary.FInterpTo(self.SpringArm.TargetArmLength,
                    self.targetArmLengthNew,
                    deltaSeconds, Alpha)
        end
    end
end

function M:SpringArmLengthNormalized()
    return UE.UKismetMathLibrary.NormalizeToRange(
        self.SpringArm.TargetArmLength, self.springArmLengthMin,
        self.springArmLengthMax)
end

-- switch view
function M:Focus(locationNew, pitchNew, yawNew, targetArmLengthNew)
    -- TargetArmLength 在Tick中改变
    self.targetArmLengthNew = targetArmLengthNew
    -- Store Current Location and Rotation
    self.locationCurrent = self:K2_GetActorLocation()
    local rotCur = self:GetControlRotation()
    self.pitchCurrent = rotCur.Pitch
    self.yawCurrent = rotCur.Yaw
    -- Store New Location and Rotation
    self.locationNew = locationNew
    self.pitchNew = pitchNew
    self.yawNew = yawNew
    -- Location and Rotation animation
    self.TimelineFocusAnimation:SetPlayRate(self.focusAnimationPlayRate)
    self.TimelineFocusAnimation:PlayFromStart()
end

function M:TimelineUpdate(alpha)
    local tempLocation = UE.UKismetMathLibrary.VLerp(self.locationCurrent,
        self.locationNew, alpha)
    local sweepHitResult = UE.FHitResult()
    self:K2_SetActorLocation(tempLocation, false, sweepHitResult, false)
    local tempRotator = UE.UKismetMathLibrary.RLerp(UE.FRotator(
            self.pitchCurrent,
            self.yawCurrent, 0) --[[rotator构造：pitch，yaw，roll]],
        UE.FRotator(self.pitchNew,
            self.yawNew, 0),
        alpha, true)

    local pc = UE.UGameplayStatics.GetPlayerController(self:GetWorld(), self.pcInt)
    if pc then
        pc:SetControlRotation(UE.FRotator(
            tempRotator.Pitch,
            tempRotator.Yaw, 0))
    end
end

-- 鼠标左右平移时
function M:MouseX(AxisValue)
    local val = self.panIntensityCurve:GetfloatValue(
            self:SpringArmLengthNormalized()) *
        self.panIntensityMouse
    local ScaleValue = AxisValue * (-1) * val * 10
    local TempRot = UE.FRotator(0, self:GetControlRotation().Yaw, 0)
    -- Screen.Print("TempRot: " .. TempRot.Pitch .. " , " .. TempRot.Yaw .. " , " .. TempRot.Roll, 0)
    local Direction = UE.UKismetMathLibrary.GetRightVector(TempRot)
    -- Screen.Print("Direction: " .. Direction.X .. " , " .. Direction.Y .. " , " .. Direction.Z, 0)

    self:K2_AddActorWorldOffset(Direction * ScaleValue * 200, false, nil, false)
end

-- 鼠标上下平移时
function M:MouseY(AxisValue)
    local val = self.panIntensityCurve:GetfloatValue(
            self:SpringArmLengthNormalized()) *
        self.panIntensityMouse
    local ScaleValue = AxisValue * (-1) * val * 10
    local TempRot = UE.FRotator(0, self:GetControlRotation().Yaw, 0)
    local Direction = UE.UKismetMathLibrary.GetForwardVector(TempRot)
    if self.pcInt ~= 1 then
        self:MoveUp(-AxisValue)
    else
        Direction = Direction * 200
    end
    self:K2_AddActorWorldOffset(Direction * ScaleValue, false, nil, false)
end

-- Q/E 上下移动视角
function M:MoveUp(value)
    local val = self.panIntensityCurve:GetfloatValue(
            self:SpringArmLengthNormalized()) *
        self.panIntensityMouse
    local upVec = self:GetActorUpVector()
    self:K2_AddActorWorldOffset(upVec * val * value * 2000, false, nil, false)
end

-- W/S 前后移动视角
function M:MoveForward(value)
    local val = self.panIntensityCurve:GetfloatValue(
            self:SpringArmLengthNormalized()) *
        self.panIntensityMouse * -2
    local Rotator = self:GetControlRotation()
    -- print(Rotator)
    local InRot = UE.UKismetMathLibrary.GetForwardVector(Rotator)
    self:K2_AddActorWorldOffset(InRot * val * value * 200, false, nil, false)
end

-- A/D 左右移动视角
function M:MoveRight(value)
    local val = self.panIntensityCurve:GetfloatValue(
            self:SpringArmLengthNormalized()) *
        self.panIntensityMouse * -2
    local Rotator = self:GetControlRotation()
    -- print(Rotator)
    local InRot = UE.UKismetMathLibrary.GetRightVector(Rotator)
    self:K2_AddActorWorldOffset(InRot * val * value * 200, false, nil, false)
end

-- 按住鼠标左键x旋转
function M:TurnRate(value)
    if self.Camera.ProjectionMode == 0 then
        local pc = UE.UGameplayStatics.GetPlayerController(self:GetWorld(), self.pcInt)
        local pcRot = pc:GetControlRotation()
        local newRotYaw = self.rotationSpeedMouse * value + pcRot.Yaw
        local viewData = UE.UKismetMathLibrary.ClampAngle(pcRot.Pitch,
            self.pitchLimitMin,
            self.pitchLimitMax)
        pc:SetControlRotation(UE.FRotator(viewData, newRotYaw, 0))
    end
end

-- 按住鼠标左键y旋转
function M:LookUpRate(value)
    if self.Camera.ProjectionMode == 0 then
        local pc = UE.UGameplayStatics.GetPlayerController(self:GetWorld(), self.pcInt)
        local pcRot = pc:GetControlRotation()
        local newRotYaw = pcRot.Yaw
        local viewData = UE.UKismetMathLibrary.ClampAngle(pcRot.Pitch +
            self.rotationSpeedMouse *
            value,
            self.pitchLimitMin,
            self.pitchLimitMax)
        pc:SetControlRotation(UE.FRotator(viewData, newRotYaw, 0))
    end
end

function M:MouseWheelUpDown(up)
    local floatValue = 100
    if self.Camera.ProjectionMode == 0 then
    elseif self.Camera.ProjectionMode == 1 then
        if up then
            if self.Camera.OrthoWidth <= 10000 and self.Camera.OrthoWidth >= 2000 then
                self.Camera.OrthoWidth = self.Camera.OrthoWidth - floatValue * self.amplificationRate
            else
                self.Camera.OrthoWidth = 2000
            end
        else
            -- 鼠标向下滚动

            if self.Camera.OrthoWidth <= 10000 and self.Camera.OrthoWidth >= 2000 then
                self.Camera.OrthoWidth = self.Camera.OrthoWidth + floatValue * self.amplificationRate
            else
                self.Camera.OrthoWidth = 10000
            end
        end
    end
end

function M:SetStart(int)
    print(int)
    self.pcInt = int
    if int == 1 then
        self:ChooseViewData("顶面")
    elseif int == 2 then
        self:ChooseViewData("西")
    elseif int == 3 then
        self:ChooseViewData("北")
    end
end

return M
