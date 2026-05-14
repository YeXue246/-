--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--
---@class UI_direction_C
local M = UnLua.Class()
local Screen = require("SandBox.Screen")

-- function M:Initialize(Initializer)

-- end

-- function M:PreConstruct(IsDesignTime)
--     self.Button_2.OnClicked:Add(self, self.ButtonN)
--     self.Button_3.OnClicked:Add(self, self.ButtonW)
--     self.Button_4.OnClicked:Add(self, self.ButtonE)
--     self.Button_5.OnClicked:Add(self, self.ButtonS)

--     self.Button_2.OnHovered:Add(self, self.ButtonHoveredN)
--     self.Button_2.OnUnHovered:Add(self, self.ButtonUnHoveredN)
--     self.Button_5.OnHovered:Add(self, self.ButtonHoveredS)
--     self.Button_5.OnUnHovered:Add(self, self.ButtonUnHoveredS)
--     self.Button_3.OnHovered:Add(self, self.ButtonHoveredW)
--     self.Button_3.OnUnHovered:Add(self, self.ButtonUnHoveredW)
--     self.Button_4.OnHovered:Add(self, self.ButtonHoveredE)
--     self.Button_4.OnUnHovered:Add(self, self.ButtonUnHoveredE)
-- end

-- function M:Construct()
--     local PawnClass = LoadClass("/Game/SandBox/BasicConfig/GamePlay/Pawn.Pawn_C")
--     self.Pawn = UE.UGameplayStatics.GetPlayerPawn(self:GetWorld(), 0):Cast(PawnClass)
-- end

-- function M:ButtonN()
--     self:Restore()
--     self.Pawn:ChooseViewData("北")
--     self.textN:SetVisibility(1)
--     self.textN_1:SetVisibility(4)
--     self.Pawn.PitchLimit_Min = 0
--     self.Pawn.PitchLimit_Max = 0
-- end

-- function M:ButtonW()
--     self:Restore()
--     self.Pawn:ChooseViewData("西")
--     self.textW:SetVisibility(1)
--     self.textW_1:SetVisibility(4)
--     self.Pawn.PitchLimit_Min = 0
--     self.Pawn.PitchLimit_Max = 0
-- end

-- function M:ButtonE()
--     self:Restore()
--     self.Pawn:ChooseViewData("东")
--     self.textE:SetVisibility(1)
--     self.textE_1:SetVisibility(4)
--     self.Pawn.PitchLimit_Min = 0
--     self.Pawn.PitchLimit_Max = 0
-- end

-- function M:ButtonS()
--     self:Restore()
--     self.Pawn:ChooseViewData("南")
--     self.textS:SetVisibility(1)
--     self.textS_1:SetVisibility(4)
--     self.Pawn.PitchLimit_Min = 0
--     self.Pawn.PitchLimit_Max = 0
-- end

-- function M:ButtonHoveredN()
--     self.textN:SetColorAndOpacity(self.Colorblue)
--     self.Image1N:SetVisibility(1)
--     self.Image2N:SetVisibility(0)
-- end

-- function M:ButtonUnHoveredN()
--     self.textN:SetColorAndOpacity(self.Colorwhite)
--     self.Image1N:SetVisibility(0)
--     self.Image2N:SetVisibility(1)
-- end

-- function M:ButtonHoveredS()
--     self.textS:SetColorAndOpacity(self.Colorblue)
--     self.Image1S:SetVisibility(1)
--     self.Image2S:SetVisibility(0)
-- end

-- function M:ButtonUnHoveredS()
--     self.textS:SetColorAndOpacity(self.Colorwhite)
--     self.Image1S:SetVisibility(0)
--     self.Image2S:SetVisibility(1)
-- end

-- function M:ButtonHoveredW()
--     self.textW:SetColorAndOpacity(self.Colorblue)
--     self.Image1W:SetVisibility(1)
--     self.Image2W:SetVisibility(0)
-- end

-- function M:ButtonUnHoveredW()
--     self.textW:SetColorAndOpacity(self.Colorwhite)
--     self.Image1W:SetVisibility(0)
--     self.Image2W:SetVisibility(1)
-- end

-- function M:ButtonHoveredE()
--     self.textE:SetColorAndOpacity(self.Colorblue)
--     self.Image1E:SetVisibility(1)
--     self.Image2E:SetVisibility(0)
-- end

-- function M:ButtonUnHoveredE()
--     self.textE:SetColorAndOpacity(self.Colorwhite)
--     self.Image1E:SetVisibility(0)
--     self.Image2E:SetVisibility(1)
-- end

-- function M:Restore()
--     self.textN:SetVisibility(0)
--     self.textN_1:SetVisibility(1)
--     self.textS:SetVisibility(0)
--     self.textS_1:SetVisibility(1)
--     self.textW:SetVisibility(0)
--     self.textW_1:SetVisibility(1)
--     self.textE:SetVisibility(0)
--     self.textE_1:SetVisibility(1)
-- end

-- function M:Tick(MyGeometry, InDeltaTime)
--     local RotStr = self.Pawn:GetControlRotation()
--     -- print(RotStr)
--     -- local Camerarevolve = UE.USceneComponent.K2_GetComponentRotation(self.Pawn.Camera)
--     self:revolve(RotStr.Yaw - 90)
--     if RotStr.Yaw > 180 then
--         RotStr.Yaw = RotStr.Yaw + 180
--     elseif RotStr.Yaw < 180 then
--         RotStr.Yaw = RotStr.Yaw + 180
--     end
--     -- local Camerarevolve = UE.USceneComponent.K2_GetComponentRotation(self.Pawn.Camera)
--     -- self:revolve(Camerarevolve.Yaw + 90)
--     -- if Camerarevolve.Yaw > 180 then
--     --     Camerarevolve.Yaw = Camerarevolve.Yaw + 180
--     -- elseif Camerarevolve.Yaw < 180 then
--     --     Camerarevolve.Yaw = Camerarevolve.Yaw + 180
--     -- end
-- end

-- -- function M:Tick(MyGeometry, InDeltaTime)
-- -- end

return M
