--
-- DESCRIPTION
--
-- @COMPANY **
-- @AUTHOR **
-- @DATE ${date} ${time}
--
---@class UI_SandBox_C
local M = UnLua.Class()
local Screen = require("SandBox.Screen")
local Model = require("SandBox.ModelNameInitialize")
local Json = require("dkjson")
local JLH = UE.UJsonLibraryHelpers
local KSysL = UE.UKismetSystemLibrary
local AMH = UE.UFlibAssetManageHelper
local KStrL = UE.UKismetStringLibrary
local BFL = UE.UMyBFL
local http = require("socket.http")
local ltn12 = require("ltn12")
local MFL = require("Framework.FunctionLibrary.MessageFunctionLibrary")
local Api = require("SandBox.Api")
local Class = require("SandBox.Class")
local DFL = require("SandBox.DataFunction")

function M:Initialize(Initializer)
    self.headers = UE.TMap("", "")
    self.Actors = UE.TMap("", UE.AActor)
    self.ChildActors = UE.TMap("", UE.AActor)
    self.AllSTAs = UE.TArray(UE.AActor)
    self.PopupS = UE.TArray(UE.AActor)
    self.loopAnimation = {}                          -- 循环动画间隔播放表
    self.NLSAs = UE.TMap("", UE.ALevelSequenceActor) -- 场景动画存储
    self.autoSaveNum = 100                           -- 自动保存方案数量
    self.isTeamScheme = false                        -- 是否为团队方案（由前端通过 IsTeamScheme API 同步）
end

-- function M:PreConstruct(IsDesignTime)
-- end

function M:Construct()
    self.pc = UE.UGameplayStatics.GetPlayerController(self:GetWorld(), 0):Cast(LoadClass(Class.hyPC))
    self.pawn = UE.UGameplayStatics.GetPlayerpawn(self:GetWorld(), 0):Cast(LoadClass(Class.hyPawn))
    local undoClass = LoadClass(Class.undoClass)
    self.undo = self:GetWorld():SpawnActor(undoClass, UE.FTransform(), UE.ESpawnActorCollisionHandlingMethod.Default,
        self, self, "")
    self.control = self:GetWorld():SpawnActor(LoadClass(Class.control), UE.FTransform(),
        UE.ESpawnActorCollisionHandlingMethod.Default, self, self, "")
    self.pawn.ui = self
    self.control.ui = self
    self.control.pawn = self.pawn
    self.undo.ui = self
    self.control.undo = self.undo
    self.undo.control = self.control
    self.UI_BG.parentUi = self
    self.UI_BM.parentUi = self

    if self.pc.bDevMode then
        self.WebSandBox:SetEnabledDevTool(true)
    end
    UnLua.Ref(self)

    self.webTip = {
        ["信息标注"] = "右下方填写配置，点击生成",
        ["阵列"] = "左方阵列窗口填写配置，点击预览模拟生成效果，看效果确认是否生成",
        ["动画配置"] = "左方动画窗口填写配置，选择动画状态看效果"
    }

    Api.Object = self

    -- self.ButtonVision.OnClicked:Add(self, self.NoShowVision)
    -- 连接 UI 元素到对应的函数
    -- 像素流送改造
    if self.pc.gi.showMode == 2 then -- pixel streaming
        self.WebSandBox:SetVisibility(1)
        self.CP:SetVisibility(1)
        local PCClass = LoadClass("/Game/SandBox/BasicConfig/Gameplay/pc.PC_C")
        self.pc = UE.UGameplayStatics.GetPlayerController(self:GetWorld(), 0):Cast(PCClass)
        self.pc.PSComp.OnInputEvent:Add(self, self.BindPS)
        -- self.pc.PSComp.OnStreamerInited:Add(self, self.addNullPlan)
    else
        local url = BFL.GetExeURL("sandBoxIp")
        local SaveToken = UE.UBlueprintPathsLibrary.ProjectDir() .. "Content/config.json"

        if UE.UBlueprintPathsLibrary.FileExists(SaveToken) then
            local jsonTable = Json.decode(BFL.ReadFile(SaveToken))
            local token = jsonTable.token
            local allUrl = url .. "/phantomIndex/planManage?token=" .. token

            self.WebSandBox:LoadURL(allUrl)
            Screen.Print("加载地址：" .. allUrl)

            self.WebSandBox.OnInterfaceEvent:Add(self, self.BindSandBox)
            self.M_Loading = LoadObject("/Game/Movies/LoadingM.LoadingM"):Cast(UE.UMediaPlayer)
            self.MS = LoadObject("/Game/Movies/Loading.Loading"):Cast(UE.UMediaSource)
            self.bLoad = self.M_Loading:OpenSource(self.MS)

            coroutine.resume(coroutine.create(function()
                KSysL.Delay(self, 0.5)
                -- 添加定时器检测
                local retryCount = 0
                local maxRetries = 5
                while retryCount < maxRetries do
                    if self.WebSandBox:GetURL() == "" then
                        retryCount = retryCount + 1
                        self.WebSandBox:LoadURL(allUrl)
                        Screen.Print("加载地址丢失，第" .. retryCount .. "次重试")
                        Screen.Print("重新加载地址：" .. allUrl)
                        if retryCount < maxRetries then
                            KSysL.Delay(self, retryCount)
                        end
                    else
                        break -- 地址已存在，退出循环
                    end
                end
                if retryCount >= maxRetries and self.WebSandBox:GetURL() == "" then
                    Screen.Print("已达到最大重试次数(" .. maxRetries .. ")，加载仍失败")
                end
            end), self)
        else
            self.Image:SetVisibility(1)
        end
        -- --启动器判断
        -- self:SynchronousToken()
    end

    --- 本地文件配置变量
    self.bAutoSave = true
    self.autoSaveTime = 300
    self:LoadConfig()
end

-- function M:Tick(MyGeometry, InDeltaTime)
-- end
------------------------ 通信方式 -----------------
-- 像素流送改造
function M:BindPS(descriptor)
    local dataStr = MFL.PixelStreamCommunication(descriptor, self.control)
    if dataStr then
        self.pc.psComp:SendPixelStreamingResponse(dataStr)
    end
end

-- 绑定 Sandbox 操作的回调函数
function M:BindSandBox(name, data, callback)
    MFL.CEFCommunication(name, data, callback, Api)
end

---统一调用前端方法
---@param text string 调用方法名称
---@param data table 传输数据表
---@warning 根据showMode选择不同的通信方式
--- ShowMessage 出提示 1 2 3
-- loaddraw 上传cad 状态
-- RealTimeData CAD坐标轴拖动数据
-- Frontdisabled 禁用顶部工具栏
function M:UECallWeb(text, data, bStr)
    if self.pc.gi.showMode == 2 then -- 像素流模式
        MFL.PixelCallWeb(self.pc.psComp, text, data)
    else
        if bStr then
            MFL.CallWebString(self.WebSandBox, text, data)
        else
            MFL.CallWeb(self.WebSandBox, text, data)
        end
    end
end

------------------------------------ 初始操作 -----------------------------
--- 网页加载完成回调
--- @param dataTable table 网页传输数据
function M:WebLoadOver(dataTable)
    -- 版本信息同步
    self:UECallWeb("currentVersion", { version = DFL.version })

    -- 启动延迟关闭加载的协程
    coroutine.resume(
        coroutine.create(function()
            UE.UKismetSystemLibrary.Delay(self, 2) -- 使用引擎延时系统
            self.CP:SetVisibility(1)               -- 关闭加载界面
        end),
        self)
end

--- 用户登录处理
--- @param dataTable table 登录凭证数据表（通常包含token/用户信息）
function M:Login(dataTable)
    -- 遍历并注入请求头参数（用于后续API鉴权）
    for k, v in pairs(dataTable) do
        self.headers:Add(k, v) -- 填充HTTP请求头字段
    end
    -- 初始化用户计划状态
    self:NullPlan() -- 重置为无方案状态/清理旧数据
end

function M:Quit(dataTable)
    self.control:QuitSetModel()
    self.WebSandBox.OnInterfaceEvent:Remove(self, self.BindSandBox)
    self.control:CancelDownload(true)
    self.control:CancelDownload(false)
    coroutine.resume(
        coroutine.create(
            function()
                UE.UKismetSystemLibrary.Delay(self, 0.5)
                self.WebSandBox:RemoveFromParent()
                KSysL.ExecuteConsoleCommand(self, "exit")
            end
        ),
        self
    )
end

