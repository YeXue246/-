--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--
---@class BP_ModelManage_C
local M = UnLua.Class()
require("GlobalConfig")
local Model = require("SandBox.ModelNameInitialize")
local Class = require("SandBox.Class")
local DFL = require("SandBox.DataFunction")
local Location = require("SandBox.UI.Location")
local BP_Floor = require("SandBox.Blueprints.DrawModel.BP_Floor")
local Screen = require("SandBox.Screen")
local RegionAreaAlgo = require("SandBox.Blueprints.RegionAreaAlgo")
-- function M:Initialize(Initializer)
-- end

function M:ReceiveBeginPlay()
    local MClass = LoadClass("/Game/SandBox/Blueprints/BP_Materials.BP_Materials_C")
    self.BPM = self:GetWorld():SpawnActor(MClass, UE.FTransform(),
        UE.ESpawnActorCollisionHandlingMethod.Default, self, self, "")

    self.importFunc = self:GetWorld():SpawnActor(LoadClass(Class.importFunc), UE.FTransform(),
        UE.ESpawnActorCollisionHandlingMethod.Default, self, self, "")

    self.conflictList = {}
    self.importedModels = {}

    -- self.Regions = UE.TMap("", UE.AActor)
    self.drawMode = "Default"

    -- self.Actors = UE.TMap("", UE.AActor)
    local BMModelCode = { "LineWall", "RoofBeam", "Box", "Cylinder", "PlasticPipe", "Tubing" }
    self.BMMs = UE.TArray("")
    for key, value in pairs(BMModelCode) do
        self.BMMs:Add(BMModelCode[key])
    end
    self:ModelFunction()
    self:AnimeFunction()

    local paths = self:GetCustomDataTable()
    table.insert(paths, { modelPath = '/Game/SandBox/Blueprints/DT_Actor.DT_Actor' })

    coroutine.resume(coroutine.create(function()
        for _, val in pairs(paths) do
            local modelData = LoadObject(val.modelPath)
            if modelData then
                self:SaveModelTabeData(modelData)
            end
            print("animePath", val.animePath)
            local animeData = LoadObject(val.animePath)
            if animeData then
                self:SaveAnimeTabeData(animeData)
            end
        end
    end), self)
end

--获取自定义数据表
function M:GetCustomDataTable()
    -- 获取项目内容目录
    local path = UE.UKismetSystemLibrary.GetProjectContentDirectory() .. "SandBoxModel/"
    local tables = {}
    local files = UE.UMyBFL.GetFolderFiles(path)

    -- 遍历文件，查找包含 "companyId" 的文件
    for _, folder in pairs(files) do
        local fullFolderPath = path .. folder
        local folderFiles = UE.UMyBFL.GetFolderFiles(fullFolderPath)
        for _, fileName in pairs(folderFiles) do
            if string.find(fileName, "ModelData") ~= nil then
                local filePath = "/Game/SandBoxModel/" .. folder .. "/ModelData.ModelData"
                -- 加载对象并添加到表中
                LoadObject(filePath)
                table.insert(tables, filePath)
            end
        end
    end
    local paths = {}
    -- 遍历所有找到的表路径，获取 "level" 和 "levelUrl" 并存储到 DataTable 中
    for _, filePath in ipairs(tables) do
        local modelTablePath = UE.UKismetStringTableLibrary.GetTableEntrySourceString(filePath, "modelTablePath")
        local animeTablePath = UE.UKismetStringTableLibrary.GetTableEntrySourceString(filePath, "animeTablePath")
        local t = { modelPath = modelTablePath, animePath = animeTablePath }
        table.insert(paths, t)
    end
    return paths
end

