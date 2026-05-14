--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class UI_BG_C
local M = UnLua.Class()

function M:Initialize(Initializer)
    self.RGBa = UE.FLinearColor(0, 0, 0, 0)
    self.RGBb = UE.FLinearColor(0, 0, 0, 0)
    self.Tex = {
        LoadObject('/Game/Textures/BG/T1.T1'),
        LoadObject('/Game/Textures/BG/T2.T2'),
        LoadObject('/Game/Textures/BG/T3.T3'),
        LoadObject('/Game/Textures/BG/T4.T4'),
    }
end

function M:PreConstruct(IsDesignTime)
    self.CB.OnCheckStateChanged:Add(self, self.EnableBackGroud)
    self.CBM.OnCheckStateChanged:Add(self, self.ShwoMenu)
    self.SBR.OnValueCommitted:Add(self, self.R)
    self.SBG.OnValueCommitted:Add(self, self.G)
    self.SBB.OnValueCommitted:Add(self, self.B)
    self.SBRa.OnValueCommitted:Add(self, self.Ra)
    self.SBRb.OnValueCommitted:Add(self, self.Rb)
    self.SBGa.OnValueCommitted:Add(self, self.Ga)
    self.SBGb.OnValueCommitted:Add(self, self.Gb)
    self.SBBa.OnValueCommitted:Add(self, self.Ba)
    self.SBBb.OnValueCommitted:Add(self, self.Bb)
    self.BT1.OnClicked:Add(self, self.SetTex1)
    self.BT2.OnClicked:Add(self, self.SetTex2)
    self.BT3.OnClicked:Add(self, self.SetTex3)
    self.BT4.OnClicked:Add(self, self.SetTex4)
    self.BT5.OnClicked:Add(self, self.SetTex5)
end

-- function M:Construct()
-- end

--function M:Tick(MyGeometry, InDeltaTime)
--end

function M:EnableBackGroud(IsChecked)
    self.ParentUI.control:ShwoBG(IsChecked)
end

function M:ShwoMenu(IsChecked)
    self.HB1:SetVisibility(IsChecked and 0 or 1)
end

function M:R(R)
    self.RGBa = UE.FLinearColor(R / 255, self.RGBa.G, self.RGBa.B, 1)
    self.ParentUI.control:SetBGT(self.RGBa, self.RGBa, false, nil)
end

function M:G(G)
    self.RGBa = UE.FLinearColor(self.RGBa.R, G / 255, self.RGBa.B, 1)
    self.ParentUI.control:SetBGT(self.RGBa, self.RGBa, false, nil)
end

function M:B(B)
    self.RGBa = UE.FLinearColor(self.RGBa.R, self.RGBa.G, B / 255, 1)
    self.ParentUI.control:SetBGT(self.RGBa, self.RGBa, false, nil)
end

function M:Ra(R)
    self.RGBa = UE.FLinearColor(R / 255, self.RGBa.G, self.RGBa.B, 1)
    self.ParentUI.control:SetBGT(self.RGBa, self.RGBb, false, nil)
end

function M:Ga(G)
    self.RGBa = UE.FLinearColor(self.RGBa.R, G / 255, self.RGBa.B, 1)
    self.ParentUI.control:SetBGT(self.RGBa, self.RGBb, false, nil)
end

function M:Ba(B)
    self.RGBa = UE.FLinearColor(self.RGBa.R, self.RGBa.G, B / 255, 1)
    self.ParentUI.control:SetBGT(self.RGBa, self.RGBb, false, nil)
end

function M:Rb(R)
    self.RGBb = UE.FLinearColor(R / 255, self.RGBb.G, self.RGBb.B, 1)
    self.ParentUI.control:SetBGT(self.RGBa, self.RGBb, false, nil)
end

function M:Gb(G)
    self.RGBb = UE.FLinearColor(self.RGBb.R, G / 255, self.RGBb.B, 1)
    self.ParentUI.control:SetBGT(self.RGBa, self.RGBb, false, nil)
end

function M:Bb(B)
    self.RGBb = UE.FLinearColor(self.RGBb.R, self.RGBb.G, B / 255, 1)
    self.ParentUI.control:SetBGT(self.RGBa, self.RGBb, false, nil)
end

function M:SetTex1()
    self.ParentUI.control:SetBGT(nil, nil, true, self.Tex[1])
end

function M:SetTex2()
    self.ParentUI.control:SetBGT(nil, nil, true, self.Tex[2])
end

function M:SetTex3()
    self.ParentUI.control:SetBGT(nil, nil, true, self.Tex[3])
end

function M:SetTex4()
    self.ParentUI.control:SetBGT(nil, nil, true, self.Tex[4])
end

function M:SetTex5()
    local files = UE.UMyBFL.OpenFile()
    local T = UE.UKismetRenderingLibrary.ImportFileAsTexture2D(self:GetWorld(), files[1])
    if T then
        self.ParentUI.control:SetBGT(nil, nil, true, T)
    end
end

return M
