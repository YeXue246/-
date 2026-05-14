--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--

---@class BP_CAD_C
local M = UnLua.Class()
local Class = require("SandBox.Class")
local json = require("dkjson")

-- 通用：根据源 CAD 文件内容生成哈希命名（用于 CAD bin 文件命名）
local function MakeHashNameFromFile(fullPath)
    if not fullPath or fullPath == "" then
        -- 没有源文件路径时退回时间戳命名，保证逻辑可继续工作
        local t = os.date("*t")
        return string.format("CAD_%04d%02d%02d_%02d%02d%02d.bin",
            t.year, t.month, t.day, t.hour, t.min, t.sec)
    end

    -- 调用 C++ 中的 UMyBFL::GetFileContentHash 获取文件内容 MD5
    local hash = UE.UMyBFL.GetFileContentHash(fullPath)
    if not hash or hash == "" then
        -- 读取/计算失败时也退回时间戳命名
        local t = os.date("*t")
        return string.format("CAD_%04d%02d%02d_%02d%02d%02d.bin",
            t.year, t.month, t.day, t.hour, t.min, t.sec)
    end
    -- 使用哈希作为文件名，确保同一 CAD 内容得到同一个 bin 名称
    return string.format("CAD_%s.bin", hash)
end

function M:Initialize(Initializer)
    self.shrinkDistance = 4
    self.dataT = {}
    self.modelType = "CAD"
    self.vertices = UE.TArray(UE.FVector)
    self.indices = UE.TArray(0)
    -- CAD 本地 bin 相对路径（相对 ProjectDir，用于跨机器可复现的加载入口）
    self.cadPath = ""
    -- CAD 本地 bin 绝对路径（仅记录当前机器上真实落盘路径，一旦写入尽量不再修改）
    self.cadFullPath = ""
    -- CAD 后端下载地址（文件服务返回的相对 url / 唯一名）
    self.cadUrl = ""
    -- 上传/解析状态标记（由外部或蓝图触发具体上传流程，这里只负责记录状态和数据）
    self._cadBinUploadInProgress = false
    self._cadBinUploadDone = false
    self._cadBinResolveInProgress = false
    -- 下载相关变量
    self._cadDownloadSavePath = ""
    self.bShow = true
end

-- 上传 CAD 文件到后端
-- 约定：需要配合项目的文件上传接口使用
-- @return boolean ok, string errorMsg
function M:UploadCadBin()
    print("[UploadCadBin] 开始执行")

    if self._cadBinUploadInProgress then
        print("[UploadCadBin] 失败：上传正在进行中")
        return false, "Upload already in progress"
    end

    -- 标记状态
    self._cadBinUploadInProgress = true
    self._cadBinUploadDone = false

    -- 构造上传地址（与 UI_SandBox 中模型/截图上传保持一致）
    local baseUrl = UE.UMyBFL.GetExeURL("RearIP")
    local uploadUrl = baseUrl .. "/dts-cloud-island-file/v1"
    local fullPathFromRel = self:ResolveCadPathToFull(self.cadPath)

    print(string.format("[UploadCadBin] 开始上传文件: %s -> %s", tostring(self.cadFullPath), uploadUrl))

    local control = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(), LoadClass(Class.control))
    local headers = control.ui.headers
    self:UploadCad(
        fullPathFromRel,
        300,
        UE.UBlueprintPathsLibrary.GetCleanFilename(fullPathFromRel),
        uploadUrl,
        "幻影平台",
        "cad_bin",
        headers)
    -- -- 允许外部（如 UI）提前注入 headers；若没有则创建空的 TMap
    -- local headers = control.ui.headers
    -- -- 创建异步上传请求（参考 UI_SandBox.lua 第 287 行）
    -- local postRequest = UE.UMyBACAsyncHTTPUpload.UploadFileAsync(
    --     self:GetWorld(),
    --     fullPathFromRel,
    --     300,
    --     UE.UBlueprintPathsLibrary.GetCleanFilename(fullPathFromRel),
    --     uploadUrl,
    --     "幻影平台",
    --     "cad_bin",
    --     headers
    -- )

    -- if not postRequest then
    --     print("[UploadCadBin] 失败：创建上传请求失败")
    --     self._cadBinUploadInProgress = false
    --     return false, "Create upload request failed"
    -- end

    -- -- 绑定回调（仿照 UI_SandBox 中 ModelUpLoad/UpLoad 的处理方式）
    -- postRequest.OnSuccess:Add(self, self.CadUpload_Success)
    -- postRequest.OnFailed:Add(self, self.CadUpload_OnFail)
    -- coroutine.resume(coroutine.create(function()
    --     postRequest:HttpActivate()
    -- end), self)

    -- print("[UploadCadBin] 上传请求已发送")
    return true, "Upload initiated"
