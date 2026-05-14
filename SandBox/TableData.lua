local TableData = {}

-- 定义 MiddleTable，用于保存模型相关的中间数据
TableData.MiddleTable = {
    contentValue = "",
    modelCode = "",
    relatedType = 0,
}
-- 创建一个Lua table
TableData.SaveTable = {
    sandboxSchemeName = "",
    sandboxSchemeId = 0,
    sandboxSchemeImage = "",
    contentValue = "",
    userId = 0,
    modelRelated = {}
}

-- 创建一个 管道点位 表，包含两个元素
TableData.PointData = {
    "", ""
}

-- 创建一个 ModleTable 表，包含通用数据、地板数据、管道数据和模型数据
TableData.ModleTable = {
    -- 通用数据
    modelName = "",
    parent = "",
    size = "",
    -- 地板数据
    FName = "",
    FLength = 0,
    FWith = 0,
    FHigh = 0,
    High = 0,
    Opacity = 0,
    -- 管道数据
    PM = "",
    Radius = 0,
    PointLocations = {},
    -- 模型数据
    ModelCode = "",
    OriginalSize = "",
    bBasic = false
}

return TableData