--------------------------------  模型文件上传主入口函数  --------------------------
--- 模型文件上传
--- @param dataTable table 预留参数表（当前版本未实际使用，保留用于未来扩展）
function M:WebUpLoad(dataTable)
    -- 弹出系统文件选择对话框，限定支持的三维文件格式
    -- 文件类型过滤器说明：
    -- 第一组：三维模型文件（fbx/obj/stl）
    -- 第二组：STEP工程文件（stp/step）
    -- 第三组：压缩包文件（zip）
    self.modelPath = BFL.SelectFile(
        "3D Files (*.fbx, *.obj, *.stl)|*.fbx;*.obj;*.stl|stp Files(*.stp,*.step)|*.stp;*.step|Zip Files(*.zip)|*.zip")

    -- 路径有效性检测（用户未取消选择时进入处理流程）
    if self.modelPath ~= "" then
        -- 工程目录获取（返回示例：D:/UnrealProjects/MyProject/）
        self.ProjectDir = UE.UBlueprintPathsLibrary.ProjectDir()

        -- 路径转换处理（将相对路径转换为绝对路径）
        -- 示例输入："Content/Model/character.fbx" → 输出："D:/Project/Content/Model/character.fbx"
        self.modelPath = UE.UBlueprintPathsLibrary.ConvertRelativePathToFull(self.modelPath, "")

        -- 构造元数据表（包含认证头信息和模型路径）
        local jsonTable = {
            Headers = self.headers:ToTable(), -- 转换headers对象为Lua table，包含鉴权token等信息
            ModelPath = self.modelPath        -- 标准化后的完整文件路径
        }

        -- 序列化配置数据为JSON字符串
        local jsonStr = Json.encode(jsonTable)

        -- 写入临时配置文件（用于外部进程读取）
        -- 文件路径：工程目录/Shot/model.txt
        -- 写入模式3 = 覆盖写入（若文件已存在则替换）
        local filePath = self.ProjectDir .. "Shot/model.txt"
        BFL.WriteFile(jsonStr, filePath, 3)

        -- 启动离屏渲染进程（用于模型预览图生成）
        -- 可执行文件路径：工程目录/Shot/modelRecordingEnv.exe
        -- 启动参数说明：
        -- -RenderOffScreen : 无界面渲染模式
        -- -ResX=600 -ResY=600 : 设置渲染分辨率600x600
        print("启动渲染进程：" .. self.ProjectDir .. "Shot/modelRecordingEnv.exe")
        BFL.OpenProcedure(self.ProjectDir .. "Shot/modelRecordingEnv.exe", "-RenderOffScreen -ResX=600 -ResY=600")

        -- 创建定时检测器（每秒检测一次渲染进程状态）
        -- 定时器委托绑定格式：{ 对象self, 回调方法CheckRunShot }
        -- 参数说明：
        -- 回调间隔：1秒
        -- 是否循环：true（直到手动清除或进程结束）
        self.checkShotTimer = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.CheckRunShot }, 1, true)
    else
        -- 用户取消选择时的错误处理
        -- 构造错误响应表（type=0表示用户取消操作）
        self.upTable = { type = 0 }

        -- 通过Web接口回调通知前端
        -- 接口名："UEUpLoad"
        -- 参数：包含错误类型的响应表
        self:UECallWeb("UELoadUp", self.upTable)
    end
end

--- 定时检测渲染进程状态
function M:CheckRunShot()
    if not BFL.IsProcedureRunning() then
        -- 清理定时器资源
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.checkShotTimer)

        -- 读取渲染输出结果
        local filePath = self.ProjectDir .. "Shot/Save.txt"
        local str = BFL.ReadFile(filePath)
        self.upTable = Json.decode(str)

        -- 根据结果类型分流处理
        if self.upTable.type == 6 then -- 类型6表示需要上传模型文件
            -- 构造异步上传请求
            local postRequest = UE.UAsyncHTTPUPLoad.AsyncHttpURLRequest(
                self.modelPath,
                BFL.GetExeURL("RearIP") .. "/dts-cloud-island-file/upload",
                self.headers
            )
            -- 绑定回调事件
            postRequest.OnSucceeded:Add(self, self.ModelUpLoad_Success)
            postRequest.OnFailed:Add(self, self.ModelUpLoad_OnFail)
        else
            -- 其他类型直接返回结果
            self:UECallWeb("UELoadUp", self.upTable)
        end
    end
end

--- 模型上传成功回调
--- @param responseData string 服务端响应数据
--- @param responseCode number HTTP状态码
function M:ModelUpLoad_Success(responseData, responseCode)
    print(responseData)
    local table = Json.decode(responseData)
    self.upTable.modelContent = table -- 追加模型元数据

    -- 提取并构造本地存储路径
    local downModelName = string.match(table.data.url, ".-([^\\/]-%.?[^%.\\/]*)$")
    local path = UE.UBlueprintPathsLibrary.ProjectDir() .. "model/" .. downModelName

    -- 启动模型下载流程
    self.control:DownloadModel(path, table.data.url, false)

    -- 最终结果回调
    self:UECallWeb("UELoadUp", self.upTable)
end

--- 模型上传失败统一处理
function M:ModelUpLoad_OnFail()
    self:UECallWeb("UELoadUp", self.upTable)
end

function M:FindModelPath(Path, str)
    local filepaths = UE.UMyBFL.GetFolderFiles(Path)
    for key, file in pairs(filepaths) do
        if string.lower(file):find(str) then
            print(file)
            return file
        end
    end
end

--- 模型查看
-- ([^\\/]-%.?[^%.\\/]*)：匹配一个捕获组，其中包含以下内容：
-- [^\\/]-：匹配任意字符，直到遇到下一个模式，但不包括反斜杠（\）和正斜杠（/）。
-- %.：匹配一个点（.）字符。
-- ?：表示前面的模式是可选的。
-- [^%.\\/]*：匹配任意字符，直到遇到下一个模式，但不包括点（.）、反斜杠（\）和正斜杠（/）。
-- $：表示字符串的结尾
function M:LookModel(dataTable)
    local downloadModelName = string.match(dataTable.url, ".-([^\\/]-%.?[^%.\\/]*)$")
    local bExists, path = self.control:DownModelTrace(downloadModelName)
    local bSuccess, ErrorMsg
    if bExists then
        local Extension = string.match(path, "^.+(%..+)$")
        if Extension == ".zip" then
            path = string.match(path, "(.+)%..+")
            for key, value in pairs(DFL.modelType) do
                local modelPath = self:FindModelPath(path, key)
                if modelPath then
                    path = path .. "/" .. modelPath
                    break
                end
            end
        end
        path = UE.UBlueprintPathsLibrary.ConvertRelativePathToFull(path, "")
        print(path)
        bSuccess, ErrorMsg = BFL.ExecuteExternalApp(path)
        if bSuccess then
            return { bSuccess = true, ErrorMsg = "模型查看成功" }
        else
            return { bSuccess = false, ErrorMsg = ErrorMsg }
        end
    else
        return { bSuccess = false, ErrorMsg = "本地不存在该模型文件" }
        -- local JsonVal = JLH.FromString("nofind")
        -- UE.UWebInterfaceHelpers.WebInterfaceCallback_Call(Callback, JsonVal)
    end
end

--------------------------- 自动下载模型 ---------------------
function M:SilentDownload(dataTable)
    if dataTable then
        local t = self.control:DownloadTrace(dataTable, false)
        return t
    end
end

---@param Nub "数字 1是下载失败，2是保存失败，3是目录创建失败，4是地址无效，5是保存路径无效,6解压失败"
function M:DownloadFeedback(Nub)
    self:UECallWeb("DownloadOut", Nub)
end

function M:DownloadOver(jsonTable)
    self:UECallWeb("DownloadOver", jsonTable)
end

-------------------------------------  方案操作 -------------------------------------
--- 初始化空方案（重置场景状态）
function M:NullPlan()
    -- 调试日志标记
    print("AddNullPlan")

    -- 设置Pawn视角模式为3D视图
    -- 参数说明：
    -- "3d" - 指定使用三维视角模式
    self.pawn:ChooseViewData("3d")

    -- 显示区域边界（1表示可见）
    self.B_Area:SetVisibility(1)

    -- 显示操作提示UI（1表示可见）
    self.B_Tip:SetVisibility(1)

    -- 调用控制器执行空方案逻辑
    -- 参数说明：
    -- true - 表示完全重置状态
    self.control:NullPlan(true)
end

--- 加载存档方案（直接加载模式）
--- 适用于本地已存在完整数据文件的快速加载场景
--- @param dataTable table 存档数据表，包含需要加载的存档信息
function M:OldLoadPlan(dataTable)
    -- 显示场景区域边界（1表示可见状态）
    self.B_Area:SetVisibility(1)

    -- 显示操作提示UI元素（1表示可见状态）
    self.B_Tip:SetVisibility(1)

    -- 调用控制器执行实际加载逻辑
    -- 参数说明：
    -- dataTable - 包含完整存档数据的结构体
    self.control:LoadData(dataTable)
end

--- 加载存档方案（远程下载模式）
--- 适用于需要从服务器下载存档文件的场景
--- @param dataTable table 存档数据表，必须包含path字段（远程文件路径）
function M:NewLoadPlan(dataTable)
    -- 构造本地存储路径（工程目录/download/文件名）
    -- 使用正则从远程路径提取文件名：
    -- 示例输入："http://server.com/archives/plan1.json" → 输出："plan1.json"
    local filePath = UE.UBlueprintPathsLibrary.ProjectDir() .. "download/" ..
        string.match(dataTable.path, ".-([^\\/]-%.?[^%.\\/]*)$")
    self.control.bLoadPlan = true

    -- 执行本地化加载流程
    -- 参数说明：
    -- filePath - 本地存储路径（如：D:/Project/download/plan1.json)
    -- dataTable.path - 原始远程路径（用于下载失败时重试）
    self:LoadLocalData(filePath, dataTable.path)
end

--- 加载本地数据文件并处理
--- @param filePath string 本地文件路径（绝对路径）
--- @param path string 远程文件路径（相对路径，可选）
function M:LoadLocalData(filePath, path)
    local content = ""
    if UE.UBlueprintPathsLibrary.FileExists(filePath) then
        content = UE.UMyBFL.ReadFile(filePath)
        if content == "" then
            return
        end
    else
        if path then
            local url = UE.UMyBFL.GetExeURL("RearIP") .. path
            print("下载文件: " .. url)
            UE.UFileToStorageDownloader.DownloadFileToStorage(url, filePath, 0, "", false, nil,
                { self, self.LoadComplete })
            self.filePath = filePath
            return
        end
        return
    end

    local data, pos, err = Json.decode(content, 1, nil)
    if err then
        return
    end

    -- 显示UI元素
    self.B_Area:SetVisibility(1) -- 显示场景区域
    self.B_Tip:SetVisibility(1)  -- 显示操作提示

    -- 数据内容处理
    if data.modelRelated then
        -- 加载模型相关数据
        self.control:LoadData(data.modelRelated)
    else
        -- 数据无效时初始化空方案
        self:addNullPlan()
    end


    -- 应用动画配置
    self.control:AnimationConfig(data)
    self.contentValue = data.contentValue
    self.control:LoadRegionData(data.contentValue)
