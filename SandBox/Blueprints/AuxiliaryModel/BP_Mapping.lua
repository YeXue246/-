--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--
---@class BP_Mapping_C
local M = UnLua.Class()
local Screen = require("SandBox.Screen")
local Model = require("SandBox.ModelNameInitialize")
local DFL = require("SandBox.DataFunction")
local Zoom_Curve = UE.UObject.Load(
    "/Game/SandBox/BasicConfig/Curves/Zoom_Intensity_Curve.Zoom_Intensity_Curve")
local Pan_Curve = UE.UObject.Load(
    "/Game/SandBox/BasicConfig/Curves/Pan_Intensity_Curve.Pan_Intensity_Curve")

function M:Initialize(Initializer)
    self.ActorTransform = UE.FTransform()
    -- local UISandBoxClass = LoadClass("/Game/SandBox/UI/UI_SandBox.UI_SandBox_C")
    -- self.uiSandBox = self:ShowUI(self.uiSandBox, UISandBoxClass)
    self.height = 0
    self.SpringArm_Length_Min = -20000
    self.SpringArm_Length_Max = 2500000
    self.TargetArmLength_New = 1000
    self.Zoom_Speed_Mouse = 2000
    self.Zoom_Intensity_Curve = Zoom_Curve
    -- pan
    self.Pan_Intensity_Mouse = 0.02
    self.Pan_Intensity_Curve = Pan_Curve
    -- rotate
    self.Rotation_Speed_Mouse = 2
    self.PitchLimit_Min = -75
    self.PitchLimit_Max = 0
    self.Pitch_Current = -117.202034
    self.Yaw_Current = 5.463144
    self.Pitch_New = 0
    self.Yaw_New = 0
    -- mouse
    self.Mouse_Hold_Left = false
    self.Mouse_Hold_Right = false
    -- location
    self.Location_Current = UE.FVector()
    self.Location_New = UE.FVector()
    -- focus factor
    self.Focus_Animation_PlayRate = 0.75
end

function M:ReceiveBeginPlay()
    local PawnClass = LoadClass("/Game/SandBox/BasicConfig/GamePlay/Pawn.Pawn_C")
    self.Pawn = UE.UGameplayStatics.GetPlayerPawn(self:GetWorld(), 0):Cast(
        PawnClass)
    local PCClass = LoadClass("/Game/SandBox/BasicConfig/Gameplay/PC.PC_C")
    self.pc = UE.UGameplayStatics.GetPlayerController(self:GetWorld(), 0):Cast(
        PCClass)
    local camera1class = LoadClass(
        '/Game/SandBox/Blueprints/zlq/camera1.camera1_C')
    self.camera1 = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(),
        camera1class)
    self.Floor = 1
    -- self.TargetArmLength_New = self.SpringArm.TargetArmLength
end

function M:ReceiveTick(DeltaSeconds)
    if self.pc.uiSandBox.control.buildActor == nil then
        self.Actor = self.pc.uiSandBox.control.buildActor
    end
    if self.Actor ~= self.pc.uiSandBox.control.buildActor then
        if self.pc.uiSandBox.JudgedetectActor then
            self.pc.uiSandBox.JudgedetectActor:K2_DestroyActor()
            self.pc.uiSandBox.JudgedetectActor = nil
        end
    end
    if self.pc.uiSandBox.control.currentFloor ~= self.Floor then
        self.Floor = self.pc.uiSandBox.control.currentFloor
    end
    if self.pc.uiSandBox.control.buildActor then
        -- print("you")
        self.Actor = self.pc.uiSandBox.control.buildActor
        if self.Actor:GetTransform() ~= self.ActorTransform then
            for i = 1, 4 do
                self:Distance(i)
            end
            self.ActorTransform = self.Actor:GetTransform()
            self.bigtf = true
        end
        if self.CilckActors then
            for i = 1, 4 do
                self:Distance(i)
            end
        end
        if self.bigtf then
            self:Big()
            self.bigtf = false
        end
    else
        for key, value in pairs(self.CilckActors) do
            value:K2_DestroyActor()
        end
        self.CilckActors:Clear()
        -- print("wu")
    end
end

