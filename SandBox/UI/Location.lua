--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--
---@class UI_location_C
local M = UnLua.Class()
local Screen = require("SandBox.Screen")
local staactor = UE.TMap("", UE.AStaticMeshActor)
local Model = require("SandBox.ModelNameInitialize")
local json = require("dkjson")
local Class = require("SandBox.Class")

-- function M:Initialize(Initializer)
-- end

function M:PreConstruct(IsDesignTime)
    -- self.CheckBox_1.OnCheckStateChanged:Add(self, self.CheckBox1)
    -- self.ComboBoxString_0.OnSelectionChanged:Add(self, self.pawnilrotation)

    self.SpinBox_0.OnValueChanged:Add(self, self.zoom)
    -- self.Button_1.OnClicked:Add(self, self.Buttonreset)
    self.Button_0.OnClicked:Add(self, self.switch)
    self.Button.OnClicked:Add(self, self.toBig)
    self.viewRate = 1

    -- self.Button_5.OnClicked:Add(self, self.magnify)
    -- self.CheckBox_1.OnCheckStateChanged:Add(self, self.survey)
    -- replace
end

function M:Construct()
    -- self.cilck = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(), LoadClass(
    --     "/Game/DNY/Blueprint/Ranging/cilck.cilck_C"))
    self.PUI = nil
    self.cilck = nil
    local pawnClass = LoadClass(Class.hyPawn)
    self.pawn = UE.UGameplayStatics.GetPlayerpawn(self:GetWorld(), 0):Cast(pawnClass)
    self.location =
        UE.UGameplayStatics.GetActorOfClass(self:GetWorld(),
            LoadClass("/Game/DNY/Blueprint/Ranging/1234565.1234565_C"))
    local pcClass = LoadClass(Class.hyPC)
    self.pc = UE.UGameplayStatics.GetPlayerController(self:GetWorld(), 0):Cast(pcClass)
end

function M:switch(Boolean, classify, view)
    local b3D = Boolean
    if view == 2 then
        b3D = not Boolean
    end
    if b3D then
        self.pc.uiSandBox.UI_direction_C_0:SetVisibility(1)
        -- local ViewDataLocation = UE.FVector(0, 0, self.pawn.Floor + 920)
        -- local ViewDataRotation = UE.FRotator(-85, -90, 0)
        -- -- self.camera1:K2_SetActorLocationAndRotation(
        -- --     ViewDataLocation,
        -- --     ViewDataRotation,
        -- --     false,
        -- --     UE.FHitResult(),
        -- --     false
        -- -- )
        self.pawn.PitchLimit_Min = -75
        self.pawn.PitchLimit_Max = 5
        if classify == 1 then
            self.pawn:ChooseViewData("3d")
            -- self.pc.uiSandBox.UI_map.TextBlock_1:SetText("2D-顶面")
        elseif classify == 2 then
            self.pawn:ChooseViewData("北")
            -- self.pc.uiSandBox.UI_map.TextBlock_1:SetText("2D-顶面")
        end

        coroutine.resume(
            coroutine.create(
                function()
                    UE.UKismetSystemLibrary.Delay(self, 1.5)
                    -- self.camera1.SceneCaptureComponent2D.ProjectionType = 1
                    self.pawn.Camera.OrthoWidth = 5000
                    self.pawn.targetArmLengthNew = 5000
                    self.pawn.Camera.ProjectionMode = 0
                end
            ),
            self
        )
    else
        -- self.pc.uiSandBox.UI_direction_C_0:SetVisibility(1)
        self.pawn:ChooseViewData("2d")
        -- local ViewDataLocation = UE.FVector(-880, -300, self.pawn.currentFloor + 920)
        -- local ViewDataRotation = UE.FRotator(-30, -90, 0)
        -- self.camera1:K2_SetActorLocationAndRotation(
        --     ViewDataLocation,
        --     ViewDataRotation,
        --     false,
        --     UE.FHitResult(),
        --     false
        -- )
        self.pawn.PitchLimit_Min = -90
        self.pawn.PitchLimit_Max = 5
        if classify == 1 then
            self.pawn:ChooseViewData("平面")

            self.pc.uiSandBox.UI_map.TextBlock_1:SetText("3D-俯视")
        elseif classify == 2 then
            self.pawn:ChooseViewData("顶面")

            self.pc.uiSandBox.UI_map.TextBlock_1:SetText("3D-俯视")
        elseif classify == 3 then
            self.pawn:ChooseViewData("立面")
            self.pc.uiSandBox.UI_map.TextBlock_1:SetText("3D-俯视")
            self.pc.uiSandBox.UI_direction_C_0:SetVisibility(0)
        end
        coroutine.resume(
            coroutine.create(
                function()
                    UE.UKismetSystemLibrary.Delay(self, 1.5)
                    -- self.pawn.Camera.OrthoWidth = 8000 / self.pawn.Jszoom * 100
                    -- self.pawn.targetArmLengthNew = 5000 / self.pawn.Jszoom * 100
                    -- self.camera1.SceneCaptureComponent2D.ProjectionType = 0
                    self.pawn.Camera.OrthoWidth = 5000
                    self.pawn.targetArmLengthNew = self.pawn.targetArmLengthNew / self.viewRate
                    self.pawn.Camera.ProjectionMode = 1
                end
            ),
            self
        )
    end
    self.pc.uiSandBox:UECallWeb("Jszoom", 100)