end

--- 下载完成回调处理
--- @param Result number 下载结果（0表示成功）
function M:LoadComplete(Result)
    print("下载方案结果" .. Result)
    if Result == 0 then
        -- 下载成功，重新尝试加载本地文件
        self:LoadLocalData(self.filePath, nil)
    else
        if UE.UBlueprintPathsLibrary.FileExists(self.filePath) then
            UE.UMyBFL.DeleteFile(self.filePath)
        end
        -- 下载失败处理（可添加错误提示）
        -- UE.UWebInterfaceHelpers.WebInterfaceCallback_Call(Callback, Jsonval)
    end
end

-- 弃用
-- function M:AnimationConfig(dataTable)
--     -- local jsonStr = JLH.JsonValue_Stringify(Data)
--     -- local jsonTable = Json.decode(jsonStr)
--     -- self.control:AnimationConfig(jsonTable)
-- end

--- 保存场景方案主入口函数
--- @param dataTable table 包含保存参数的表结构：
---   planName: 方案名称
---   sandboxSchemeId: 方案ID（0表示新建方案）
---   userId: 用户标识
function M:SavePlan(dataTable)
    -- 初始化保存参数
    self.planName = dataTable.planName
    self.planId = dataTable.sandboxSchemeId
    self.userId = dataTable.userId

    -- ID有效性处理（0值转为nil）
    if self.planId == 0 then
        self.planId = nil
    end


    -- 执行核心保存逻辑（延迟1秒，避免 RegionInner 导入/清理等异步数据未就绪）
    coroutine.resume(
        coroutine.create(function()
            if self.control.drawMode == "RegionInner" then
                self:NewLoadPlan({ path = self.path })
                KSysL.Delay(self, 1)
                self.control:ClearRegionInModels()
                KSysL.Delay(self, 1)
                self.control:ImportLocalRegionData()
                KSysL.Delay(self, 1)
            end

            self:SaveData(self.planName, self.planId, self.userId)
        end),
        self)
end

--- 执行实际数据保存操作
--- @param planName string 方案名称
--- @param planId number|nil 方案ID（nil表示新建）
--- @param userId string 用户标识
function M:SaveData(planName, planId, userId)
    -- 从控制器获取序列化数据
    local saveTable = self.control:SaveData(planName, planId, userId)
    -- 注意：保存回调是异步的，不能把 contentValue 放到 self 上（多次保存会互相覆盖导致串包）
    local contentValue = saveTable.contentValue
    local jsonString = Json.encode(saveTable)

    -- 构造API请求URL
    local url = BFL.GetExeURL("RearIP") .. "/phantom-platform-data/v1.95/sandboxScheme/uploadJsonFile"
    self.bSaveWait = false -- 重置等待标志

    -- 创建HTTP上传请求
    local postRequest = UE.UAsyncHTTPUPLoad.CustomizeHttpRequest(jsonString, url, self.headers)
    postRequest.OnSucceeded:Add(self, function(_, content, statusCode)
        self:SaveOverToWeb(content, statusCode, contentValue)
    end)
    postRequest.OnFailed:Add(self, function(_, content, statusCode)
        self:SaveOverToWeb(content, statusCode, contentValue)
    end)
    local delayTime = 5 + 2 * math.ceil(self.control.modelManage:GetModelNum() / 500)
    -- 设置超时检测协程（5秒超时）
    coroutine.resume(coroutine.create(function()
        KSysL.Delay(self, delayTime)
        if not self.bSaveWait then
            self:SaveOverToWeb(nil, nil, contentValue)
            print("保存超时")
        end
    end), self)

    print("数据保存请求已发送")
end

--- 保存完成回调处理
--- @param content string|nil 服务器响应内容（可能为空/超时）
--- @param statusCode number|nil HTTP状态码（可能为空/超时）
--- @param contentValueOverride string|nil 本次请求对应的 contentValue（避免并发保存串包）
function M:SaveOverToWeb(content, statusCode, contentValueOverride)
    Screen.Print("保存结果" .. tostring(content))
    self.bSaveWait = true -- 标记已完成
    local data = nil
    if content and content ~= "" then
        data = Json.decode(content)
    end
    if type(data) ~= "table" then
        data = {
            success = false,
            statusCode = statusCode,
            message = content and tostring(content) or "Save request timeout or empty response"
        }
    end
    data.contentValue = contentValueOverride or self.contentValue
    -- 通过像素流通知前端
    self:UECallWeb("Save", data)
end

--- 保存后处理（截图上传流程）
--- @param dataTable table 包含方案ID的响应数据
function M:SaveReturn(dataTable)
    -- 更新方案ID（保持原有或使用新ID）
    self.planId = dataTable.sandboxSchemeId == 0 and self.planId or dataTable.sandboxSchemeId

    -- 清理截图目录
    local shotPath = UE.UBlueprintPathsLibrary.ScreenShotDir()
    local TPs = BFL.GetFolderFiles(shotPath)
    for _, filename in pairs(TPs) do
        os.remove(shotPath .. filename)
    end

    -- 执行场景截图命令
    KSysL.ExecuteConsoleCommand(self:GetWorld(), "ScreenShot")

    -- 延迟处理截图上传（0.4秒等待截图生成）
    coroutine.resume(coroutine.create(function()
        KSysL.Delay(self, 0.4)
        TPs = BFL.GetFolderFiles(shotPath)
        if TPs:Num() == 0 then
            self:SaveImage(self.planId, "")
            return
        end
        local Path = shotPath .. TPs[1] -- 获取最新截图

        if UE.UBlueprintPathsLibrary.FileExists(Path) then
            -- 构造截图上传请求
            local uploadUrl = BFL.GetExeURL("RearIP") .. "/dts-cloud-island-file/upload"
            local postRequest = UE.UAsyncHTTPUPLoad.AsyncHttpURLRequest(Path, uploadUrl, self.headers)
            postRequest.OnSucceeded:Add(self, self.UpLoad_Success)
            postRequest.OnFailed:Add(self, self.UpLoad_OnFail)
        else
            self:SaveImage(self.planId, Path)
        end
    end), self)
end

--- 截图上传成功回调
--- @param responseData string 服务器响应JSON
--- @param responseCode number HTTP状态码
function M:UpLoad_Success(responseData, responseCode)
    print("图片保存成功", responseData)

    -- 解析响应获取图片URL
    local Jv = JLH.Parse(responseData)
    local Jo = JLH.ToObject(Jv)
    local Jv2 = JLH.JsonObject_GetValue(Jo, "data")
    local Jo2 = JLH.ToObject(Jv2)
    local url = JLH.JsonObject_GetString(Jo2, "url")

    -- 保存图片关联信息
    self:SaveImage(self.planId, url)
end

--- 截图上传失败回调
--- @param responseData string 错误信息
--- @param responseCode number HTTP状态码
function M:UpLoad_OnFail(responseData, responseCode)
    print("图片保存失败", responseData, responseCode)
end

--- 保存图片关联信息到方案
--- @param planId number 方案ID
--- @param url string 图片URL
function M:SaveImage(planId, url)
    -- 构造图片关联数据
    local saveTable = {
        sandboxSchemeId = planId,
        sandboxSchemeImage = url,
    }
    print("图片关联信息准备保存")
    -- 实际保存逻辑可在此扩展...
    self:UECallWeb("SaveImage", saveTable)
end

function M:ButtonSave()
    self:UECallWeb("ButtonSave", nil)
end

function M:ButtonSaveAs()
    self:UECallWeb("ButtonSaveAs", nil)
end

----------------------------- 本地配置读取 -----------------------------
function M:LoadConfig()
    local localSave = UE.UBlueprintPathsLibrary.ProjectDir() .. "autosave/config.json"
    if UE.UBlueprintPathsLibrary.FileExists(localSave) then
        local str = UE.UMyBFL.ReadFile(localSave)
        local jsonT = Json.decode(str)
        if jsonT then
            self.pawn.viewportPanning = jsonT.ViewportPanning or self.pawn.viewportPanning
            self.pawn.viewportScaling = jsonT.ViewportScaling or self.pawn.viewportScaling
            self.autoSaveTime = jsonT.AutoSaveTime or self.autoSaveTime
            if jsonT.AutoSaveTF ~= nil then
                self.bAutoSave = jsonT.AutoSaveTF
            end
        end
    end
end

function M:SaveUELocal(dataTable)
    self.pawn.viewportPanning = dataTable.ViewportPanning or self.pawn.viewportPanning
    self.pawn.viewportScaling = dataTable.ViewportScaling or self.pawn.viewportScaling
    self.autoSaveTime = dataTable.AutoSaveTime or self.autoSaveTime
    if dataTable.AutoSaveTF ~= nil then
        self.bAutoSave = dataTable.AutoSaveTF
    end
    self:SaveConfig()
    if self.bAutoSave then
        self:AutoSavePlan()
        self:EnableAutoSave()
    end
end

function M:SaveConfig()
    local saveTable = {
        ViewportPanning = self.pawn.viewportPanning,
        ViewportScaling = self.pawn.viewportScaling,
        AutoSaveTime = self.autoSaveTime,
        AutoSaveTF = self.bAutoSave
    }
    local jsonString = Json.encode(saveTable)
    local localSave = UE.UBlueprintPathsLibrary.ProjectDir() .. "autosave/config.json"
    BFL.WriteFile(jsonString, localSave, 3)

    if self.GroupsTimer then
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.GroupsTimer)
    end
end

