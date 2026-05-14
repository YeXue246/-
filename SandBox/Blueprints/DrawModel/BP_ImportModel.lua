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

local DefaultMaterialParams =
{
    [123] =
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

-- 数据出
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
        ["Materials"] = self:SaveMaterialDatas(),
    }
    return table
end

-- 数据进
function M:ModelLoad(table, bUndo)
    local BS                  = UE.UJsonLibraryHelpers.ToVector(UE.UJsonLibraryHelpers.Parse(table["BSize"]))
    local OS                  = UE.UJsonLibraryHelpers.ToVector(UE.UJsonLibraryHelpers.Parse(table["OriginalSize"]))

    self.modelCode            = table["ModelCode"]
    self.path                 = table["Path"]
    self.clickType            = table["CType"] ~= 0 and table["CType"] or self.clickType
    self.modelType            = table["Type"]
    self.size                 = BS
    self.originalSize         = OS
    self.LoadMaterialSaveData = table["Materials"]
    if bUndo then
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

function M:SetData(table)
    print(self.originalSize, "OriginalSize")
    self.size = table.Size
    table.T.Scale3D = table.Size / self.originalSize
    self:K2_SetActorTransform(table.T, false, UE.FHitResult(), false)
    -- self.showName = table.showname
    self:GetAttachParentActor().showName = table.showname
end

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

    if self.LoadMaterialSaveData then
        self:LoadMaterialDatas(
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

function M:InitMaterialDatas()
    self.MaterialDatas = {}

    local Count = self.PMesh:GetNumMaterials()

    for i = 0, Count - 1 do
        local MID =
            self.PMesh:CreateDynamicMaterialInstance(i)

        local SourceParams =
            self:ReadSourceMaterial(i)

        local Key = tostring(i)

        self.MaterialDatas[Key] =
        {
            MaterialKey = Key,

            SlotIndex = i,

            MID = MID,

            bModified = false,

            SourceState =
            {
                TemplateID = 0,

                Params =
                    self:DeepCopy(
                        SourceParams
                    )
            },

            CurrentState =
            {
                TemplateID = 0,

                Params =
                    self:DeepCopy(
                        SourceParams
                    )
            }

        }
    end
end

function M:ReadSourceMaterial(SlotIndex)
    local MID =
        self.PMesh:GetMaterial(SlotIndex)

    --------------------------------------------------
    -- 默认兜底
    --------------------------------------------------

    local Params =
    {
        BaseColorConstant =
        {
            R = 1,
            G = 1,
            B = 1
        },

        MetallicRation    = 0,
        RoughnessRation   = 0.5,
        EmissiveRation    = 0,
        NormalRation      = 1
    }

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

    --------------------------------------------------
    -- State
    --------------------------------------------------

    Data.CurrentState =
        self:DeepCopy(
            NewState
        )

    --------------------------------------------------
    -- Dirty
    --------------------------------------------------

    Data.bModified = true

    --------------------------------------------------
    -- 自动刷新
    --------------------------------------------------

    self:_ApplyMaterial(
        MaterialKey
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

    --------------------------------------------------
    -- CurrentState
    --------------------------------------------------

    local State =
        Data.CurrentState

    State.Params =
        State.Params or {}

    --------------------------------------------------
    -- 修改
    --------------------------------------------------

    State.Params[
    ParamName
    ] = Value

    --------------------------------------------------
    -- Dirty
    --------------------------------------------------

    Data.bModified = true

    --------------------------------------------------
    -- 自动刷新
    --------------------------------------------------

    self:_ApplyMaterial(
        MaterialKey
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

    local State =
        Data.CurrentState

    --------------------------------------------------
    -- Source
    --------------------------------------------------

    local FinalParams =
        self:DeepCopy(
            Data.SourceState.Params
        )

    --------------------------------------------------
    -- Template
    --------------------------------------------------

    local TemplateName =
        State.TemplateName

    if TemplateName then
        local Template =
            MaterialTemplateData[
            TemplateName
            ]

        if Template then
            FinalParams =
                self:MergeParams(
                    FinalParams,
                    Template
                )
        end
    end

    --------------------------------------------------
    -- Override
    --------------------------------------------------

    FinalParams =
        self:MergeParams(
            FinalParams,
            State.Params
        )

    --------------------------------------------------
    -- Apply
    --------------------------------------------------

    self:ApplyToMID(
        MID,
        FinalParams
    )
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
        return
    end

    --------------------------------------------------
    -- 恢复 Commit
    --------------------------------------------------

    Data.CurrentState =
        self:DeepCopy(
            Data.SourceState
        )

    Data.bModified = false

    self:_ApplyMaterial(
        MaterialKey
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

    --------------------------------------------------
    -- 更新状态
    --------------------------------------------------

    Data.CurrentState =
        self:DeepCopy(
            NewState
        )

    Data.bModified = true

    --------------------------------------------------
    -- Apply
    --------------------------------------------------

    self:_ApplyMaterial(
        MaterialKey
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

    --------------------------------------------------
    -- CurrentState
    --------------------------------------------------

    local State =
        Data.CurrentState

    if not State then
        return
    end

    --------------------------------------------------
    -- Params
    --------------------------------------------------

    State.Params =
        State.Params or {}

    --------------------------------------------------
    -- 修改当前状态
    --------------------------------------------------

    State.Params[
    ParamName
    ] = Value

    --------------------------------------------------
    -- 标记修改
    --------------------------------------------------

    Data.bModified = true

    --------------------------------------------------
    -- 重新应用
    --------------------------------------------------

    self:_ApplyMaterial(
        MaterialKey
    )
end

function M:SaveMaterialDatas()
    local SaveData = {}

    for Key, Data in pairs(
        self.MaterialDatas
    ) do
        --------------------------------------------------
        -- 保存 CurrentState
        --------------------------------------------------

        SaveData[Key] =
            self:DeepCopy(
                Data.CurrentState
            )

        --------------------------------------------------
        -- Commit
        --------------------------------------------------

        Data.SourceState =
            self:DeepCopy(
                Data.CurrentState
            )

        Data.bModified = false
    end

    return SaveData
end

function M:LoadMaterialDatas(
    SaveData
)
    if not SaveData then
        return
    end

    for Key, Saved in pairs(
        SaveData
    ) do
        local Data =
            self.MaterialDatas[
            Key
            ]

        if Data then
            --------------------------------------------------
            -- Source
            --------------------------------------------------

            Data.SourceState =
                self:DeepCopy(
                    Saved
                )

            --------------------------------------------------
            -- Current
            --------------------------------------------------

            Data.CurrentState =
                self:DeepCopy(
                    Saved
                )

            --------------------------------------------------
            -- Apply
            --------------------------------------------------

            self:_ApplyMaterial(
                Key
            )
        end
    end
end

return M
