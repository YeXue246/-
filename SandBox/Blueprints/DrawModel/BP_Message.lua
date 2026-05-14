--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_Message_C
local M = UnLua.Class()
local DFL = require("SandBox.DataFunction")
local Class = require("SandBox.Class")

function M:Initialize(Initializer)
    self.modelType = 11
    self.clickType = 4
    self.matTable  = {
        '/Game/SandBox/Materials/M_Point_2.M_Point_2',
        '/Game/SandBox/Materials/M_Point2_Inst.M_Point2_Inst',
        '/Game/SandBox/Materials/M_Point2_Inst2.M_Point2_Inst2',
    }
    -- self.showName = ""
    self.bMove     = true
    self.bhandle   = true
    self.bShow     = false
    self.text      = ""
    self.color     = UE.FLinearColor(1, 1, 1, 1)
    self.textSize  = 16
    self.bclock    = false
end

function M:ReceiveBeginPlay()
    self.widgetUI = self.Widget:GetWidget()
    self.pawn = UE.UGameplayStatics.GetPlayerPawn(self:GetWorld(), 0)
    self.camera = UE.UGameplayStatics.GetPlayerCameraManager(self:GetWorld(), 0)
    self.ParticleSystem:Activate(true)
end

function M:ReceiveTick(DeltaSeconds)
    if self.Widget:IsVisible() and self.bShow then
        -- local r = self.pawn:GetControlRotation()
        -- self:K2_SetActorRotation(UE.FRotator(-r.Pitch + 5, r.Yaw + 180, 0), false)
        local d = self:GetDistanceTo(self.camera)
        -- print(d)
        if d > 6000 then
            self.widgetUI:SetVisibility(1)
        else
            self.widgetUI:SetVisibility(4)
        end
    end
end

-- 数据出
function M:ModelSave()
    local table = {
        ["CType"] = self.clickType,
        ["Color"] = UE.UJsonLibraryHelpers.JsonValue_Stringify
            (UE.UJsonLibraryHelpers.FromLinearColor(self.color)),
        -- ["showname"] = self.showName,
        ["Text"] = self.text,
        ["bShow"] = self.bShow,
        ["bhandle"] = self.bhandle,
        ["bMove"] = self.bMove,
        ["TSize"] = self.textSize,
    }
    return table
end

-- 数据进
function M:ModelLoad(table)
    self.clickType = table["CType"] ~= 0 and table["CType"] or self.clickType
    self.modelType = table["Type"]
    self.color     = UE.UJsonLibraryHelpers.ToLinearColor(UE.UJsonLibraryHelpers.Parse(table["Color"]))
    -- self.showname = table["showName"]
    self.text      = table["Text"]
    self.bShow     = table["bShow"]
    self.bhandle   = table["bhandle"]
    self.bMove     = table["bMove"]
    self.textSize  = table["TSize"]
    self:SetMessage()
    self:SetMessageM()
    self:SetMessageShow()
end

-- 创建
function M:SetMessage()
    self.widgetUI.Text:SetText(self.text)
    self.FontInfo.Size = self.textSize
    self.widgetUI.Text:SetFont(self.FontInfo)
    self.CO.SpecifiedColor = self.color
    self.widgetUI.Text:SetColorAndOpacity(self.CO)
end

function M:SetMessageShow()
    print(self.bShow, "SetMessageShow")
    if self.bShow then
        self.Widget:SetVisibility(true, true)
    else
        self.Widget:SetVisibility(false, true)
    end
end

function M:SetMessageM()
    if self.bShow then
        self:SetM(3)
    else
        self:SetM(1)
    end
end

function M:Select()
    local control = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(),
        LoadClass(Class.control))
    self.modelManage.ModelSelect[self.modelType](self, control)
end

function M:SetM(Nub)
    -- self.Cone:SetMaterial(0, LoadObject(self.matTable[Nub]))
end

-- 前端数据交互
function M:SetData(table)
    if table.bCreate then
        self:K2_SetActorLocation(UE.FVector(table.x, table.y, table.z), false, nil, false)
    end
    self.color                           = UE.FLinearColor(table.r / 255, table.g / 255, table.b / 255, table.a / 100)
    -- self.showName                        = table.showname
    self:GetAttachParentActor().showName = table.showname
    self.text                            = table.info
    -- print(self.text, 333)
    self.textSize                        = table.fontSize
    self.bShow                           = table.clock
    self:SetMessage()
end

function M:GetData()
    local transform = self:GetTransform()
    local outTable = {
        x        = DFL.integrate(transform.Translation.X),
        y        = DFL.integrate(transform.Translation.Y),
        z        = DFL.integrate(transform.Translation.Z),
        r        = DFL.integrate(self.color.R * 255),
        g        = DFL.integrate(self.color.G * 255),
        b        = DFL.integrate(self.color.B * 255),
        a        = DFL.integrate(self.color.A * 100),
        showname = self:GetAttachParentActor().showName,
        info     = self.text,
        fontSize = self.textSize,
        bCreate  = true,
        clock    = self.bShow,
        bMove    = self.bMove,
    }
    return outTable
end

return M