-- 激活模型表
function M:ModelFunction()
    -- DIY是所有模型的最顶层的挂载者,Group是组,1是地板，2是基础模型，3是行业模型，4是管道，5是墙,6区域，7输送线，8标注
    -- 9是水平标注，10导入模型，11是信息面板,12是动画模型,13是虚线标注,14是通道，15是路径
    -- Multi是多选的辅助类actor，不进入保存读取，数据传输这类表

    -- 模型类型表
    self.class = {
        [1] = "/Game/SandBox/Blueprints/DrawModel/BP_Floor.BP_Floor_C",
        [2] = "/Game/SandBox/Blueprints/DrawModel/BP_Model.BP_Model_C",
        [3] = "/Game/SandBox/Blueprints/DrawModel/BP_Model.BP_Model_C",
        [4] = "/Game/SandBox/Blueprints/DrawModel/BP_Pipeline.BP_Pipeline_C",
        [5] = "/Game/SandBox/Blueprints/DrawModel/BP_Wall.BP_Wall_C",
        [6] = "/Game/SandBox/Blueprints/DrawModel/BP_Area.BP_Area_C",
        [7] = "/Game/SandBox/Blueprints/DrawModel/BP_SSX.BP_SSX_C",
        [8] = "/Game/SandBox/Blueprints/DrawModel/BP_BZ.BP_BZ_C",
        [9] = "/Game/SandBox/Blueprints/DrawModel/BP_VerticalBZ.BP_VerticalBZ_C",
        [10] = "/Game/SandBox/Blueprints/DrawModel/BP_ImportModel.BP_ImportModel_C",
        [11] = "/Game/SandBox/Blueprints/DrawModel/BP_Message.BP_Message_C",
        [12] = "/Game/SandBox/Blueprints/DrawModel/BP_SAGC.BP_SAGC_C",
        [13] = '/Game/SandBox/Blueprints/DrawModel/BP_DashedLine.BP_DashedLine_C',
        [14] = '/Game/SandBox/Blueprints/DrawModel/BP_Passage.BP_Passage_C',
        [15] = '/Game/SandBox/Blueprints/DrawModel/BP_Path.BP_Path_C',
        DIY = "/Game/SandBox/Blueprints/AuxiliaryModel/BP_DIY.BP_DIY_C",
        Group = "/Game/SandBox/Blueprints/AuxiliaryModel/BP_Group.BP_Group_C",
        Multi = "/Game/SandBox/Blueprints/AuxiliaryModel/BP_Multi.BP_Multi_C",
        CAD = "/Game/SandBox/Blueprints/AuxiliaryModel/BP_CAD.BP_CAD_C",
        RegionArea = "/Game/SandBox/Blueprints/AuxiliaryModel/BP_RegionArea.BP_RegionArea_C",
    }

    -- 模型生成
    self.ModelCreate = {
        ["Multi"] = function()
            -- 生成多选模型（例如：多选）
            local Multis = UE.UGameplayStatics.GetAllActorsOfClass(self:GetWorld(),
                LoadClass(self.class["Multi"]))
            for key, value in pairs(Multis) do
                value:K2_DestroyActor()
            end
            self.Multi = self:GetWorld():SpawnActor(LoadClass(self.class["Multi"]), UE.FTransform(),
                UE.ESpawnActorCollisionHandlingMethod.Default, self, self)
            return self.Multi
        end,
        ["DIY"] = function()
            -- 生成特殊模型（例如：DIY）
            self.DIY = self:GetWorld():SpawnActor(LoadClass(self.class["DIY"]), UE.FTransform(),
                UE.ESpawnActorCollisionHandlingMethod.Default, self, self)
            self:ActorInputMap(self.DIY, "DIY", "幻影")
            return self.DIY
        end,
        ["Group"] = function(Name, showName, Translation)
            local T = Translation and Translation or UE.FTransform()
            local actor = self:GetWorld():SpawnActor(LoadClass(self.class["Group"]), T,
                UE.ESpawnActorCollisionHandlingMethod.Default, self, self, "")
            actor.time = os.time()
            self:ActorInputMap(actor, Name, showName)
            return actor
        end,
        ["CAD"] = function()
            if self.cad then
                self.cad:K2_DestroyActor()
            end
            if LoadClass(self.class["CAD"]) then
                self.cad = self:GetWorld():SpawnActor(LoadClass(self.class["CAD"]), UE.FTransform(),
                    UE.ESpawnActorCollisionHandlingMethod.Default, self, self)
                return self.cad
            end
        end,
        [1] = function(Name, control, Mesh, Transform, showName)
            -- 生成地板模型
            local actor = self.ModelCreate["Group"](Name, showName)
            actor:K2_AttachToActor(self.DIY, "", 0, 0, 0, true)
            actor.bhandle = false
            self.Actors:Add(Name, actor)
            Name = Name .. "Floor"
            local class = LoadClass(self.class[1])
            local actor = self:ModelCreateModel(Name, control, class, Transform, showName .. "画布")
            return actor
        end,
        -- 生成基础模型
        [2] = function(Name, control, Mesh, Transform, showName, ModelCategory)
            local class = LoadClass(self.class[2])
            local actor = self:ModelCreateModel(Name, control, class, Transform, showName, ModelCategory)
            actor.StaticMeshComponent:SetStaticMesh(Mesh)
            return actor
        end,
        -- 生成行业模型
        [3] = function(Name, control, Mesh, Transform, showName, ModelCategory)
            local class = LoadClass(self.class[3])
            local actor = self:ModelCreateModel(Name, control, class, Transform, showName, ModelCategory)
            actor.StaticMeshComponent:SetStaticMesh(Mesh)
            return actor
        end,
        -- 生成管道模型
        [4] = function(Name, control, Mesh, Transform, showName, ModelCategory)
            local class = LoadClass(self.class[4])
            local actor = self:ModelCreateModel(Name, control, class, Transform, showName, ModelCategory)
            return actor
        end,
        -- 生成墙模型
        [5] = function(Name, control, Mesh, Transform, showName, ModelCategory)
            local class = LoadClass(self.class[5])
            local actor = self:ModelCreateModel(Name, control, class, Transform, showName, ModelCategory)
            actor.Height = control.CurrentCH
            return actor
        end,
        -- 生成区域模型
        [6] = function(Name, control, Mesh, Transform, showName)
            local class = LoadClass(self.class[6])
            local actor = self:ModelCreateModel(Name, control, class, Transform, showName)
            return actor
        end,
        -- 生成sxx模型
        [7] = function(Name, control, Mesh, Transform, showName, ModelCategory)
            local class = LoadClass(self.class[7])
            local actor = self:ModelCreateModel(Name, control, class, Transform, showName, ModelCategory)
            return actor
        end,
        -- 生成标注模型
        [8] = function(Name, control, Mesh, Transform, showName)
            local class = LoadClass(self.class[8])
            local actor = self:ModelCreateBZ(Name, control, class, Transform, showName)
            return actor
        end,
        -- 生成垂直标注模型
        [9] = function(Name, control, Mesh, Transform, showName)
            local class = LoadClass(self.class[9])
            local actor = self:ModelCreateBZ(Name, control, class, Transform, showName)
            return actor
        end,
        -- 生成导入模型
        [10] = function(Name, control, Mesh, Transform, showName, ModelCategory)
            local class = LoadClass(self.class[10])
            local actor = self:ModelCreateModel(Name, control, class, Transform, showName, ModelCategory)
            return actor
        end,
        -- 生成信息标注模型
        [11] = function(Name, control, Mesh, Transform, showName)
            local class = LoadClass(self.class[11])
            local actor = self:ModelCreateModel(Name, control, class, Transform, showName)
            return actor
        end,
        -- 生成动画模型
        [12] = function(Name, control, Mesh, Transform, showName, ModelCategory)
            local class = LoadClass(self.class[12])
            local actor = self:ModelCreateModel(Name, control, class, Transform, showName, ModelCategory)
            actor.SkeletalMesh:SetSkeletalMeshAsset(Mesh)
            return actor
        end,
        -- 生成虚线模型
        [13] = function(Name, control, Mesh, Transform, showName, ModelCategory)
            local class = LoadClass(self.class[13])
            local actor = self:ModelCreateModel(Name, control, class, Transform, showName, ModelCategory)
            return actor
        end,
        [14] = function(Name, control, Mesh, Transform, showName, ModelCategory)
            local class = LoadClass(self.class[14])
            local actor = self:ModelCreateModel(Name, control, class, Transform, showName, ModelCategory)
            return actor
        end,
        [15] = function(Name, control, Mesh, Transform, showName, ModelCategory)
            local class = LoadClass(self.class[15])
            local actor = self:ModelCreateModel(Name, control, class, Transform, showName, ModelCategory)
            return actor
        end,
    }

    -- 模型取消选择时的操作
    self.ModelCancelSelect = {
        ["Multi"] = function(control)
            control.buildActor:Select(false)
            control.buildActor = nil
            self:DestroyGizmo()
        end,
        ["DIY"] = function(control)
        end,
        ["Group"] = function(control)
            control.buildActor = nil
            self:DestroyGizmo()
            self:ClearAllAroundLine()
        end,
        [1] = function(control)
            -- 地板取消选择时的操作
            -- TODO: Add specific logic for floor cancellation
        end,
        [2] = function(control)
            -- 基础模型取消选择时的操作
            control.buildActor.StaticMeshComponent:SetRenderCustomDepth(false)
            control.buildActor = nil
            self:DestroyGizmo()
            self:ClearCatch(true, control)
            self:ClearAllAroundLine()
        end,
        [3] = function(control)
            -- 行业模型取消选择时的操作
            control.buildActor.StaticMeshComponent:SetRenderCustomDepth(false)
            control.buildActor = nil
            self:DestroyGizmo()
            self:ClearCatch(true, control)
            self:ClearAllAroundLine()
        end,
        [4] = function(control)
            -- 管道模型取消选择时的操作
            self:SplineActorCancelSel(control)
        end,
        [5] = function(control)
            -- 墙模型取消选择时的操作
            self:SplineActorCancelSel(control)
        end,
        [6] = function(control)
            self:SplineActorCancelSel(control)
        end,
        [7] = function(control)
            self:SplineActorCancelSel(control)
        end,
        [8] = function(control)
            -- 区域模型取消选择时的操作
            control.buildActor:SetBZM()
            control.buildActor = nil
        end,
        [9] = function(control)
            -- 区域模型取消选择时的操作
            control.buildActor:SetM(2)
            control.buildActor = nil
        end,
        [10] = function(control)
            -- 基础模型取消选择时的操作
            control.buildActor.PMesh:SetRenderCustomDepth(false)
            control.buildActor = nil
            self:DestroyGizmo()
            self:ClearCatch(true, control)
            self:ClearAllAroundLine()
        end,
        [11] = function(control)
            -- 区域模型取消选择时的操作
            control.buildActor:SetMessageM()
            control.buildActor:SetMessageShow()
            control.buildActor = nil
            self:DestroyGizmo()
        end,
        [12] = function(control)
            -- 动画模型取消选择时的操作
            control.buildActor.SkeletalMesh:SetRenderCustomDepth(false)
            control.buildActor = nil
            self:DestroyGizmo()
            self:ClearCatch(true, control)
            self:ClearAllAroundLine()
        end,
        [13] = function(control)
            self:SplineActorCancelSel(control)
        end,
        [14] = function(control)
            self:SplineActorCancelSel(control)
        end,
        [15] = function(control)
            self:SplineActorCancelSel(control)
        end,
    }

    -- 模型选择时的操作
    self.ModelSelect = {
        ["Multi"] = function(actor, control)
            self:ModelClear(control)
            actor:Select(true)
            control.buildActor = actor
            self:CreateGizmo(actor)
        end,
        ["DIY"] = function(actor, control)
        end,
        ["Group"] = function(actor, control)
            if actor.bhandle then
                self:ModelClear(control)
                control.buildActor = actor
                if actor.bMove then
                    self:CreateGizmo(actor)
                end
                control.clickType = 1
            end
        end,
        [1] = function(actor, control)
            -- 选择地板模型时的操作
            self:ModelClear(control)
            control.clickType = 1
        end,
        [2] = function(actor, control)
            -- 选择基础模型时的操作
            self:ModelClear(control)
            actor.StaticMeshComponent:SetRenderCustomDepth(true)
            control.buildActor = actor
            if actor.bMove then
                self:CreateGizmo(actor)
                if control.bCatch then
                    self:CreateCatch(actor, true, control)
                end
            end
            self:BuildAllAroundLine(actor)
            control.clickType = 1
        end,
        [3] = function(actor, control)
            -- 选择行业模型时的操作
            self:ModelClear(control)
            actor.StaticMeshComponent:SetRenderCustomDepth(true)
            control.buildActor = actor
            if actor.bMove then
                self:CreateGizmo(actor)
                if control.bCatch then
                    self:CreateCatch(actor, true, control)
                end
            end
            self:BuildAllAroundLine(actor)
            control.clickType = 1
        end,
        [4] = function(actor, control)
            -- 选择管道模型时的操作
            self:SplineActorSel(actor, control)
        end,
        [5] = function(actor, control)
            self:SplineActorSel(actor, control)
        end,
        [6] = function(actor, control)
            self:SplineActorSel(actor, control)
        end,
        [7] = function(actor, control)
            -- 选择输送线模型时的操作
            self:SplineActorSel(actor, control)
        end,
        [8] = function(actor, control)
            if control.buildActor then
                self.ModelCancelSelect[control.buildActor.modelType](control)
            end
            control.buildActor = actor
            actor:SetM(2)
            control.clickType = 3
        end,
        [9] = function(actor, control)
            -- 选择输送线模型时的操作
            if control.buildActor then
                self.ModelCancelSelect[control.buildActor.modelType](control)
            end
            control.buildActor = actor
            actor:SetM(1)
            control.clickType = 3
        end,
        [10] = function(actor, control)
            self:ModelClear(control)
            actor.PMesh:SetRenderCustomDepth(true)
            control.buildActor = actor
            if actor.bMove then
                self:CreateGizmo(actor)
                if control.bCatch then
                    self:CreateCatch(actor, true, control)
                end
            end
            self:BuildAllAroundLine(actor)
            control.clickType = 1
        end,
        [11] = function(actor, control)
            self:ModelClear(control)
            control.buildActor = actor
            actor:SetM(2)
            actor.Widget:SetVisibility(true, true)
            if actor.bMove then
                self:CreateGizmo(actor)
            end
            control.clickType = 1
        end,
        [12] = function(actor, control)
            -- 动画模型取消选择时的操作
            self:ModelClear(control)
            actor.SkeletalMesh:SetRenderCustomDepth(true)
            control.buildActor = actor
            if actor.bMove then
                self:CreateGizmo(actor)
                if control.bCatch then
                    self:CreateCatch(actor, true, control)
                end
            end
            self:BuildAllAroundLine(actor)
            control.clickType = 1
        end,
        [13] = function(actor, control)
            self:SplineActorSel(actor, control)
        end,
        [14] = function(actor, control)
            self:SplineActorSel(actor, control)
        end,
        [15] = function(actor, control)
            self:SplineActorSel(actor, control)
        end,
    }

    -- 模型删除时的操作
    self.ModelDelete = {
        ["Multi"] = function(actor, control)
            actor:Delete(control)
            control.buildActor = nil
            self:DestroyGizmo()
        end,
        ["DIY"] = function(actor, control)
        end,
        ["Group"] = function(actor, control)
            -- if actor.bhandle then
            self:DestroyChildActors(actor)

            if actor == control.buildActor then
                self:ActorOutMap(actor, control)
                control.buildActor = nil
                self:DestroyGizmo()
                control:FloorDataToView()
            else
                self:ActorOutMap(actor)
            end
            -- end
        end,
        [1] = function(actor, control)
            -- 删除地板模型时的操作
        end,
        -- 删除基础模型、行业模型
        [2] = function(actor, control)
            self:DestroyActors(actor, control)
        end,
        [3] = function(actor, control)
            self:DestroyActors(actor, control)
        end,
        [4] = function(actor, control)
            -- 删除管道模型时的操作
            self:ClearPoints()
            self:DestroyActors(actor, control)
        end,
        [5] = function(actor, control)
            -- 删除墙模型时的操作
            self:ClearPoints()
            self:DestroyActors(actor, control)
        end,
        [6] = function(actor, control)
            -- 删除区域模型时的操作
            self:ClearPoints()
            self:DestroyActors(actor, control)
        end,
        [7] = function(actor, control)
            -- 删除输送线模型时的操作
            self:ClearPoints()
            self:DestroyActors(actor, control)
        end,
        [8] = function(actor, control)
            if actor == control.buildActor then
                control.buildActor = nil
            end
            self:ActorOutMap(actor, control)
        end,
        [9] = function(actor, control)
            if actor == control.buildActor then
                control.buildActor = nil
            end
            self:ActorOutMap(actor, control)
        end,
        [10] = function(actor, control)
            self:DestroyActors(actor, control)
        end,
        [11] = function(actor, control)
            self:DestroyActors(actor, control)
        end,
        [12] = function(actor, control)
            self:DestroyActors(actor, control)
        end,
        [13] = function(actor, control)
            self:ClearPoints()
            self:DestroyActors(actor, control)
        end,
        [14] = function(actor, control)
            self:ClearPoints()
            self:DestroyActors(actor, control)
        end,
        [15] = function(actor, control)
            self:ClearPoints()
            self:DestroyActors(actor, control)
        end,
    }

    -- 模型保存时的操作
    self.ModelSave = function(actor, table)
        local T = actor:ModelSave()
        if not T then
            return
        end
        for key, value in pairs(T) do
            table[key] = value
        end
    end


    -- 模型读取时的操作
    self.ModelLoad = function(actor, table, bUndo)
        actor:ModelLoad(table, bUndo)
    end

    -- 设置模型数据
    self.SetData = {
        ["DIY"] = function(actor, table)
        end,
        [8] = function(actor, table)
            -- 设置区域模型的相关数据
            actor:SetData(table)
        end,
        [9] = function(actor, table)
            -- 设置区域模型的相关数据
            actor:SetData(table)
        end,
        [13] = function(actor, table)
            actor:SetData(table)
        end,
        ["default"] = function(actor, table)
            local L = actor:SetData(table)
            if actor.clickType == 1 then
                if self.gizmo then
                    if table.T then
                        self.gizmo:K2_SetActorLocation(table.T.Translation, false, UE.FHitResult(), false)
                    else
                        self.gizmo:K2_SetActorLocation(actor:K2_GetActorLocation(), false, UE.FHitResult(), false)
                    end
                end
            elseif actor.clickType == 2 then
                return L
            elseif actor.clickType == 4 then
                if self.gizmo then
                    self.gizmo:K2_SetActorLocation(actor:K2_GetActorLocation(), false, UE.FHitResult(), false)
                end
            end
        end,
    }

    -- 获取模型数据
    self.GetData = {
        ["DIY"] = function(actor)
        end,
        ["Group"] = function(actor)
            return actor:GetData()
        end,
        [1] = function(actor, FloorInt)
            -- 获取地板模型的数据
            -- return actor:GetData(FloorInt)
        end,
        [6] = function(actor, CH, FH)
            -- 获取区域模型的数据
            return actor:GetData(FH)
        end,
        [8] = function(actor)
            -- 获取区域模型的数据
            return actor:GetData()
        end,
        [9] = function(actor)
            -- 获取区域模型的数据
            return actor:GetData()
        end,
        ["default"] = function(actor)
            -- 剩余的模型数据
            return actor:GetData()
        end,
    }
end

-- 激活动画表
function M:AnimeFunction()
    self.animeTypeTable = {
        self.class[7],
        self.class[15],
        self.class[4],
        ["animeModel"] = self.class[12]
    }
end

-- 查找动画
function M:FindAnime(animationCode)
    if self.AnimeDatas:Find(animationCode) then
        return self.AnimeDatas:Find(animationCode).url
    end
    return nil
end