-- 1S,2N,3W,4E
-- 生成测距线
function M:Distance(Int)
    -- print("123456")
    -- local Actor = self.control.buildActor
    if self.Actor then
        local origin, boxExtent = self.Actor:GetActorBounds(false)
        local ActorName = Model.GetActorAccurateDisplayName(self.Actor)
        local FloorActor =
            self.pc.uiSandBox.control.modelManage:FindActor(self.Floor .. "Floor-s")
        -- print("FloorActor--" ..
        --   UE.UKismetSystemLibrary.GetObjectName(FloorActor))
        local OriginFloor, BoxExtentFloor = FloorActor:GetActorBounds(false)
        -- print("OriginFloor" .. tostring(OriginFloor))
        -- print("BoxExtentFloor" .. tostring(BoxExtentFloor))

        local Start = UE.FVector()
        local End = UE.FVector()
        local FloorEnd = UE.FVector()
        if Int == 1 then
            Start = UE.FVector(origin.X - boxExtent.X, origin.Y,
                OriginFloor.Z + BoxExtentFloor.Z + 10)
            End = UE.FVector(math.abs(origin.X - boxExtent.X) * -200, origin.Y,
                OriginFloor.Z + BoxExtentFloor.Z + 10)
            FloorEnd = UE.FVector(OriginFloor.X - BoxExtentFloor.X, origin.Y,
                OriginFloor.Z + BoxExtentFloor.Z + 10)
        elseif Int == 2 then
            Start = UE.FVector(origin.X + boxExtent.X, origin.Y,
                OriginFloor.Z + BoxExtentFloor.Z + 10)
            End = UE.FVector(math.abs(origin.X + boxExtent.X) * 200, origin.Y,
                OriginFloor.Z + BoxExtentFloor.Z + 10)
            FloorEnd = UE.FVector(OriginFloor.X + BoxExtentFloor.X, origin.Y,
                OriginFloor.Z + BoxExtentFloor.Z + 10)
        elseif Int == 3 then
            Start = UE.FVector(origin.X, origin.Y + boxExtent.Y,
                OriginFloor.Z + BoxExtentFloor.Z + 10)
            End = UE.FVector(origin.X, math.abs(origin.Y + boxExtent.Y) * 200,
                OriginFloor.Z + BoxExtentFloor.Z + 10)
            FloorEnd = UE.FVector(origin.X, OriginFloor.Y + BoxExtentFloor.Y,
                OriginFloor.Z + BoxExtentFloor.Z + 10)
        elseif Int == 4 then
            Start = UE.FVector(origin.X, origin.Y - boxExtent.Y,
                OriginFloor.Z + BoxExtentFloor.Z + 10)
            End = UE.FVector(origin.X, math.abs(origin.Y - boxExtent.Y) * -200,
                OriginFloor.Z + BoxExtentFloor.Z + 10)
            FloorEnd = UE.FVector(origin.X, OriginFloor.Y - BoxExtentFloor.Y,
                OriginFloor.Z + BoxExtentFloor.Z + 10)
        end
        -- Screen.Print(math.abs(origin.X - boxExtent.X))
        local HitRes = UE.FHitResult()
        print("1")
        UE.UKismetSystemLibrary.LineTraceSingle(self:GetWorld(), Start, End,
            UE.ETraceTypeQuery.Model, false,
            nil, 0, HitRes, true)
        local ActorName = UE.UKismetSystemLibrary.GetDisplayName(HitRes.HitObjectHandle.Actor)
        -- print(HitRes.bBlockingHit)
        local CilckActor = self.CilckActors:Find(Int)
        for key, value in pairs(self.CilckActors) do
            -- print(key)
        end
        if not CilckActor then
            -- print("shengcheng")
            local CilckActorClass = LoadClass(
                "/Game/SandBox/Blueprints/zlq/BP_CilckActor.BP_CilckActor_C")
            local Transform = UE.FTransform()
            Transform.Translation = UE.FVector(0, 0, 0)
            CilckActor = self:GetWorld():SpawnActor(CilckActorClass, Transform,
                UE.ESpawnActorCollisionHandlingMethod
                .Default, self, self)
            self.CilckActors:Add(Int, CilckActor)
        end
        if HitRes.bBlockingHit then
            local Location = UE.FVector(HitRes.Location.X, HitRes.Location.Y,
                OriginFloor.Z + BoxExtentFloor.Z + 10)
            CilckActor:cilckactor(Start, Location)
            local white = UE.UObject.Load(
                "/Game/SandBox/Materials/M_Point_2.M_Point_2")
            CilckActor.EndPoint:SetMaterial(0, white)
            CilckActor.StartPoint:SetMaterial(0, white)
            CilckActor.Cable:SetMaterial(0, white)
        else
            -- print(Int .. "当前方向")
            -- print(FloorEnd)
            CilckActor:cilckactor(Start, FloorEnd)
            local Red = UE.UObject.Load(
                "/Game/SandBox/Materials/M_Point_3.M_Point_3")
            CilckActor.EndPoint:SetMaterial(0, Red)
            CilckActor.StartPoint:SetMaterial(0, Red)
            CilckActor.Cable:SetMaterial(0, Red)
            -- if self.CilckActors:Find(Int) then
            --     local Location = UE.FVector(HitRes.Location.X, HitRes.Location.Y, origin.Z)
            --     self.CilckActors:Find(Int):cilckactor(Start, Location, HitRes.bBlockingHit)
            -- end
        end
    end
end

--小地图视角追随
function M:Big()
    -- print("ToBig1")
    -- Screen.Print(tostring(UE.UKismetSystemLibrary.GetObjectName(self.Actor)))
    local origin, Box = self.Actor:GetActorBounds(false)
    -- Screen.Print(tostring(origin),10)
    local l = DFL.integrate(math.max(Box.X, Box.Y, Box.Z))
    -- print(l .. "|" .. Box.X .. "|" .. Box.Y .. "|" .. Box.Z)
    local Focus_Curve = LoadObject(
        "/Game/SandBox/BasicConfig/Curves/Focus_Curve.Focus_Curve")
    local r = Focus_Curve:GetFloatValue(l)
    -- Screen.Print(r,10)
    local Rotator1 = UE.FRotator(-20, 130, 0)
    local Rotator2 = UE.FRotator(-90, 0, 0)
    local SweepHitResult = UE.FHitResult()
    -- self.Pawn.Camera.ProjectionMode = 0
    if self.Pawn.Camera.ProjectionMode == 1 then
        -- self.camear1.SceneCaptureComponent2D.ProjectionMode = 1
        self.camera1:K2_SetActorLocationAndRotation(origin, Rotator1, false, SweepHitResult, false)
        self.camera1.SpringArm.TargetArmLength = r / 3
        -- origin, -20, 130, r)
        -- print(tostring(origin) .. "123456")
        -- print("ToBig2")
    elseif self.Pawn.Camera.ProjectionMode == 0 then
        -- self.camear1.SceneCaptureComponent2D.ProjectionMode = 0
        self.camera1:K2_SetActorLocationAndRotation(origin, Rotator2, false, SweepHitResult, false)
        self.camera1.SpringArm.TargetArmLength = r / 3
    end
end

return M