----------------------- 自动保存与配置项 -----------------------
function M:LoadUELocal(dataTable)
    local id = {
        ViewportPanning = self.pawn.viewportPanning,
        ViewportScaling = self.pawn.viewportScaling,
        AutoSaveTime = self.autoSaveTime,
        AutoSaveTF = self.bAutoSave
    }
    return id
end

--- 自动保存配置处理
--- @param dataTable table 包含自动保存参数的表格，需包含以下字段：
---   - planName (string) 方案名称
---   - sandboxSchemeId (number) 沙盒方案ID
---   - userId (number) 用户标识
function M:AutoSave(dataTable)
    -- 缓存关键配置参数
    self.planName = dataTable.planName      -- 当前操作方案名称
    self.planId = dataTable.sandboxSchemeId -- 沙盒环境方案ID
    self.userId = dataTable.userId          -- 用户唯一标识

    -- 自动保存开关检测
    if self.bAutoSave then    -- bAutoSave (自动保存开关标志)
        self:EnableAutoSave() -- 触发定时保存任务
    end
end

function M:IsCanAutoSave(dataTable)
    -- 缓存关键配置参数
    self.bCanAutoSave = dataTable.bCanAutoSave -- 当前操作方案是否支持自动保存
end

--- 激活自动保存定时器
--- 通过虚幻引擎的定时器系统启动周期性保存任务
function M:EnableAutoSave()
    self.autoSaveTimer = UE.UKismetSystemLibrary.K2_SetTimerDelegate(
        { self, self.AutoSavePlan }, -- 绑定对象方法与回调
        self.autoSaveTime,           -- 通常从配置表读取
        true                         -- 循环执行标志位
    )
end

--------- 自动保存核心代码 ---------
function M:AutoSavePlan()
    if self.bCanAutoSave ~= nil and not self.bCanAutoSave then
        return
    end
    local saveTable = self.control:SaveData(self.planName, self.planId, self.userId)
    local jsonString = Json.encode(saveTable)
    -- 保存到本地
    local folderPath = UE.UBlueprintPathsLibrary.ProjectDir() .. "autosave"
    folderPath = UE.UBlueprintPathsLibrary.ConvertRelativePathToFull(folderPath, "")
    local localSave = folderPath .. "/autosave_" .. self.planName .. "_" .. self.planId .. "_" .. os.time() .. ".json"

    local files = UE.UMyBFL.GetFolderFiles(folderPath)
    local fileT = {}
    for k, v in pairs(files) do
        if string.find(v, "autosave") ~= nil then
            -- 查找最后一个下划线的位置
            local bool, lstr, rstr = UE.UKismetStringLibrary.Split(v, "_", nil, nil, 1, 1)
            -- 提取时间戳部分
            local time = string.gsub(rstr, ".json", "") -- 1598515200
            time = time and tonumber(time) or 0
            table.insert(fileT, { time = time, file = v })
        end
    end
    -- 获取最早修改的文件
    if #fileT >= self.autoSaveNum then
        table.sort(fileT, function(a, b) return a.time < b.time end)

        -- 删除最早修改的文件
        UE.UMyBFL.DeleteFile(string.format('%s/%s', folderPath, fileT[1].file))
        -- os.remove(string.format('%s/%s', folderPath, oldestFile))
        print(string.format('Deleted oldest file: %s', fileT[1].file))
    else
        print('No matching files found.')
    end
    UE.UMyBFL.WriteFile(jsonString, localSave, 3)
    self:UECallWeb("ShowMessage", {
        Type = 1,
        Text = "自动保存本地成功"
    })
end

----------------------- 自动保存调用 -----------------------
function M:GetAutoSave(dataTable)
    local folderPath = UE.UBlueprintPathsLibrary.ProjectDir() .. "autosave"
    local files = BFL.GetFolderFiles(folderPath)
    local fileT = {}
    for k, v in pairs(files) do
        if string.find(v, "autosave") ~= nil then
            -- 查找最后一个下划线的位置
            local bool, lstr, rstr            = UE.UKismetStringLibrary.Split(v, "_", nil, nil, 1, 1)
            -- local planNameandId      = string.gsub(lstr, "autosave_", "")
            local bool, lstr, sandboxSchemeId = UE.UKismetStringLibrary.Split(lstr, "_", nil, nil, 1, 1)
            -- 提取时间戳部分
            local time                        = string.gsub(rstr, ".json", "") -- 1598515200
            if time and sandboxSchemeId == self.planId then
                table.insert(fileT, { time = tonumber(time), file = v })
            end
        end
    end
    return fileT
end

function M:UseAutoSave(dataTable)
    self.control:NullPlan(true)
    local filePath = UE.UBlueprintPathsLibrary.ProjectDir() .. "autosave/" .. dataTable.file
    self:LoadLocalData(filePath, nil)
end

--------------------------- 撤销库
function M:Undo(dataTable)
    self.undo:Undo()
end

function M:Redo(dataTable)
    self.undo:Redo()
end

function M:RedoStep(nub, num, bClear) -- 像素流送改造
    self:UECallWeb("noRedo", {
        nub = nub,
        num = num,
        bclear = bClear
    })
end

function M:UndoStep(num, redoNum)
    self:UECallWeb("UndoStep", { num = num, redoNum = redoNum })
end

--------------- 模型操作 ----------------
function M:DrawPlace(dataTable)
    self.control:CreateModel("Area", "地板", false)
end

-- 绘制模型的函数
function M:DrawModel(dataTable)
    local Str = self.control:CreateModel(dataTable.modelCode, dataTable.showName, dataTable.modelUrl,
        dataTable.modelCategoryCode, dataTable.isAnimation)
    if self.control.splineMenuUi then
        self.control.splineMenuUi:RemoveFromParent()
        self.control.splineMenuUi = nil
    end
    return { Str }
end

-- 标注
function M:Mapping(dataTable)
    if dataTable.type == 1 then
        self.control:CreateModel("VerticalBZ", "水平标注", false)
    else
        self.control:CreateModel("bz", "尺寸标注", false)
    end
end

-- 删除模型的函数
function M:DeleteModel(dataTable)
    self.control:DeleteModel()
end

-- 处理楼层信息的函数
function M:FloorInfo(dataTable)
    local T = self.control:FloorDataToModel(dataTable)
    if T then
        return T
    end
end

--- 解析模型信息数据并转换为模型参数
--- @param dataTable table 包含模型信息的JSON数据表
function M:ModelInfo(dataTable)
    local t = UE.UKismetMathLibrary.Conv_RotatorToTransform(UE.FRotator(0, dataTable.angle, 0))
    t.Translation = UE.FVector(dataTable.x, dataTable.y, dataTable.z)
    local size = UE.FVector(dataTable.length, dataTable.width, dataTable.height)
    local DT = {
        T = t,
        Size = size,
        showname = dataTable.showname
    }
    self.control:ModelDataToModel(DT)
end

--- 将管道模型数据转换为JSON格式
--- @function PipeInfo
--- @param dataTable table 包含管道模型数据的表
--- @return table 转换后的JSON数据表
function M:PipeInfo(dataTable)
    local L = self.control:ModelDataToModel(dataTable)              -- 转换模型数据
    local T = {}                                                    -- 初始化返回表
    if L then                                                       -- 检查数据有效性
        T = Json.decode(JLH.JsonValue_Stringify(JLH.FromVector(L))) -- JSON序列化处理
    end
    return T                                                        -- 返回处理结果
end

--- 将墙体模型数据转换为JSON格式
--- @function WallInfo
--- @param dataTable table 包含墙体模型数据的表
--- @return table 转换后的JSON数据表
function M:WallInfo(dataTable)
    local L = self.control:ModelDataToModel(dataTable)              -- 转换模型数据
    local T = {}                                                    -- 初始化返回表
    if L then                                                       -- 检查数据有效性
        T = Json.decode(JLH.JsonValue_Stringify(JLH.FromVector(L))) -- JSON序列化处理
    end
    return T                                                        -- 返回处理结果
end

--- 区域信息数据处理函数
--- @function AreaInfo
--- @param dataTable table 包含区域模型数据的输入表
--- @return table 处理后的JSON格式数据表
function M:AreaInfo(dataTable)
    local L = self.control:ModelDataToModel(dataTable)              -- 调用模型数据转换方法
    local T = {}                                                    -- 初始化返回结果表
    if L then                                                       -- 检查数据有效性
        T = Json.decode(JLH.JsonValue_Stringify(JLH.FromVector(L))) -- JSON序列化与反序列化处理
    end
    return T                                                        -- 返回处理结果
end

--- 处理SSX模型信息数据
--- @function SSXInfo
--- @param dataTable table 包含SSX模型数据的输入表
--- @return table 处理后的JSON格式数据表
function M:SSXInfo(dataTable)
    local L = self.control:ModelDataToModel(dataTable)              -- 调用模型数据转换方法
    local T = {}                                                    -- 初始化返回结果表
    if L then                                                       -- 检查数据有效性
        T = Json.decode(JLH.JsonValue_Stringify(JLH.FromVector(L))) -- JSON序列化与反序列化处理
    end
    return T                                                        -- 返回处理结果
end

--- 处理消息数据
--- @function MessageInfo
--- @param dataTable table 包含消息数据的输入表
function M:MessageInfo(dataTable)
    self.control:MessageData(dataTable) -- 将消息数据传递给控制器处理
end

--- 处理分组模型数据
--- @function GroupInfo
--- @param dataTable table 包含分组模型数据的输入表
function M:GroupInfo(dataTable)
    self.control:ModelDataToModel(dataTable) -- 将分组模型数据传递给模型转换方法
end

--- 处理虚线模型数据
--- @function DashedLineInfo
--- @param dataTable table 包含虚线模型数据的输入表
function M:DashedLineInfo(dataTable)
    self.control:ModelDataToModel(dataTable) -- 将虚线模型数据传递给模型转换方法