function M:SplineActorCancelSel(control)
    if control.buildActor.modelType ~= 7 then
        control.buildActor.PMesh:SetRenderCustomDepth(false)
    else
        for key, value in pairs(control.buildActor.SPMCs) do
            if value then
                value:SetRenderCustomDepth(false)
            end
        end
    end
    control:RemoveSplineMenu()
    self:ClearPoints()

    control.buildActor = nil
    self:DestroyGizmo()
    self:ClearAllAroundLine()
end

function M:SplineActorSel(actor, control)
    self:ModelClear(control)
    control.buildActor = actor
    local A
    actor.currentPoint = 1
    if actor.bOverall or not actor.bMove then
        A = actor
        if actor.modelType ~= 7 then
            actor.PMesh:SetRenderCustomDepth(true)
        else
            for key, value in pairs(actor.SPMCs) do
                if value then
                    value:SetRenderCustomDepth(true)
                end
            end
        end
    else
        self:BuildPoint(actor.simplePoints)
        A = self.NubPoints:Find(1)
    end
    -- self:BuildAllAroundLine(actor)
    if actor.bMove then
        self:CreateGizmo(A)
    end
    control.clickType = 2
end

function M:FindActor(name, bActors)
    if not name or name == "" then
        return nil
    end
    if self.drawMode == "RegionInner" and not bActors then
        -- RegionInner 模式下，优先限制在区域内 Actor 集合里查找
        -- 但像 Floor/画布/一些全局辅助对象通常不属于区域内集合，否则会导致“找不到地板”等基础依赖
        local actor = self.RegionInnerActors and self.RegionInnerActors:Find(name) or nil
        if actor then
            return actor
        end
        if tostring(name) == "1" or name == "DIY" or string.find(name, "Floor") ~= nil
            or string.find(name, "BZ") ~= nil then
            return self.Actors:Find(name)
        end
    else
        return self.Actors:Find(name)
    end
end

function M:DestroyGizmo()
    if self.gizmo then
        self.gizmo:K2_DestroyActor()
        self.gizmo = nil
    end
end

function M:CreateGizmo(actor)
    self:DestroyGizmo()

    local Transform = actor:GetTransform()
    self.gizmo = self:GetWorld():SpawnActor(LoadClass("/Game/RuntimeGizmo/Blueprints/BP_Gizmo.BP_Gizmo_C"),
        Transform,
        UE.ESpawnActorCollisionHandlingMethod.Default, self, self, "")
    local control = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(),
        LoadClass(Class.control))
    if control then
        self.gizmo.ClickGizmo:Add(control, control.TrackGizmo)
    end
    self.gizmo:AttachGizmo(actor)
    print(Transform, self.gizmo:GetTransform())
    self:GizmoMode()
end

function M:GizmoMode()
    if self.gizmo then
        local pawnClass = LoadClass(Class.hyPawn)
        local pawn = UE.UGameplayStatics.GetPlayerPawn(self:GetWorld(), 0):Cast(pawnClass)
        self.gizmo.TranslateRoot:SetVisibility(true, true)
        if pawn.Camera.ProjectionMode == 1 then
            local rotate = pawn:K2_GetActorRotation()
            if rotate.Pitch < -84 then
                self.gizmo.ArrowZ:SetVisibility(false, true)
                self.gizmo.PlaneX:SetVisibility(false, true)
                self.gizmo.PlaneY:SetVisibility(false, true)
            elseif (rotate.Yaw < -85 and rotate.Yaw > -95) or (rotate.Yaw > 85 and rotate.Yaw < 95) then
                self.gizmo.ArrowY:SetVisibility(false, true)
                self.gizmo.PlaneX:SetVisibility(false, true)
                self.gizmo.PlaneZ:SetVisibility(false, true)
            elseif (rotate.Yaw < 5 and rotate.Yaw > 5) or (rotate.Yaw > -185 and rotate.Yaw < -175) then
                self.gizmo.ArrowX:SetVisibility(false, true)
                self.gizmo.PlaneY:SetVisibility(false, true)
                self.gizmo.PlaneZ:SetVisibility(false, true)
            end
        end
    end
end

-- 会进行一次判断确认有无清除选中
function M:ModelClear(control)
    if control.buildActor then
        self.ModelCancelSelect[control.buildActor.modelType](control)
    end
end

-- 生成模型函数
function M:ModelCreateModel(Name, control, Class, Transform, showName, ModelCategory)
    -- 如果没有传递 Transform 参数，则使用默认的 UE.FTransform()
    Transform = Transform or UE.FTransform()

    self:ModelClear(control)

    -- 在世界中生成一个 AActor
    local ParentActor = self.ModelCreate["Group"](Name, showName)
    ParentActor.ModelCategory = ModelCategory
    -- 将 ParentActor 附加到 actor 中指定的父级上
    ParentActor:K2_AttachToActor(self:FindActor(control.currentFloor), "", 0, 0, 0, true)

    -- 在世界中生成指定类的 actor
    local actor = self:GetWorld():SpawnActor(Class, Transform, UE.ESpawnActorCollisionHandlingMethod.Default, self,
        self, "")
    actor.ModelCategory = ModelCategory
    -- 为生成的 actor 设置名称

    -- 将生成的 actor 附加到 ParentActor 上
    actor:K2_AttachToActor(ParentActor, "", 0, 0, 0, true)

    self:ActorInputMap(actor, Name .. "-s", showName, control)

    actor.modelManage = self

    -- 将生成的 actor 添加到 Actors 列表中

    if string.find(showName, "画布") then
        ParentActor.bhandle = false
    end

    if not actor.time then
        actor.time = os.time()
    end

    -- 返回生成的 actor
    return actor
end

-- 读取数据还原模型
function M:DataCreateModel(dataTable)
    local size
    if type(dataTable.size) == "string" then
        local sizeObj = UE.UJsonLibraryHelpers.Parse(dataTable.size)
        size = UE.UJsonLibraryHelpers.ToTransform(sizeObj)
        if math.abs(size.Translation.X) > 1e+16 then
            size.Translation = UE.FVector(0, 0, 0)
        end
    else
        size = dataTable.Size
    end
    if dataTable.Type == nil then
        if dataTable.modelName == "DIY" then
            dataTable.Type = "DIY"
        else
            dataTable.Type = "Group"
        end
    end
    print(size, "size")
    -- print(self.class[dataTable.modelType], "DataCreateModel,LoadClass")
    local actor = self:GetWorld():SpawnActor(LoadClass(self.class[dataTable.Type]), size,
        UE.ESpawnActorCollisionHandlingMethod.Default, self, self, "")
    if actor.modelType == "CAD" then
        self.cad = actor
        goto continue
    end
    self:ActorInputMap(actor, dataTable.modelName, dataTable.showName)
    if dataTable.parent then
        local FActor = self.Actors:Find(dataTable.parent)
        if not FActor and dataTable.parentData then
            local p = dataTable.parentData
            FActor = self.ModelCreate["Group"](p.modelName, p.showName, p.Size)
            FActor.relatedId = dataTable.parentData.relatedId
            FActor.relatedCode = dataTable.parentData.relatedCode
            FActor.ModelCategory = dataTable.parentData.modelCategoryCode
            self.ModelLoad(FActor, dataTable)
            if dataTable.parentData.parent == "" then
                FActor:K2_AttachToActor(self.Actors:Find(1), "", 1, 1, 1, true)
            else
                local PPA = self.Actors:Find(dataTable.parentData.parent)
                if PPA then
                    FActor:K2_AttachToActor(PPA, "", 1, 1, 1, true)
                else
                    FActor:K2_AttachToActor(self.Actors:Find(1), "", 1, 1, 1, true)
                end
            end
        end
        actor:K2_AttachToActor(FActor, "", 1, 1, 1, true)
    end

    ::continue::

    actor.relatedId = dataTable.relatedId
    actor.relatedCode = dataTable.relatedCode
    actor.ModelCategory = dataTable.modelCategoryCode

    actor.bhandle = dataTable.handle
    actor.bMove = dataTable.Move
    actor.time = dataTable.time
    actor.modelManage = self.modelManage
    self.ModelLoad(actor, dataTable)
    local MeshLoad = self.MeshDatas:Find(actor.modelCode)
    if MeshLoad then
        if actor:Cast(LoadClass(self.class[2])) then
            actor.StaticMeshComponent:SetStaticMesh(LoadObject(MeshLoad.Mesh))
        elseif actor:Cast(LoadClass(self.class[12])) then
            actor.SkeletalMesh:SetSkeletalMeshAsset(LoadObject(MeshLoad.Mesh))
        end
    end
    self:ActorMat(actor)
    return actor
end

function M:ActorMat(actor)
    if actor.materialCode then
        actor:SetDynamicMaterial()
    end
end

function M:ActorInputMap(actor, name, showName, control)
    Model.SetActorName(actor, name, showName)
    self.ShowNames:Add(showName)
    self.Actors:Add(name, actor)

    -- RegionInner 模式：如果模型在区域内，则同时注册到 RegionInnerActors
    if self.drawMode == "RegionInner" then
        self.RegionInnerActors:Add(name, actor)
    end

    if control then
        control:TreeDataOut()
    end
end

function M:ActorOutMap(actor, control)
    local Name = Model.GetActorAccurateDisplayName(actor)
    self.Actors:Remove(Name)
    if actor.showName then
        self.ShowNames:RemoveItem(actor.showName)
    end

    -- RegionInner 模式：同步从 RegionInnerActors 中移除（注意大小写要与其它判断保持一致）
    if self.drawMode == "RegionInner" and self.RegionInnerActors then
        self.RegionInnerActors:Remove(Name)
    end

    actor:K2_DestroyActor()
    if control then
        control:TreeDataOut()
    end
end

function M:ActorShowNameChange(actor, showName, oldName)
    if actor then
        if actor.showName then
            self.ShowNames:RemoveItem(actor.showName)
            actor.showName = showName
            self.ShowNames:Add(showName)
        end
    else
        self.ShowNames:RemoveItem(oldName)
        self.ShowNames:Add(showName)
    end
end

-- 生成标注与垂直标注
function M:ModelCreateBZ(Name, control, Class, Transform, showName)
    -- 如果没有传递 Transform 参数，则使用默认的 UE.FTransform()
    Transform = Transform or UE.FTransform()
    self:ModelClear(control)
    local BZP = self:FindActor(control.currentFloor .. "BZ")
    if not BZP then
        local ParentActor = self:GetWorld():SpawnActor(LoadClass(self.class["Group"]), UE.FTransform(),
            UE.ESpawnActorCollisionHandlingMethod.Default, self, self, "")
        ParentActor:K2_AttachToActor(self:FindActor(control.currentFloor), "", 0, 0, 0, true)
        self:ActorInputMap(ParentActor, control.currentFloor .. "BZ", "标注")
        BZP = ParentActor
    end
    -- 在世界中生成指定类的 actor
    local actor = self:GetWorld():SpawnActor(Class, Transform, UE.ESpawnActorCollisionHandlingMethod.Default, self,
        self, "")
    -- 将生成的 actor 附加到 BZP 上
    actor:K2_AttachToActor(BZP, "", 0, 0, 0, true)
    self:ActorInputMap(actor, Name, showName, control)
    actor.modelManage = self
    -- 返回生成的 actor
    return actor
end

-- 销毁模型
function M:DestroyActors(actor, control)
    local P = actor:GetAttachParentActor()

    self:DestroyChildActors(actor)

    if control and actor == control.buildActor then
        control.buildActor = nil
        self:ClearAllAroundLine()
    end

    self:ActorOutMap(actor)

    if P:GetAttachedActors():Num() == 0 then
        -- 销毁父级和当前 actor
        self:ActorOutMap(P)
    end

    if control and control.buildActor == nil then
        -- 如果有 gizmo（Build Placement Ghost），也销毁它
        self:DestroyGizmo()
        self:ClearCatch(true, control)
        control:FloorDataToView()
    end