end

function M:reset()
    self.pawn.jszoom = 100
    if self.pawn.Camera.ProjectionMode == 0 then
        self:switch(true, 1, 1)
    elseif self.pawn.Camera.ProjectionMode == 1 then
        self:switch(false, 1, 1)
    end
    self.pc.uiSandBox:UECallWeb("Jszoom", 100)
end

function M:zoom(Value)
    self.pawn:SetZoomFromJs(Value)
end

function M:toBig(Actor)
    local ShowMeshs = UE.TArray(UE.AStaticMeshActor)
    print(Actor.modelType)
    if Actor.modelType == "Multi" then
        ShowMeshs = Actor.STCActors
    elseif Actor.modelType == "Group" then
        local As = UE.TArray(UE.AActor)
        Actor:GetAttachedActors(As, true)
        if As:Num() > 0 then
            Model.GetChildOfStaticMeshActors(As, ShowMeshs)
        end
    elseif Actor.modelType then
        ShowMeshs:Add(Actor)
    end
    if ShowMeshs:Num() > 0 then
        self:ToCenter(ShowMeshs)
    else
        self:reset()
    end
    self.pawn:CallJszoom()
end

function M:ToCenter(ShowMeshs)
    local origin, Box = UE.UGameplayStatics.GetActorArrayBounds(ShowMeshs, false)
    local radius = math.max(math.sqrt(Box.X ^ 2 + Box.Y ^ 2 + Box.Z ^ 2), 10)
    local resolution = UE.UWidgetLayoutLibrary.GetViewportSize(self:GetWorld())
    local aspectToUse = resolution.X / resolution.Y

    if Box.Z / Box.X > 2 then
        radius = Box.Z * 2
    end

    if aspectToUse then
        radius = radius * aspectToUse
    end

    local halfFOVRadians = math.rad(self.pawn.Camera.FieldOfView / 2)
    local distanceFromSphere = (radius / math.tan(halfFOVRadians))
    local Rota = self.pawn:K2_GetActorRotation()
    -- local pitch = -20
    -- local yaw = 130
    distanceFromSphere = distanceFromSphere > 1000 and distanceFromSphere or 1000
    print(distanceFromSphere, 4084080)
    self.pawn:Focus(origin, Rota.pitch, Rota.yaw, distanceFromSphere * 1.5)
end

return M