end

--- 处理垂直线模型数据
--- @function VeratcalLineInfo
--- @param dataTable table 包含垂直线模型数据的输入表
function M:VeratcalLineInfo(dataTable)
    self.control:ModelDataToModel(dataTable) -- 将垂直线模型数据传递给模型转换方法
end

--- 处理通道模型数据
--- @function PassagewayInfo
--- @param dataTable table 包含通道模型数据的输入表
--- @return table 处理后的JSON格式数据表
function M:PassagewayInfo(dataTable)
    local L = self.control:ModelDataToModel(dataTable)              -- 调用模型数据转换方法处理通道数据
    local T = {}                                                    -- 初始化返回结果表
    if L then                                                       -- 检查数据有效性
        T = Json.decode(JLH.JsonValue_Stringify(JLH.FromVector(L))) -- JSON序列化与反序列化处理
    end
    return T                                                        -- 返回处理后的通道数据
end

--- 处理路径模型数据
--- @function PathInfo
--- @param dataTable table 包含路径模型数据的输入表
--- @return table 处理后的JSON格式数据表
function M:PathInfo(dataTable)
    local L = self.control:ModelDataToModel(dataTable)              -- 调用模型数据转换方法处理路径数据
    local T = {}                                                    -- 初始化返回结果表
    if L then                                                       -- 检查数据有效性
        T = Json.decode(JLH.JsonValue_Stringify(JLH.FromVector(L))) -- JSON序列化与反序列化处理
    end
    return T                                                        -- 返回处理后的路径数据
end

--- 区域面积信息处理函数
--- @function AreaAreaInfo
--- @param dataTable table 包含区域颜色和透明度数据的输入表
--- @return table 返回区域使用率数据表
function M:AreaAreaInfo(dataTable)
    local Color = UE.FLinearColor(dataTable.r / 255, dataTable.g / 255, dataTable.b / 255, dataTable.a / 100) -- 创建UE4线性颜色对象(RGB归一化，透明度百分比转换)
    self.CO.SpecifiedColor =
        Color                                                                                                 -- 设置控件的指定颜色
    self.T_value:SetColorAndOpacity(self.CO)                                                                  -- 应用颜色和透明度设置到文本控件
    local table = self.control:AreaUsageRateOut()                                                             -- 调用control层获取区域使用率数据
    return table                                                                                              -- 返回区域使用率数据表
    -- 以下为注释掉的JSON返回逻辑(已废弃):
    -- local jsonStr = Json.encode(table)  -- 将结果表编码为JSON字符串
    -- print(jsonStr)  -- 打印调试信息
    -- local JsonVal = JLH.Parse(jsonStr)  -- 解析JSON字符串为JsonValue对象
    -- UE.UWebInterfaceHelpers.WebInterfaceCallback_Call(Callback, JsonVal)  -- 通过Web接口回调返回数据
end

function M:MaterialInfo(dataTable)
    if dataTable.materialCode and dataTable.materialCode ~= "" then
        self.control:SetModelMaterial(dataTable)
    end
end

function M:PassFloorData(jsonTable)
    self:UECallWeb("floorData", jsonTable, true)
end

function M:SetModelData(jsonTable)
    self:UECallWeb("modelData", jsonTable, true)
end

---@param jsonTable  "里面是数字 1是地板，2是基础模型，3是行业模型，4是管道，5是墙"
function M:ShowBoard(jsonTable)
    self:UECallWeb("showBoard", jsonTable)
end

function M:AddFloor(dataTable)
end

function M:DrawDashedLine(dataTable)
    self.control:CreateModel("DashedLine", "虚线标注", false)
end

-------------------------- 模型提示 -------------------------
function M:ModelTip(dataTable)
    self:ShowModelTip(dataTable.name, self.webTip[dataTable.name])
    self.control.bBuild = false
end

function M:ShowModelTip(NameA, NameB)
    self.B_Tip:SetVisibility(4)
    self.Tip1:SetText(NameA)
    self.Tip2:SetText(NameB)
end

function M:ModelTipHide(dataTable)
    self.B_Tip:SetVisibility(1)
end

--------------- 组操作 ----------------
--- 处理组合操作
--- @function GroupTogether
--- @param _dataTable table 包含组合数据的输入表(当前未使用)
function M:GroupTogether(_dataTable)
    -- local jsonTable = Json.decode(JLH.JsonValue_Stringify(Data))
    -- self.control:GroupTogether(jsonTable)
    self.control:GroupTogether()
end

--- 处理分组拆分操作
--- @function GroupSplit
--- @param dataTable table 包含分组数据的输入表(当前未使用)
function M:GroupSplit(dataTable)
    self.control:GroupSplit(dataTable)
end

----------------- 开始复制操作
--- @function StartCopy
function M:StartCopy()
    self:UECallWeb("StartCopy", nil)
end

--- 批量复制操作处理函数
--- @function BatchCopy
--- @param dataTable table 包含批量复制数据的输入表
function M:BatchCopy(dataTable)
    self.control:BatchCopy(dataTable) -- 调用control层的批量复制方法处理数据
end

--- 模型数组复制功能
--- @function ModelArrayCopy
--- @param dataTable table 包含模型数组数据的输入表
function M:ModelArrayCopy(dataTable)
    self.control:ModelArrayCopy(dataTable)
end

--- 取消模型数组操作功能
--- @function CancelModelArray
--- @param dataTable table 包含需要取消操作的模型数组数据
function M:CancelModelArray(dataTable)
    coroutine.resume(coroutine.create(function()
        KSysL.Delay(self, 0.7)                   -- 延迟0.7秒执行

        self.control:CancelModelArray(dataTable) -- 调用control层取消模型数组操作
    end), self)
end

function M:Copy(dataTable)
    self.control:CopyModelTable(self.control.BatchActors)
end

function M:Paste(dataTable)
    self.control:PasteModelTable()
end

function M:AdvancedCpopy(dataTable)
    self.control:AdvancedCpopy()
end

function M:AdvancedPaste(dataTable)
    self.control:AdvancedPaste()
end

function M:StopCrossCopy(dataTable)
    self.control.CopyTable = {}
end

------------------------- 视角操作 -------------------------------
function M:changeTo2D(dataTable)
    local type = dataTable.type
    local view = dataTable.view
    self.UI_location:switch(false, type, view)
end

function M:changeTo3D(dataTable)
    local type = dataTable.type
    local view = dataTable.view
    self.UI_location:switch(true, type, view)
end

function M:resetView(dataTable)
    self.UI_location:reset()
end

function M:toBig(dataTable)
    if self.control.buildActor then
        self.UI_location:toBig(self.control.buildActor)
    end
end

function M:changeScale(dataTable)
    self.UI_location:zoom(dataTable / 100)
end

function M:ChooseFacade(dataTable)
    self.pawn:ChooseViewData(dataTable)
end

------------------------- 模型列表 ---------------------------
function M:SelectModelMenu(dataTable)
    if #dataTable > 1 then
        self.bWebSel = false
    else
        self.bWebSel = true
    end

    self.control:WebSelActor(dataTable)
end

function M:ClearSelect(dataTable)
    self.control:WebSelActor()
end

function M:ClickModelMenu(dataTable)
    local T = self.control:WebLockActor(dataTable.ID, dataTable.bMove)
    if T then
        return T
        -- local jsonStr = Json.encode(T)
        -- local JsonVal = JLH.Parse(jsonStr)
        -- UE.UWebInterfaceHelpers.WebInterfaceCallback_Call(Callback, JsonVal)
    end
end

--- 模型可见性控制
function M:SetModleVisibility(dataTable)
    -- 调用底层控制接口
    local T = self.control:WebHideActor(dataTable.ID, dataTable.bVisit)
    return T -- 直接返回控制结果给调用方
end

function M:PageSize(dataTable)
    local bNormal = dataTable.dataType ~= "search"

    local t = self.control:TakeRange(dataTable.sizeData, bNormal)
    return t
end

function M:PageSearch(dataTable)
    local t = self.control:TreeSearch(dataTable.searchData)
    return t
end

function M:ShowSel(table)
    if self.bWebSel then
        self.bWebSel = false
        return
    end
    self:UECallWeb("selectModel", table)
    self:UECallWeb("automaticPositioningFun", nil)
end

function M:ShowPanel()
    self:UECallWeb("ShowPanel", nil)
end

--------------------------- 导航栏 ----------------------
function M:BackHome(Data)
    self:addNullPlan()
    self.pawn:SplitScreen(true)
    self.control:CheckInput(false)
    self.control.bCatch = false
    self.UI_location:switch(true, 1, 1)
    if self.GroupsTimer then
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.GroupsTimer)
    end
    if self.pc.gi.showMode == 2 then
        self.control:DisableKeyBoard(true)
    end
    -- self.ButtonVision:SetVisibility(1)
end

function M:addNullPlan(dataTable)
    print("addNullPlan")
    self.B_Area:SetVisibility(1)
    self.B_Tip:SetVisibility(1)
    self.control:NullPlan(true)
    self.pawn:ChooseViewData("3d")
    -- self.pawn:ChooseViewData("3d")
end