end

-- 销毁子集模型
function M:DestroyChildActors(actor)
    local Childs = actor:GetAttachedActors()
    if Childs:Num() > 0 then
        for key, value in pairs(Childs) do
            self:DestroyChildActors(value)
            self:ActorOutMap(value)
        end
    end
end

-- 下载模型回显
function M:LoadDownloadModel(path)
    local DownloadModels = UE.UGameplayStatics.GetAllActorsOfClass(self:GetWorld(), LoadClass(self.class[10]))
    for _, value in pairs(DownloadModels) do
        if value.path == path then
            value:LoadModel()
        end
    end
end

-- 清除线性控制点位
function M:ClearPoints()
    if self.NubPoints:Num() > 0 then
        for key, value in pairs(self.NubPoints) do
            value:K2_DestroyActor()
            self.NubPoints:Remove(key)
        end
        for key, value in pairs(self.SplineBZs) do
            value:K2_DestroyActor()
        end
        self:ClearPointBZs()
    end
    self:ClearShowArea()
end

-- 创建线性控制点位
function M:BuildPoint(points, actorOverride)
    -- 创建点位

    self:ClearPoints()
    local int = points:Num()
    local control = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(),
        LoadClass(Class.control))
    -- 在区域协作（RegionArea）等模式下，control.buildActor 可能为空，这里允许显式传入当前 actor
    local buildActor = actorOverride or (control and control.buildActor)
    for i = 1, int do
        local T = UE.FTransform()
        T.Translation = points[i]

        local point = self:GetWorld():SpawnActor(LoadClass(Class.point), T,
            UE.ESpawnActorCollisionHandlingMethod.Default, self, self, "")
        point:SetKey(i, control)
        self.NubPoints:Add(i, point)
        point.Spline = self
        if i > 1 then
            point.LastPoint = self.NubPoints:Find(i - 1)
            point:ShowData()
            self:BuildPointBZ(point, control)
        end
    end
    local P1 = self.NubPoints:Find(1)
    P1.LastPoint = self.NubPoints:Find(int)
    P1:ShowData()
    if not control.bBuild then
        self:BuildPointBZ(P1, control)
    end

    if int > 2 then
        local l1 = points[1]
        local LQ = points[int - 1]
        local LC = points[int]
        local NQC = LQ - LC
        NQC.Z = 0
        NQC:Normalize()
        local NC1 = LC - l1
        NC1.Z = 0
        NC1:Normalize()
        if math.abs(math.abs(NQC.Y) - 1) == 0 then
            self.NubPoints:Find(int):SetM(2)
            points[int] = UE.FVector(LQ.X, LC.Y, LC.Z)
            self.NubPoints:Find(int):K2_SetActorLocation(points[int], false, UE.FHitResult(), false)
        elseif math.abs(math.abs(NQC.X) - 1) == 0 then
            self.NubPoints:Find(int):SetM(2)
            points[int] = UE.FVector(LC.X, LQ.Y, LC.Z)
            self.NubPoints:Find(int):K2_SetActorLocation(points[int], false, UE.FHitResult(), false)
        end
        if math.abs(math.abs(NC1.Y) - 1) == 0 then
            self.NubPoints:Find(int):SetM(2)
            points[int] = UE.FVector(l1.X, LC.Y, LC.Z)
            self.NubPoints:Find(int):K2_SetActorLocation(points[int], false, UE.FHitResult(), false)
        elseif math.abs(math.abs(NC1.X) - 1) == 0 then
            self.NubPoints:Find(int):SetM(2)
            points[int] = UE.FVector(LC.X, l1.Y, LC.Z)
            self.NubPoints:Find(int):K2_SetActorLocation(points[int], false, UE.FHitResult(), false)
        end
    end

    if buildActor and buildActor.modelType == 6 then
        self:BuildShowArea(buildActor)
    end
end

-- 清除点位与线性标注
function M:ClearPointBZs()
    for key, value in pairs(self.SplineBZs) do
        value:K2_DestroyActor()
    end
    self.SplineBZs:Clear()
end

-- 创建点位与线性标注
function M:BuildPointBZ(Point, control)
    local BZT = UE.FTransform()
    BZT.Translation = Point.LastPoint:K2_GetActorLocation()
    local SplineBZ = self:GetWorld():SpawnActor(
        LoadClass('/Game/SandBox/Blueprints/AuxiliaryModel/BP_SplineBZ.BP_SplineBZ_C'), BZT,
        UE.ESpawnActorCollisionHandlingMethod.Default, self, self, "")
    local ModelRadius = 100.0
    if self.drawMode ~= "RegionArea" then
        if control.buildActor.modelType == 4 then
            ModelRadius = ModelRadius + control.buildActor.radius
        elseif control.buildActor.modelType == 5 then
            ModelRadius = ModelRadius + control.buildActor.thickness / 2
        elseif control.buildActor.modelType == 7 then
            ModelRadius = ModelRadius + control.buildActor.ssdWitch / 2
        end
    end
    SplineBZ:SetSplineBZ(Point, control, ModelRadius)
    self.SplineBZs:Add(SplineBZ)
end

-- 创建四周线：为选中的 actor 生成四向对齐参考线及吸附提示
function M:BuildAllAroundLine(actor)
    -- 先清除旧参考线
    self:ClearAllAroundLine()

    -- 仅对基础/行业/导入/动画模型先做额外包围盒检测（TraceOtherModel）
    local bBox = false
    if actor.modelType == 2 or actor.modelType == 3 or actor.modelType == 10 or actor.modelType == 12 then
        bBox = actor:TraceOtherModel(false)
    end


    -- 若未命中其他模型，则继续生成四向参考线
    if not bBox then
        -- 获取 actor 的真实包围盒
        local origin, boxExtent
        if actor.modelType == 10 then
            origin, boxExtent = actor:GetModelBounds()
        else
            origin, boxExtent = actor:GetActorBounds(true)
        end

        -- 计算四向检测所需的参数
        local detectionParams = self:CalculateDetectionParams(origin, boxExtent)

        -- 加载参考线 actor 类和获取主控制器
        local selectBZClass = LoadClass('/Game/SandBox/Blueprints/AuxiliaryModel/BP_SelectBZ.BP_SelectBZ_C')
        local control = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(), LoadClass(Class.control))

        -- 组装忽略列表和更新参考线生成位置
        local actorsToIgnore = self:BuildActorsToIgnoreAndUpdateCreateT(actor, control, origin, boxExtent,
            detectionParams)

        -- 依次进行四向检测
        local alignLineTable = self:PerformFourDirectionDetection(actor, detectionParams, selectBZClass, control,
            actorsToIgnore)

        -- 若四向中任意两边对齐，则最终整体吸附到交点
        self:PerformFinalAlignment(actor, alignLineTable)
    end
end

-- 计算四向检测所需的参数
function M:CalculateDetectionParams(origin, boxExtent)
    local params = {}

    -- 四向检测起点（向内偏移 10，避免自碰撞）
    params.startTable = {
        UE.FVector(origin.X - boxExtent.X + 10, origin.Y, origin.Z),
        UE.FVector(origin.X, origin.Y + boxExtent.Y - 10, origin.Z),
        UE.FVector(origin.X + boxExtent.X - 10, origin.Y, origin.Z),
        UE.FVector(origin.X, origin.Y - boxExtent.Y + 10, origin.Z)
    }

    -- 四向检测终点（向外延伸 10000）
    params.endTable = {
        UE.FVector(origin.X - boxExtent.X - 10000, origin.Y, origin.Z),
        UE.FVector(origin.X, origin.Y + boxExtent.Y + 10000, origin.Z),
        UE.FVector(origin.X + boxExtent.X + 10000, origin.Y, origin.Z),
        UE.FVector(origin.X, origin.Y - boxExtent.Y - 10000, origin.Z)
    }

    -- 四向 BoxTrace 的半尺寸（厚度 5，高度取包围盒 Z）
    params.sizeTable = {
        UE.FVector(0, boxExtent.Y - 5, boxExtent.Z),
        UE.FVector(boxExtent.X - 5, 0, boxExtent.Z),
        UE.FVector(0, boxExtent.Y - 5, boxExtent.Z),
        UE.FVector(boxExtent.X - 5, 0, boxExtent.Z)
    }

    -- 四向法线（用于后续对齐判定）
    params.normalTable = {
        UE.FVector(1, 0, 0),
        UE.FVector(0, -1, 0),
        UE.FVector(-1, 0, 0),
        UE.FVector(0, 1, 0)
    }

    -- 参考线 actor 的生成位置（底部四角）
    params.createTable = {
        UE.FVector(origin.X - boxExtent.X, origin.Y, origin.Z - boxExtent.Z),
        UE.FVector(origin.X, origin.Y + boxExtent.Y, origin.Z - boxExtent.Z),
        UE.FVector(origin.X + boxExtent.X, origin.Y, origin.Z - boxExtent.Z),
        UE.FVector(origin.X, origin.Y - boxExtent.Y, origin.Z - boxExtent.Z)
    }

    return params
end

-- 组装忽略列表和更新参考线生成位置
function M:BuildActorsToIgnoreAndUpdateCreateT(actor, control, origin, boxExtent, params)
    local actorsToIgnore = UE.TArray(UE.AActor)
    actorsToIgnore:Add(actor)

    if control.buildActor.clickType == 2 then
        actorsToIgnore:Add(control.buildActor)
        for k, v in pairs(self.NubPoints) do
            actorsToIgnore:Add(v)
        end
        -- 编辑点模式下，参考线生成位置统一到 actor 中心，避免错位
        params.createTable = { origin, origin, origin, origin }
    end

    -- 检测底部是否存在区域模型，并将其加入排除数组
    local hitResult = UE.FHitResult()
    local startPos, endPos = UE.FVector(), UE.FVector()
    if control.buildActor.clickType == 1 then
        startPos = UE.FVector(origin.X, origin.Y, origin.Z)
        endPos = UE.FVector(startPos.X, startPos.Y, startPos.Z - boxExtent.Z - 100)
    elseif control.buildActor.clickType == 2 then
        startPos = actor:K2_GetActorLocation()
        endPos = UE.FVector(startPos.X, startPos.Y, startPos.Z - 100) -- 向下检测100个单位
    end


    -- 使用LineTrace检测底部区域模型
    UE.UKismetSystemLibrary.LineTraceSingle(
        self:GetWorld(),
        startPos, endPos,
        UE.ETraceTypeQuery.Floor,
        false, actorsToIgnore, 0,
        hitResult, true
    )

    -- 如果检测到区域模型（modelType == 6），则加入排除数组
    local hitActor = hitResult.HitObjectHandle.actor
    if hitActor then
        if hitActor and hitActor.modelType == 6 then
            actorsToIgnore:Add(hitActor)
        end
    end

    return actorsToIgnore
end

-- 检查命中的 actor 是否有效
function M:IsValidHitActor(hitActor)
    if hitActor.clickType == 1 then
        local hasStaticMesh = hitActor.StaticMeshComponent and hitActor.StaticMeshComponent.StaticMesh
        local hasSkeletalMesh = hitActor.SkeletalMesh and hitActor.SkeletalMesh.SkeletalMesh
        local hasProceduralMesh = hitActor.PMesh and hitActor.PMesh:GetNumSections() > 0
        return (hasStaticMesh or hasSkeletalMesh or hasProceduralMesh)
    end
    return true -- 非 clickType==1 的 actor 默认有效
end

-- 计算吸附位置
function M:CalculateSnapPosition(directionIndex, position, hitActor)
    local originAlign, boxAlign = hitActor:GetActorBounds(true)

    if hitActor.clickType == 1 then
        if directionIndex == 1 then
            position.X = originAlign.X + boxAlign.X
        elseif directionIndex == 2 then
            position.Y = originAlign.Y - boxAlign.Y
        elseif directionIndex == 3 then
            position.X = originAlign.X - boxAlign.X
        elseif directionIndex == 4 then
            position.Y = originAlign.Y + boxAlign.Y
        end
    end

    return position, originAlign