end

-- CAD 上传成功回调
-- @param responseData string 服务端响应数据（JSON）
-- @param responseCode number HTTP 状态码
function M:CadUpload_Success(responseData, responseCode)
    print(string.format("[CadUpload_Success] code=%s, data=%s", tostring(responseCode), tostring(responseData)))

    self._cadBinUploadInProgress = false
    self._cadBinUploadDone = true

    if not responseData or responseData == "" then
        print("[CadUpload_Success] 空响应，无法解析 cadUrl")
        return
    end

    local ok, resp = pcall(json.decode, responseData)
    if not ok or not resp then
        print("[CadUpload_Success] JSON 解析失败")
        return
    end

    -- 兼容结构：{ data = { url = "xxx" } } 或 { url = "xxx" }
    local url = nil
    if resp and resp.data then
        url = resp.data.resourcePath
    end

    if url and url ~= "" then
        self.cadUrl = url
        print("[CadUpload_Success] cadUrl 设置为: " .. tostring(self.cadUrl))
    else
        print("[CadUpload_Success] 响应中未找到 url 字段")
    end
end

-- CAD 上传失败回调
function M:CadUpload_OnFail()
    print("[CadUpload_OnFail] CAD 上传失败")
    -- 避免一直卡在“上传中”状态，允许后续重试
    self._cadBinUploadInProgress = false
    self._cadBinUploadDone = true
end

function M:ResolveCadPathToFull(pathOrRel)
    local p = pathOrRel or self.cadPath
    if not p or p == "" then return "" end
    local projectDir = UE.UBlueprintPathsLibrary.ProjectDir()
    -- 约定：cadPath 永远是相对 ProjectDir 的路径，这里只做一次拼接
    return projectDir .. p
end

