--[[
    沙盒系统玩家控制器
    负责处理玩家输入、UI显示和像素流送等功能

    @公司 **
    @作者 **
    @创建时间 2024-01-17
    @最后修改 2024-01-17
]]

---@class HY_PC_C 沙盒玩家控制器类
---@field uiSandBox UUserWidget 沙盒UI实例
---@field PSComp UPixelStreamingInput 像素流送输入组件
---@field GI GameInstance 游戏实例引用
---@field UI UUserWidget UI实例引用
---@field bShowMouseCursor boolean 是否显示鼠标光标
local M = UnLua.Class()

-- 引入依赖模块
local Class = require("SandBox.Class")
require("GlobalConfig")

---游戏开始时调用
function M:ReceiveBeginPlay()
    -- 仅主玩家控制器执行初始化
    if UE.UGameplayStatics.GetPlayerControllerID(self) ~= 0 then
        return
    end
    UE.UKismetSystemLibrary.ExecuteConsoleCommand(self, "t.MaxFPS 60")

    -- 基础设置
    self:InitializeBasicSettings()

    -- 像素流送功能初始化
    self:InitializePixelStreaming()

    -- 加载并显示沙盒UI
    self:InitializeSandboxUI()
end

---初始化基础设置
function M:InitializeBasicSettings()
    -- 默认显示鼠标光标
    self.bShowMouseCursor = true
    self.bDevMode = UE.UMyBFL.GetExeUrl("bScreen") ~= ""
    if self.bDevMode then
        UE.UKismetSystemLibrary.ExecuteConsoleCommand(self, "ENABLEALLSCREENMESSAGES")
    else
        UE.UKismetSystemLibrary.ExecuteConsoleCommand(self, "DISABLEALLSCREENMESSAGES")
    end
end

---初始化像素流送功能
function M:InitializePixelStreaming()
    -- 获取游戏实例
    self.gi = UE.UGameplayStatics.GetGameInstance(self:GetWorld()):Cast(LoadClass(ClassUrl.gi))
    self.gi:GetMode()
    if self.gi.inMode ~= 4 then
        UE.UGameplayStatics.OpenLevel(self:GetWorld(), "L_Main", true, "")
    end
    -- 像素流送模式特殊处理
    if self.gi.showMode == 2 then
        if UE.UPixelStreamingInput then
            -- 隐藏系统光标
            self.bShowMouseCursor = false

            -- 创建像素流输入组件
            self.psComp = self:AddComponentByClass(
                UE.UPixelStreamingInput, -- 组件类
                false,                   -- 手动附加
                UE.FTransform(),         -- 默认变换
                false                    -- 非模板
            )
        else
            print("警告：像素流送模式下未找到PixelStreamingInput组件")
        end
    end
end

---初始化沙盒UI
function M:InitializeSandboxUI()
    -- 加载UI类
    local uiSandBoxClass = LoadClass(Class.ui)
    if not uiSandBoxClass then
        error("错误：无法加载沙盒UI类", 2)
        return
    end

    -- 创建并显示UI
    self.uiSandBox = self:ShowUI(self.uiSandBox, uiSandBoxClass)
end

---显示UI界面
---@param ui UUserWidget 现有UI实例（可选）
---@param uiClass UClass UI类
---@return UUserWidget 返回UI实例
function M:ShowUI(ui, uiClass)
    -- 参数检查
    if not uiClass then
        error("错误：未指定UI类", 2)
        return nil
    end

    -- 获取玩家控制器
    ---@type APlayerController
    local playerController = UE.UGameplayStatics.GetPlayerController(self:GetWorld(), 0)
    if not playerController then
        error("错误：无法获取玩家控制器", 2)
        return nil
    end

    -- UI实例处理
    if ui then
        -- 已有实例：确保显示在视口中
        if not ui:IsInViewport() then
            ui:AddToViewport()
        end
    else
        -- 创建新实例
        ---@type UUserWidget
        local newUI = UE.UWidgetBlueprintLibrary.Create(
            self:GetWorld(), -- 世界对象
            uiClass,         -- UI类
            playerController -- 玩家控制器
        )

        if not newUI then
            error("错误：UI创建失败", 2)
            return nil
        end

        -- 更新引用并显示
        ui = newUI
        ui:AddToViewport()
    end

    return ui
end

return M
