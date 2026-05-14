--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class HY_GM_C
local M = UnLua.Class()

-- function M:Initialize(Initializer)
-- end

-- function M:UserConstructionScript()
-- end

function M:ReceiveBeginPlay()
end

function M:InitStreamer()
    local PCClass = LoadClass("/Game/SandBox/BasicConfig/Gameplay/PC.PC_C")
    self.PC = UE.UGameplayStatics.GetPlayerController(self:GetWorld(), 0):Cast(PCClass)
    self.PC.uiSandBox:addNullPlan();
end

-- function M:ReceiveEndPlay()
-- end

-- function M:ReceiveTick(DeltaSeconds)
-- end

-- function M:ReceiveAnyDamage(Damage, DamageType, InstigatedBy, DamageCauser)
-- end

-- function M:ReceiveActorBeginOverlap(OtherActor)
-- end

-- function M:ReceiveActorEndOverlap(OtherActor)
-- end
return M