-- 确保 CAD bin 已经落盘到工程目录下的固定相对路径
-- 约定：
--   - bin 文件统一保存到：ProjectDir/OutAsset/CADBin/时间戳.bin
---   - 返回值：
---       ok       : boolean，是否成功生成/复用本地 bin
---       fullPath : string，bin 的绝对路径
---       relPath  : string，相对 ProjectDir 的路径（用于存档）
---@param maxWaitSeconds number|nil 预留参数，与蓝图版本保持一致，当前实现未使用
---@return boolean ok, string fullPath, string relPath
function M:EnsureLocalCadBin(maxWaitSeconds)
    print("[EnsureLocalCadBin] 开始执行")
    maxWaitSeconds = maxWaitSeconds or 0

    local projectDir = UE.UBlueprintPathsLibrary.ProjectDir()

    -- 1）已存在有效的相对路径并且文件存在：直接复用，不再生成
    if self.cadPath and self.cadPath ~= "" then
        local fullPathFromRel = self:ResolveCadPathToFull(self.cadPath)
        if fullPathFromRel ~= "" and UE.UBlueprintPathsLibrary.FileExists(fullPathFromRel) then
            print("[EnsureLocalCadBin] 复用已有的文件: " .. fullPathFromRel)
            return true, fullPathFromRel, self.cadPath
        end
    end

    -- 2）生成新的 bin 路径：OutAsset/CADBin/基于源 CAD 内容的哈希名.bin（相对 ProjectDir）
    print("[EnsureLocalCadBin] 创建新文件路径")
    local relDir = "OutAsset/CADBin/"
    local fileName = MakeHashNameFromFile(self.cadFullPath)
    local relPath = relDir .. fileName
    local fullPath = projectDir .. relPath
    print("[EnsureLocalCadBin] 目标路径: " .. fullPath)

    -- 3）确保目录存在（使用 UMyBFL.CreatFolder）
    local dirPath = "OutAsset/CADBin"
    print("[EnsureLocalCadBin] 确保目录存在: " .. dirPath)
    UE.UMyBFL.CreatFolder(dirPath)

    -- 4）从 cadFullPath 复制文件到项目内指定目录
    local ok = false
    if self.cadFullPath and self.cadFullPath ~= "" and UE.UBlueprintPathsLibrary.FileExists(self.cadFullPath) then
        print("[EnsureLocalCadBin] 复制文件: " .. self.cadFullPath .. " -> " .. fullPath)
        -- 使用 C++ 中的 UMyBFL.CopyFile 直接进行文件复制，第三个参数表示允许覆盖
        ok = UE.UMyBFL.CopyFile(self.cadFullPath, fullPath, true)
        if not ok then
            print("[EnsureLocalCadBin] 复制失败")
        end
    else
        print("[EnsureLocalCadBin] 源文件不存在或路径为空")
    end

    -- 5）双重校验：复制成功 + 文件是否真实存在
    if ok and UE.UBlueprintPathsLibrary.FileExists(fullPath) then
        print("[EnsureLocalCadBin] 文件复制成功")
        -- 更新相对路径（用于存档）
        self.cadPath = relPath
        return true, fullPath, relPath
    else
        print("[EnsureLocalCadBin] 文件复制失败: " .. fullPath)
        return false, "", ""
    end
end

-- 数据出
function M:ModelSave()
    -- 尝试上传 CAD 文件（如果还未上传成功）
    if self.cadFullPath and self.cadFullPath ~= "" and not self._cadBinUploadDone then
        local uploadOk, uploadErr = self:UploadCadBin()
        if uploadOk then
            print("CAD upload initiated: " .. uploadErr)
        else
            print("CAD upload failed: " .. uploadErr)
        end
    end

    local table = {
        ["Type"] = self.modelType,
        ["CADName"] = self.cadName,
        ["CADTime"] = self.cadTime,
        ["cadOffset"] = UE.UJsonLibraryHelpers.JsonValue_Stringify(UE.UJsonLibraryHelpers.FromVector(self.cadOffset)),
        ["bShow"] = self.bShow,
    }
    -- 仅保存 bin 的相对路径（相对 ProjectDir，命名规则由 EnsureLocalCadBin/下载逻辑统一管理）
    table["cadPath"] = self.cadPath
    table["cadFullPath"] = self.cadFullPath
    print("cadFullPath: " .. self.cadFullPath)
    -- 保存后端下载地址/唯一名（便于异机拉取并按规则重命名本地文件）
    table["cadUrl"] = self.cadUrl
    -- 兜底：没有 bin 时，仍保存 dataT，保证方案可加载（但会变大）
    table["dataT"] = self.dataT
    return table
end

