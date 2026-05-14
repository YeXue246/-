---
--- 协作区域几何与约束算法模块
--- 抽离自 `BP_Control.lua` 中的 RegionArea 区段，供协作区域相关逻辑复用
---

local UE = UE or _G.UE

local M = {}

-- 调试开关：设为 false 关闭所有打印
local bDebug = false

-- 调试打印辅助函数
local function DebugPrint(...)
    if bDebug then
        print(...)
    end
end

-- 模块加载探针：用于确认 RegionAreaAlgo 已加载
DebugPrint("[RegionAreaAlgo] 协作区域算法模块已加载")

-- 计算多边形的有向面积（用于判断顶点顺序：正数=逆时针，负数=顺时针）
local function GetPolygonSignedArea(polygonPoints)
    local n = polygonPoints:Num()
    if n < 3 then return 0 end
    local area = 0
    for i = 1, n do
        -- print("RegionInner", polygonPoints[i])
        local j = i % n + 1
        area = area + polygonPoints[i].X * polygonPoints[j].Y - polygonPoints[j].X * polygonPoints[i].Y
    end
    return area / 2
end

--- 射线法（Ray Casting）判断点是否在2D凸/凹多边形内（忽略Z轴，XY平面）
--- @param point UE.FVector 待检测点
--- @param polygonPoints UE.TArray<UE.FVector> 多边形顶点（顺序相连，自动闭合）
--- @return boolean 是否在多边形内部
function M.IsPointInPolygon(point, polygonPoints)
    local n = polygonPoints:Num()
    if n < 3 then return false end
    local inside = false
    local px, py = point.X, point.Y
    local j = n
    -- #region agent log
    local signedArea = GetPolygonSignedArea(polygonPoints)
    local windingOrder = signedArea > 0 and "CCW" or "CW"
    DebugPrint(string.format(
        "[RegionAreaAlgo] IsPointInPolygon 入口: point(%.3f,%.3f), polygonNum=%d, windingOrder=%s, signedArea=%.6f",
        px, py, n, windingOrder, signedArea))
    -- #endregion
    for i = 1, n do
        local xi, yi = polygonPoints[i].X, polygonPoints[i].Y
        local xj, yj = polygonPoints[j].X, polygonPoints[j].Y
        -- 射线与多边形边的交叉判断
        if ((yi > py) ~= (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    -- #region agent log
    DebugPrint(string.format(
        "[RegionAreaAlgo] IsPointInPolygon 出口: result=%s",
        tostring(inside)))
    -- #endregion
    return inside
end

--- 检测点是否在多边形的严格内部（不在边界上）
--- @param point UE.FVector 待检测点
--- @param polygonPoints UE.TArray<UE.FVector> 多边形顶点
--- @param epsilon number 边界容差（默认1e-3，约0.1厘米）
--- @return boolean 是否在严格内部
function M.IsPointStrictlyInsidePolygon(point, polygonPoints, epsilon)
    epsilon = epsilon or 1e-3
    local n = polygonPoints:Num()
    if n < 3 then return false end

    -- #region agent log
    local signedArea = GetPolygonSignedArea(polygonPoints)
    local windingOrder = signedArea > 0 and "CCW" or "CW"
    DebugPrint(string.format(
        "[RegionAreaAlgo] IsPointStrictlyInsidePolygon 入口: point(%.3f,%.3f), polygonNum=%d, windingOrder=%s, epsilon=%.6f",
        point.X, point.Y, n, windingOrder, epsilon))
    -- #endregion

    -- 先检查是否在边界上
    local px, py = point.X, point.Y
    local onBoundary = false
    for i = 1, n do
        local j = i % n + 1
        local ax, ay = polygonPoints[i].X, polygonPoints[i].Y
        local bx, by = polygonPoints[j].X, polygonPoints[j].Y

        -- 检查点是否在线段上（使用点到线段距离）
        local abx, aby = bx - ax, by - ay
        local apx, apy = px - ax, py - ay
        local lenSq = abx * abx + aby * aby
        if lenSq > 1e-10 then
            local t = (apx * abx + apy * aby) / lenSq
            if t >= 0 and t <= 1 then
                -- 点在边的延长线上，计算到边的距离
                local projX = ax + t * abx
                local projY = ay + t * aby
                local distSq = (px - projX) ^ 2 + (py - projY) ^ 2
                if distSq < epsilon * epsilon then
                    -- #region agent log
                    DebugPrint(string.format(
                        "[RegionAreaAlgo] 检测到点在边界上: edgeIndex=%d, distSq=%.6f, epsilonSq=%.6f",
                        i, distSq, epsilon * epsilon))
                    -- #endregion
                    return false -- 在边界上
                end
            end
        end
    end

    -- 不在边界上，检查是否在内部
    local result = M.IsPointInPolygon(point, polygonPoints)
    -- #region agent log
    DebugPrint(string.format(
        "[RegionAreaAlgo] IsPointStrictlyInsidePolygon 出口: onBoundary=%s, insideResult=%s",
        tostring(onBoundary), tostring(result)))
    -- #endregion
    return result
end

--- 求点到线段的最近点（XY平面），若距离 < threshold 则返回该吸附点，否则返回 nil
--- @param point UE.FVector 当前位置
--- @param polygonPoints UE.TArray<UE.FVector> 多边形顶点
--- @param threshold number 吸附距离阈值（厘米）
--- @return UE.FVector|nil 吸附点（在边上），未触发则返回 nil
function M.GetSnapEdgePoint(point, polygonPoints, threshold)
    local n = polygonPoints:Num()
    if n < 2 then return nil end
    local bestDistSq = threshold * threshold
    local bestPoint  = nil
    for i = 1, n do
        local j        = i % n + 1 -- 自动从最后一点连回第一点（闭合）
        local ax, ay   = polygonPoints[i].X, polygonPoints[i].Y
        local bx, by   = polygonPoints[j].X, polygonPoints[j].Y
        local abx, aby = bx - ax, by - ay
        local apx, apy = point.X - ax, point.Y - ay
        local lenSq    = abx * abx + aby * aby
        local t        = 0
        if lenSq > 0 then
            t = (apx * abx + apy * aby) / lenSq
            t = math.max(0, math.min(1, t))
        end
        -- 边上最近点
        local cx, cy = ax + t * abx, ay + t * aby
        local distSq = (point.X - cx) ^ 2 + (point.Y - cy) ^ 2
        if distSq < bestDistSq then
            bestDistSq = distSq
            bestPoint  = UE.FVector(cx, cy, point.Z)
        end
    end
    return bestPoint
end

--- 2D XY 线段相交测试（参数法）
--- 检测 p1→p2 与 q1→q2 是否相交；若相交，返回沿 p1→p2 的参数 t（0<t≤1）及交点坐标 ix, iy
--- 不相交时 t 为 nil，ix/iy 为 0
--- 注意：t 使用严格大于小量（> 1e-4），避免 prevPt 恰好落在边界上时 t≈0 导致预览卡死
function M.SegmentIntersect(p1x, p1y, p2x, p2y, q1x, q1y, q2x, q2y)
    local dx    = p2x - p1x
    local dy    = p2y - p1y
    local ex    = q2x - q1x
    local ey    = q2y - q1y
    local denom = dx * ey - dy * ex
    if math.abs(denom) < 1e-6 then return nil, 0, 0 end -- 平行 / 共线
    local fx = q1x - p1x
    local fy = q1y - p1y
    local t  = (fx * ey - fy * ex) / denom
    local u  = (fx * dy - fy * dx) / denom
    -- t > 1e-4：排除起点恰好在边界（t≈0）的退化情况，防止预览点卡住
    if t > 1e-4 and t <= 1 and u >= 0 and u <= 1 then
        return t, p1x + t * dx, p1y + t * dy
    end
    return nil, 0, 0
end

--- 检测多边形是否存在自交且交叉面积 > 0 的情况（忽略相邻边和公共端点）
--- 这里通过检测非相邻边段是否在内部真正相交来近似判断"自交面积 > 0"
--- @param polygonPoints UE.TArray<UE.FVector>
--- @return boolean 是否存在自交
function M.HasSelfIntersectionArea(polygonPoints)
    local n = polygonPoints:Num()
    if n < 4 then return false end

    for i = 1, n do
        local i2  = i % n + 1
        local a1x = polygonPoints[i].X
        local a1y = polygonPoints[i].Y
        local a2x = polygonPoints[i2].X
        local a2y = polygonPoints[i2].Y

        for j = i + 1, n do
            local j2 = j % n + 1
            -- 跳过共享端点 / 相邻边（包括首尾相连的边），只检测真正的"跨边"交叉
            if not (i == j or i2 == j or i == j2 or i2 == j2) then
                local b1x = polygonPoints[j].X
                local b1y = polygonPoints[j].Y
                local b2x = polygonPoints[j2].X
                local b2y = polygonPoints[j2].Y
                local t = select(1, M.SegmentIntersect(a1x, a1y, a2x, a2y, b1x, b1y, b2x, b2y))
                if t then
                    -- 发现任意一组非相邻边段内部相交，可认为存在交叉且交叉面积 > 0
                    return true
                end
            end
        end
    end

    return false
end

--- 若线段 prevPt→curPt 穿越多边形某条边，返回最近的交点（沿线段参数 t 最小）及对应的 t 值
--- "最近"指最靠近 prevPt 的穿越点，即第一个穿出/穿入点
--- 支持三种越界检测，按优先级排列：
---   ① 【首点压边】prevPt 已在某边上，curPt 偏向内侧 → 投影 curPt 到该边，t=0（最高优先）
---   ② 【常规穿越】绘制段与区域边非平行时的标准相交检测，t ∈ (1e-4, 1]
---   ③ 【平行线原理】绘制边与区域边平行（denom≈0）且两端点异侧 → 投影夹紧，t=1.0
--- @param prevPt UE.FVector 上一个已确认点
--- @param curPt  UE.FVector 当前鼠标位置
--- @param polygonPoints UE.TArray<UE.FVector> 多边形顶点
--- @return UE.FVector|nil 交点/夹紧点（Z 取 curPt.Z），或 nil（不穿越）
--- @return number          对应的 t 值（无交点时为 math.huge）
function M.GetEdgeCrossPoint(prevPt, curPt, polygonPoints)
    local n = polygonPoints:Num()
    if n < 2 then return nil, math.huge end
    local bestT     = math.huge
    local bestX, bestY
    local dpx       = curPt.X - prevPt.X
    local dpy       = curPt.Y - prevPt.Y
    local drawLenSq = dpx * dpx + dpy * dpy

    -- 多边形重心：用于判断各边"内侧"方向（重心必在多边形内部）
    local cx, cy    = 0, 0
    for i = 1, n do
        cx = cx + polygonPoints[i].X
        cy = cy + polygonPoints[i].Y
    end
    cx = cx / n
    cy = cy / n

    for i = 1, n do
        local a       = polygonPoints[i]
        local b       = polygonPoints[i % n + 1]
        local ex      = b.X - a.X
        local ey      = b.Y - a.Y

        -- 边法线（A→B 左法线，未归一化），用于首点压边判定
        local nx      = -ey
        local ny      = ex
        local dotPrev = (prevPt.X - a.X) * nx + (prevPt.Y - a.Y) * ny
        local dotCur  = (curPt.X - a.X) * nx + (curPt.Y - a.Y) * ny

        -- ── ① 首点压边优先检测（在其它交点之前）────────────────────────────
        -- prevPt 恰好落在本边上（|dotPrev| ≈ 0），且 curPt 明显偏向多边形内侧时，
        -- 直接将 curPt 投影到本边，以 t=0 返回（绝对最高优先级）。
        -- 内侧判据：重心与本边同侧 → dotCur 与 dotCent 同号。
        if math.abs(dotPrev) <= 1e-2 and math.abs(dotCur) > 1e-3 then
            local dotCent = (cx - a.X) * nx + (cy - a.Y) * ny
            if dotCur * dotCent > 0 then
                local edgeLenSq = ex * ex + ey * ey
                if edgeLenSq > 1e-6 then
                    local apx    = curPt.X - a.X
                    local apy    = curPt.Y - a.Y
                    local tp     = math.max(0, math.min(1, (apx * ex + apy * ey) / edgeLenSq))
                    -- t=0 < 任何 SegmentIntersect 返回的 t（>1e-4），后续边无法覆盖
                    bestT        = 0
                    bestX, bestY = a.X + tp * ex, a.Y + tp * ey
                end
            end
        end

        -- ── ② 常规相交检测 ───────────────────────────────────────────────
        local t, ix, iy = M.SegmentIntersect(
            prevPt.X, prevPt.Y, curPt.X, curPt.Y,
            a.X, a.Y, b.X, b.Y
        )
        if t and t < bestT then
            bestT        = t
            bestX, bestY = ix, iy
        end
    end

    if bestX then
        return UE.FVector(bestX, bestY, curPt.Z), bestT
    end
    return nil, math.huge
end

--- 检测两个多边形是否重叠（有重叠面积，不包括边界接触）
--- 只检测真正的内部交叉面积，边界接触不算重叠
--- @param poly1 UE.TArray<UE.FVector> 第一个多边形
--- @param poly2 UE.TArray<UE.FVector> 第二个多边形
--- @return boolean 是否重叠
function M.DoPolygonsOverlap(poly1, poly2)
    local n1 = poly1:Num()
    local n2 = poly2:Num()
    if n1 < 3 or n2 < 3 then return false end

    -- #region agent log
    local area1 = GetPolygonSignedArea(poly1)
    local area2 = GetPolygonSignedArea(poly2)
    local order1 = area1 > 0 and "CCW" or "CW"
    local order2 = area2 > 0 and "CCW" or "CW"
    DebugPrint(string.format(
        "[RegionAreaAlgo] DoPolygonsOverlap 入口: poly1Num=%d, poly1Order=%s, poly1Area=%.6f, poly2Num=%d, poly2Order=%s, poly2Area=%.6f",
        n1, order1, area1, n2, order2, area2))
    -- #endregion

    -- 检测 poly1 的顶点是否在 poly2 的严格内部（不在边界上）
    for i = 1, n1 do
        local result = M.IsPointStrictlyInsidePolygon(poly1[i], poly2)
        -- #region agent log
        DebugPrint(string.format(
            "[RegionAreaAlgo] Poly1 顶点在 Poly2 内检查: vertexIndex=%d, vertex(%.3f,%.3f), result=%s",
            i, poly1[i].X, poly1[i].Y, tostring(result)))
        -- #endregion
        if result then
            return true
        end
    end

    -- 检测 poly2 的顶点是否在 poly1 的严格内部（不在边界上）
    for i = 1, n2 do
        local result = M.IsPointStrictlyInsidePolygon(poly2[i], poly1)
        -- #region agent log
        DebugPrint(string.format(
            "[RegionAreaAlgo] Poly2 顶点在 Poly1 内检查: vertexIndex=%d, vertex(%.3f,%.3f), result=%s",
            i, poly2[i].X, poly2[i].Y, tostring(result)))
        -- #endregion
        if result then
            return true
        end
    end

    -- 检测两个多边形的边是否在内部相交（不是端点接触）
    -- 只检测边的内部相交（t 和 u 都在 (0,1) 范围内，排除端点）
    for i = 1, n1 do
        local i2 = i % n1 + 1
        local a1x = poly1[i].X
        local a1y = poly1[i].Y
        local a2x = poly1[i2].X
        local a2y = poly1[i2].Y

        for j = 1, n2 do
            local j2 = j % n2 + 1
            local b1x = poly2[j].X
            local b1y = poly2[j].Y
            local b2x = poly2[j2].X
            local b2y = poly2[j2].Y

            -- 使用更严格的相交检测：t 和 u 必须在 (epsilon, 1-epsilon) 范围内
            -- 这样可以排除端点接触的情况
            local dx = a2x - a1x
            local dy = a2y - a1y
            local ex = b2x - b1x
            local ey = b2y - b1y
            local denom = dx * ey - dy * ex
            if math.abs(denom) > 1e-6 then -- 不平行
                local fx = b1x - a1x
                local fy = b1y - a1y
                local t = (fx * ey - fy * ex) / denom
                local u = (fx * dy - fy * dx) / denom
                local epsilon = 1e-4
                -- 只在内部相交时返回 true（排除端点接触）
                if t > epsilon and t < 1 - epsilon and u > epsilon and u < 1 - epsilon then
                    -- #region agent log
                    DebugPrint(string.format(
                        "[RegionAreaAlgo] 检测到边相交: edge1Index=%d, edge2Index=%d, t=%.6f, u=%.6f",
                        i, j, t, u))
                    -- #endregion
                    return true
                end
            end
        end
    end

    -- #region agent log
    DebugPrint(string.format(
        "[RegionAreaAlgo] DoPolygonsOverlap 出口: result=false"))
    -- #endregion
    return false
end

--- 吸附到其他区域边界的距离阈值（厘米），超出此范围不触发吸附
M.REGION_SNAP_THRESHOLD = 80

return M
