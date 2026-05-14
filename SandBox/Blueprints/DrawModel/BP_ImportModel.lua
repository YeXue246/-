--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_ImportModel_C
local M = UnLua.Class()
local Class = require("SandBox.Class")
local DFL = require("SandBox.DataFunction")
local MaterialTemplateData =
    require("SandBox.MaterialTemplateData")

local MaterialParamNames =
{
    "BaseColorConstant",
    "MetallicRation",
    "RoughnessRation",
    "EmissiveRation",
    "NormalRation"
}

local MaterialTemplateOrder =
{
    "Gold",
    "ChromeSilver",
    "Iron",
    "PolishedSteel",
    "NewGalvanizedSteel",
    "PolishedAluminum",
    "Copper",
    "MirrorStainlessSteel",
    "WhiteSemiGlossPaintMetal",
    "BlackPaintMetal",
    "PlasticBlack",
    "PlasticWhite",
    "MattePlastic",
    "Rubber",
    "Concrete",
    "CementFloor",
    "IndustrialFloor",
    "WhiteWall",
    "LEDRed",
    "LEDGreen",
    "LEDBlue",
    "Screen",
    "WarningYellow",
    "WarningRed",
    "IndustrialDefault",
    "BrushedSteel",
    "GalvanizedSteel"
}

local DefaultMaterialParams =
{
    BaseColorConstant =
    {
        R = 0.650,
        G = 0.650,
        B = 0.680
    },

    MetallicRation    = 0.100,
    RoughnessRation   = 0.550,
    EmissiveRation    = 0.000,
    NormalRation      = 1.000
}


function M:Initialize(Initializer)
    self.modelType = 10
    self.clickType = 1
    self.modelCode = ""
    self.modelManage = nil
    -- self.showName = ""
    self.path = ""
    self.bMove = true
    self.bLoading = false -- 加载状态标记
    self.MaterialDatas = {}
    -- 前端交互用：GetData/SetData 透传的材质状态，结构为 { [MaterialKey] = MaterialState }。
    self.MaterialSaveData = nil
    -- 存档用：ModelSave/ModelLoad 使用的“已保存 SourceState”，不要与 MaterialSaveData 混用。
    self.MaterialSourceSaveData = nil
    self.LoadMaterialSourceSaveData = nil
    self.LoadMaterialSaveData = nil
end

function M:ReceiveBeginPlay()
    self.control = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(), LoadClass(Class.control))
    self.ImportFunc = self.control.modelManage.importFunc
end

function M:UpdateCollisionBoxSize()
    if self.CollisionBox then
        if self.size then
            local scale = self.size / 100
            -- print("scale:", scale, "name:", self:GetAttachParentActor().showName,
            -- UE.UKismetSystemLibrary.GetDisplayName(self))
            self.CollisionBox:SetWorldScale3D(scale, false, nil, false)
            -- print("scale:", self.CollisionBox:K2_GetComponentScale(), "name:", self:GetAttachParentActor().showName)
        elseif self.originalSize then
            self.CollisionBox:SetWorldScale3D(self.originalSize / 100, false, nil, false)
        end
        self.CollisionBox:K2_SetRelativeLocation(UE.FVector(0, 0, 0), false, nil, false)
    end
end

function M:UpdateCollisionStatus(bColliding)
    if self.CollisionBox then
        if self.bLoading then
            -- 加载过程中：黄色材质
            local yellowMat = LoadObject("/Game/SandBox/Materials/M_Light_Inst3.M_Light_Inst3")
            self.CollisionBox:SetMaterial(0, yellowMat)
        else
            if bColliding then
                -- 碰撞状态：红色材质
                local redMat = LoadObject("/Game/SandBox/Materials/M_Light_Inst.M_Light_Inst")
                self.CollisionBox:SetMaterial(0, redMat)
            else
                -- 可放置状态：绿色材质
                local greenMat = LoadObject("/Game/SandBox/Materials/M_Light_Inst2.M_Light_Inst2")
                self.CollisionBox:SetMaterial(0, greenMat)
            end
        end
        self.CollisionBox:SetHiddenInGame(false)
    end
end

function M:UpdateLoadingStatus(bLoading)
    self.bLoading = bLoading
    if self.CollisionBox then
        -- 设置盒体可见性
        self.CollisionBox:SetHiddenInGame(false)
        -- 设置盒体材质为黄色
        local yellowMat = LoadObject("/Game/SandBox/Materials/M_Light_Inst3.M_Light_Inst3")
        self.CollisionBox:SetMaterial(0, yellowMat)
    end
end

function M:HideCollisionBox()
    if self.CollisionBox then
        self.CollisionBox:SetHiddenInGame(true)
    end
end

function M:GetModelBounds()
    local origin, boxExtent
    if self.Meshs:Num() == 0 then
        origin, boxExtent = UE.UKismetSystemLibrary.GetComponentBounds(self.PMesh)
    else
        _, origin, boxExtent = UE.UMyBFL.GetComponentsBound(self.Meshs)
    end
    return origin, boxExtent