end

-- 判定是否对齐
function M:IsAligned(directionIndex, position, originAlign)
    local normalAlign = UE.FVector(position.X - originAlign.X, position.Y - originAlign.Y, 0)
    local bAlign = false

    if math.abs(normalAlign.X) < 3 and (directionIndex == 2 or directionIndex == 4) then
        bAlign = true
    elseif math.abs(normalAlign.Y) < 3 and (directionIndex == 1 or directionIndex == 3) then
        bAlign = true
    end

    return bAlign
end

-- 计算自动吸附的位移
function M:CalculateAutoSnapOffset(directionIndex, distance)
    local offsetPosition = UE.FVector(0, 0, 0)

    if directionIndex == 1 then
        offsetPosition.X = -distance
    elseif directionIndex == 2 then
        offsetPosition.Y = distance
    elseif directionIndex == 3 then
        offsetPosition.X = distance
    elseif directionIndex == 4 then
        offsetPosition.Y = -distance
    end

    return offsetPosition
end

-- 依次进行四向检测
function M:PerformFourDirectionDetection(actor, params, selectBZClass, control, actorsToIgnore)
    local alignLineTable = {}

    for i = 1, 4 do
        local hitResult = UE.FHitResult()

        -- BoxTraceSingle：检测 sizeTable[i] 范围内首个 Model 通道物体
        local bTrace = UE.UKismetSystemLibrary.BoxTraceSingle(
            self:GetWorld(),
            params.startTable[i], params.endTable[i],
            params.sizeTable[i], UE.FRotator(0, 0, 0),
            UE.ETraceTypeQuery.Model,
            false, actorsToIgnore, 0,
            hitResult, true
        )

        if bTrace then
            local hitActor = hitResult.HitObjectHandle.actor
            -- print(hitActor.modelType)

            -- 检查命中的 actor 是否有效
            if not self:IsValidHitActor(hitActor) then
                return alignLineTable -- 无效目标，提前返回
            end

            -- 生成参考线 actor
            local transform = UE.FTransform()
            if params.createTable[i].Z <= 0 then
                params.createTable[i].Z = 2 -- 保证在地表之上
            end
            transform.Translation = params.createTable[i]
            local selectBZ = self:GetWorld():SpawnActor(
                selectBZClass, transform,
                UE.ESpawnActorCollisionHandlingMethod.Default,
                self, self
            )

            -- 计算碰撞点坐标（Z 统一用参考高度）
            local position = UE.FVector(hitResult.Location.X, hitResult.Location.Y, params.createTable[i].Z)
            local originAlign = UE.FVector(0, 0, 0)

            -- 计算吸附位置
            position, originAlign = self:CalculateSnapPosition(i, position, hitActor)

            -- 判定是否对齐
            local bAlign = self:IsAligned(i, position, originAlign)

            -- 设置参考线数据并记录
            local distance = selectBZ:SetSelectBZ(position, control, params.normalTable[i], bAlign, actor)
            self.SelectBZs:Add(selectBZ)

            -- 若出现对齐，记录对方中心供最后整体吸附
            if bAlign then
                alignLineTable[i] = originAlign
            end

            -- 若开启自动吸附（bBuild）且当前 actor 为基础/行业模型，则实时移动
            if distance and control.bBuild and (actor.modelType == 2 or actor.modelType == 3) then
                local offsetPosition = self:CalculateAutoSnapOffset(i, distance)
                -- print(position, os.clock()) -- 调试用：打印移动时的时间戳
                actor:K2_AddActorWorldOffset(offsetPosition, false, nil, false)
            end
        end
    end

    return alignLineTable
end

-- 执行最终对齐操作
function M:PerformFinalAlignment(actor, alignLineTable)
    if next(alignLineTable) and (actor.modelType == 2 or actor.modelType == 3) then
        local position = actor:K2_GetActorLocation()

        -- 处理 Y 轴对齐
        if alignLineTable[1] then
            position = UE.FVector(position.X, alignLineTable[1].Y, position.Z)
        elseif alignLineTable[3] then
            position = UE.FVector(position.X, alignLineTable[3].Y, position.Z)
        end

        -- 处理 X 轴对齐
        if alignLineTable[2] then
            position = UE.FVector(alignLineTable[2].X, position.Y, position.Z)
        elseif alignLineTable[4] then
            position = UE.FVector(alignLineTable[4].X, position.Y, position.Z)
        end

        actor:K2_SetActorLocation(position, false, nil, false)
    end
end

-- 清除四周线
function M:ClearAllAroundLine()
    if self.SelectBZs:Num() > 0 then
        for key, value in pairs(self.SelectBZs) do
            value:K2_DestroyActor()
        end
        self.SelectBZs:Clear()
    end
end

-- 清除面积展示
function M:BuildShowArea(actor)
    if actor.modelType ~= 6 then
        return
    end
    self:ClearShowArea()
    local o = UE.FVector(0, 0, 0)
    for k, v in pairs(actor.simplePoints) do
        o = UE.UKismetMathLibrary.Add_VectorVector(o, v)
    end
    o = o / actor.simplePoints:Num()
    o.Z = actor.thickness + 30
    local t = UE.FTransform()
    t.Translation = o
    local showAreaClass = LoadClass(Class.area)
    if showAreaClass then
        self.showArea = self:GetWorld():SpawnActor(showAreaClass, t, UE.ESpawnActorCollisionHandlingMethod.Default, self,
            self, "SandBox.Blueprints.AuxiliaryModel.BP_ShowArea")
        self.showArea:SetArea(actor)
    end
end

-- 生成面积展示
function M:ClearShowArea()
    if self.showArea then
        self.showArea:K2_DestroyActor()
        self.showArea = nil
    end
end

-- 生成标注吸附动态提示点
function M:CreatePointTip(L, Nub)
    self:ClearPointTip()
    local T = UE.FTransform()
    T.Translation = L
    local pClass = LoadClass(Class.pointTip)
    if pClass then
        self.P = self:GetWorld():SpawnActor(pClass, T,
            UE.ESpawnActorCollisionHandlingMethod.Default, self, self, "")
        self.P:SetM(Nub)
    end
end

-- 删除标注吸附动态提示点
function M:ClearPointTip()
    if self.P then
        self.P:K2_DestroyActor()
        self.P = nil
    end
end

-- 生成捕捉辅助模型
function M:CreateCatch(actor, bActive, control, Z)
    local origin, box = actor:GetActorBounds(true)
    if Z ~= nil and Z >= box.Z and control.bZ then
        self.t = UE.FTransform()
        self.l = UE.FVector(origin.X, origin.Y, origin.Z + box.Z)
    else
        self.t = UE.FTransform()
        self.l = UE.FVector(origin.X, origin.Y, origin.Z - box.Z)
    end
    -- local t = UE.FTransform()
    -- local l = UE.FVector(origin.X, origin.Y, origin.Z - box.Z)
    self.l.z = self.l.z > 0 and self.l.z or 0
    self.t.Translation = self.l
    local catch = self:GetWorld():SpawnActor(
        LoadClass('/Game/SandBox/Blueprints/AuxiliaryModel/BP_Catch.BP_Catch_C'),
        self.t, UE.ESpawnActorCollisionHandlingMethod.Default, self, self, "")
    catch:SetCatch(actor)
    if bActive then
        self.catch = catch
        control.ui:ShowModelTip("", "点击黄点进入点位捕捉模式")
    else
        self.Catchs:Add(catch)
    end
end

-- 清除捕捉辅助模型
function M:ClearCatch(bActive, control)
    if bActive then
        if self.catch then
            self.catch:K2_DestroyActor()
            self.catch = nil
            control.ui:ModelTipHide()
        end
    end
    for key, value in pairs(self.Catchs) do
        value:K2_DestroyActor()
    end
    self.Catchs:Clear()
end

-- 生成捕捉辅助框模型
function M:CreateBorder(actor, hitResult)
    self:ClearBorder()
    self.border = self:GetWorld():SpawnActor(
        LoadClass('/Game/SandBox/Blueprints/AuxiliaryModel/BP_Border.BP_Border_C'),
        self.t, UE.ESpawnActorCollisionHandlingMethod.Default, self, self, "")
    self.border:SetModel(actor, hitResult)
end

-- 清除捕捉辅助框模型
function M:ClearBorder()
    if self.border then
        self.border:K2_DestroyActor()
        self.border = nil
    end
end

-- 获取场景中除地板模型外的静态网格体模型数量
function M:GetModelNum()
    -- 某些加载/初始化流程中（例如 NewLoadPlan/LoadLocalData），DIY 可能尚未创建或尚未回填，
    -- 这里做一次兜底，确保不因 nil 崩溃（该函数不分模式都应可用）。
    if not self.DIY or not UE.UKismetSystemLibrary.IsValid(self.DIY) then
        if self.FindActor then
            self.DIY = self:FindActor("DIY")
        end
        if (not self.DIY or not UE.UKismetSystemLibrary.IsValid(self.DIY)) and self.ModelCreate and self.ModelCreate["DIY"] then
            self.ModelCreate["DIY"]()
        end
        if not self.DIY or not UE.UKismetSystemLibrary.IsValid(self.DIY) then
            print("GetModelNum: DIY 未初始化，返回 0")
            return 0
        end
    end

    local actors = UE.TArray(UE.AActor)
    self.DIY:GetAttachedActors(actors, true, true)
    local num = 0
    -- for _, v in pairs(actors) do
    for i = 1, actors:Num() do
        local v = actors[i]
        if v:Cast(UE.AStaticMeshActor) and v.modelType ~= 1 then
            num = num + 1
        end
    end
    print("场景模型数量", num)
    return num
end

-- 导出规划数据的函数，当前为空实现
function M:ExportPlanDataToCad()
    local planData = {
        Model = {},
        Passage = {},
        Area = {},
        Pipeline = {},
        MessageBZ = {},
        VerticalBZ = {},
        SizeBZ = {},
        Wall = {},
        DashedLine = {},
        SAGC = {},
        ImportModel = {},
        SSX = {},
        Path = {},
    }

    -- 与 GetModelNum 同步兜底：避免 DIY 未初始化导致导出崩溃
    if not self.DIY or not UE.UKismetSystemLibrary.IsValid(self.DIY) then
        if self.FindActor then
            self.DIY = self:FindActor("DIY")
        end
        if (not self.DIY or not UE.UKismetSystemLibrary.IsValid(self.DIY)) and self.ModelCreate and self.ModelCreate["DIY"] then
            self.ModelCreate["DIY"]()
        end
        if not self.DIY or not UE.UKismetSystemLibrary.IsValid(self.DIY) then
            print("ExportPlanDataToCad: DIY 未初始化，返回空数据")
            return planData
        end
    end

    local actors = UE.TArray(UE.AActor)
    self.DIY:GetAttachedActors(actors, true, true)
    for _, v in pairs(actors) do
        if v then
            self:GetCadData(v, planData)
        end
    end
    return planData
end