function M:DownloadImg(dataTable)
    local Path = BFL.SaveFileNameToFolder("Image Files (*.png)|*.png")
    print(Path)
    if Path ~= "" then
        self.WebSandBox:SetVisibility(1)
        -- 调用 Windows 的截图工具
        Path = UE.UBlueprintPathsLibrary.ConvertRelativePathToFull(Path, "")
        if string.find(Path, "%.png$") == nil then
            Path = Path .. ".png"
        end
        local Color = UE.FLinearColor(1, 1, 1, 1)
        self.CO.SpecifiedColor = Color
        self.T_value:SetColorAndOpacity(self.CO)
        self.control:AreaUsageRateOut()

        coroutine.resume(coroutine.create(function()
            local shotPath = UE.UBlueprintPathsLibrary.ScreenShotDir()
            local TPs = BFL.GetFolderFiles(shotPath)
            for key, value in pairs(TPs) do
                os.remove(shotPath .. value)
            end
            KSysL.Delay(self, 0.1)
            -- KSysL.ExecuteConsoleCommand(self:GetWorld(), "ScreenShot ")
            -- KSysL.Delay(self, 0.2)
            KSysL.ExecuteConsoleCommand(self:GetWorld(), "ScreenShot showui ")
            KSysL.Delay(self, 0.2)
            TPs = BFL.GetFolderFiles(shotPath)
            BFL.ModifyPNG(shotPath .. TPs[1], Path)
            -- local T = self:shotExport(shotPath .. TPs[1], shotPath .. TPs[2], Path)
            if self.pc.gi.showMode ~= 2 then -- pixel streaming
                self.WebSandBox:SetVisibility(4)
            end
            self.B_Area:SetVisibility(1)
        end), self)
    end
end

function M:shotExport(TP1, TP2, path)
    local Material = UE.UKismetMaterialLibrary.CreateDynamicMaterialInstance(self:GetWorld(), LoadObject(
        '/Game/SandBox/Materials/M_Shot.M_Shot'), "", 0)
    print(TP1, TP2)
    local T1 = UE.UKismetRenderingLibrary.ImportFileAsTexture2D(self:GetWorld(), TP1)
    local T2 = UE.UKismetRenderingLibrary.ImportFileAsTexture2D(self:GetWorld(), TP2)
    Material:SetTextureParameterValue("T1", T1)
    Material:SetTextureParameterValue("T2", T2)
    local T2D = LoadObject('/Game/SandBox/Textures/Shot.Shot')
    UE.UKismetRenderingLibrary.DrawMaterialToRenderTarget(self:GetWorld(), T2D, Material)
    self:ExportImage(path)
end

function M:ShowVision(dataTable)
    if dataTable then
        self.pawn:SplitScreen()
    else
        self:NoShowVision()
    end
end

--- 将方案导出为CAD或JSON文件
--- @param dataTable table 包含导出参数的表，其中type字段表示导出类型：1为DXF文件，2为JSON文件
function M:ExportPlantoCad(dataTable)
    -- 初始化导出文件路径
    local path = ""

    -- 根据是否为重新导出选择不同的路径获取方式
    if not dataTable.isReexport then
        -- 根据导出类型选择文件保存对话框
        if dataTable.type == 1 then
            path = BFL.SaveFileNameToFolder("Cad Files (*.dxf)|*.dxf")
            if path == "" then
                goto continue
            end
            if string.find(path, "%.dxf$") == nil then
                path = path .. ".dxf"
            end
        elseif dataTable.type == 2 then
            path = BFL.SaveFileNameToFolder("Json Files (*.json)|*.json")
        end
    else
        -- 重新导出时，根据导出类型获取对应的路径
        if dataTable.type == 1 then
            path = self.outCadPath
        elseif dataTable.type == 2 then
            path = string.gsub(self.outCadPath, "%.dxf$", ".json")
            if string.find(path, "%.json$") == nil then
                path = path .. ".json"
            end
        end
    end
    -- 如果用户取消选择文件，通知前端导出失败
    ::continue::
    if path == "" then
        self:ExportCadStep(false, dataTable.type, 1)
        return
    end

    path = UE.UBlueprintPathsLibrary.ConvertRelativePathToFull(path, "")

    -- 通知前端开始保存提示
    self:UECallWeb("SaveTip", dataTable)

    -- 尝试调用控制器导出方案数据
    local bSuccess, planData = pcall(self.control.ExportPlanDataToCad, self.control)

    -- 导出数据失败，通知前端导出失败
    if not bSuccess then
        self:ExportCadStep(false, dataTable.type, 2)
        return
    end

    -- 初始化数据文件路径
    local dataPath = path

    -- 如果是导出DXF文件，修改数据文件扩展名为.json，用于后续转换
    if dataTable.type == 1 then
        dataPath = string.gsub(dataPath, "%.dxf$", ".json")
    end

    -- 将导出的数据序列化为JSON并写入文件
    local bWrite = UE.UMyBFL.WriteFile(Json.encode(planData), dataPath, 3)

    -- 文件写入失败，通知前端导出失败
    if not bWrite then
        self:ExportCadStep(false, dataTable.type, 3)
        return
    end

    -- 根据导出文件类型进行不同处理
    if dataTable.type == 1 then
        -- 如果是导出DXF文件，调用转换程序进行转换
        local outCadExePath = UE.UBlueprintPathsLibrary.ProjectDir() .. "cad/MeshToDXF.exe"
        local args = string.format("--cli \"%s\" \"%s\" \"%s\"", dataPath, path, "")
        self.outCadPath = path
        BFL.OpenProcedure(outCadExePath, args)
        -- 设置定时器检查转换是否完成
        self.checkExportTimer = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.CheckExport }, 1, false)
    elseif dataTable.type == 2 then
        -- 如果是导出JSON文件，直接通知前端导出成功
        self:ExportCadStep(true, dataTable.type, nil)
    end
end

--- 取消导出CAD文件
function M:CancelExportCad(dataTable)
    -- 取消导出程序的执行
    BFL.CloseProcedure()
    -- 通知前端导出取消
    -- self:ExportCadStep(false, dataTable.type, 1)
    if self.checkExportTimer then
        -- 清除定时器
        UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.checkExportTimer)
        self.checkExportTimer = nil
    end
    -- 获取中间JSON文件路径
    local path = string.gsub(self.outCadPath, "%.dxf$", ".json")
    -- 删除中间JSON文件和CAD文件（添加重试机制）
    coroutine.resume(
        coroutine.create(
            function()
                local maxRetries = 3 -- 最大重试次数
                local retryCount = 0

                -- 循环直到文件被删除或达到最大重试次数
                while retryCount < maxRetries do
                    UE.UKismetSystemLibrary.Delay(self, 1)
                    print("删除文件前：", path, self.outCadPath)

                    -- 检查并删除中间JSON文件
                    if UE.UBlueprintPathsLibrary.FileExists(path) then
                        UE.UMyBFL.DeleteFile(path)
                        if UE.UBlueprintPathsLibrary.FileExists(path) then
                            print("删除JSON文件失败，将在1秒后重试")
                            retryCount = retryCount + 1
                            UE.UKismetSystemLibrary.Delay(self, 1)
                            goto continue
                        end
                    end

                    -- 检查并删除CAD文件
                    if UE.UBlueprintPathsLibrary.FileExists(self.outCadPath) then
                        UE.UMyBFL.DeleteFile(self.outCadPath)
                        if UE.UBlueprintPathsLibrary.FileExists(self.outCadPath) then
                            print("删除CAD文件失败，将在1秒后重试")
                            retryCount = retryCount + 1
                            UE.UKismetSystemLibrary.Delay(self, 1)
                            goto continue
                        end
                    end

                    -- 如果两个文件都已删除或不存在，则退出循环
                    if not UE.UBlueprintPathsLibrary.FileExists(path) and
                        not UE.UBlueprintPathsLibrary.FileExists(self.outCadPath) then
                        break
                    end

                    ::continue::
                end

                -- 最终检查，如果仍有文件未删除，输出警告
                if retryCount >= maxRetries then
                    if UE.UBlueprintPathsLibrary.FileExists(path) then
                        print("警告：达到最大重试次数，JSON文件仍未删除")
                    end
                    if UE.UBlueprintPathsLibrary.FileExists(self.outCadPath) then
                        print("警告：达到最大重试次数，CAD文件仍未删除")
                    end
                end
            end
        )
    )
end

--- 检查CAD导出程序是否执行完成
function M:CheckExport()
    -- 如果导出程序仍在运行，继续设置定时器检查
    if BFL.IsProcedureRunning() then
        self.checkExportTimer = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.CheckExport }, 1, false)
    else
        -- 获取中间JSON文件路径
        local path = string.gsub(self.outCadPath, "%.dxf$", ".json")
        -- 删除中间JSON文件
        UE.UMyBFL.DeleteFile(path)

        -- 导出程序已结束，检查导出文件是否存在
        if UE.UBlueprintPathsLibrary.FileExists(self.outCadPath) then
            -- 文件存在，通知前端导出成功
            self:ExportCadStep(true, 1, nil)
        else
            -- 文件不存在，通知前端导出失败
            self:ExportCadStep(false, 1, 4)
        end
        -- 清除定时器
        self.checkExportTimer = nil
    end
end

--- 通知前端导出CAD文件的步骤及结果
--- @param bSuccess boolean 操作是否成功
--- @param type number 导出文件的类型：1为DXF文件，2为JSON文件
--- @param errorType number|nil 错误类型：1为用户取消选择文件，2为导出数据失败，3为写入文件失败，4为导出程序执行失败，nil表示无错误
function M:ExportCadStep(bSuccess, type, errorType)
    -- 构造导出结果表
    local t = {
        isSuccess = bSuccess,
        type = type,
        errorType = errorType,
    }
    -- 通知前端导出步骤及结果
    self:UECallWeb("ExportCadStep", t)
end

function M:NoShowVision()
    self.pawn:SplitScreen()
    -- self.ButtonVision:SetVisibility(1)
    self:ShowPanel()
end

function M:ButtonVision()
    self:UECallWeb("ButtonVision", nil)
end

-----------------------  空间域动画
function M:AnimationList(dataTable)
    local table = self.control:AnimationList()
    return table
end

function M:AnimationPlay(dataTable)
    self.control:AnimationPlay(dataTable)