-- 数据进
function M:ModelLoad(table)
    print("[ModelLoad] 开始执行")
    self.dataT = table["dataT"]
    self.cadPath = table["cadPath"] or ""
    self.cadFullPath = table["cadFullPath"] or ""
    self.cadUrl = table["cadUrl"] or ""
    self.cadName = table["cadName"] or ""
    self.cadTime = table["cadTime"] or ""
    if table["bShow"] ~= nil then
        self.bShow = table["bShow"]
    end
    if table["cadOffset"] then
        self.cadOffset = UE.UJsonLibraryHelpers.ToVector(UE.UJsonLibraryHelpers.Parse(table["cadOffset"]))
        self.PMesh:K2_SetWorldLocation(self.cadOffset, false, nil, false)
    end

    print("[ModelLoad] cadPath: " .. self.cadPath)
    print("[ModelLoad] cadFullPath: " .. self.cadFullPath)
    print("[ModelLoad] cadUrl: " .. self.cadUrl)

    -- 优先使用相对路径
    if self.cadPath and self.cadPath ~= "" then
        local fullPathFromRel = self:ResolveCadPathToFull(self.cadPath)
        if fullPathFromRel ~= "" and UE.UBlueprintPathsLibrary.FileExists(fullPathFromRel) then
            print("[ModelLoad] 使用相对路径加载: " .. fullPathFromRel)
            self:SetCADFromBin(fullPathFromRel, false)
        elseif self.cadUrl and self.cadUrl ~= "" then
            -- 本地文件都不存在，但有下载地址，尝试从后端下载
            print("[ModelLoad] 本地文件不存在，尝试从后端下载")
            self:DownloadCadFromUrl()
        elseif self.cadFullPath and self.cadFullPath ~= "" and UE.UBlueprintPathsLibrary.FileExists(self.cadFullPath) then
            -- 相对路径的文件不存在，尝试绝对路径
            print("[ModelLoad] 相对路径文件不存在，使用绝对路径加载: " .. self.cadFullPath)
            self:SetCADFromBin(self.cadFullPath, false)
        elseif self.dataT then
            -- 无可用路径，仅 dataT 时，作为纯内存模式加载
            print("[ModelLoad] 使用 dataT 纯内存加载")
            self:SetCAD(self.dataT, false)
        else
            print("[ModelLoad] 无法加载 CAD：没有可用的路径或数据")
        end
    elseif self.cadFullPath and self.cadFullPath ~= "" and UE.UBlueprintPathsLibrary.FileExists(self.cadFullPath) then
        -- 无相对路径，但有绝对路径且文件存在
        print("[ModelLoad] 使用绝对路径加载: " .. self.cadFullPath)
        self:SetCADFromBin(self.cadFullPath, false)
    elseif self.cadUrl and self.cadUrl ~= "" then
        -- 无可用路径，但有下载地址，尝试从后端下载
        print("[ModelLoad] 本地文件不存在，尝试从后端下载")
        self:DownloadCadFromUrl()
    elseif self.dataT then
        -- 无可用路径，仅 dataT 时，作为纯内存模式加载
        print("[ModelLoad] 使用 dataT 纯内存加载")
        self:SetCAD(self.dataT, false)
    else
        print("[ModelLoad] 无法加载 CAD：没有可用的路径或数据")
    end

    self:IsShowCad(self.bShow)
end

-- 从后端下载 CAD 文件
function M:DownloadCadFromUrl()
    print("[DownloadCadFromUrl] 开始执行")
    if not self.cadUrl or self.cadUrl == "" then
        print("[DownloadCadFromUrl] 失败：没有下载地址")
        return
    end

    -- 显示下载提示
    local control = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(), LoadClass(Class.control))
    control.ui:UECallWeb("ShowMessage", { Type = 1, Text = "正在下载 CAD 文件..." })

    local projectDir = UE.UBlueprintPathsLibrary.ProjectDir()

    -- 确定保存路径
    local savePath = ""
    if self.cadPath and self.cadPath ~= "" then
        savePath = projectDir .. self.cadPath
    else
        -- 如果没有 cadPath，生成一个基于下载完成后内容哈希的路径
        local relDir = "OutAsset/CADBin/"
        -- 先用时间戳生成一个临时文件名，下载完成后由 EnsureLocalCadBin 统一按哈希落盘
        local t = os.date("*t")
        local tempName = string.format("CAD_TMP_%04d%02d%02d_%02d%02d%02d.bin",
            t.year, t.month, t.day, t.hour, t.min, t.sec)
        local relPath = relDir .. tempName
        savePath = projectDir .. relPath
        -- cadPath/cadFullPath 在下载完成并调用 EnsureLocalCadBin 后会被更新为哈希命名
        self.cadPath = relPath
    end

    print("[DownloadCadFromUrl] 下载地址: " .. self.cadUrl)
    print("[DownloadCadFromUrl] 保存路径: " .. savePath)

    -- 确保目录存在（使用 UMyBFL.CreatFolder）
    local dirPath = "OutAsset/CADBin"
    print("[DownloadCadFromUrl] 确保目录存在: " .. dirPath)
    UE.UMyBFL.CreatFolder(dirPath)

    -- 保存下载路径，供回调使用
    self._cadDownloadSavePath = savePath

    -- 构建完整下载 URL
    local fullUrl = UE.UMyBFL.GetExeURL("RearIP") .. self.cadUrl
    print("[DownloadCadFromUrl] 完整下载 URL: " .. fullUrl)

    -- 开始下载
    UE.UFileToStorageDownloader.DownloadFileToStorage(
        fullUrl,
        savePath,
        0,
        "",
        false,
        { self, self.CadDownloadProgress },
        { self, self.CadDownloadComplete }
    )