end

function M:GetBox(bBasic)
    local origin, boxExtent = self:GetModelBounds()

    if boxExtent ~= UE.FVector(0, 0, 0) then
        self.originalSize = boxExtent * 2
        self.size = self.originalSize
    end
    self.bBasic = bBasic
    if self.control then
        self.control:ModelDataToView()
    end
end

--[[
    接口函数：模型存档输出。
    通信结构：
    {
        ModelCode, OriginalSize, BSize, Path, CType,
        MaterialSourceStates = {
            [MaterialKey] = { TemplateID, TemplateName, Params = { BaseColorConstant, MetallicRation, ... } }
        }
    }
    注意：ModelSave/ModelLoad 只使用 MaterialSourceStates 保存“已保存的 SourceState”，
    不和前端交互用的 MaterialSaveData 混用。
]]
function M:ModelSave()
    if self.size == UE.FVector(0, 0, 0) then
        local origin, boxExtent = self:GetModelBounds()
        self.size = boxExtent * 2
    end
    local table = {
        ["ModelCode"] = self.modelCode,
        ["OriginalSize"] = UE.UJsonLibraryHelpers.JsonValue_Stringify(
            UE.UJsonLibraryHelpers.FromVector(self.originalSize)),
        ["BSize"] = UE.UJsonLibraryHelpers.JsonValue_Stringify(UE.UJsonLibraryHelpers.FromVector(self.size)),
        ["Path"] = self.path,
        ["CType"] = self.clickType,
        ["MaterialSourceStates"] = self:SaveMaterialSourceStates(),
    }
    return table
end

--[[
    接口函数：模型存档读取。
    通信结构同 ModelSave；Materials 仅作为旧数据兼容入口读取，不再作为新的存档字段写出。
]]
function M:ModelLoad(table, bUndo)
    local BS                  = UE.UJsonLibraryHelpers.ToVector(UE.UJsonLibraryHelpers.Parse(table["BSize"]))
    local OS                  = UE.UJsonLibraryHelpers.ToVector(UE.UJsonLibraryHelpers.Parse(table["OriginalSize"]))
    local SourceSaveData      = table["MaterialSourceStates"] or table["Materials"]

    self.modelCode            = table["ModelCode"]
    self.path                 = table["Path"]
    self.clickType            = table["CType"] ~= 0 and table["CType"] or self.clickType
    self.modelType            = table["Type"]
    self.size                 = BS
    self.originalSize         = OS
    self.MaterialSourceSaveData = self:NormalizeMaterialSourceSaveData(SourceSaveData)
    self.LoadMaterialSourceSaveData = self:DeepCopy(self.MaterialSourceSaveData)
    self.MaterialSaveData     = self:DeepCopy(self.MaterialSourceSaveData)
    self.LoadMaterialSaveData = nil
    if bUndo then
        if self.LoadMaterialSourceSaveData then
            self:UseMaterialSourceStates(
                self.LoadMaterialSourceSaveData
            )
        else
            self:RestoreAllMaterials()
        end
        return
    end
    self:LoadModel()
end

function M:TraceOtherModel()
    local origin, boxExtent = self:GetModelBounds()
    local objectTypes = UE.TArray(UE.EObjectTypeQuery)
    objectTypes:Add(UE.EObjectTypeQuery.WorldStatic)
    local actorsToIgnore = UE.TArray(UE.AActor)
    actorsToIgnore:Add(self)
    local bTrace = UE.UKismetSystemLibrary.BoxOverlapActors(self:GetWorld(), origin, boxExtent,
        objectTypes, UE.AStaticMeshActor, actorsToIgnore, UE.TArray(UE.AActor))
    return bTrace
end

--[[
    接口函数：前端修改模型数据。
    入参材质结构：table.Materials / table.MaterialStates，结构同 GetSavedMaterialInteractionData 注释。
    如果带材质数据，必须走 ApplyMaterialInteractionData，保证和外部材质修改同一入口。
]]
function M:SetData(table)
    print(self.originalSize, "OriginalSize")
    self.size = table.Size
    table.T.Scale3D = table.Size / self.originalSize
    self:K2_SetActorTransform(table.T, false, UE.FHitResult(), false)
    -- self.showName = table.showname
    self:GetAttachParentActor().showName = table.showname

    local MaterialState =
        self:GetSavedMaterialInteractionData(
            table.Materials or table.MaterialStates
        )

    if MaterialState then
        self:ApplyMaterialInteractionData(MaterialState)
    end
end