function M:GetCadData(actor, cadData)
    local function GetModelCadData(actor)
        local data = actor:ModelSave()
        local origin, _ = actor:GetActorBounds(false)
        local boxSize = DFL.toVector(data["BSize"])
        local cadData = {
            Name = actor:GetAttachParentActor().showName,
            Type = data.ModelCode,
            Location = { origin.X, origin.Y, origin.Z },
            BoxSize = { boxSize.X / 2, boxSize.Y / 2, boxSize.Z / 2 },
            Rotation = actor:K2_GetActorRotation().Yaw,
            Scale = { actor:GetActorScale3D().X, actor:GetActorScale3D().Y, actor:GetActorScale3D().Z }
        }
        return cadData
    end

    local function GetSplineCadData(actor)
        local width = 0.0
        if actor.modelType == 4 then
            width = actor.pipeType == 1 and (actor.radius * 2) or actor.width
        elseif actor.modelType == 5 then
            width = actor.thickness
            -- elseif actor.modelType == 6 then
        elseif actor.modelType == 7 then
            width = actor.ssdWitch
            -- elseif actor.modelType == 13 then
            --     width = actor.width
        elseif actor.modelType == 14 then
            width = actor.frameWidth * 2 + actor.passageWidth
        elseif actor.modelType == 15 then
            width = actor.radius * 2
        end

        local vertices = {}
        local points = actor.simplePoints
        for _, curr in pairs(points) do
            if curr then
                table.insert(vertices, { x = curr.X, y = curr.Y })
            end
        end

        if actor.bClose then
            table.insert(vertices, vertices[1])
        end
        -- 获取 Actor 包围盒和中心位置
        local origin, boxExtent = actor:GetActorBounds(false)
        local boxSize = { boxExtent.X * 2, boxExtent.Y * 2, boxExtent.Z * 2 }
        local location = { origin.X, origin.Y, origin.Z }
        -- 组装单个 Passage JSON
        local cadData = {
            Name     = actor:GetAttachParentActor().showName,
            Location = location,
            BoxSize  = boxSize,
            width    = width,
            vertices = vertices
        }
        if actor.modelType == 13 then
            cadData.Name = actor.text
        end
        return cadData
    end
    local function GetBZCadData(actor)
        local name = actor.showName
        local p1, p2, ref1, ref2, location
        if actor.modelType == 8 then
            p1 = { actor.StartPoint:K2_GetComponentLocation().X, actor.StartPoint:K2_GetComponentLocation().Y, actor
                .StartPoint:K2_GetComponentLocation().Z }
            p2 = { actor.EndPoint:K2_GetComponentLocation().X, actor.EndPoint:K2_GetComponentLocation().Y, actor
                .EndPoint:K2_GetComponentLocation().Z }
        elseif actor.modelType == 9 then
            p1 = { actor.Sphere:K2_GetComponentLocation().X, actor.Sphere:K2_GetComponentLocation().Y, actor.Sphere
                :K2_GetComponentLocation().Z }
            p2 = { actor.Sphere1:K2_GetComponentLocation().X, actor.Sphere1:K2_GetComponentLocation().Y, actor.Sphere1
                :K2_GetComponentLocation().Z }
            ref2 = { actor.Cable2:K2_GetComponentLocation().X, actor.Cable2:K2_GetComponentLocation().Y, actor.Cable2
                :K2_GetComponentLocation().Z }
            ref1 = { actor.Cable1:K2_GetComponentLocation().X, actor.Cable1:K2_GetComponentLocation().Y, actor.Cable1
                :K2_GetComponentLocation().Z }
        elseif actor.modelType == 11 then
            name = actor.text
            local origin, _ = actor:GetActorBounds(false)
            location = { origin.X, origin.Y, origin.Z }
        end
        -- 组装单个 Passage JSON
        local cadData = {
            Name     = name,
            P1       = p1,
            P2       = p2,
            Ref1     = ref1,
            Ref2     = ref2,
            Location = location,
        }
        return cadData
    end

    local actorExportCad = {
        [2] = function(actor, cadData)
            local modelData = GetModelCadData(actor)
            table.insert(cadData.Model, modelData)
        end,
        [3] = function(actor, cadData)
            local modelData = GetModelCadData(actor)
            table.insert(cadData.Model, modelData)
        end,
        [4] = function(actor, cadData)
            local modelData = GetSplineCadData(actor)
            table.insert(cadData.Pipeline, modelData)
        end,
        [5] = function(actor, cadData)
            local modelData = GetSplineCadData(actor)
            table.insert(cadData.Wall, modelData)
        end,
        [6] = function(actor, cadData)
            local modelData = GetSplineCadData(actor)
            table.insert(cadData.Area, modelData)
        end,
        [7] = function(actor, cadData)
            local modelData = GetSplineCadData(actor)
            table.insert(cadData.SSX, modelData)
        end,
        [8] = function(actor, cadData)
            local modelData = GetBZCadData(actor)
            table.insert(cadData.SizeBZ, modelData)
        end,
        [9] = function(actor, cadData)
            local modelData = GetBZCadData(actor)
            table.insert(cadData.VerticalBZ, modelData)
        end,
        [10] = function(actor, cadData)
            local modelData = GetModelCadData(actor)
            table.insert(cadData.ImportModel, modelData)
        end,
        [11] = function(actor, cadData)
            local modelData = GetBZCadData(actor)
            table.insert(cadData.MessageBZ, modelData)
        end,
        [12] = function(actor, cadData)
            local modelData = GetModelCadData(actor)
            table.insert(cadData.SAGC, modelData)
        end,
        [13] = function(actor, cadData)
            local modelData = GetSplineCadData(actor)
            table.insert(cadData.DashedLine, modelData)
        end,
        [14] = function(actor, cadData)
            local modelData = GetSplineCadData(actor)
            table.insert(cadData.Passage, modelData)
        end,
        [15] = function(actor, cadData)
            local modelData = GetSplineCadData(actor)
            table.insert(cadData.Path, modelData)
        end,
    }

    if actorExportCad[actor.modelType] then
        actorExportCad[actor.modelType](actor, cadData)
    end
end

