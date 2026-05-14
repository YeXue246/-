--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class UI_map_C
local M = UnLua.Class()
local Class = require("SandBox.Class")


--function M:Initialize(Initializer)

--end

function M:PreConstruct(IsDesignTime)
    -- self.Button_4.OnClicked:Add(self, self.switch3d)
    -- self.Button_3.OnClicked:Add(self, self.switch2d)
end

function M:Construct()
    local camera1class = LoadClass(
        '/Game/SandBox/Blueprints/zlq/camera1.camera1_C')
    self.camera1 = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(), camera1class)
    local pawnClass = LoadClass(Class.hyPawn)
    self.pawn = UE.UGameplayStatics.GetPlayerPawn(self:GetWorld(), 0):Cast(
        pawnClass)
end

-- function M:switch2d()
--     if self.pawn.Floor == nil then
--         self.pawn.Floor = self.camera1:K2_GetActorLocation().Z
--     end
--     local ViewDataLocation = UE.FVector(0, 0, self.pawn.Floor + 960)
--     local ViewDataRotation = UE.FRotator(-90, 90, 0)
--     local SweepHitResult = UE.FHitResult()
--     self.camera1:K2_SetActorLocationAndRotation(ViewDataLocation, ViewDataRotation, false, SweepHitResult, false)
--     self.camera1.SceneCaptureComponent2D.ProjectionMode = 1
-- end

-- function M:switch3d()
--     if self.pawn.Floor == nil then
--         self.pawn.Floor = self.camera1:K2_GetActorLocation().Z
--     end
--     print(self.pawn.Floor)
--     print(self.camera1:K2_GetActorLocation().Z)
--     local ViewDataLocation = UE.FVector(0, 0, self.pawn.Floor + 960)
--     local ViewDataRotation = UE.FRotator(-135, 90, 0)
--     local SweepHitResult = UE.FHitResult()
--     self.camera1:K2_SetActorLocationAndRotation(ViewDataLocation, ViewDataRotation, false, SweepHitResult, false)
--     self.camera1.SceneCaptureComponent2D.ProjectionMode = 0
-- end

-- function M:ToBig(Actor)
--     Screen.Print("ToBig", 10)
--     if Actor then
--         local A = Actor
--         local origin, Box = A:GetActorBounds(false)
--         local l = DFL.integrate(math.max(Box.X, Box.Y, Box.Z))
--         print(l .. "|" .. Box.X .. "|" .. Box.Y .. "|" .. Box.Z)
--         local Focus_Curve = LoadObject(
--                                 "/Game/SandBox/BasicConfig/Curves/Focus_Curve.Focus_Curve")
--         local r = Focus_Curve:GetFloatValue(l)
--         self.camera1:focus(origin, -20, 130, r)
--     end
-- end




-- function M:focus()
--         -- TargetArmLength 在Tick中改变
--         self.TargetArmLength_New = TargetArmLength_New
--         -- Store Current Location and Rotation
--         self.Location_Current = self:K2_GetActorLocation()
--         local RotCur = self:GetControlRotation()
--         self.Pitch_Current = RotCur.Pitch
--         self.Yaw_Current = RotCur.Yaw
--         -- Store New Location and Rotation
--         self.Location_New = Location_New
--         self.Pitch_New = Pitch_New
--         self.Yaw_New = Yaw_New
--         -- Location and Rotation animation
--         self.Timeline_Focus_Animation:SetPlayRate(self.Focus_Animation_PlayRate)
--         self.Timeline_Focus_Animation:PlayFromStart()
-- end


-- function M:Tick(MyGeometry, InDeltaTime)
--     if self:IsPawnControlled() then
--         -- debug
--         local LocStr = UE.UKismetStringLibrary.Conv_VectorToString(
--             self:K2_GetActorLocation())
--         local RotStr = UE.UKismetStringLibrary.Conv_RotatorToString(
--             self:GetControlRotation())
--         local ArmLenStr = UE.UKismetStringLibrary.Conv_FloatToString(
--             self.TargetArmLength_New)
--         Screen.Print(LocStr .. " " .. RotStr .. " + " .. ArmLenStr, 0)
--         -- change spring arm length every frame
--         local IsEqual = UE.UKismetMathLibrary.NearlyEqual_FloatFloat(
--             self.SpringArm.TargetArmLength,
--             self.TargetArmLength_New, 0)
--         if not IsEqual then
--             local Alpha = UE.UKismetMathLibrary.Lerp(3, 1,
--                 self:SpringArm_Length_Normalized())
--             self.SpringArm.TargetArmLength =
--                 UE.UKismetMathLibrary.FInterpTo(self.SpringArm.TargetArmLength,
--                     self.TargetArmLength_New,
--                     DeltaSeconds, Alpha)
--         end
--     end
-- end

return M
