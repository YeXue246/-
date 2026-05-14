--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--require("LuaPanda").start("127.0.0.1", 8818);

---@class UI_Grid_C
local M = UnLua.Class()

-- function M:Initialize(Initializer)
-- end

function M:PreConstruct(IsDesignTime)
    self.GMPC = LoadObject('/Game/SandBox/Materials/MPC_Gird.MPC_Gird')
    self.FRGB = UE.UKismetMaterialLibrary.GetVectorParameterValue(self:GetWorld(), self.GMPC, "FloorColor")
    self.GRGB = UE.UKismetMaterialLibrary.GetVectorParameterValue(self:GetWorld(), self.GMPC, "LineColor")

    self.CBM.OnCheckStateChanged:Add(self, self.ShwoMenu)
    self.SBR.OnValueCommitted:Add(self, self.FR)
    self.SBG.OnValueCommitted:Add(self, self.FG)
    self.SBB.OnValueCommitted:Add(self, self.FB)
    self.SBRG.OnValueCommitted:Add(self, self.GR)
    self.SBGG.OnValueCommitted:Add(self, self.GG)
    self.SBBG.OnValueCommitted:Add(self, self.GB)
    self.bP.OnCheckStateChanged:Add(self, self.ShwoP)
    self.PW.OnValueCommitted:Add(self, self.PWidth)
    self.PS.OnValueCommitted:Add(self, self.PSize)
    self.bS.OnCheckStateChanged:Add(self, self.ShwoS)
    self.SW.OnValueCommitted:Add(self, self.SWidth)
    self.SS.OnValueCommitted:Add(self, self.SSize)
end

-- function M:Construct()
-- end

--function M:Tick(MyGeometry, InDeltaTime)
--end

function M:ShwoMenu(IsChecked)
    self.HB1:SetVisibility(IsChecked and 0 or 1)
end

function M:FR(R)
    self.FRGB = UE.FLinearColor(R / 255, self.FRGB.G, self.FRGB.B, 1)
    UE.UKismetMaterialLibrary.SetVectorParameterValue(self:GetWorld(), self.GMPC, "FloorColor", self.FRGB)
end

function M:FG(G)
    self.FRGB = UE.FLinearColor(self.FRGB.R, G / 255, self.FRGB.B, 1)
    UE.UKismetMaterialLibrary.SetVectorParameterValue(self:GetWorld(), self.GMPC, "FloorColor", self.FRGB)
end

function M:FB(B)
    self.FRGB = UE.FLinearColor(self.FRGB.R, self.FRGB.G, B / 255, 1)
    UE.UKismetMaterialLibrary.SetVectorParameterValue(self:GetWorld(), self.GMPC, "FloorColor", self.FRGB)
end

function M:GR(R)
    self.GRGB = UE.FLinearColor(R / 255, self.GRGB.G, self.GRGB.B, 1)
    UE.UKismetMaterialLibrary.SetVectorParameterValue(self:GetWorld(), self.GMPC, "LineColor", self.GRGB)
end

function M:GG(G)
    self.GRGB = UE.FLinearColor(self.GRGB.R, G / 255, self.GRGB.B, 1)
    UE.UKismetMaterialLibrary.SetVectorParameterValue(self:GetWorld(), self.GMPC, "LineColor", self.GRGB)
end

function M:GB(B)
    self.GRGB = UE.FLinearColor(self.GRGB.R, self.GRGB.G, B / 255, 1)
    UE.UKismetMaterialLibrary.SetVectorParameterValue(self:GetWorld(), self.GMPC, "LineColor", self.GRGB)
end

function M:ShwoP(IsChecked)
    UE.UKismetMaterialLibrary.SetScalarParameterValue(self:GetWorld(), self.GMPC, "UseGrid", IsChecked and 1 or 0)
end

function M:PWidth(width)
    UE.UKismetMaterialLibrary.SetScalarParameterValue(self:GetWorld(), self.GMPC, "PrimaryGridLineWidth", width)
end

function M:PSize(Size)
    UE.UKismetMaterialLibrary.SetScalarParameterValue(self:GetWorld(), self.GMPC, "PrimaryGridSize", Size)
end

function M:ShwoS(IsChecked)
    UE.UKismetMaterialLibrary.SetScalarParameterValue(self:GetWorld(), self.GMPC, "UseSecondaryGrid",
        IsChecked and 1 or 0)
end

function M:SWidth(width)
    UE.UKismetMaterialLibrary.SetScalarParameterValue(self:GetWorld(), self.GMPC, "SecondaryGridLineWidth", width)
end

function M:SSize(Size)
    UE.UKismetMaterialLibrary.SetScalarParameterValue(self:GetWorld(), self.GMPC, "SecondaryGridSize", Size)
end

return M