end

function M:AnimationSinglePlay(dataTable)
    self.control:AnimationSinglePlay(dataTable)
end

function M:GetMapModel(dataTable)
    local t = self.control:GetAnimeModel(dataTable)
    return t
end

function M:GenerateAnimation(dataTable)
    local t = self.control:SetAnimeData(dataTable)
    return t
end

function M:SelectPathAniList(dataTable)
    self.control:SelectAnime(dataTable)
end

function M:CloseLujinAni(dataTable)
    self.control:CloseAnime(dataTable)
end

function M:AnimationStop()
    self:UECallWeb("animationStop", nil)
end

function M:StopOperate(jsonTable)
    self:UECallWeb("StopOperate", jsonTable)
end

--  像素流送使用
function M:DisableKeyBoard(dataTable)
    self.control:DisableKeyBoard(dataTable.bdisable)
end

----------------------------- 虚假仿真代码 --------------------------------
-- function M:OpenLevel(jsonTable)
--     -- local jsonStr = JLH.JsonValue_Stringify(Data)
--     -- local jsonTable = Json.decode(jsonStr)

--     if jsonTable.phantomType then
--         if self.LevelName ~= jsonTable.levelName then
--             local T = self:ClearLevel()
--             -- print(self.modelManage.Actors:Num(), 22222)
--             self.LightLevel = UE.ULevelStreamingDynamic.LoadLevelInstance(self:GetWorld(),
--                 '/Game/GeneralContent/Features/SpaceConfig/Maps/Level_Light', UE.FVector(), UE.FRotator())
--             if jsonTable.schemeResponse.modelList then
--                 for key, value in pairs(jsonTable.schemeResponse.modelList) do
--                     local T = Json.decode(value.contentValue)
--                     -- 排除地板与组合
--                     local bool1 = string.find(T.modelName, "Floor") == nil and string.find(T.modelName, "Group") == nil
--                     -- 排除标注
--                     local bool2 = true
--                     if T.parent then
--                         bool2 = string.find(T.parent, "1BZ") == nil and string.find(T.modelName, "1BZ") == nil
--                     end
--                     if bool1 and bool2 then
--                         self.modelManage:DataCreateModel(T)
--                     end
--                 end
--             end

--             local T = self:LevelShow()
--             self.LevelName = jsonTable.levelName
--             for key, value in pairs(self.modelManage.Actors) do
--                 self.Actors:Add(key, value)
--             end

--             self.bFromHY = jsonTable.phantomType
--         end
--     else
--         if LevelURL[jsonTable.levelName] then
--             local path = LevelURL[jsonTable.levelName]
--             if self.LevelName ~= jsonTable.levelName then
--                 self.LevelName = jsonTable.levelName
--                 local T = self:ClearLevel()

--                 self.Level = UE.ULevelStreamingDynamic.LoadLevelInstance(self:GetWorld(), path, UE.FVector(),
--                     UE.FRotator())
--                 if self.Level then
--                     self.Level.OnLevelShown:Add(self, self.LevelShow)
--                 else
--                     local T = {
--                         levelName = "关卡资源未下载"
--                     }
--                 end
--             end
--         else
--             self.LevelName = jsonTable.levelName
--             local T = self:ClearLevel()
--             local T = {
--                 levelName = "没有该关卡"
--             }
--             return T
--         end
--     end
-- end

function M:LevelShow()
    Model.ModelLoadedInitial(self, self.Actors, self.ChildActors, self.LevelName)
    -- self.BPM:StoreAllStaticMeshOriginalMaterials(UE.UGameplayStatics
    --     .GetAllActorsOfClass(self:GetWorld(), UE.AStaticMeshActor))
    self.AllSTAs = UE.UGameplayStatics.GetAllActorsOfClass(self:GetWorld(), UE.AStaticMeshActor)
    -- print(self.Actors:Num(), "AAAA")
    local LSAs = UE.UGameplayStatics.GetAllActorsOfClass(self:GetWorld(), UE.ALevelSequenceActor) -- 场景动画获取

    for key, value in pairs(LSAs) do
        local Path = UE.UKismetSystemLibrary.BreakSoftObjectPath(value.LevelSequence)
        local s1, s2, Name = UE.UBlueprintPathsLibrary.Split(Path)
        self.NLSAs:Add(Name, value)
    end
end

function M:ClearLevel()
    if self.Level then
        local T = self:LevelRemove()
        self.Level:SetIsRequestingUnloadAndRemoval(true)
        self.Level = nil
    end
    if self.bFromHY and self.LightLevel then
        for key, value in pairs(self.modelManage.Actors) do
            value:K2_DestroyActor()
        end
        local T = self:LevelRemove()
        self.modelManage.Actors:Clear()
        self.LightLevel:SetIsRequestingUnloadAndRemoval(true)
        self.LightLevel = nil
    end
end

function M:LevelRemove()
    self.Actors:Clear()
    self.ChildActors:Clear()
    self.NLSAs:Clear()
end

-- 生成前端信息面板
function M:CreateWebTag(dataTable)
    local backTable = {}
    for key, value in pairs(dataTable) do
        local tagData = self.modelControl:CreateTag(value, 1) -- 类型1表示前端标签
        backTable[key] = tagData
    end
    return backTable
end

function M:DeleteTag(dataTable)
    if dataTable == nil or #dataTable > 0 then
        return { "未传入数据" }
    end
    for _, value in pairs(dataTable) do
        self.modelControl:DeleteTag(value.id, value.type)
    end
end

function M:ClearTags(dataTable)
    for key, value in pairs(self.PopupS) do
        value:K2_DestroyActor()
    end
    self.PopupS:Clear()
end

function M:TransmitData(dataTable)
    local id = dataTable.id
    local webData = dataTable.data
    for key, value in pairs(self.PopupS) do
        if value.ID == id then
            value.BindUI.PupopWeb:Call("TransmitData", webData)
            Screen.Print("已发送数据至弹窗" .. id)
        end
    end
end

function M:ToView(dataTable)
    local AllSTAs = UE.UGameplayStatics.GetAllActorsOfClass(self:GetWorld(), UE.AStaticMeshActor)
    local origin, boxExtent = UE.UGameplayStatics.GetActorArrayBounds(AllSTAs, true)

    if origin == UE.FVector(0, 0, 0) then
        return
    end

    if dataTable.viewId == 1 then
        self.pawn:ToCenter(origin, boxExtent, nil, nil, UE.FVector2D(100, 80))
    elseif dataTable.viewId == 2 then
        self.pawn:ToCenter(origin, boxExtent, nil, nil, UE.FVector2D(400, -150))
    elseif dataTable.viewId == 3 then
        self.pawn:ToCenter(origin, boxExtent, nil, nil, UE.FVector2D(0, -150))
    end
end

function M:ModelSignal(table)
    self:UECallWeb("ModelSignal", table)
end

function M:GoFangzhen(dataTable)
    self.control:CheckInput(true)
    if not self.modelControl then
        local modelClass = LoadClass(ClassUrl.modelControl)
        self.modelControl = self:GetWorld():SpawnActor(modelClass, UE.FTransform(),
            UE.ESpawnActorCollisionHandlingMethod.Default,
            self, self, "Framework.Blueprints.ObjectClass.Model.BP_modelControl")
    end
end

-- 动画实时播放
-- 前端给的参数
-- loop 循环
-- AnimationName 动画名
-- AnimationType 动画播放类型 1播放2暂停3停止
-- TimeInterval 循环动画间隔
function M:ActualEquipmentCondition(dataTable)
    local PlayA = self.NLSAs:Find(dataTable.AnimationName)
    if PlayA then
        if dataTable.AnimationType == 1 and not PlayA.SequencePlayer:IsPlaying() then
            if dataTable.loop then
                if dataTable.TimeInterval == 0 then
                    PlayA.SequencePlayer:PlayLooping(-1)
                    self.loopAnimation[dataTable.AnimationName] = {
                        Time = dataTable.TimeInterval,
                        Animation = PlayA.SequencePlayer,
                        bWaitPlay = false
                    }
                else
                    PlayA.SequencePlayer:Play()
                    PlayA.SequencePlayer.OnStop:Add(self, self.IntervalPlay)
                    self.loopAnimation[dataTable.AnimationName] = {
                        Time = dataTable.TimeInterval,
                        Animation = PlayA.SequencePlayer,
                        bWaitPlay = true
                    }
                end
            else
                PlayA.SequencePlayer:Play()
            end
        elseif dataTable.AnimationType == 2 and not PlayA.SequencePlayer:IsPaused() then
            PlayA.SequencePlayer:Pause()
            if self.loopAnimation[dataTable.AnimationName] then
                self.loopAnimation[dataTable.AnimationName] = nil
                PlayA.SequencePlayer.OnStop:Remove(self, self.IntervalPlay)
            end
        elseif dataTable.AnimationType == 3 then
            PlayA.SequencePlayer:Stop()
            if self.loopAnimation[dataTable.AnimationName] then
                self.loopAnimation[dataTable.AnimationName] = nil
                PlayA.SequencePlayer.OnStop:Remove(self, self.IntervalPlay)
            end
        end
    else
        local T = {
            AnimationName = "没有该动画"
        }
        return
    end
end

function M:IntervalPlay()
    for key, value in pairs(self.loopAnimation) do
        if not (value.Animation:IsPlaying() or value.Animation:IsReversed()) and value.bWaitPlay then
            coroutine.resume(coroutine.create(function()
                -- print(value.Time)
                UE.UKismetSystemLibrary.Delay(self, tonumber(value.Time))
                -- print(key)
                if self.loopAnimation[key] then
                    value.Animation:Play()
                    value.Animation.OnStop:Add(self, self.IntervalPlay)
                    value.bWaitPlay = true
                end
            end), self)
            value.bWaitPlay = false
        end
    end
