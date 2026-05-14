--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_Input2_C
local M = UnLua.Class()
local BindKey = UnLua.Input.BindKey
local Model = require("SandBox.ModelNameInitialize")


BindKey(M, "LeftMouseButton", "DoubleClick", function(self, Key)
    local Start, End = Model.GetLineValue(self.control.pc)
    local HitRes = UE.FHitResult()
    print("1")
    UE.UKismetSystemLibrary.LineTraceSingle(self.control:GetWorld(), Start, End, UE.ETraceTypeQuery.Visibility, false,
        nil,
        UE.EDrawDebugTrace.None, HitRes, true)
    if HitRes.HitObjectHandle.Actor then
        local PA = HitRes.HitObjectHandle.Actor:GetAttachParentActor()
        local Name = Model.GetActorAccurateDisplayName(PA)
        local table = {
            modelName = Name,
            triggerMode = 3,
        }
        self.control.ui:ModelSignal(table)
    end
end, { ConsumeInput = false })
-- function M:Initialize(Initializer)
-- end

-- function M:UserConstructionScript()
-- end

-- function M:ReceiveBeginPlay()
-- end

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