end

-- CAD 下载进度回调
function M:CadDownloadProgress(BytesReceived, ContentLength)
    print("[CadDownloadProgress] 已下载: " .. BytesReceived .. "/" .. ContentLength)
end

-- CAD 下载完成回调
function M:CadDownloadComplete(Result)
    print("[CadDownloadComplete] 下载完成，结果: " .. Result)
    local control = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(), LoadClass(Class.control))

    if Result == 0 then
        -- 下载成功
        print("[CadDownloadComplete] 下载成功，开始加载 CAD")
        control.ui:UECallWeb("ShowMessage", { Type = 1, Text = "CAD 文件下载成功" })
        -- 加载 CAD
        local fullPathFromRel = self:ResolveCadPathToFull(self.cadPath)
        self:SetCADFromBin(fullPathFromRel, false)
    else
        control.ui:UECallWeb("ShowMessage", { Type = 2, Text = "CAD 文件下载失败" })
    end
end

function M:SetCAD(jsonTable, bCreate)
    local index = 0
    local pointSizes = UE.TArray(UE.FVector)
    for key, value in pairs(jsonTable) do
        if value.type == "line" then
            local startPoint = UE.FVector(value["start"][1], -value["start"][2], value["start"][3])
            local endPoint = UE.FVector(value["end"][1], -value["end"][2], value["end"][3])
            local eStartA, eEndA, eStartB, eEndB = self:ExpandedEdges(startPoint, endPoint)
            self:PointArray(index, eStartA, eEndA, eStartB, eEndB)
            index = index + 1
            pointSizes:AddUnique(startPoint)
            pointSizes:AddUnique(endPoint)
            if bCreate then
                self.dataT[index] = value
            end
        end
    end
    if self.vertices:Num() == 0 then
        return false
    end
    self.PMesh:CreateMeshSection(0, self.vertices, self.indices, nil, nil, nil, nil, false)
    self.PMesh:SetMaterial(0, LoadObject('/Game/SandBox/Materials/M_Bai.M_Bai'))
    self:SetPoint(pointSizes)
    if bCreate then
        local o, b = UE.UKismetSystemLibrary.GetComponentBounds(self.PMesh)
        o = -o
        o.z = 2
        self.cadOffset = o
    end
    self.PMesh:K2_SetRelativeLocation(self.cadOffset, false, nil, false)
    self:IsShowPoints(false)
    self:SetBoxCollsion()
    self:TrackArea()
    return true
end

function M:SetCADFromBin(binPath, bCreate)
    print("[SetCADFromBin] 开始执行, bCreate = " .. tostring(bCreate))
    if self.cadFullPath == "" then
        self.cadFullPath = binPath
    end
    print("[SetCADFromBin] 文件存在，开始解析")
    --  PMesh:LoadCad
    self.PMesh:LoadCad(binPath)
    local mat = LoadObject('/Game/SandBox/Materials/M_Bai.M_Bai')
    for i = 1, self.PMesh:GetNumMaterials() do
        self.PMesh:SetMaterial(i - 1, mat)
    end

    if bCreate then
        local o, b = UE.UKismetSystemLibrary.GetComponentBounds(self.PMesh)
        o = -o
        o.z = 2
        self.cadOffset = o
    end
    self.PMesh:K2_SetRelativeLocation(self.cadOffset, false, nil, false)
    self:IsShowPoints(false)
    self:SetBoxCollsion()
    self:TrackArea()

    -- CAD 加载完成后，确保保存到项目指定文件夹并上传（如果 bCreate 为 true）
    if self.cadPath == "" then
        print("[SetCADFromBin] bCreate 为 true，开始复制文件")
        local ok, fullPath, relPath = self:EnsureLocalCadBin()
    end
    if self.cadUrl == "" then
        self:UploadCadBin()
    end

    print("[SetCADFromBin] 执行完成")
