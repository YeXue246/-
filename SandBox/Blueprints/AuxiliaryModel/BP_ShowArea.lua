--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_ShowArea_C
local M = UnLua.Class()
local DFL = require("SandBox.DataFunction")

function M:ReceiveBeginPlay()
    self.widgetUI = self.Widget:GetWidget()
end

-- 创建选中物体标注
function M:SetArea(actor)
    local AreaActor = actor
    local Num = AreaActor.SplineAsPath:GetNumberOfSplinePoints()
    local Vs = UE.TArray(UE.FVector)
    for i = 1, Num do
        local PV = AreaActor.SplineAsPath:GetLocationAtSplinePoint(i - 1, 0)
        Vs:Add(PV)
    end
    local TotalFloorArea = self:CalculateIrregularPolygonArea(Vs)
    self.widgetUI.T_Name:SetText(AreaActor:GetAttachParentActor().showName)
    self.widgetUI.T_Area:SetText(tostring(DFL.integrate(TotalFloorArea / 100) / 100))
end

-- 计算不规则多边形的面积
function M:CalculateIrregularPolygonArea(PolygonVertices)
    -- 初始化面积
    local Area = 0.0

    -- 获取多边形顶点数量
    local NumVertices = PolygonVertices:Num()

    -- 遍历多边形的每个顶点
    for i = 1, NumVertices do
        -- 获取当前顶点和下一个顶点的坐标
        local CurrentVertex = PolygonVertices[i]
        local NextVertex = PolygonVertices[(i % NumVertices) + 1] -- 如果是最后一个顶点，则下一个顶点是第一个顶点

        -- 计算当前顶点与下一个顶点的叉积并累加到面积中
        Area = Area + (NextVertex.x - CurrentVertex.x) * (NextVertex.y + CurrentVertex.y)
    end

    -- 最终面积为叉积的绝对值的一半
    Area = math.abs(Area) * 0.5

    -- 返回多边形的面积
    return Area
end

return M