end

----------------------- CAD ------------------------------
-- type = 1 未选择文件
-- type = 2 转换程序丢失
-- type = 3 转换中
-- type = 4 转换失败
-- type = 5 构建CAD
-- type = 6 构建完成
function M:GetDrawing(dataTable)
    -- 选择本地 CAD bin 文件
    local binPath = BFL.SelectFile("dxf转换文件 (*.bin)|*.bin")
    if binPath == "" then
        return self:UECallWeb("loaddraw", {
            type = 1
        })
    end

    -- 记录名称与时间戳（用于方案保存与缓存命名）
    self.cadName = UE.UBlueprintPathsLibrary.GetBaseFilename(binPath, true)
    self.cadTime = os.time()

    -- 规范为绝对路径，避免驱动器/工作目录差异
    binPath = UE.UBlueprintPathsLibrary.ConvertRelativePathToFull(binPath, "")

    -- 上报文件大小（复用原 uploadFileSize 调用）
    local curfilesize = UE.UFileFunctionsRealTimeImport.fileSize(1, binPath)
    local jsonStr = Json.encode({
        Size = curfilesize / 1024 / 1024,
        Name = self.cadName
    })
    local jsonVal = JLH.Parse(jsonStr)
    self.WebSandBox:Call("uploadFileSize", jsonVal)

    -- 通知前端：开始构建 CAD
    self:UECallWeb("loaddraw", {
        type = 5
    })

    -- 异步构建 CAD：直接从 bin 文件创建，不再经过 dxf->json 转换与轮询
    coroutine.resume(coroutine.create(function()
        UE.UKismetSystemLibrary.Delay(self, 0.1)
        local ok, err = pcall(function()
            self.control:CreateCADFromBin(binPath, self.cadName, self.cadTime)
        end)

        if ok then
            self:UECallWeb("loaddraw", {
                type = 6
            })
            -- 从 bin 构建成功后，同步触发 CAD bin 落盘与上传，保证保存时已有相对路径/绝对路径/下载地址
            pcall(function()
                self:TryEnsureCadBinOnly()
                self:TryUploadCadBin()
            end)
        else
            print("CreateCADFromBin error: " .. tostring(err))
            self:UECallWeb("loaddraw", {
                type = 7
            })
        end

        -- 通知前端本次加载流程结束
        self.WebSandBox:Call("loadover", nil)
    end), self)
end

function M:StopUploadCAD()
    UE.UKismetSystemLibrary.K2_ClearAndInvalidateTimerHandle(self:GetWorld(), self.examine)
end

function M:ExamineJson()
    self.examine = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.ExamineJsonTime }, 1, false)
end

function M:ExamineJsonTime()
    self.waitSec = self.waitSec + 1
    -- self.DXFjsonDrawing = "D:\\MyDesktop\\123123123.json"
    local bExist = UE.UBlueprintPathsLibrary.FileExists(self.DXFjsonDrawing)
    if bExist then
        local content = BFL.ReadFile(self.DXFjsonDrawing)
        local jsonTable = Json.decode(content)
        if not jsonTable then
            return self:UECallWeb("loaddraw", {
                type = 4
            })
        end
        self:UECallWeb("loaddraw", {
            type = 5
        })

        coroutine.resume(coroutine.create(function()
            UE.UKismetSystemLibrary.Delay(self, 2)
            local bSuccess = self.control:CreateCAD(jsonTable, self.cadName, self.cadTime)
            if bSuccess then
                self:UECallWeb("loaddraw", {
                    type = 6
                })
                -- 构建阶段：确保 CAD bin 落盘并立即触发上传机制
                pcall(function()
                    -- 先确保本地相对路径 bin（同时在 CAD 上填充 cadPath / cadFullPath）
                    self:TryEnsureCadBinOnly()
                    -- 再触发上传，拿到后端唯一命名/下载地址（cadUrl）
                    self:TryUploadCadBin()
                end)
            else
                self:UECallWeb("loaddraw", {
                    type = 7
                })
            end
        end), self)
    else
        print("等待转换" .. self.waitSec)
        -- if self.waitSec > 20 then
        -- return self:UECallWeb("loaddraw", {
        --     type = 4
        -- })
        -- else
        self.examine = UE.UKismetSystemLibrary.K2_SetTimerDelegate({ self, self.ExamineJsonTime }, 1, false)
        -- end
    end
    self.WebSandBox:Call("loadover", nil)
end

function M:IsCadData(dataTable)
    local isCad = false
    local isShow = false
    if self.control.modelManage.cad then
        isCad = true
        isShow = self.control.modelManage.cad.bShow == nil and true or self.control.modelManage.cad.bShow
    end
    local t = { isCad = isCad, isShow = isShow }
    return t
end

function M:GetCadData(dataTable)
    local t = self.control:GetCadData()
    return t
end

function M:CloseCadWindow(dataTable)
    self.control:CloseCadWindow(dataTable)
end

function M:SetCadData(dataTable)
    self.control:SetCadData(dataTable)
end

function M:IsShowCad(dataTable)
    self.control:IsShowCad(dataTable)
end

----------------- ue.interface.RealTimeData
------------------------
function M:IsOpenPointCap(dataTable)
    local bNotChange = self.control:IsCatch(dataTable.bPointCap)
    if bNotChange then
        return { bNotChange }
    end
end

function M:ClickSpace(dataTable)
    self.control.IsSpace = dataTable.isClick
end

function M:SyncbCatch(bool)
    local jsonTable = Json.encode({
        bCatch = bool
    })
    self:UECallWeb("SyncbCatch", jsonTable)
end

function M:ClearSplineMenu(dataTable)
    self.control:RemoveSplineMenu()
end

function M:SynchronousToken(dataTable)
    local SaveToken = UE.UBlueprintPathsLibrary.ProjectDir() .. "Content/config.json"
    local jsonTable = Json.decode(BFL.ReadFile(SaveToken))
    return jsonTable
end

------- 新增模式关系 协作区域模式 ---------------------

--- 切换绘制模式
--- @param dataTable table 模式数据表，包含mode字段（模式名称，如"RegionArea"）
--- 当切换到RegionArea模式时，显示方案协作提示并隐藏位置UI；其他模式则隐藏提示并显示位置UI
function M:SwitchDrawMode(dataTable)
    self.control:SwitchDrawMode(dataTable.mode)
    if dataTable.mode == "RegionArea" then
        self:ShowModelTip("方案协作",
            "通过绘制虚线区域分配协作范围及协作人，" ..
            "双击左键开始绘制，左键点击确认点，右键点击取消绘制" ..
            " 当前处于绘制功能下需要通过空格+左/中键进行视角旋转或移动")
        self.UI_location:switch(false, 1, 1)
    elseif dataTable.mode == "RegionInner" then
        self:ShowModelTip("方案协作",
            "标注的区域为由你进行协作搭建的区域，请双击区域进行搭建")
    else
        self:ModelTipHide()
        self.UI_location:switch(true, 1, 1)
    end
end

--- 切换方案协作编辑状态
--- @param dataTable table 状态数据表，包含switchStatus字段（布尔值，表示是否启用编辑）
--- 控制协作区域的编辑权限，启用后可以进行区域的编辑操作
function M:SwitchSchemeAssist(dataTable)
    self.control.bRegionEdit = dataTable.switchStatus
end

--- 设置当前方案是否为团队方案
--- 前端通过 IsTeamScheme { flag = true/false } 调用
--- 仅当为团队方案时，协作区域才会随方案一起保存 / 加载
---@param dataTable table { flag: boolean }
function M:IsTeamScheme(dataTable)
    if not dataTable then
        return
    end
    -- 默认 false，只有明确传入 true 时才视为团队方案
    self.isTeamScheme = dataTable.flag == true
end

--- 选择区域
--- @param dataTable table 区域数据表，包含区域标识信息
--- 根据传入的区域数据选中对应的协作区域
function M:SelectRegion(dataTable)
    self.control:SelectRegion(dataTable)
end

--- 更新区域数据
--- @param dataTable table 区域数据表，包含需要更新的区域信息
--- 更新指定协作区域的数据，如区域范围、协作人等信息
function M:UpdateRegionData(dataTable)
    self.control:UpdateRegionData(dataTable)
end

--- 删除区域
--- @param dataTable table 区域数据表，包含需要删除的区域标识信息
--- 删除指定的协作区域
function M:DeleteRegion(dataTable)
    self.control:DeleteRegion(dataTable)
end

--- 获取区域数据
--- @param dataTable table 预留参数表（当前版本未实际使用）
--- @return table 返回包含regionAreas（区域列表）和isRegOps（编辑状态）的JSON表
--- 获取所有协作区域的数据和当前编辑状态，用于数据同步或保存
function M:GetRegionData(dataTable)
    local jsonTable = {
        regionAreas = self.control:OutRegionData(true),
        isRegOps = self.control.bRegionEdit
    }
    return jsonTable
end

--- RegionInner：保存区域内模型数据到本地并校验“用户区域是否一致”
--- 前端会传入云端方案最新地址与最新区域信息：
---  - path：云端方案文件地址（用于追踪）
---  - contentValue：方案内容里的区域信息 JSON（用于兜底推断所属区域）
--- 前端期望返回 { bSaveVS = true/false, ... }
function M:ValidAssistorSave(dataTable)
    -- 注意：这里不要提前解 JSON，交给底层 BP_Control:ValidAssistorSave 自己处理
    -- BP_Control 期望拿到 dataTable.contentValue（string）和 dataTable.path
    self.path = dataTable.path
    return self.control:ValidAssistorSave(dataTable)
end

function M:CommunicationCleanup(functionName)
    self.control:CommunicationCleanup(functionName)
end

return M