end

function M:ExpandedEdges(startPoint, endPoint)
    local edge = endPoint - startPoint
    edge:Normalize()
    --  计算法线向量
    local normal = UE.FVector(-edge.Y, edge.X, 0)
    local eStartA = startPoint + normal * self.shrinkDistance
    local eEndA = endPoint + normal * self.shrinkDistance
    local eStartB = startPoint - normal * self.shrinkDistance
    local eEndB = endPoint - normal * self.shrinkDistance
    return eStartA, eEndA, eStartB, eEndB
end

function M:IsShowCad(bShow)
    if bShow ~= nil then
        self.bShow = bShow
    end
    self.PMesh:SetVisibility(self.bShow, false)
end

function M:PointArray(index, eStartA, eEndA, eStartB, eEndB)
    self.vertices:Add(eStartA)
    self.vertices:Add(eEndA)
    self.vertices:Add(eEndB)
    self.vertices:Add(eStartB)
    self.indices:Add(0 + index * 4)
    self.indices:Add(1 + index * 4)
    self.indices:Add(2 + index * 4)
    self.indices:Add(0 + index * 4)
    self.indices:Add(2 + index * 4)
    self.indices:Add(3 + index * 4)
end

function M:SetPoint(pointSizes)
    for key, value in pairs(pointSizes) do
        -- 调用UE方法优势不用设计碰撞通道
        self:AddPoint(value)
    end
end

function M:IsShowPoints(bShow)
    if bShow then
        self.InstancedPoint:SetVisibility(true, true)
    else
        self.InstancedPoint:SetVisibility(false, true)
    end
end

function M:SetBoxCollsion()
    local o, b = UE.UKismetSystemLibrary.GetComponentBounds(self.PMesh)
    -- self.PMesh:K2_SetRelativeLocation(o, false, nil, false)
    self.Box:SetBoxExtent(b, true)
end

function M:TrackArea()
    if not self.modelManage then
        local mmClass = LoadClass(Class.modelManage)
        self.modelManage = UE.UGameplayStatics.GetActorOfClass(self:GetWorld(), mmClass)
    end
    -- 获取区域边界框
    local o, b = self:GetActorBounds(true)
    -- 执行盒体碰撞检测
    local outHits = UE.TArray(UE.FHitResult())

    UE.UKismetSystemLibrary.BoxTraceMulti(
        self:GetWorld(), o, o, b, UE.FRotator(0, 0, 0),
        UE.ETraceTypeQuery.Floor, true, nil, 0, outHits, true
    )
    -- 处理碰撞结果
    local maxZ = 2          -- 初始化最大z值为当前cad生成的值
    local highestArea = nil -- 存储z值最高的area对象

    for _, value in pairs(outHits) do
        local area = value.HitObjectHandle.Actor:Cast(LoadClass(self.modelManage.class[6]))
        if area then
            -- 获取area的碰撞盒并提取z坐标
            local o, b = area:GetActorBounds(true)
            local currentZ = o.z + b.z

            -- 比较并更新最大z值
            if currentZ > maxZ then
                maxZ = currentZ
                highestArea = area
            end
        end
    end
    -- 此时maxZ变量中存储了检测到的area对象中的最高z坐标值
    -- 使用maxZ设置当前actor的高度
    local currentLocation = self:K2_GetActorLocation()
    local newLocation = UE.FVector(currentLocation.X, currentLocation.Y, maxZ + 2)
    self:K2_SetActorLocation(newLocation, false, nil, false)
end

return M
