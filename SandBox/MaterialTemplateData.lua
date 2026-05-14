
local MaterialTemplateData = {}

--[[
    材质模板只保存动态材质实例实际使用的参数：
    BaseColorConstant 为 0~1 线性颜色，Metallic/Roughness/Normal 建议保持 0~1；
    Emissive 可大于 1，用于 LED、屏幕等自发光效果。
]]

----------------------------------------------------------------
-- 黄金材质
----------------------------------------------------------------

MaterialTemplateData.Gold =
{
    BaseColorConstant =
    {
        R = 0.950,
        G = 0.720,
        B = 0.220
    },

    MetallicRation  = 1.000,
    RoughnessRation = 0.100,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 银材质
----------------------------------------------------------------

MaterialTemplateData.ChromeSilver =
{
    BaseColorConstant =
    {
        R = 0.970,
        G = 0.960,
        B = 0.930
    },

    MetallicRation  = 1.000,
    RoughnessRation = 0.060,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 铁材质
----------------------------------------------------------------

MaterialTemplateData.Iron =
{
    BaseColorConstant =
    {
        R = 0.560,
        G = 0.570,
        B = 0.580
    },

    MetallicRation  = 1.000,
    RoughnessRation = 0.450,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}
----------------------------------------------------------------
-- 钢材质
----------------------------------------------------------------

MaterialTemplateData.PolishedSteel =
{
    BaseColorConstant =
    {
        R = 0.720,
        G = 0.720,
        B = 0.740
    },

    MetallicRation  = 1.000,
    RoughnessRation = 0.180,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 新镀锌钢板：偏亮、偏冷，适合新设备外壳或金属板材
----------------------------------------------------------------
MaterialTemplateData.NewGalvanizedSteel =
{
    BaseColorConstant =
    {
        R = 0.820,
        G = 0.840,
        B = 0.850
    },

    MetallicRation  = 1.000,
    RoughnessRation = 0.380,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}


----------------------------------------------------------------
-- 铝合金材质
----------------------------------------------------------------

MaterialTemplateData.PolishedAluminum =
{
    BaseColorConstant =
    {
        R = 0.910,
        G = 0.920,
        B = 0.930
    },

    MetallicRation  = 1.000,
    RoughnessRation = 0.120,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 铜材质
----------------------------------------------------------------

MaterialTemplateData.Copper =
{
    BaseColorConstant =
    {
        R = 0.960,
        G = 0.640,
        B = 0.540
    },

    MetallicRation  = 1.000,
    RoughnessRation = 0.180,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}
-- MaterialTemplateData.Brass =
-- {
--     BaseColorConstant =
--     {
--         R = 0.930,
--         G = 0.780,
--         B = 0.450
--     },

--     MetallicRation  = 1.000,
--     RoughnessRation = 0.280,
--     EmissiveRation  = 0.000,
--     NormalRation    = 1.000
-- }

-- MaterialTemplateData.Bronze =
-- {
--     BaseColorConstant =
--     {
--         R = 0.720,
--         G = 0.550,
--         B = 0.350
--     },

--     MetallicRation  = 0.950,
--     RoughnessRation = 0.450,
--     EmissiveRation  = 0.000,
--     NormalRation    = 1.000
-- }

-- MaterialTemplateData.DoorHandleGold =
-- {
--     BaseColorConstant =
--     {
--         R = 1.000,
--         G = 0.850,
--         B = 0.320
--     },

--     MetallicRation  = 1.000,
--     RoughnessRation = 0.120,
--     EmissiveRation  = 0.000,
--     NormalRation    = 1.000
-- }

-- MaterialTemplateData.DoorHandleBrass =
-- {
--     BaseColorConstant =
--     {
--         R = 0.960,
--         G = 0.820,
--         B = 0.420
--     },

--     MetallicRation  = 1.000,
--     RoughnessRation = 0.180,
--     EmissiveRation  = 0.000,
--     NormalRation    = 1.000
-- }

----------------------------------------------------------------
-- 镜面不锈钢
----------------------------------------------------------------

MaterialTemplateData.MirrorStainlessSteel =
{
    BaseColorConstant =
    {
        R = 0.850,
        G = 0.860,
        B = 0.870
    },

    MetallicRation  = 1.000,
    RoughnessRation = 0.050,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 工业喷漆金属
----------------------------------------------------------------

MaterialTemplateData.WhiteSemiGlossPaintMetal =
{
    BaseColorConstant =
    {
        R = 0.950,
        G = 0.950,
        B = 0.950
    },

    MetallicRation  = 0.000,
    RoughnessRation = 0.280,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 黑色工业喷漆金属
----------------------------------------------------------------
MaterialTemplateData.BlackPaintMetal =
{
    BaseColorConstant =
    {
        R = 0.080,
        G = 0.080,
        B = 0.080
    },

    MetallicRation  = 0.000,
    RoughnessRation = 0.680,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 黑色塑料
----------------------------------------------------------------

MaterialTemplateData.PlasticBlack =
{
    BaseColorConstant =
    {
        R = 0.100,
        G = 0.100,
        B = 0.100
    },

    MetallicRation  = 0.000,
    RoughnessRation = 0.650,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 白色塑料
----------------------------------------------------------------

MaterialTemplateData.PlasticWhite =
{
    BaseColorConstant =
    {
        R = 0.850,
        G = 0.850,
        B = 0.850
    },

    MetallicRation  = 0.000,
    RoughnessRation = 0.620,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 哑光塑料
----------------------------------------------------------------

MaterialTemplateData.MattePlastic =
{
    BaseColorConstant =
    {
        R = 0.180,
        G = 0.180,
        B = 0.180
    },

    MetallicRation  = 0.000,
    RoughnessRation = 0.780,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 橡胶材质
----------------------------------------------------------------

MaterialTemplateData.Rubber =
{
    BaseColorConstant =
    {
        R = 0.050,
        G = 0.050,
        B = 0.050
    },

    MetallicRation  = 0.000,
    RoughnessRation = 0.900,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 混凝土材质
----------------------------------------------------------------

MaterialTemplateData.Concrete =
{
    BaseColorConstant =
    {
        R = 0.580,
        G = 0.580,
        B = 0.580
    },

    MetallicRation  = 0.000,
    RoughnessRation = 0.920,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 水泥地面
----------------------------------------------------------------

MaterialTemplateData.CementFloor =
{
    BaseColorConstant =
    {
        R = 0.450,
        G = 0.450,
        B = 0.450
    },

    MetallicRation  = 0.000,
    RoughnessRation = 0.950,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 工业地胶
----------------------------------------------------------------

MaterialTemplateData.IndustrialFloor =
{
    BaseColorConstant =
    {
        R = 0.220,
        G = 0.250,
        B = 0.280
    },

    MetallicRation  = 0.020,
    RoughnessRation = 0.820,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 白墙材质
----------------------------------------------------------------

MaterialTemplateData.WhiteWall =
{
    BaseColorConstant =
    {
        R = 0.820,
        G = 0.820,
        B = 0.800
    },

    MetallicRation  = 0.000,
    RoughnessRation = 0.900,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 红色LED
----------------------------------------------------------------

MaterialTemplateData.LEDRed =
{
    BaseColorConstant =
    {
        R = 1.000,
        G = 0.100,
        B = 0.100
    },

    MetallicRation  = 0.000,
    RoughnessRation = 0.250,
    EmissiveRation  = 3.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 绿色LED
----------------------------------------------------------------

MaterialTemplateData.LEDGreen =
{
    BaseColorConstant =
    {
        R = 0.100,
        G = 1.000,
        B = 0.100
    },

    MetallicRation  = 0.000,
    RoughnessRation = 0.250,
    EmissiveRation  = 3.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 蓝色LED
----------------------------------------------------------------

MaterialTemplateData.LEDBlue =
{
    BaseColorConstant =
    {
        R = 0.100,
        G = 0.300,
        B = 1.000
    },

    MetallicRation  = 0.000,
    RoughnessRation = 0.250,
    EmissiveRation  = 3.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 屏幕材质
----------------------------------------------------------------

MaterialTemplateData.Screen =
{
    BaseColorConstant =
    {
        R = 0.020,
        G = 0.020,
        B = 0.020
    },

    MetallicRation  = 0.000,
    RoughnessRation = 0.080,
    EmissiveRation  = 1.500,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 警示黄
----------------------------------------------------------------

MaterialTemplateData.WarningYellow =
{
    BaseColorConstant =
    {
        R = 1.000,
        G = 0.750,
        B = 0.050
    },

    MetallicRation  = 0.000,
    RoughnessRation = 0.550,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 警示红
----------------------------------------------------------------

MaterialTemplateData.WarningRed =
{
    BaseColorConstant =
    {
        R = 0.850,
        G = 0.080,
        B = 0.080
    },

    MetallicRation  = 0.000,
    RoughnessRation = 0.580,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 工业默认材质：需与 BP_ImportModel.lua 的默认兜底参数保持一致
----------------------------------------------------------------

MaterialTemplateData.IndustrialDefault =
{
    BaseColorConstant =
    {
        R = 0.650,
        G = 0.650,
        B = 0.680
    },

    MetallicRation  = 0.100,
    RoughnessRation = 0.550,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}





----------------------------------------------------------------
-- 拉丝钢材质
----------------------------------------------------------------

MaterialTemplateData.BrushedSteel =
{
    BaseColorConstant =
    {
        R = 0.720,
        G = 0.730,
        B = 0.750
    },

    MetallicRation  = 1.000,
    RoughnessRation = 0.420,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}

----------------------------------------------------------------
-- 普通镀锌钢板：比 NewGalvanizedSteel 更灰、更粗糙，用于常规/轻度氧化板材
----------------------------------------------------------------

MaterialTemplateData.GalvanizedSteel =
{
    BaseColorConstant =
    {
        R = 0.750,
        G = 0.760,
        B = 0.780
    },

    MetallicRation  = 1.000,
    RoughnessRation = 0.520,
    EmissiveRation  = 0.000,
    NormalRation    = 1.000
}


----------------------------------------------------------------
-- 返回材质模板表
----------------------------------------------------------------

return MaterialTemplateData