--[[
    接口函数：前端读取模型数据。
    出参材质结构：MDTV.Materials = self.MaterialSaveData，即已保存/已提交的前端交互材质状态。
]]
function M:GetData(CH)
    local T = self:GetTransform()
    if self.size == nil then
        return {}
    end
    local MDTV = {
        length = DFL.integrate(self.size.X),
        width = DFL.integrate(self.size.Y),
        height = DFL.integrate(self.size.Z),
        -- top = CH - DFL.integrate(self.size.Z),
        angle = DFL.integrate(UE.UKismetMathLibrary.Quat_Rotator(T.Rotation).Yaw),
        x = DFL.integrate(T.Translation.X),
        y = DFL.integrate(T.Translation.Y),
        z = DFL.integrate(T.Translation.Z),
        bBasic = self.bBasic,
        showname = self:GetAttachParentActor().showName,
        bMove = self.bMove,
    }

    self:AppendMaterialInteractionData(MDTV)

    return MDTV
end

function M:LoadModel()
    self:SetActorScale3D(UE.FVector(1, 1, 1))
    if not self.CollisionBox then
        self:CreateCollisionBox() -- 蓝图函数
        -- 设置加载状态
        self:UpdateLoadingStatus(true)
        if self.originalSize then
            self:UpdateCollisionBoxSize()
        end
    end
    -- print("scale1:", self.CollisionBox:K2_GetComponentScale(), "name:", self:GetAttachParentActor().showName)
    self.PMesh:ClearAllMeshSections()
    -- print("scale1.5:", self.CollisionBox:K2_GetComponentScale(), "name:", self:GetAttachParentActor().showName)
    local extension = string.match(self.path, "^.+(%..+)$")
    extension = string.lower(extension)
    local LoadMesh
    if extension == ".zip" then
        local path = UE.UBlueprintPathsLibrary.ProjectDir() .. string.match(self.path, "model/[^%.]+")
        if not UE.UBlueprintPathsLibrary.DirectoryExists(path) then
            print("Zip model directory not exists:", path)
            return
        end
        local modelPath
        local fileType = 0
        for key, value in pairs(DFL.modelType) do
            modelPath = self:FindModelPath(path, key)
            if modelPath then
                fileType = value
                local fullModelPath = path .. "/" .. modelPath
                if UE.UBlueprintPathsLibrary.FileExists(fullModelPath) then
                    self:LoadMeshfFile(fileType, fullModelPath)
                    print(fullModelPath)
                else
                    print("Model file not exists:", fullModelPath)
                end
                break
            end
        end
    else
        local DownModelName = string.match(self.path, "%.-([^\\/]-%.?[^%.\\/]*)$")
        local path = UE.UBlueprintPathsLibrary.ProjectDir() .. "model/" .. DownModelName
        if not UE.UBlueprintPathsLibrary.FileExists(path) then
            print("Model file not exists:", path)
            -- print("scale2:", self.CollisionBox:K2_GetComponentScale(), "name:", self:GetAttachParentActor().showName)
            return
        end
        if extension == ".stp" or extension == ".step" then
            local pathStp = string.sub(path, 0, -(#extension + 1)) .. "Temp.stl"
            if UE.UBlueprintPathsLibrary.FileExists(pathStp) then
                self:LoadMeshfFile(2, pathStp)
                -- LoadMesh = UE.URealTimeImportAsyncNodeLoadMesh.LoadMeshFileAsyncNode(
                --     2, 1, Path, 1, true, true, true)
                goto continue
            end
        end
        local fileType = DFL.modelType[extension]
        -- if extension == ".fbx" and UE.UMyBFL.GetExeURL("Mode") == "testImport" then
        if extension == ".fbx" then
            -- self:LoadNewFBX(path)

            self.ImportFunc:LoadNewFBX(path, self)
            -- local L = self:K2_GetActorLocation()
            -- local actors = UE.TArray(UE.AActor)
            -- actors:Add(self)
            -- local bHaveBox, O, B = UE.UMyBFL.GetComponentsBound(self.Meshs)
            -- if bHaveBox then
            --     local Location = -O + UE.FVector(0, 0, B.Z)
            --     self.PMesh:K2_SetWorldLocation(Location, false, nil, false)
            --     if not self.OriginalSize then
            --         self:GetBox(self.bBasic)
            --     end
            -- end
            -- return
        else
            local fileType = DFL.modelType[extension]
            if fileType then
                self:LoadMeshfFile(fileType, path)
            else
                print("Invalid file type:", extension)
            end
        end
        -- LoadMesh = UE.URealTimeImportAsyncNodeLoadMesh.LoadMeshFileAsyncNode(
        --     FileType, 1, Path, 1, true, true, true)
    end
    ::continue::
    -- if LoadMesh then
    --     LoadMesh.OnSuccess:Add(self, self.LoadSuccess)
    --     LoadMesh.OnFail:Add(self, self.LoadFail)
    --     LoadMesh:Activate()
    -- else
    --     print("无模型")
    -- end
end

function M:FindModelPath(Path, str)
    local filepaths = UE.UMyBFL.GetFolderFiles(Path)
    for key, file in pairs(filepaths) do
        if file:find(str) then
            print(file)
            return file
        end
    end
end

function M:LoadSuccess(modelStructs, errorMessage)
    for k, val in pairs(modelStructs) do
        for index, value in pairs(val.meshStructs) do
            local MaterialStruct = value.materialData
            local i = index - 1
            self.PMesh:CreateMeshSection(i, value.vertices, value.triangles, value.normals, value.UV0, nil, nil, true)
            if not MaterialStruct.isEmpty and MaterialStruct.textures:Num() > 0 then
                --local DMI = self.PMesh:CreateDynamicMaterialInstance(i, self.MTex, nil)
                local DMI = self.PMesh:GetMaterial(i)
                for key, Texval in pairs(MaterialStruct.textures) do
                    local tex = self:GetTexture(Texval)
                    if tex then
                        if Texval.textureType == UE.ERTITextureType.E_Kd then
                            DMI:SetTextureParameterValue("Diffuse", tex)
                        elseif Texval.textureType == UE.ERTITextureType.E_bump or Texval.textureType == UE.ERTITextureType.E_norm then
                            DMI:SetTextureParameterValue("Normal", tex)
                        end
                    end
                end
            else
                --local DMI = self.PMesh:CreateDynamicMaterialInstance(i, self.MRGB, nil)
                local DMI = self.PMesh:GetMaterial(i)
                DMI:SetVectorParameterValue("Diffuse",
                    UE.UKismetMathLibrary.Conv_ColorToLinearColor(MaterialStruct.diffuse))
            end
        end
    end
    self:GetModelSize()
end

function M:GetModelSize()
    -- 加载完成，更新状态
    self.bLoading = false

    local L = self.PMesh:K2_GetComponentLocation()
    local bGet, O, B
    if self.Meshs:Num() > 0 then
        bGet, O, B = UE.UMyBFL.GetComponentsBound(self.Meshs)
    else
        O, B = UE.UKismetSystemLibrary.GetComponentBounds(self.PMesh)
    end
    local Location = L - O + UE.FVector(0, 0, B.Z)
    self.PMesh:K2_SetRelativeLocation(Location, false, nil, false)
    -- print("O:", O, "B:", B)
    if (not self.control.bBuild or self.control.clickType == "Array") and self.size then
        self:HideCollisionBox()
        local scale = self.size / self.originalSize
        self.CollisionBox:SetWorldScale3D(self.originalSize / 100)
        self:SetActorScale3D(scale)
    else
        self:GetBox(self.bBasic)
        if self.control.bBuild then
            self:UpdateCollisionBoxSize()
            self:UpdateCollisionStatus(false)
        end
    end


    self:InitMaterialDatas()

    if self.LoadMaterialSourceSaveData then
        self:UseMaterialSourceStates(
            self.LoadMaterialSourceSaveData
        )
    end

    if self.LoadMaterialSaveData then
        self:ApplyMaterialInteractionData(
            self.LoadMaterialSaveData
        )
    end
end

function M:LoadFail(modelStructs, errorMessage)
    -- 加载失败，更新状态
    self.bLoading = false
    print(errorMessage, 3333333333)
    -- 隐藏碰撞盒
    self:HideCollisionBox()
end

function M:ReceiveEndPlay()
    -- 取消当前模型的异步生成任务
    if self.ImportFunc then
        self.ImportFunc:CancelImportForActor(self)
    end
end

function M:DeepCopy(obj)
    if type(obj) ~= "table" then
        return obj
    end

    local newTable = {}

    for k, v in pairs(obj) do
        newTable[k] = self:DeepCopy(v)
    end

    return newTable
end

function M:CopyMaterialParamTable(Params)
    local Result = {}

    if not Params then
        return Result
    end

    for _, ParamName in ipairs(MaterialParamNames) do
        if Params[ParamName] ~= nil then
            Result[ParamName] =
                self:DeepCopy(
                    Params[ParamName]
                )
        end
    end

    return Result
end

function M:IsEmptyTable(Table)
    if not Table then
        return true
    end

    return next(Table) == nil
end

function M:GetMaterialSaveState(State)
    local Normalized =
        self:NormalizeMaterialState(State)

    local Params =
        self:CopyMaterialParamTable(
            Normalized.Params
        )

    local TemplateName =
        self:ResolveTemplateName(Normalized)

    if not TemplateName and self:IsEmptyTable(Params) then
        return nil
    end

    return
    {
        TemplateID = Normalized.TemplateID,
        TemplateName = TemplateName,
        Params = Params
    }
end

function M:GetMaterialComponents()
    local Components = {}

    if self.Meshs and self.Meshs:Num() > 0 then
        for i = 1, self.Meshs:Num() do
            local Component =
                self.Meshs[i]

            if Component and UE.UKismetSystemLibrary.IsValid(Component) then
                Components[#Components + 1] =
                {
                    Component = Component,
                    ComponentIndex = i,
                    KeyPrefix = "M" .. tostring(i) .. ":"
                }
            end
        end
    end

    if #Components == 0 and self.PMesh then
        Components[#Components + 1] =
        {
            Component = self.PMesh,
            ComponentIndex = 0,
            KeyPrefix = ""
        }
    end

    return Components
end

function M:InitMaterialDatas()
    self.MaterialDatas = {}

    local Components =
        self:GetMaterialComponents()

    for _, ComponentData in ipairs(Components) do
        local Component =
            ComponentData.Component

        local Count =
            Component:GetNumMaterials()

        for i = 0, Count - 1 do
            local MID =
                Component:CreateDynamicMaterialInstance(i)

            local SourceParams =
                self:ReadSourceMaterial(Component, i)

            local Key =
                ComponentData.KeyPrefix .. tostring(i)

            self.MaterialDatas[Key] =
            {
                MaterialKey = Key,

                ComponentIndex = ComponentData.ComponentIndex,

                Component = Component,

                SlotIndex = i,

                MID = MID,

                bModified = false,

                SourceState =
                {
                    TemplateID = 0,
                    TemplateName = nil,

                    Params =
                        self:DeepCopy(
                            SourceParams
                        )
                },

                CurrentState =
                {
                    TemplateID = 0,
                    TemplateName = nil,

                    Params = {}
                }

            }
        end
    end
end

function M:ReadSourceMaterial(Component, SlotIndex)
    if not SlotIndex then
        SlotIndex = Component
        Component = self.PMesh
    end

    local MID =
        Component and Component:GetMaterial(SlotIndex)

    --------------------------------------------------
    -- 默认兜底
    --------------------------------------------------

    local Params =
        self:DeepCopy(DefaultMaterialParams)

    if not MID then
        return Params
    end

    --------------------------------------------------
    -- BaseColor
    --------------------------------------------------

    local BC =
        UE.FLinearColor(1, 1, 1, 1)

    local bColor, Color =
        MID:GetVectorParameterValue(
            "BaseColorConstant",
            BC
        )

    if bColor then
        Params.BaseColorConstant =
        {
            R = Color.R,
            G = Color.G,
            B = Color.B
        }
    end

    --------------------------------------------------
    -- Scalar
    --------------------------------------------------

    local function ReadScalar(Name, Default)
        local bSuccess, Value =
            MID:GetScalarParameterValue(
                Name,
                Default
            )

        if bSuccess then
            return Value
        end

        return Default
    end

    Params.MetallicRation =
        ReadScalar(
            "MetallicRation",
            0
        )

    Params.RoughnessRation =
        ReadScalar(
            "RoughnessRation",
            0.5
        )

    Params.EmissiveRation =
        ReadScalar(
            "EmissiveRation",
            0
        )

    Params.NormalRation =
        ReadScalar(
            "NormalRation",
            1
        )

    return Params
end

-- 外部如果直接改了 MID 参数，可调用本函数把 MID 当前值同步回 CurrentState。
function M:SyncMaterialStateFromMID(
    MaterialKey,
    bCommit
)
    local Data =
        self.MaterialDatas[
        MaterialKey
        ]

    if not Data then
        return false
    end

    local Params =
        self:ReadSourceMaterial(
            Data.Component or self.PMesh,
            Data.SlotIndex
        )

    Data.CurrentState =
        self:NormalizeMaterialState(
        {
            TemplateID = 0,
            TemplateName = nil,
            Params = Params
        }
        )

    if bCommit then
        self:CommitMaterialDatas(MaterialKey)
    else
        Data.bModified = true
    end

    return true
end

-- 统一材质修改入口：支持切模板、单参数、多参数、恢复和外部 MID 同步。
-- 示例：ApplyMaterialChange(Key, "RoughnessRation", 0.4)
-- 示例：ApplyMaterialChange(Key, { TemplateName = "Gold", Params = { RoughnessRation = 0.2 } })
function M:ApplyMaterialChange(
    MaterialKey,
    Change,
    Value
)
    local Data =
        self.MaterialDatas[
        MaterialKey
        ]

    if not Data then
        return false
    end

    if type(Change) == "string" then
        Change =
        {
            Params =
            {
                [Change] = Value
            }
        }
    end

    if not Change then
        return false
    end

    if Change.bRestore then
        local bSuccess = self:RestoreMaterial(MaterialKey)

        if bSuccess and Change.bCommit then
            self:CommitMaterialDatas(MaterialKey)
        end

        return bSuccess
    end

    if Change.bSyncFromMID then
        return self:SyncMaterialStateFromMID(
            MaterialKey,
            Change.bCommit
        )
    end

    local State =
        self:NormalizeMaterialState(
            Data.CurrentState
        )

    if Change.State then
        State =
            self:NormalizeMaterialState(
                Change.State
            )
    end

    local bTemplateChanged = false

    if Change.TemplateID ~= nil then
        State.TemplateID =
            tonumber(Change.TemplateID) or 0
        State.TemplateName = nil
        bTemplateChanged = true
    end

    if Change.TemplateName ~= nil then
        State.TemplateName = Change.TemplateName
        State.TemplateID = Change.TemplateID or State.TemplateID or 0
        bTemplateChanged = true
    end

    State.TemplateName =
        self:ResolveTemplateName(State)

    local Params =
        Change.Params or Change.ParamValues

    if bTemplateChanged and not Change.bKeepParams then
        State.Params = {}
    end

    if Params then
        State.Params =
            State.Params or {}

        for ParamName, ParamValue in pairs(Params) do
            State.Params[ParamName] =
                self:DeepCopy(ParamValue)
        end
    end

    Data.CurrentState =
        self:NormalizeMaterialState(State)

    Data.bModified = true

    self:_ApplyMaterial(MaterialKey)

    if Change.bCommit then
        self:CommitMaterialDatas(MaterialKey)
    end

    return true
end

function M:UpdateMaterialState(
    MaterialKey,
    NewState
)
    local Data =
        self.MaterialDatas[
        MaterialKey
        ]

    if not Data then
        return
    end

    self:ApplyMaterialChange(
        MaterialKey,
        {
            State = NewState
        }
    )
end

function M:UpdateMaterialParam(
    MaterialKey,
    ParamName,
    Value
)
    local Data =
        self.MaterialDatas[
        MaterialKey
        ]

    if not Data then
        return
    end

    self:ApplyMaterialChange(
        MaterialKey,
        ParamName,
        Value
    )
end

function M:_ApplyMaterial(MaterialKey)
    local Data =
        self.MaterialDatas[
        MaterialKey
        ]

    if not Data then
        return
    end

    local MID = Data.MID

    if not MID then
        return
    end

    local FinalParams =
        self:GetMaterialFinalParams(
            Data.SourceState,
            Data.CurrentState
        )

    self:ApplyToMID(
        MID,
        FinalParams
    )
end

function M:GetMaterialStateParams(
    State,
    BaseParams
)
    local Result =
        self:DeepCopy(BaseParams or {})

    local Normalized =
        self:NormalizeMaterialState(State)

    local TemplateName =
        self:ResolveTemplateName(Normalized)

    if TemplateName then
        local Template =
            MaterialTemplateData[
            TemplateName
            ]

        if Template then
            Result =
                self:MergeParams(
                    Result,
                    Template
                )
        end
    end

    return self:MergeParams(
        Result,
        Normalized.Params
    )
end

function M:GetMaterialFinalParams(
    SourceState,
    CurrentState
)
    local SourceParams =
        self:GetMaterialStateParams(
            SourceState,
            {}
        )

    return self:GetMaterialStateParams(
        CurrentState,
        SourceParams
    )
end

function M:ResolveTemplateName(State)
    if not State then
        return nil
    end

    if State.TemplateName and MaterialTemplateData[State.TemplateName] then
        return State.TemplateName
    end

    local TemplateID =
        tonumber(State.TemplateID)

    if TemplateID and TemplateID > 0 then
        return MaterialTemplateOrder[TemplateID]
    end

    return nil
end

function M:NormalizeMaterialState(State)
    local Normalized =
        self:DeepCopy(State or {})

    Normalized.TemplateID =
        tonumber(Normalized.TemplateID) or 0

    if Normalized.TemplateName and not MaterialTemplateData[Normalized.TemplateName] then
        Normalized.TemplateName = nil
    end

    if not Normalized.TemplateName then
        Normalized.TemplateName =
            self:ResolveTemplateName(Normalized)
    end

    Normalized.Params =
        self:CopyMaterialParamTable(
            Normalized.Params
        )

    return Normalized
end

function M:MergeParams(Base, Override)
    if not Override then
        return Base
    end

    local Result =
        self:DeepCopy(Base)

    for k, v in pairs(Override) do
        if type(v) == "table" then
            Result[k] =
                self:DeepCopy(v)
        else
            Result[k] = v
        end
    end

    return Result
end

function M:ApplyToMID(MID, Params)
    if not MID or not Params then
        return
    end

    --------------------------------------------------
    -- BaseColor
    --------------------------------------------------

    local BC =
        Params.BaseColorConstant

    if BC then
        MID:SetVectorParameterValue(
            "BaseColorConstant",

            UE.FLinearColor(
                BC.R,
                BC.G,
                BC.B,
                1
            )
        )
    end

    --------------------------------------------------
    -- Scalar
    --------------------------------------------------

    if Params.MetallicRation ~= nil then
        MID:SetScalarParameterValue(
            "MetallicRation",
            Params.MetallicRation
        )
    end

    if Params.RoughnessRation ~= nil then
        MID:SetScalarParameterValue(
            "RoughnessRation",
            Params.RoughnessRation
        )
    end

    if Params.EmissiveRation ~= nil then
        MID:SetScalarParameterValue(
            "EmissiveRation",
            Params.EmissiveRation
        )
    end

    if Params.NormalRation ~= nil then
        MID:SetScalarParameterValue(
            "NormalRation",
            Params.NormalRation
        )
    end
end

function M:RestoreMaterial(MaterialKey)
    local Data =
        self.MaterialDatas[
        MaterialKey
        ]

    if not Data then
        return false
    end

    --------------------------------------------------
    -- 恢复到初始化时读取的原始材质
    --------------------------------------------------

    Data.CurrentState =
    {
        TemplateID = 0,
        TemplateName = nil,
        Params = {}
    }

    Data.bModified = false

    self:_ApplyMaterial(
        MaterialKey
    )

    return true
end

function M:RestoreAllMaterials()
    if not self.MaterialDatas then
        return
    end

    for Key, _ in pairs(
        self.MaterialDatas
    ) do
        self:RestoreMaterial(Key)
    end
end

--[[
    接口函数：外部/前端直接改材质的统一入口。
    支持结构：
    1) { MaterialKey = "0", State = MaterialState, bCommit = true }
    2) { MaterialKey = "0", TemplateID = 1, Params = { RoughnessRation = 0.2 }, bCommit = true }
    3) { Materials = { [MaterialKey] = MaterialState } } 批量交互结构
]]
function M:GetMaterialData(JSONT)
    if not JSONT then
        return false
    end

    local SaveData =
        JSONT.Materials or JSONT.MaterialStates

    if SaveData then
        self:ApplyMaterialInteractionData(SaveData)
        return true
    end

    local MaterialKey =
        JSONT.MaterialKey or JSONT.materialKey or JSONT.Key or JSONT.key

    if not MaterialKey then
        return false
    end

    return self:ApplyMaterialChange(
        MaterialKey,
        JSONT
    )
end

function M:SetMaterialState(
    MaterialKey,
    NewState
)
    local Data =
        self.MaterialDatas[
        MaterialKey
        ]

    if not Data then
        return
    end

    self:ApplyMaterialChange(
        MaterialKey,
        {
            State = NewState
        }
    )
end

function M:SetMaterialParam(
    MaterialKey,
    ParamName,
    Value
)
    local Data =
        self.MaterialDatas[
        MaterialKey
        ]

    if not Data then
        return
    end

    self:ApplyMaterialChange(
        MaterialKey,
        ParamName,
        Value
    )
end

function M:NormalizeMaterialSaveData(SaveData)
    if not SaveData then
        return nil
    end

    local Result = {}
    local bHasData = false

    for Key, Saved in pairs(
        SaveData
    ) do
        local State =
            self:GetMaterialSaveState(
                Saved
            )

        if State then
            Result[Key] = State
            bHasData = true
        end
    end

    if not bHasData then
        return nil
    end

    return Result
end

function M:NormalizeMaterialSourceSaveData(SaveData)
    return self:NormalizeMaterialSaveData(SaveData)
end

function M:GetEmptyMaterialState()
    return
    {
        TemplateID = 0,
        TemplateName = nil,
        Params = {}
    }
end

-- 把当前显示效果固化成新的 SourceState，用于 ModelSave/ModelLoad 的存档结构。
function M:GetCommittedMaterialSourceState(Data)
    if not Data then
        return nil
    end

    local SourceState =
        self:NormalizeMaterialState(
            Data.SourceState
        )

    local CurrentState =
        self:NormalizeMaterialState(
            Data.CurrentState
        )

    local FinalParams =
        self:GetMaterialFinalParams(
            SourceState,
            CurrentState
        )

    local TemplateID = CurrentState.TemplateID
    local TemplateName = CurrentState.TemplateName

    if not TemplateName then
        TemplateID = SourceState.TemplateID
        TemplateName = SourceState.TemplateName
    end

    return self:GetMaterialSaveState(
    {
        TemplateID = TemplateID,
        TemplateName = TemplateName,
        Params = FinalParams
    }
    )
end

-- 保存点：把 CurrentState 复制/固化为新的 SourceState，同时刷新 MaterialSourceSaveData 和 MaterialSaveData。
function M:CommitMaterialDatas(MaterialKey)
    if not self.MaterialDatas then
        self.MaterialSourceSaveData = nil
        self.MaterialSaveData = nil
        return nil
    end

    local SourceSaveData =
        self:DeepCopy(
            self.MaterialSourceSaveData or {}
        )

    local FrontSaveData =
        self:DeepCopy(
            self.MaterialSaveData or {}
        )

    local function CommitOne(Key, Data)
        local SourceState =
            self:GetCommittedMaterialSourceState(
                Data
            )

        if SourceState then
            Data.SourceState =
                self:DeepCopy(
                    SourceState
                )

            Data.CurrentState =
                self:GetEmptyMaterialState()

            Data.bModified = false

            SourceSaveData[Key] =
                self:DeepCopy(
                    SourceState
                )

            FrontSaveData[Key] =
                self:DeepCopy(
                    SourceState
                )

            self:_ApplyMaterial(Key)
        else
            SourceSaveData[Key] = nil
            FrontSaveData[Key] = nil
        end
    end

    if MaterialKey then
        local Data =
            self.MaterialDatas[
            MaterialKey
            ]

        if Data then
            CommitOne(MaterialKey, Data)
        end
    else
        SourceSaveData = {}
        FrontSaveData = {}

        for Key, Data in pairs(
            self.MaterialDatas
        ) do
            CommitOne(Key, Data)
        end
    end

    self.MaterialSourceSaveData =
        self:NormalizeMaterialSourceSaveData(
            SourceSaveData
        )

    self.MaterialSaveData =
        self:NormalizeMaterialSaveData(
            FrontSaveData
        )

    return self:DeepCopy(
        self.MaterialSaveData
    )
end

-- bCommit 为 true 时固化当前状态；为空时只生成当前预览快照，不改保存结构。
function M:GetMaterialDataSnapshot(bCommit)
    if bCommit then
        return self:CommitMaterialDatas()
    end

    local SaveData = {}
    local bHasData = false

    for Key, Data in pairs(
        self.MaterialDatas
    ) do
        local State =
            self:GetCommittedMaterialSourceState(
                Data
            )

        if State then
            SaveData[Key] = State
            bHasData = true
        end
    end

    if not bHasData then
        return nil
    end

    return SaveData
end

function M:SaveMaterialSourceStates()
    self:CommitMaterialDatas()

    return self:DeepCopy(
        self.MaterialSourceSaveData
    )
end

function M:SaveMaterialDatas()
    return self:DeepCopy(
        self.MaterialSaveData
    )
end

--[[
    接口函数：前端交互材质结构归一化。
    通信结构：
    Materials / MaterialStates = {
        [MaterialKey] = {
            TemplateID = number,
            TemplateName = string | nil,
            Params = {
                BaseColorConstant = { R, G, B },
                MetallicRation = number,
                RoughnessRation = number,
                EmissiveRation = number,
                NormalRation = number
            }
        }
    }
]]
function M:GetSavedMaterialInteractionData(
    SaveData
)
    return self:DeepCopy(
        self:NormalizeMaterialSaveData(
            SaveData or self.MaterialSaveData
        )
    )
end

-- 接口函数：GetData 输出给前端时，只拼接 MaterialSaveData。
function M:AppendMaterialInteractionData(
    DataTable
)
    if not DataTable then
        return DataTable
    end

    local MaterialState =
        self:GetSavedMaterialInteractionData()

    if MaterialState then
        DataTable.Materials = MaterialState
    else
        DataTable.Materials = nil
    end

    return DataTable
end

-- 接口函数：SetData/前端材质交互统一入口；内部走 ApplyMaterialChange，同步状态、参数、MID 和保存数据。
function M:ApplyMaterialInteractionData(
    SaveData
)
    local NormalizedSaveData =
        self:GetSavedMaterialInteractionData(SaveData)

    if not NormalizedSaveData then
        self.MaterialSaveData = nil
        self.LoadMaterialSaveData = nil
        return
    end

    self.MaterialSaveData =
        self:DeepCopy(
            NormalizedSaveData
        )

    if not self.MaterialDatas or not next(self.MaterialDatas) then
        self.LoadMaterialSaveData =
            self:DeepCopy(
                NormalizedSaveData
            )
        return
    end

    for Key, Saved in pairs(
        NormalizedSaveData
    ) do
        self:ApplyMaterialChange(
            Key,
            {
                State = Saved,
                bCommit = true
            }
        )
    end

    self.LoadMaterialSaveData = nil
end

-- ModelLoad 专用：恢复存档 SourceState，不使用前端交互结构进行混写。
function M:UseMaterialSourceStates(
    SaveData
)
    local NormalizedSourceData =
        self:NormalizeMaterialSourceSaveData(
            SaveData
        )

    self.MaterialSourceSaveData =
        self:DeepCopy(
            NormalizedSourceData
        )

    self.MaterialSaveData =
        self:DeepCopy(
            NormalizedSourceData
        )

    if not NormalizedSourceData then
        self.LoadMaterialSourceSaveData = nil
        return
    end

    if not self.MaterialDatas or not next(self.MaterialDatas) then
        self.LoadMaterialSourceSaveData =
            self:DeepCopy(
                NormalizedSourceData
            )
        return
    end

    for Key, SourceState in pairs(
        NormalizedSourceData
    ) do
        local Data =
            self.MaterialDatas[
            Key
            ]

        if Data then
            Data.SourceState =
                self:DeepCopy(
                    SourceState
                )

            Data.CurrentState =
                self:GetEmptyMaterialState()

            Data.bModified = false

            self:_ApplyMaterial(
                Key
            )
        end
    end

    self.LoadMaterialSourceSaveData = nil
end

function M:LoadMaterialSourceStates(
    SaveData
)
    self:UseMaterialSourceStates(SaveData)
end

-- 旧接口兼容：旧调用路径的 Materials 按新 SourceState 读取入口处理。
function M:UseMaterialDatas(
    SaveData
)
    self:UseMaterialSourceStates(SaveData)
end

function M:LoadMaterialDatas(
    SaveData
)
    self:UseMaterialDatas(SaveData)
end

return M