-- 冲突检测函数
-- 功能：检测场景中所有模型之间的位置重叠冲突
-- 检测范围：只对指定类型的模型进行检测
-- 参与检测的模型类型：基础模型(2)、行业模型(3)、管道(4)、输送线(7)、导入模型(10)、动画模型(12)、通道(14)、路径(15)
-- 排除的模型类型：地板(1)、墙(5)、区域(6)、标注(8)、水平标注(9)、信息面板(11)、虚线标注(13)、DIY、Group等
-- 返回值：冲突列表，包含冲突的模型名称和位置信息
function M:DetectAndGenerateConflictList()
    self.conflictList = {}
    self.importedModels = {}

    if not self.Actors then
        print("模型管理器 Actors 无效，跳过冲突检测")
        return
    end

    local allActors = UE.TArray(UE.AActor)
    for _, actor in pairs(self.Actors) do
        allActors:Add(actor)
    end

    local checkedPairs = {}

    for i = 1, allActors:Num() do
        local actor1 = allActors[i]
        if actor1 and actor1:IsValid() then
            local actor1Type = actor1.modelType
            local actor1Name = UE.UKismetSystemLibrary.GetObjectName(actor1)

            local isActor1Eligible = (actor1Type == 2 or actor1Type == 3 or actor1Type == 4 or
                actor1Type == 7 or actor1Type == 10 or actor1Type == 12 or
                actor1Type == 14 or actor1Type == 15)

            for j = i + 1, allActors:Num() do
                local actor2 = allActors[j]
                if actor2 and actor2:IsValid() then
                    local actor2Type = actor2.modelType
                    local pairKey = actor1Name .. "_" .. UE.UKismetSystemLibrary.GetObjectName(actor2)

                    local isActor2Eligible = (actor2Type == 2 or actor2Type == 3 or actor2Type == 4 or
                        actor2Type == 7 or actor2Type == 10 or actor2Type == 12 or
                        actor2Type == 14 or actor2Type == 15)

                    if not checkedPairs[pairKey] and isActor1Eligible and isActor2Eligible then
                        checkedPairs[pairKey] = true

                        local origin1, boxExtent1 = actor1:GetActorBounds(false)
                        local objectTypes = UE.TArray(UE.EObjectTypeQuery)
                        objectTypes:Add(UE.EObjectTypeQuery.Model) -- 使用模型通道
                        local actorsToIgnore = UE.TArray(UE.AActor)
                        actorsToIgnore:Add(actor1)
                        local hitActors = UE.TArray(UE.AActor)

                        local bOverlap = UE.UKismetSystemLibrary.BoxOverlapActors(
                            self:GetWorld(), origin1, boxExtent1,
                            objectTypes, UE.AStaticMeshActor, actorsToIgnore, hitActors)

                        if bOverlap then
                            for _, hitActor in pairs(hitActors) do
                                if hitActor == actor2 then
                                    local loc1 = actor1:K2_GetActorLocation()
                                    local loc2 = actor2:K2_GetActorLocation()

                                    local conflict = {
                                        model1 = actor1Name,
                                        model2 = UE.UKismetSystemLibrary.GetObjectName(actor2),
                                        location1 = {
                                            x = loc1.X,
                                            y = loc1.Y,
                                            z = loc1.Z
                                        },
                                        location2 = {
                                            x = loc2.X,
                                            y = loc2.Y,
                                            z = loc2.Z
                                        }
                                    }

                                    table.insert(self.conflictList, conflict)
                                    print("检测到冲突: " .. conflict.model1 .. " <-> " .. conflict.model2)
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    print("冲突检测完成，共发现 " .. #self.conflictList .. " 处冲突")
    return self.conflictList
end

-- 按模型类型进行重叠检测的函数
-- 功能：在方案合并后检测导入模型与现有模型之间的位置重叠
-- 与DetectAndGenerateConflictList的区别：本函数专门用于合并方案后的检测，使用showName作为模型标识
--
-- 检测策略说明：
-- 1. 箱体模型（直接边界框检测）：基础模型(2)、行业模型(3)、导入模型(10)、动画模型(12)
--    - 直接使用边界框检测（BoxOverlapActors），检测到即记录为冲突
--
-- 2. 线性模型（边界框检测 + 二次反向检测）：管道(4)、输送线(7)、通道(14)、路径(15)
--    - 第一步：使用当前模型的边界框进行BoxOverlapActors检测
--    - 第二步：当检测到潜在重叠时，使用被检测模型的边界框进行反向检测
--    - 只有当双向检测都通过时才记录为真正的冲突
--
-- 参与检测的模型类型：基础模型(2)、行业模型(3)、管道(4)、输送线(7)、导入模型(10)、动画模型(12)、通道(14)、路径(15)
-- 返回值：冲突列表，包含重叠的模型名称和位置信息
function M:DetectModelOverlapByType()
    local conflictList = {}

    if not self.Actors then
        print("模型管理器 Actors 无效，跳过重叠检测")
        return conflictList
    end

    -- 箱体模型类型：直接边界框检测
    local boxModelTypes = {
        [2] = true,  -- 基础模型
        [3] = true,  -- 行业模型
        [10] = true, -- 导入模型
        [12] = true  -- 动画模型
    }

    -- 线性模型类型：边界框检测 + 二次反向检测
    local linearModelTypes = {
        [4] = true,  -- 管道
        [7] = true,  -- 输送线
        [14] = true, -- 通道
        [15] = true  -- 路径
    }

    -- 所有参与检测的模型类型
    local targetTypes = {
        [2] = true,
        [3] = true,
        [4] = true,
        [7] = true,
        [10] = true,
        [12] = true,
        [14] = true,
        [15] = true
    }

    local checkedPairs = {}
    local targetActors = {}

    for _, actor in pairs(self.Actors) do
        if actor and actor:IsValid() and actor.modelType and targetTypes[actor.modelType] then
            table.insert(targetActors, actor)
        end
    end

    for i = 1, #targetActors do
        local actor1 = targetActors[i]
        local actor1Name = actor1.showName or UE.UKismetSystemLibrary.GetObjectName(actor1)
        local actor1Type = actor1.modelType
        local origin1, boxExtent1 = actor1:GetActorBounds(false)

        local objectTypes = UE.TArray(UE.EObjectTypeQuery)
        objectTypes:Add(UE.EObjectTypeQuery.Model) -- 使用模型通道

        local actorsToIgnore = UE.TArray(UE.AActor)
        actorsToIgnore:Add(actor1) -- 忽略自身碰撞

        local outHits = UE.TArray(UE.FHitResult())

        -- 第一步：使用BoxTraceMulti进行检测
        -- 计算一个微小的偏移作为结束位置，确保检测覆盖整个边界框
        local endLocation = origin1 + UE.FVector(0.01, 0.01, 0.01)
        local bOverlap = UE.UKismetSystemLibrary.BoxTraceMulti(
            self:GetWorld(), origin1, endLocation, boxExtent1, UE.FRotator(0, 0, 0),
            UE.ETraceTypeQuery.Model, true, actorsToIgnore, 0, outHits, true)

        -- 从outHits中提取hitActors
        local hitActors = UE.TArray(UE.AActor)
        for _, hit in pairs(outHits) do
            local actor = hit.HitObjectHandle.Actor
            if actor and actor:IsValid() then
                hitActors:Add(actor)
            end
        end

        if bOverlap then
            for _, hitActor in pairs(hitActors) do
                if hitActor and hitActor:IsValid() and hitActor.modelType and targetTypes[hitActor.modelType] then
                    local hitActorName = hitActor.showName or UE.UKismetSystemLibrary.GetObjectName(hitActor)
                    local pairKey = actor1Name .. "_" .. hitActorName
                    local reversePairKey = hitActorName .. "_" .. actor1Name

                    if not checkedPairs[pairKey] and not checkedPairs[reversePairKey] then
                        local bFinalConflict = false

                        -- 判断是否是线性模型
                        local isActor1Linear = linearModelTypes[actor1Type]
                        local isActor2Linear = linearModelTypes[hitActor.modelType]

                        if isActor1Linear or isActor2Linear then
                            -- 线性模型：需要进行二次反向检测
                            local origin2, boxExtent2 = hitActor:GetActorBounds(false)

                            local actorsToIgnore2 = UE.TArray(UE.AActor)
                            actorsToIgnore2:Add(hitActor)

                            local outHits2 = UE.TArray(UE.FHitResult())

                            -- 第二步：使用被检测模型的边界框进行反向检测
                            local endLocation2 = origin2 + UE.FVector(0.01, 0.01, 0.01)
                            local bReverseOverlap = UE.UKismetSystemLibrary.BoxTraceMulti(
                                self:GetWorld(), origin2, endLocation2, boxExtent2, UE.FRotator(0, 0, 0),
                                UE.ETraceTypeQuery.Model, true, actorsToIgnore2, 0, outHits2, true)

                            if bReverseOverlap then
                                -- 从outHits2中提取hitActors2
                                local hitActors2 = UE.TArray(UE.AActor)
                                for _, hit in pairs(outHits2) do
                                    local actor = hit.HitObjectHandle.Actor
                                    if actor and actor:IsValid() then
                                        hitActors2:Add(actor)
                                    end
                                end

                                -- 检查反向检测是否也命中了actor1
                                for _, reverseHitActor in pairs(hitActors2) do
                                    if reverseHitActor == actor1 then
                                        -- 双向检测都通过，记录为冲突
                                        bFinalConflict = true
                                        break
                                    end
                                end
                            end
                        else
                            -- 箱体模型：直接边界框检测通过即记录为冲突
                            bFinalConflict = true
                        end

                        if bFinalConflict then
                            checkedPairs[pairKey] = true
                            checkedPairs[reversePairKey] = true

                            local loc1 = actor1:K2_GetActorLocation()
                            local loc2 = hitActor:K2_GetActorLocation()

                            local conflict = {
                                modelName = actor1Name,
                                location = {
                                    x = loc1.X,
                                    y = loc1.Y,
                                    z = loc1.Z
                                },
                                overlappingModelName = hitActorName,
                                overlappingLocation = {
                                    x = loc2.X,
                                    y = loc2.Y,
                                    z = loc2.Z
                                }
                            }

                            table.insert(conflictList, conflict)
                            -- print("检测到重叠: " .. conflict.modelName .. " 与 " .. conflict.overlappingModelName)
                        end
                    end
                end
            end
        end
    end

    print("重叠检测完成，共发现 " .. #conflictList .. " 处重叠")
    return conflictList
end

-- ===========================================================================
-- RegionArea（协作区域）专属逻辑
--   • M:RegSel           — 选中协作区域（写 curReg，不写 buildActor）
--   • M:CreateRegion     — 在场景中生成一个 BP_RegionArea Actor
--   • M:DestroyRegion    — 销毁协作区域 Actor 并清理索引
--
-- 表项分布（位于 M:ModelFunction 中）
-- ===========================================================================
-- 生成协作区域 Actor
function M:CreateRegion(name, control, showName)
    -- 如果没有传递 Transform 参数，则使用默认的 UE.FTransform()
    local transform = UE.FTransform()

    self:ModelClear(control)
    local class = LoadClass(self.class["RegionArea"])

    -- 在世界中生成指定类的 actor
    local actor = self:GetWorld():SpawnActor(class, transform, UE.ESpawnActorCollisionHandlingMethod.Default, self,
        self, "")
    -- 为生成的 actor 设置名称
    -- 约定：协作区域不单独维护 id，直接使用 `name`（区域 Actor 的 modelName）作为唯一标识，
    -- 并作为 `self.Regions` 的 key（后续 Enter/Select/Find 都依赖这个字符串）。
    Model.SetActorName(actor, name, nil)
    actor.showName = showName
    self.Regions:Add(name, actor)
    -- 返回生成的 actor
    return actor
end

--- 通过 regModelName（区域模型名称）查找对应的协作区域 Actor
--- @param regModelName string
--- @return AActor|nil
function M:FindRegionAreaActorByRegionName(regModelName)
    if not regModelName or regModelName == "" or not self.Regions then
        return nil
    end

    -- 约定：协作区域没有单独 id，使用区域 Actor 的 modelName（regModelName）作为唯一标识，
    -- 且 `self.Regions` 以 regModelName 作为 key 存储（CreateRegion 时 Add(name, actor)）。
    -- 先走 TMap 直查；若历史数据存在“键与实际 Actor 名称不一致”的情况，再走扫描兜底。
    local direct = self.Regions:Find(regModelName)
    if direct and UE.UKismetSystemLibrary.IsValid(direct) then
        return direct
    end

    for _, reg in pairs(self.Regions) do
        if UE.UKismetSystemLibrary.IsValid(reg) then
            local name = Model.GetActorAccurateDisplayName(reg)
            if name == regModelName then
                return reg
            end
        end
    end

    return nil
end

-- 选中协作区域（对齐 SplineActorSel，但目标写入 control.curReg 而非 control.buildActor）
function M:RegionSelcet(actor, control)
    self:RegionClear(control)
    control.curReg = actor

    -- 若区域已有记录的当前点索引，则优先使用；否则默认为 1
    local num = actor.simplePoints:Num()
    local currentIndex = actor.currentPoint or 1
    if currentIndex < 1 or currentIndex > num then
        currentIndex = 1
    end
    actor.currentPoint = currentIndex

    -- 为协作区域生成点位（用于显示/编辑轮廓）
    self:BuildPoint(actor.simplePoints, actor)
    -- 这里预留 A 变量以便后续如需在选中区域时自动创建 gizmo 时使用
    local point = self.NubPoints:Find(currentIndex)
    self:CreateGizmo(point)
end

function M:RegionClear(control)
    if control.curReg then
        control.curReg.currentPoint = 1
        self:ClearPoints()
        self:DestroyGizmo()
        control.curReg = nil
    end
end

-- 销毁协作区域 Actor 并清理索引
function M:DestroyRegion(actor, control)
    if control and actor == control.curReg then
        self:RegionClear(control)
        control.curReg = nil
    end
    local modelName = Model.GetActorAccurateDisplayName(actor)
    self.Regions:Remove(modelName)
    actor:K2_DestroyActor()

    if control and control.curReg == nil then
        -- 如果有 gizmo（Build Placement Ghost），也销毁它
        self:DestroyGizmo()
        self:ClearCatch(true, control)
        control:FloorDataToView()
    end
end

function M:ClearAllRegions()
    for key, value in pairs(self.Regions) do
        if UE.UKismetSystemLibrary.IsValid(value) then
            value:K2_DestroyActor()
        end

        self.Regions:Remove(key)
    end
end

-- 获取区域内模型
-- @param bLog boolean 可选，是否输出调试日志（默认 false）
function M:GetAllRegionInnerActors()
    print("[RegionInner] 开始获取区域内模型")
    self.RegionInnerActors:Clear()
    if self.Actors:Num() <= 4 then
        print("[RegionInner] 总模型数量小于4，不进行区域内的模型搜集")
        return
    end
    local dbg = false -- 调试开关：传入 true 时会输出/统计更多 RegionInner 的筛选过程信息

    -- 下面这些是调试统计计数器（不影响功能逻辑，只用于观察“区域内 Actor 收集”的筛选/添加情况）
    local regionN, actorIterN, validN, addedN = 0, 0, 0, 0    -- 区域数量 / 遍历到的 Actor 次数 / 有效 Actor 数 / 最终加入区域内列表数
    local filteredRootN, filteredCadN, filteredDiyN = 0, 0, 0 -- 被过滤掉的：root/CAD/DIY 相关数量
    local filteredFloorN, filteredBZN = 0, 0                  -- 被过滤掉的：Floor（地板/楼层节点）/BZ（基础依赖节点）相关数量
    local insideFalseN = 0                                    -- inside 判断为 false（不在区域内/不通过包含测试）的数量
    local addedGroupN = 0                                     -- 以“组/集合”方式一次性加入的数量（用于区分单个 Actor addedN）

    -- RegionInner：排除不应参与统计/树构建的 Actor（floor/bz/root/cad/diy 等）
    local function _isRegionInnerExcluded(name, actor)
        if not actor or not UE.UKismetSystemLibrary.IsValid(actor) then
            return true
        end
        local t = actor.modelType
        local nameStr = tostring(name)

        -- CAD / DIY 不参与
        if t == "CAD" then
            filteredCadN = filteredCadN + 1
            return true
        end
        if t == "DIY" or nameStr == "DIY" then
            filteredDiyN = filteredDiyN + 1
            return true
        end

        -- root（旧逻辑：tostring(t)=="1" 会导致把 floor 计为 root；这里保留兼容计数口径但不再单独区分）
        if nameStr == "1" then
            filteredRootN = filteredRootN + 1
            return true
        end

        -- Floor-s / BZ 等基础依赖节点不纳入区域内统计
        if string.find(nameStr, "Floor") ~= nil then
            filteredFloorN = filteredFloorN + 1
            return true
        end
        if string.find(nameStr, "BZ") ~= nil then
            filteredBZN = filteredBZN + 1
            return true
        end

        return false
    end

    -- RegionInner：把 actor 本身 + 父对象链自动加入（用于树结构补齐 Group 父节点）
    local function _addActorAndParents(name, actor)
        local visited = {}
        local function _safeAdd(n, a)
            if not a or not UE.UKismetSystemLibrary.IsValid(a) then
                return
            end
            local key = tostring(n)
            if visited[key] then
                return
            end
            visited[key] = true
            if not _isRegionInnerExcluded(n, a) then
                print(n, "区域内的模型名称")
                self.RegionInnerActors:Add(n, a)
            end
        end

        _safeAdd(name, actor)

        local cur = actor
        for _ = 1, 32 do
            if not cur or not UE.UKismetSystemLibrary.IsValid(cur) then
                break
            end
            local parent = cur:GetAttachParentActor()
            if not parent or not UE.UKismetSystemLibrary.IsValid(parent) then
                break
            end
            local parentName = Model.GetActorAccurateDisplayName(parent)
            -- 遇到 floor/root/BZ/DIY/CAD 等直接停止向上扩散（避免把基础节点卷进 RegionInner）
            if _isRegionInnerExcluded(parentName, parent) then
                break
            end
            _safeAdd(parentName, parent)
            cur = parent
        end
    end

    -- 判断模型是否在RegionInnerActors中
    local function _isActorInMap(name)
        return self.RegionInnerActors:Find(name) ~= nil
    end

    local regionKeys = self.Regions:Keys()
    for i = 1, regionKeys:Num() do
        local regionName = regionKeys[i]
        local regionActor = self.Regions:Find(regionName)
        if not regionActor or not UE.UKismetSystemLibrary.IsValid(regionActor) then
            goto regionContinue
        end
        print("[RegionInner] regionActor有多少个", self.Regions:Num())
        if regionActor and UE.UKismetSystemLibrary.IsValid(regionActor) then
            regionN = regionN + 1
            local polygon = self:GetRegionPolygon(regionActor)
            print("[RegionInner] actors有多少个", self.Actors:Num())
            local keys = self.Actors:Keys()
            -- for name, actor in pairs(self.Actors) do
            for i = 1, keys:Num() do
                local name = keys[i]
                local actor = self.Actors:Find(name)
                if not actor or not UE.UKismetSystemLibrary.IsValid(actor) then
                    goto continue
                end
                actorIterN = actorIterN + 1
                if actor and UE.UKismetSystemLibrary.IsValid(actor) then
                    validN = validN + 1
                    if not _isActorInMap(name) and not _isRegionInnerExcluded(name, actor) then
                        -- 只对 type(delType) == "number" 的对象做“是否在区域内”的几何判定
                        -- 这里的 delType 等价于外部逻辑里的删除类型（通常就是 actor.modelType）
                        local delType = actor.modelType
                        if type(delType) == "number" then
                            if self:IsActorFullyInsideRegion(regionActor, actor, polygon) then
                                _addActorAndParents(name, actor)
                                addedN = addedN + 1
                                if actor.modelType == "Group" then
                                    addedGroupN = addedGroupN + 1
                                end
                                if dbg and addedN <= 10 then
                                    print("[RegionInner] add: " ..
                                        tostring(name) .. " type=" .. tostring(actor.modelType))
                                end
                            else
                                insideFalseN = insideFalseN + 1
                            end
                        end
                    else
                        print("[RegionInner] actor不在区域内", name)
                    end
                end
                ::continue::
            end
        end
        ::regionContinue::
    end
    if dbg then
        print("[RegionInner] GetAllRegionInnerActors done: regions=" .. tostring(regionN) ..
            " actorsIter=" .. tostring(actorIterN) ..
            " valid=" .. tostring(validN) ..
            " added=" .. tostring(addedN) ..
            " addedGroup=" .. tostring(addedGroupN) ..
            " filtered(root/cad/diy/floor/bz)=" .. tostring(filteredRootN) .. "/" .. tostring(filteredCadN) .. "/" ..
            tostring(filteredDiyN) .. "/" .. tostring(filteredFloorN) .. "/" .. tostring(filteredBZN) ..
            " insideFalse=" .. tostring(insideFalseN))
    end
end

--- 获取指定协作区域的平面多边形（XY 平面），用于 RegionInner 相关几何判断
--- 约定：直接复用 BP_RegionArea 上维护的 simplePoints（区域轮廓点列）
---@param areaActor any BP_RegionArea 实例（Actor）
---@return any 区域轮廓点列（TArray<FVector>）或 nil
function M:GetRegionPolygon(areaActor)
    if not areaActor or not UE.UKismetSystemLibrary.IsValid(areaActor) then
        ---@diagnostic disable-next-line: redundant-return-value
        return nil
    end

    local pts = areaActor.simplePoints
    if not pts or not pts.Num or pts:Num() < 3 then
        ---@diagnostic disable-next-line: redundant-return-value
        return nil
    end

    -- 直接返回 simplePoints：Control 侧仅做只读几何判断，不会修改点集
    ---@diagnostic disable-next-line: redundant-return-value
    return pts
end

--- 判断指定 Actor 是否“完全位于”给定协作区域内部（仅判定水平投影 XY）
--- 判定规则：根据 actor.clickType 选择判断方式（碰撞/数据点/起终点），最终都映射为“关键点都在区域多边形严格内部”
---@param areaActor any 协作区域 Actor（BP_RegionArea）
---@param actor any 待检测 Actor
---@param polygon any 预先计算好的区域多边形；为 nil 时内部自动获取
---@return boolean
function M:IsActorFullyInsideRegion(areaActor, actor, polygon)
    -- 调试开关：需要查看“模型是否在区域内”的详细判定过程时，可将其改为 true
    local dbgInside = false

    local function _log(...)
        if dbgInside then
            print("[RegionInner:IsActorFullyInsideRegion]", ...)
        end
    end

    if not actor or not UE.UKismetSystemLibrary.IsValid(actor) then
        _log("待检测 Actor 无效，返回 false")
        return false
    end
    if not areaActor or not UE.UKismetSystemLibrary.IsValid(areaActor) then
        _log("区域 Actor 无效，返回 false")
        return false
    end

    -- 区域自身不参与“在区域内”的判定
    if actor == areaActor then
        _log("待检测 Actor 与区域 Actor 相同，返回 false")
        return false
    end

    local areaName = Model.GetActorAccurateDisplayName(areaActor)
    local actorName = Model.GetActorAccurateDisplayName(actor)

    _log("开始区域内判定",
        "区域=", tostring(areaName),
        "对象=", tostring(actorName),
        "clickType=", tostring(actor.clickType))

    polygon = polygon or self:GetRegionPolygon(areaActor)
    if not polygon or not polygon.Num or polygon:Num() < 3 then
        _log("多边形数据无效，返回 false")
        return false
    end

    -- clickType 分流（按需求）：
    -- 1: 走 actor 碰撞/包围盒（默认）
    -- 2: 走数据点（simplePoints/points）
    -- 3: 走起点/终点（StartPoint/EndPoint 或 Sphere/Sphere1）
    local ct = actor.clickType

    local function _isPointInside(p)
        local ok = false
        if p then
            ok = RegionAreaAlgo.IsPointStrictlyInsidePolygon(p, polygon, 1e-3)
        end
        _log("  点判定：",
            "对象=", tostring(actorName),
            "坐标=(", p and (tostring(p.X) .. "," .. tostring(p.Y) .. "," .. tostring(p.Z)) or "nil", ")",
            "是否在多边形内=", tostring(ok))
        return ok
    end

    if ct == 2 then
        _log("使用 simplePoints/points 模式（clickType=2）")
        local pts = actor.simplePoints or actor.points
        if pts and pts.Num and pts:Num() >= 2 then
            for _, p in pairs(pts) do
                if not _isPointInside(p) then
                    _log("simplePoints 中存在点在区域外，返回 false")
                    return false
                end
            end
            _log("所有 simplePoints 点均在区域内，返回 true")
            return true
        end
        -- 点集缺失时回退到包围盒判定
    elseif ct == 3 then
        _log("使用起点/终点模式（clickType=3）")
        local p1, p2 = nil, nil
        if actor.StartPoint and actor.EndPoint then
            p1 = actor.StartPoint:K2_GetComponentLocation()
            p2 = actor.EndPoint:K2_GetComponentLocation()
        elseif actor.Sphere and actor.Sphere1 then
            p1 = actor.Sphere:K2_GetComponentLocation()
            p2 = actor.Sphere1:K2_GetComponentLocation()
        end
        if p1 and p2 then
            local ok1 = _isPointInside(p1)
            local ok2 = _isPointInside(p2)
            local ok = ok1 and ok2
            _log("起点/终点判定结果：", "起点在区域内=", tostring(ok1), "终点在区域内=", tostring(ok2), "最终结果=",
                tostring(ok))
            return ok
        end
        -- 起终点缺失时回退到包围盒判定
    end

    -- 优先使用静态网格体/PMesh 的碰撞包围盒（更贴近“以静态网格体碰撞判断”的语义）
    -- 如果没有可用组件，则回退到 ActorBounds(bOnlyCollidingComponents=true)。
    local function _isBoundsInside(origin, extent)
        if not origin or not extent then
            _log("  包围盒无效（origin/extent 为空），返回 false")
            return false
        end
        local z = origin.Z - extent.Z
        local corners = {
            UE.FVector(origin.X - extent.X, origin.Y - extent.Y, z),
            UE.FVector(origin.X - extent.X, origin.Y + extent.Y, z),
            UE.FVector(origin.X + extent.X, origin.Y - extent.Y, z),
            UE.FVector(origin.X + extent.X, origin.Y + extent.Y, z),
        }
        for _, p in ipairs(corners) do
            -- 使用“在内部或边上”判定，压线的角点视为在区域内
            if not RegionAreaAlgo.IsPointStrictlyInsidePolygon(p, polygon, 1e-3) then
                _log("  包围盒某个角在多边形外，返回 false")
                return false
            end
        end
        _log("  包围盒所有角都在多边形内，返回 true")
        return true
    end

    -- local anyComp = false
    -- local comps = {}
    -- -- 常见静态网格组件字段：BP_Model.StaticMeshComponent / 导入模型 PMesh / CAD PMesh 等
    -- if actor.StaticMeshComponent then
    --     table.insert(comps, actor.StaticMeshComponent)
    -- end
    -- if actor.PMesh then
    --     table.insert(comps, actor.PMesh)
    -- end

    -- for _, comp in ipairs(comps) do
    --     if comp and UE.UKismetSystemLibrary.IsValid(comp) then
    --         anyComp = true
    --         local o, e = UE.UKismetSystemLibrary.GetComponentBounds(comp)
    --         _log("检查组件包围盒",
    --             "区域=", tostring(areaName),
    --             "对象=", tostring(actorName),
    --             "组件名=", tostring(comp:GetName()))
    --         if not _isBoundsInside(o, e) then
    --             _log("组件包围盒不完全在区域内，返回 false")
    --             return false
    --         end
    --     end
    -- end

    -- if anyComp then
    --     _log("所有组件包围盒均在区域内，返回 true")
    --     return true
    -- end

    -- 回退：使用 Actor 的“仅碰撞组件”包围盒
    local origin, extent = actor:GetActorBounds(true)
    if actor.modelType == 10 then
        origin, extent = actor:GetModelBounds()
    elseif actor.modelType == "Group" then
        local childActors = UE.TArray(UE.AActor)
        actor:GetAttachedActors(childActors, true, true)
        origin, extent = UE.UGameplayStatics.GetActorArrayBounds(childActors, false)
    end
    _log(origin, extent)
    local parentActor = actor:GetAttachParentActor()
    _log("使用 Actor:GetActorBounds(true) 进行回退判定",
        "区域=", tostring(areaName),
        "对象=", tostring(actorName),
        "显示名=", tostring(parentActor and parentActor.showName or "nil"))
    local ok = _isBoundsInside(origin, extent)
    _log("ActorBounds 判定结果：", tostring(ok))
    return ok
end

--- 获取指定协作区域内部“完全落入”的所有模型 Actor 列表
--- @param regModelName string 协作区域模型名称（regModelName）
--- @return UE.TArray<UE.AActor> 区域内 Actor 列表
function M:GetActorsInRegion(regModelName)
    local result = UE.TArray(UE.AActor)

    if not self.Actors or not self.Regions then
        return result
    end

    local areaActor = self:FindRegionAreaActorByRegionName(regModelName)
    if not areaActor or not UE.UKismetSystemLibrary.IsValid(areaActor) then
        return result
    end

    local polygon = self:GetRegionPolygon(areaActor)
    if not polygon or not polygon.Num or polygon:Num() < 3 then
        return result
    end

    for _, actor in pairs(self.Actors) do
        if actor and UE.UKismetSystemLibrary.IsValid(actor) and actor ~= areaActor then
            if self:IsActorFullyInsideRegion(areaActor, actor, polygon) then
                result:Add(actor)
            end
        end
    end

    return result
end

-- ===========================================================================
-- END RegionArea
-- ===========================================================================

return M
