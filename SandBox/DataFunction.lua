--- 数据工具模块
--- @class DataFunction
--- @description 提供数据转换、类型处理和路径映射的核心工具函数
--- @field version string 当前模块版本号
--- @field modelType table 模型文件扩展名到类型ID的映射表
--- @field ST_DTPath table 资源路径映射表（编辑器路径→运行时路径）
--- @field timerSec number 定时器基础间隔（单位：秒）
--- @field modelMaterial table 支持材质设置的模型类型白名单

local DataFunction = {}
local Json = require("dkjson") -- 引入第三方JSON库

-- 模块版本标识
DataFunction.version = 'v2.2.8'

--- 模型文件类型枚举
--- @table modelType
--- @key .obj number OBJ格式模型（类型ID=0）
--- @key .fbx number FBX格式模型（类型ID=1）
--- @key .stl number STL格式模型（类型ID=2）
--- @key .stp number STEP格式模型（类型ID=3）
--- @key .step number STEP格式别名（类型ID=3）
DataFunction.modelType = {
    [".obj"] = 0,
    [".fbx"] = 1,
    [".stl"] = 2,
    [".stp"] = 3,
    [".step"] = 3,
}

--- 数值取整处理
--- @function integrate
--- @param num number 待处理数值
--- @return number 四舍五入后的整数值
--- @description 调用UE4的Round函数实现标准四舍五入
function DataFunction.integrate(num)
    return UE.UKismetMathLibrary.Round(num)
end

--- JSON字符串转FVector
--- @function toVector
--- @param string string JSON格式的向量字符串
--- @return userdata UE4的FVector对象
--- @note 输入格式要求：{"x":1.0,"y":2.0,"z":3.0}
function DataFunction.toVector(string)
    if not string then
        return UE.FVector(0, 0, 0)
    end
    local vectorT = Json.decode(string)
    local vector  = UE.FVector(vectorT.x, vectorT.y, vectorT.z)
    return vector
end

--- FVector转JSON字符串
--- @function fromVector
--- @param vector userdata UE4的FVector对象
--- @return string JSON格式的向量字符串
--- @note 输出格式：{"x":1,"y":2,"z":3}（数值已取整）
function DataFunction.fromVector(vector)
    local vectorT = {
        x = DataFunction.integrate(vector.X),
        y = DataFunction.integrate(vector.Y),
        z = DataFunction.integrate(vector.Z),
    }
    local string  = Json.encode(vectorT)
    return string
end

--- 向量分量取整
--- @function integrateVector
--- @param vector userdata UE4的FVector对象
--- @return userdata 分量取整后的新FVector
--- @description 原地修改向量对象的XYZ分量
function DataFunction.integrateVector(vector)
    vector.X = DataFunction.integrate(vector.X)
    vector.Y = DataFunction.integrate(vector.Y)
    vector.Z = DataFunction.integrate(vector.Z)
    return vector
end

--- JSON字符串转FLinearColor
--- @function toColor
--- @param string string JSON格式的颜色字符串
--- @return userdata UE4的FLinearColor对象
--- @note 输入格式要求：{"R":1.0,"G":0.5,"B":0.0,"A":1.0}
function DataFunction.toColor(string)
    if not string then
        return UE.FLinearColor(1.0, 1.0, 1.0, 1.0) -- 默认返回白色
    end
    local colorT = Json.decode(string)
    if not colorT then
        return UE.FLinearColor(1.0, 1.0, 1.0, 1.0) -- 默认返回白色
    end
    local r     = colorT.r or colorT.R or 1.0
    local g     = colorT.g or colorT.G or 1.0
    local b     = colorT.b or colorT.B or 1.0
    local a     = colorT.a or colorT.A or 1.0
    local color = UE.FLinearColor(r, g, b, a)
    return color
end

--- FLinearColor转JSON字符串
--- @function fromColor
--- @param color userdata UE4的FLinearColor对象
--- @return string JSON格式的颜色字符串
--- @note 输出格式：{"r":255,"g":128,"b":0,"a":255}（分量已归一化处理）
function DataFunction.fromColor(color)
    local colorT = {
        r = tonumber(string.format("%.2f", tostring(color.R))),
        g = tonumber(string.format("%.2f", tostring(color.G))),
        b = tonumber(string.format("%.2f", tostring(color.B))),
        a = tonumber(string.format("%.2f", tostring(color.A))),
    }
    local string = Json.encode(colorT)
    return string
end

--- 数据表资源路径映射
--- @table ST_DTPath
--- @key Content/... string 编辑器中的.uasset资源路径
--- @value /Game/... string 运行时对应的资源引用路径
--- @description 实现开发路径与打包路径的自动转换
DataFunction.ST_DTPath = {
    ["Content/Model/BasicModel/DT_BasicModel.uasset"] = "/Game/Model/BasicModel/DT_BasicModel.DT_BasicModel",
    ["Content/Model/BodyPaper/DT_BodyPaper.uasset"] = "/Game/Model/BodyPaper/DT_BodyPaper.DT_BodyPaper",
    ["Content/Model/HouseholdPaper/DT_HouseholdPaper.uasset"] =
    "/Game/Model/HouseholdPaper/DT_HouseholdPaper.DT_HouseholdPaper",
    ["Content/Model/SpecialPaper/DT_SpecialPaper.uasset"] = "/Game/Model/SpecialPaper/DT_SpecialPaper.DT_SpecialPaper",
    ["Content/Model/Transformer/DT_Transformer.uasset"] = "/Game/Model/Transformer/DT_Transformer.DT_Transformer",
    ["Content/SandBox/Blueprints/DT_Actor.uasset"] = "/Game/SandBox/Blueprints/DT_Actor.DT_Actor",
    ["Content/QIANKUN/DT_kerun.uasset"] = '/Game/QIANKUN/DT_kerun.DT_kerun',
    ["Content/Model/kmsn/DT_kmsn.uasset"] = "/Game/Model/kmsn/DT_kmsn.DT_kmsn",
    ["Content/jinqing/DT_jinqiang.uasset"] = '/Game/jinqing/DT_jinqiang.DT_jinqiang',
    ["Content/quzhou/DT_tongheng.uasset"] = '/Game/quzhou/DT_tongheng.DT_tongheng',
    ["Content/xinjiashuo/DT_xjs.uasset"] = '/Game/xinjiashuo/DT_xjs.DT_xjs',
}
-- 定时器基础间隔（20毫秒）
DataFunction.timerSec = 0.10
--- 支持材质的模型类型白名单
--- @table modelMaterial
--- @key Wall boolean 墙面模型
--- @key Box boolean 立方体模型
--- @key RoofBeam boolean 屋顶梁模型
--- @key Cylinder boolean 圆柱体模型
--- @key LineWall boolean 线型墙面
--- @key Area boolean 区域模型
DataFunction.modelMaterial = {
    ["Wall"] = true,
    ["Box"] = true,
    ["RoofBeam"] = true,
    ["Cylinder"] = true,
    -- ["road"] = true,
    ["LineWall"] = true,
    ["Area"] = true,
}

return DataFunction
