--[[
    Senko UI · 插件式 Roblox 執行器 UI 庫  v1.0.0
    https://github.com/Tseting-nil/senko-ui
    ------------------------------------------------------------
    以 xiaoyeuzixi/HanaBi-ui-Genshin（C++20 / Dear ImGui）的設計語言為基礎，以 Roblox Luau 重新實作：
      · 內建「基礎」主題：曜石、雲母 + 極光、暮霞、深海、星雲、櫻霧（原創壁紙），其他主題由插件提供
      · 多語系：English（預設）/ 繁體中文，SenkoUI:SetLanguage 即時切換主題頁文字，SenkoUI:AddLocale 可擴充
      · 角色壁紙插件：純 JSON（plugins/<插件>/<角色>/character.json），不執行任何外部程式碼，說明見 PLUGINS.md
      · 分頁圖示內建 Lucide 名稱（Icon = "settings"），不需另外載入
      · 插件管理：讀取 plugins/index.json，主題頁開關即當場下載 / 移除，可清除各插件的圖片快取
      · Lua 擴充（進階）：粒子 / 圖示 / 自訂控件 / 事件，以 SenkoUI:LoadPlugin 載入
      · 元素徽記、側欄滑動指示器、主題專屬視窗按鈕造型、可自訂側欄底部文字（Footer）
      · 開關 / 滑桿 / 分段 / 下拉 / 標籤選擇 / 按鍵錄入 / 輸入框 / 按鈕 / 控制台
      · 進度條 / 環形儀表 / 統計區塊 / 色彩選擇器 / Slots 槽位選擇
      · 主題庫頁（自訂分類篩選、長方形主題卡、字號 100%–125%、啟動模式）
      · 開場動畫（徽記展開後停駐側欄，可點擊跳過）
      · 壁紙（網址或 workspace 檔案 → getcustomasset），緩慢漂移、滑鼠視差、角色呼吸、微光粒子
      · 通知、設定檔存取、拖曳、縮放、最小化、最大化、手機懸浮按鈕

    用法：
      local SenkoUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Tseting-nil/senko-ui/main/SenkoUI.lua"))()
      SenkoUI:LoadPlugins()   -- 讀取官方角色壁紙插件清單，需在 CreateWindow 之前
      local Window = SenkoUI:CreateWindow({ Title = "Senko UI", Theme = "Obsidian", Footer = "Senko UI v1.0" })
      local Tab = Window:AddTab({ Title = "主要", Icon = "◆" })
      local Sec = Tab:AddSection({ Title = "AIM", Caption = "自瞄" })
      Sec:AddToggle({ Title = "啟用", Default = true, Flag = "Aim", Callback = function(v) end })
]]

local SenkoUI = {
    Version = "1.0.0",
    Flags = {},
    Options = {},
    Animations = true,
    Folder = "SenkoUI",
}

-- ============================================================
-- 服務
-- ============================================================
local cloneref = cloneref or function(o) return o end
local function getService(name)
    return cloneref(game:GetService(name))
end

local TweenService = getService("TweenService")
local UserInputService = getService("UserInputService")
local RunService = getService("RunService")
local HttpService = getService("HttpService")
local TextService = getService("TextService")
local Players = getService("Players")
local CoreGui = getService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local FONT = Enum.Font.Gotham
local FONT_MED = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold
local WHITE = Color3.new(1, 1, 1)

-- ============================================================
-- 基礎工具
-- ============================================================
local function rgb(h)
    return Color3.fromRGB(math.floor(h / 65536) % 256, math.floor(h / 256) % 256, h % 256)
end

local function new(class, props, children)
    local obj = Instance.new(class)
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then
            parent = v
        else
            obj[k] = v
        end
    end
    for _, child in ipairs(children or {}) do
        child.Parent = obj
    end
    if parent then
        obj.Parent = parent
    end
    return obj
end

local function corner(obj, radius)
    return new("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = obj })
end

local function pad(obj, top, right, bottom, left)
    return new("UIPadding", {
        PaddingTop = UDim.new(0, top or 0),
        PaddingRight = UDim.new(0, right or top or 0),
        PaddingBottom = UDim.new(0, bottom or top or 0),
        PaddingLeft = UDim.new(0, left or right or top or 0),
        Parent = obj,
    })
end

local function tween(obj, props, duration, style, direction)
    if not SenkoUI.Animations or duration == 0 then
        for k, v in pairs(props) do
            obj[k] = v
        end
        return nil
    end
    local t = TweenService:Create(
        obj,
        TweenInfo.new(duration or 0.32, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
        props
    )
    t:Play()
    return t
end

-- 依 instant 決定直接設定或補間
local function setp(obj, props, instant, duration, style)
    if instant then
        for k, v in pairs(props) do
            obj[k] = v
        end
    else
        tween(obj, props, duration or 0.28, style)
    end
end

-- 補間完成後執行（關閉動畫時立即執行）
local function tweenThen(obj, props, duration, style, direction, callback)
    local t = tween(obj, props, duration, style, direction)
    if t then
        t.Completed:Connect(function()
            callback()
        end)
    else
        callback()
    end
end

local function safeCall(fn, ...)
    if type(fn) ~= "function" then
        return
    end
    local args = table.pack(...)
    task.spawn(function()
        local ok, err = pcall(fn, table.unpack(args, 1, args.n))
        if not ok then
            warn("[SenkoUI] 回呼錯誤：" .. tostring(err))
        end
    end)
end

local function isPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function viewport()
    local cam = workspace.CurrentCamera
    return cam and cam.ViewportSize or Vector2.new(1280, 720)
end

-- 插件事件（WindowCreated / WindowDestroyed / ThemeChanged / ThemeTabBuilt），由 api:On 註冊
local Hooks = {}
local createdWindows = 0
local openWindows = {} -- 插件管理當場載入插件時，通知這些視窗更新主題卡與圖示

local function fireHook(event, ...)
    for _, hook in ipairs(Hooks[event] or {}) do
        local ok, err = pcall(hook.fn, ...)
        if not ok then
            warn(string.format("[SenkoUI] 插件 %s 的 %s 事件出錯：%s", hook.plugin, event, tostring(err)))
        end
    end
end

-- ============================================================
-- 檔案系統（執行器專用，不存在時自動略過）
-- ============================================================
local FS = {}
FS.available = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"

function FS.ensureFolder(path)
    if not FS.available then
        return
    end
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(path) then
            makefolder(path)
        end
    end)
end

function FS.readJson(path)
    if not FS.available then
        return nil
    end
    local ok, result = pcall(function()
        if not isfile(path) then
            return nil
        end
        return HttpService:JSONDecode(readfile(path))
    end)
    return ok and result or nil
end

function FS.writeJson(path, data)
    if not FS.available then
        return false
    end
    local ok = pcall(function()
        writefile(path, HttpService:JSONEncode(data))
    end)
    return ok
end

function FS.list(path)
    local out = {}
    if not FS.available or type(listfiles) ~= "function" then
        return out
    end
    pcall(function()
        for _, file in ipairs(listfiles(path)) do
            local name = tostring(file):match("([^/\\]+)%.json$")
            if name then
                table.insert(out, name)
            end
        end
    end)
    table.sort(out)
    return out
end

-- 資料夾內檔案（不含子資料夾）的總大小與數量
function FS.folderSize(path)
    local bytes, count = 0, 0
    if not FS.available or type(listfiles) ~= "function" then
        return bytes, count
    end
    pcall(function()
        if type(isfolder) == "function" and not isfolder(path) then
            return
        end
        for _, file in ipairs(listfiles(path)) do
            if isfile(file) then
                local ok, data = pcall(readfile, file)
                if ok and type(data) == "string" then
                    bytes = bytes + #data
                    count = count + 1
                end
            end
        end
    end)
    return bytes, count
end

local function formatBytes(n)
    if n >= 1048576 then
        return string.format("%.1f MB", n / 1048576)
    elseif n >= 1024 then
        return string.format("%.0f KB", n / 1024)
    end
    return n .. " B"
end

-- 刪除資料夾內所有檔案（不含子資料夾），回傳刪除數量
function FS.clearFolder(path)
    local removed = 0
    if not FS.available or type(listfiles) ~= "function" or type(delfile) ~= "function" then
        return removed
    end
    pcall(function()
        if type(isfolder) == "function" and not isfolder(path) then
            return
        end
        for _, file in ipairs(listfiles(path)) do
            if isfile(file) and pcall(delfile, file) then
                removed = removed + 1
            end
        end
    end)
    return removed
end

-- ============================================================
-- 多語系（i18n）：介面文字依 SenkoUI.Language 取字典（預設 English）；SenkoUI:AddLocale 可新增語言或補字
-- 語言存於 settings.json，在主題頁「外觀 → 語言」或 SenkoUI:SetLanguage 切換；主題卡、分類、插件管理即時更新
-- ============================================================
local LOCALES = {
    ["zh-TW"] = {
        _name = "繁體中文",
        ["intro.skip"] = "點擊跳過",
        ["notify.title"] = "通知",
        ["tab.default"] = "分頁 %d",
        ["dropdown.none"] = "未選擇",
        ["dropdown.placeholder"] = "請選擇…",
        ["key.none"] = "無",
        ["key.recording"] = "按下按鍵…",
        ["config.noFile.title"] = "無法儲存",
        ["config.noFile.content"] = "目前執行器不支援檔案存取。",
        ["config.saved"] = "設定已儲存",
        ["config.saveFailed"] = "儲存失敗",
        ["config.notFound"] = "找不到設定檔",
        ["config.loaded"] = "設定已載入",
        ["group.all"] = "全部",
        ["group.basic"] = "基礎",
        ["group.custom"] = "自訂",
        ["region.workspace"] = "你的工作空間",
        ["theme.Obsidian"] = "曜石",
        ["theme.Obsidian.motto"] = "靜夜",
        ["theme.Mica"] = "雲母",
        ["theme.Mica.motto"] = "晨光",
        ["theme.Aurora"] = "極光",
        ["theme.Aurora.motto"] = "夜空下的綠",
        ["theme.Dusk"] = "暮霞",
        ["theme.Dusk.motto"] = "落日餘暉",
        ["theme.Abyss"] = "深海",
        ["theme.Abyss.motto"] = "光落入海",
        ["theme.Nebula"] = "星雲",
        ["theme.Nebula.motto"] = "遠方的塵埃",
        ["theme.Sakura"] = "櫻霧",
        ["theme.Sakura.motto"] = "春霧裡的花",
        ["themeTab.title"] = "主題",
        ["themeTab.subtitle"] = "按自己的喜好，調整空間的細節",
        ["section.themes"] = "主題庫",
        ["section.wallpaper"] = "壁紙",
        ["section.plugins"] = "插件管理",
        ["section.appearance"] = "外觀",
        ["section.startup"] = "啟動選擇",
        ["section.config"] = "設定檔",
        ["section.window"] = "視窗",
        ["wall.noSupport"] = "目前執行器不支援 writefile / getcustomasset，無法顯示壁紙，介面會使用主題漸層。",
        ["wall.show"] = "顯示壁紙",
        ["wall.showDesc"] = "只有設定了壁紙的主題會顯示",
        ["wall.strength"] = "壁紙強度",
        ["wall.motion"] = "背景動態",
        ["wall.motionDesc"] = "緩慢漂移、滑鼠視差與角色呼吸",
        ["wall.particles"] = "微光粒子",
        ["plugin.count"] = "%d 位角色與壁紙",
        ["plugin.countOne"] = "%d 位角色與壁紙",
        ["plugin.on"] = "開啟",
        ["plugin.off"] = "關閉",
        ["plugin.downloading"] = "下載中 %d/%d",
        ["plugin.enabled"] = "%s 已開啟：%d 位角色",
        ["plugin.enabledFailed"] = "%s 已開啟：%d 位角色，%d 張圖片下載失敗",
        ["plugin.disabled"] = "%s 已關閉，主題已移除",
        ["plugin.failed"] = "%s 載入失敗，詳見主控台（F9）",
        ["plugin.uncategorized"] = "未分類",
        ["plugin.clear"] = "清除「%s」圖片快取",
        ["plugin.clearSize"] = "（%s，%d 個檔案）",
        ["plugin.clearEmpty"] = "（無快取）",
        ["plugin.calculating"] = "（計算中…）",
        ["plugin.cleared"] = "已清除快取",
        ["plugin.clearedContent"] = "%s：刪除 %d 個檔案",
        ["plugin.noDelfile"] = "目前執行器不支援 delfile，無法清除快取；可手動刪除 workspace\\%s\\assets 資料夾。",
        ["plugin.note"] = "開啟即下載該插件的角色主題與壁紙並加入主題庫；關閉立即移除。已下載的檔案要按清除才會刪掉。",
        ["look.fontSize"] = "文字大小",
        ["look.animations"] = "介面動畫",
        ["look.animationsDesc"] = "關閉後所有過渡改為即時切換",
        ["look.language"] = "語言",
        ["look.languageDesc"] = "主題卡與插件管理即時切換，其他文字重新執行腳本後套用",
        ["look.languageChanged"] = "已切換為 %s",
        ["boot.when"] = "下次啟動時",
        ["boot.follow"] = "跟隨目前",
        ["boot.fixed"] = "固定主題",
        ["boot.random"] = "隨機主題",
        ["boot.note"] = "固定主題會記住切換當下的主題；隨機會從有壁紙的主題中抽選，沒有時從全部主題抽。",
        ["cfg.name"] = "設定檔名稱",
        ["cfg.list"] = "已儲存的設定",
        ["cfg.empty"] = "（無）",
        ["cfg.save"] = "儲存目前設定",
        ["cfg.load"] = "載入設定",
        ["cfg.refresh"] = "重新整理清單",
        ["keys.toggle"] = "顯示 / 隱藏介面",
        ["keys.toggleDesc"] = "Backspace 清除，Esc 取消",
    },
    en = {
        _name = "English",
        ["intro.skip"] = "Click to skip",
        ["notify.title"] = "Notice",
        ["tab.default"] = "Tab %d",
        ["dropdown.none"] = "None",
        ["dropdown.placeholder"] = "Select…",
        ["key.none"] = "None",
        ["key.recording"] = "Press a key…",
        ["config.noFile.title"] = "Can't save",
        ["config.noFile.content"] = "This executor doesn't support file access.",
        ["config.saved"] = "Config saved",
        ["config.saveFailed"] = "Save failed",
        ["config.notFound"] = "Config not found",
        ["config.loaded"] = "Config loaded",
        ["group.all"] = "All",
        ["group.basic"] = "Basic",
        ["group.custom"] = "Custom",
        ["region.workspace"] = "Your workspace",
        ["theme.Obsidian"] = "Obsidian",
        ["theme.Obsidian.motto"] = "Quiet night",
        ["theme.Mica"] = "Mica",
        ["theme.Mica.motto"] = "Morning light",
        ["theme.Aurora"] = "Aurora",
        ["theme.Aurora.motto"] = "Green under the night sky",
        ["theme.Dusk"] = "Dusk",
        ["theme.Dusk.motto"] = "Afterglow",
        ["theme.Abyss"] = "Abyss",
        ["theme.Abyss.motto"] = "Light falling into the deep",
        ["theme.Nebula"] = "Nebula",
        ["theme.Nebula.motto"] = "Distant stardust",
        ["theme.Sakura"] = "Sakura Mist",
        ["theme.Sakura.motto"] = "Blossoms in spring haze",
        ["themeTab.title"] = "Themes",
        ["themeTab.subtitle"] = "Tune the space to your taste",
        ["section.themes"] = "Library",
        ["section.wallpaper"] = "Wallpaper",
        ["section.plugins"] = "Plugins",
        ["section.appearance"] = "Appearance",
        ["section.startup"] = "Startup",
        ["section.config"] = "Configs",
        ["section.window"] = "Window",
        ["wall.noSupport"] = "This executor lacks writefile / getcustomasset, so wallpapers can't be shown; the theme gradient is used instead.",
        ["wall.show"] = "Show wallpaper",
        ["wall.showDesc"] = "Only themes with a wallpaper show one",
        ["wall.strength"] = "Wallpaper strength",
        ["wall.motion"] = "Background motion",
        ["wall.motionDesc"] = "Slow drift, mouse parallax and breathing",
        ["wall.particles"] = "Particles",
        ["plugin.count"] = "%d characters & wallpapers",
        ["plugin.countOne"] = "%d character & wallpaper",
        ["plugin.on"] = "On",
        ["plugin.off"] = "Off",
        ["plugin.downloading"] = "Downloading %d/%d",
        ["plugin.enabled"] = "%s enabled: %d characters",
        ["plugin.enabledFailed"] = "%s enabled: %d characters, %d images failed to download",
        ["plugin.disabled"] = "%s disabled – its themes were removed",
        ["plugin.failed"] = "%s failed to load – see the console (F9)",
        ["plugin.uncategorized"] = "Uncategorized",
        ["plugin.clear"] = "Clear \"%s\" image cache",
        ["plugin.clearSize"] = " (%s, %d files)",
        ["plugin.clearEmpty"] = " (empty)",
        ["plugin.calculating"] = " (calculating…)",
        ["plugin.cleared"] = "Cache cleared",
        ["plugin.clearedContent"] = "%s: %d files deleted",
        ["plugin.noDelfile"] = "This executor lacks delfile, so the cache can't be cleared here; delete workspace\\%s\\assets manually.",
        ["plugin.note"] = "Turning a plugin on downloads its character themes and wallpapers into the library; turning it off removes them right away. Downloaded files stay until you clear them.",
        ["look.fontSize"] = "Text size",
        ["look.animations"] = "Animations",
        ["look.animationsDesc"] = "When off, every transition is instant",
        ["look.language"] = "Language",
        ["look.languageDesc"] = "Theme cards and plugins update instantly; other text after re-running the script",
        ["look.languageChanged"] = "Switched to %s",
        ["boot.when"] = "On next launch",
        ["boot.follow"] = "Keep current",
        ["boot.fixed"] = "Fixed theme",
        ["boot.random"] = "Random",
        ["boot.note"] = "Fixed remembers the theme at the time you chose it; Random picks among themes with wallpapers, or all themes if none have one.",
        ["cfg.name"] = "Config name",
        ["cfg.list"] = "Saved configs",
        ["cfg.empty"] = "(none)",
        ["cfg.save"] = "Save current",
        ["cfg.load"] = "Load",
        ["cfg.refresh"] = "Refresh list",
        ["keys.toggle"] = "Show / hide UI",
        ["keys.toggleDesc"] = "Backspace clears, Esc cancels",
    },
}

SenkoUI.Language = "en"
do
    local saved = FS.readJson(SenkoUI.Folder .. "/settings.json")
    if saved and type(saved.language) == "string" then
        SenkoUI.Language = saved.language
    end
end

-- 依目前語言取字串：目前語言 → English → 繁體中文 → 鍵名；有參數時套用 string.format
local function T(key, ...)
    local dict = LOCALES[SenkoUI.Language]
    local s = dict and dict[key]
    if s == nil then
        s = LOCALES.en[key] or LOCALES["zh-TW"][key] or key
    end
    if select("#", ...) > 0 then
        return string.format(s, ...)
    end
    return s
end

-- 字串或語系表 { ["zh-TW"] = ..., en = ... } → 目前語言的字串（缺少時依序退回 English、繁體中文）
local function localized(value)
    if type(value) ~= "table" then
        return value
    end
    return value[SenkoUI.Language] or value.en or value["zh-TW"] or select(2, next(value))
end

-- ============================================================
-- 圖片資源：HttpGet 下載 → writefile 快取 → getcustomasset 取得 rbxasset 位址
-- （ImageLabel 不能直接吃 http 網址，必須經過執行器的 getcustomasset）
-- ============================================================
local Assets = { cache = {}, pending = {}, folders = {} }
Assets.getAsset = getcustomasset or getsynasset
Assets.available = FS.available and type(Assets.getAsset) == "function"

local function urlKey(url)
    local h = 0
    for i = 1, #url do
        h = (h * 31 + url:byte(i)) % 2147483647
    end
    return tostring(h)
end

-- folder：快取子資料夾（插件名稱），讓插件管理能分別計算 / 清除各插件下載的圖片
function Assets.load(url, folder)
    if not url or url == "" or not Assets.available then
        return nil
    end
    if Assets.cache[url] then
        return Assets.cache[url]
    end
    -- 同一張圖同時被要求多次時只下載一次
    while Assets.pending[url] do
        task.wait(0.1)
    end
    if Assets.cache[url] then
        return Assets.cache[url]
    end
    Assets.pending[url] = true
    local result
    local ok, err = pcall(function()
        -- 非網址時視為執行器 workspace 內的相對路徑，直接取用
        if not url:match("^https?://") then
            if not isfile(url) then
                error("找不到本機圖片：" .. url)
            end
            result = Assets.getAsset(url)
            return
        end
        FS.ensureFolder(SenkoUI.Folder)
        FS.ensureFolder(SenkoUI.Folder .. "/assets")
        local name = ((url:match("([^/?#]+)$") or "image"):gsub("[^%w%._%-]", "_"))
        -- 轉檔服務的網址沒有副檔名，補上 .png（部分執行器的 getcustomasset 靠副檔名判斷格式）
        local lower = name:lower()
        if not (lower:match("%.png$") or lower:match("%.jpe?g$")) then
            name = "image.png"
        end
        local dir = SenkoUI.Folder .. "/assets"
        if type(folder) == "string" and folder ~= "" then
            dir = dir .. "/" .. folder:gsub("[^%w%._%-]", "_")
            FS.ensureFolder(dir)
        end
        local path = dir .. "/" .. urlKey(url) .. "_" .. name
        if not isfile(path) then
            local data = game:HttpGet(url)
            local head = type(data) == "string" and data:sub(1, 4) or ""
            -- 只接受 PNG / JPG，避免把 404 頁面寫成圖片
            if head ~= "\137PNG" and head:sub(1, 3) ~= "\255\216\255" then
                error("不是有效的 PNG / JPG：" .. url)
            end
            writefile(path, data)
        end
        result = Assets.getAsset(path)
    end)
    Assets.pending[url] = nil
    if ok and result then
        Assets.cache[url] = result
        Assets.folders[url] = folder or ""
        return result
    end
    warn("[SenkoUI] 圖片載入失敗：" .. tostring(err))
    return nil
end

SenkoUI.Assets = Assets

-- ============================================================
-- 圖示：名稱 → rbxassetid；Lucide 圖示內建（見檔案結尾），其他可用 AddIcons 註冊
-- ============================================================
SenkoUI.Icons = {}
local warnedIcons = {}
local iconResolvers = {} -- 圖示表找不到時依序呼叫（可 yield，例如線上下載），見 AddIconResolver

local function warnIcon(name)
    if not warnedIcons[name] then
        warnedIcons[name] = true
        warn("[SenkoUI] 找不到圖示「" .. name .. "」，請確認名稱正確（Lucide 名稱見 https://lucide.dev/icons/）")
    end
end

-- 只查圖示表（不 yield）：回傳圖片位址；nil = 當成文字圖示；false = 像圖示名稱但表裡沒有
local function resolveIcon(value)
    if type(value) == "number" then
        return "rbxassetid://" .. value
    end
    if type(value) ~= "string" or value == "" then
        return nil
    end
    if value:find("^rbxasset") then
        return value
    end
    if value:match("^%d+$") then
        return "rbxassetid://" .. value
    end
    local key = value:lower()
    local found = SenkoUI.Icons[key] or SenkoUI.Icons["lucide-" .. key]
    if found then
        return found
    end
    if #value > 1 and value:match("^[%w%-]+$") then
        return false
    end
    return nil
end

-- 查圖示表，找不到再交給解析器（可能 yield）；成功的結果寫回圖示表，失敗回傳 nil
local function lookupIcon(value)
    local image = resolveIcon(value)
    if image ~= false then
        return image or nil
    end
    for _, resolver in ipairs(iconResolvers) do
        local ok, result = pcall(resolver.fn, value)
        if ok and type(result) == "string" and result ~= "" then
            SenkoUI.Icons[value:lower()] = result
            return result
        elseif not ok then
            warn("[SenkoUI] 插件 " .. tostring(resolver.plugin) .. " 的圖示解析出錯：" .. tostring(result))
        end
    end
    warnIcon(value)
    return nil
end

-- ============================================================
-- 主題定義
-- 核心只內建「曜石（黑）」與「雲母（白）」，其餘主題由插件提供（見 PLUGINS.md）
-- 以 T 結尾的欄位是 BackgroundTransparency / Transparency（0 = 不透明）
-- ============================================================
local function isNumericKey(k)
    return k:sub(-1) == "T" or k == "radius" or k == "cardRadius"
end

-- 所有主題共用的色票骨架；AddTheme 沒指定 Base 時以此為底
local BASE_PALETTE = {
    win0 = 0x11263C, win1 = 0x274658,
    winStroke = 0x8FE6F6, winStrokeT = 0.72,
    sidebar = 0x0C192B, sidebarT = 0.45,
    hairline = 0x8FE6F6, hairlineT = 0.85,
    divider = 0xEAF4FF, dividerT = 0.88,
    card = 0x152A41, cardT = 0.42,
    cardStroke = 0xA0CDE7, cardStrokeT = 0.8,
    trackOff = 0xFFFFFF, trackOffT = 0.84,
    knob = 0xFFFFFF, knobStroke = 0x000000, knobStrokeT = 0.7,
    segTrack = 0x000000, segTrackT = 0.68,
    segPill = 0xFFFFFF, segPillT = 0.86,
    field = 0xFFFFFF, fieldT = 0.93,
    fieldStroke = 0xFFFFFF, fieldStrokeT = 0.87,
    text = 0xEAF4FF, text2 = 0xBED2E5, text3 = 0x94ABC4,
    accent = 0x8FE6F6, accent2 = 0xB6A8FF,
    good = 0x6FF0C0, warn = 0xFFC978,
    toast = 0x0C192B, toastT = 0.04,
    radius = 12, cardRadius = 9,
}

local function makePalette(base, overrides)
    local p = {}
    for k, v in pairs(base) do
        p[k] = v
    end
    for k, v in pairs(overrides or {}) do
        p[k] = v
    end
    for k, v in pairs(p) do
        if type(v) == "number" and not isNumericKey(k) then
            p[k] = rgb(v)
        end
    end
    return p
end

local THEMES = {
    {
        key = "Obsidian", i18n = "theme.Obsidian", nameCn = LOCALES["zh-TW"]["theme.Obsidian"], nameEn = "OBSIDIAN", tag = "DARK", groups = { "Basic" }, glyph = "花",
        character = false, shape = "circle",
        caption = "",
        constellation = "S E N K O   U I", regionKey = "region.workspace",
        aliases = { "dark" },
        palette = makePalette(BASE_PALETTE, {
            win0 = 0x171B21, win1 = 0x101317,
            winStroke = 0xFFFFFF, winStrokeT = 0.88,
            sidebar = 0x13161B, sidebarT = 0.1,
            hairline = 0x4DA3FF, hairlineT = 0.9,
            divider = 0xFFFFFF, dividerT = 0.93,
            card = 0xFFFFFF, cardT = 0.94,
            cardStroke = 0xFFFFFF, cardStrokeT = 0.93,
            trackOff = 0xFFFFFF, trackOffT = 0.88,
            knob = 0xFFFFFF, knobStroke = 0x000000, knobStrokeT = 0.6,
            segTrack = 0x000000, segTrackT = 0.72,
            segPill = 0xFFFFFF, segPillT = 0.9,
            field = 0xFFFFFF, fieldT = 0.95,
            fieldStroke = 0xFFFFFF, fieldStrokeT = 0.92,
            text = 0xF5F6F8, text2 = 0x9BA3AF, text3 = 0x5E6672,
            accent = 0x4DA3FF, accent2 = 0x9BE0FF,
            good = 0x3DDC97, warn = 0xFFB74D,
            toast = 0x171B21, toastT = 0,
        }),
    },
    {
        key = "Mica", i18n = "theme.Mica", nameCn = LOCALES["zh-TW"]["theme.Mica"], nameEn = "MICA", tag = "LIGHT", groups = { "Basic" }, glyph = "花",
        character = false, shape = "circle",
        caption = "",
        constellation = "S E N K O   U I", regionKey = "region.workspace",
        aliases = { "light" },
        palette = makePalette(BASE_PALETTE, {
            win0 = 0xFBFCFE, win1 = 0xF1F3F8,
            winStroke = 0x1E283C, winStrokeT = 0.84,
            sidebar = 0xF7F9FC, sidebarT = 0.1,
            hairline = 0x1E283C, hairlineT = 0.9,
            divider = 0x1E283C, dividerT = 0.9,
            card = 0xFFFFFF, cardT = 0,
            cardStroke = 0x1E283C, cardStrokeT = 0.9,
            trackOff = 0x1E283C, trackOffT = 0.84,
            knob = 0xFFFFFF, knobStroke = 0x1E283C, knobStrokeT = 0.8,
            segTrack = 0x1E283C, segTrackT = 0.9,
            segPill = 0xFFFFFF, segPillT = 0,
            field = 0x1E283C, fieldT = 0.95,
            fieldStroke = 0x1E283C, fieldStrokeT = 0.9,
            text = 0x111A2B, text2 = 0x5B6678, text3 = 0x98A2B3,
            accent = 0x0A84FF, accent2 = 0x5AC8FA,
            good = 0x12B981, warn = 0xE8A33D,
            toast = 0xFFFFFF, toastT = 0,
        }),
    },
}

-- 基礎壁紙主題：壁紙為 Senko UI 原創程序化圖（assets/wallpapers/），選到時才下載
local BASIC_WALLPAPER_THEMES = {
    {
        key = "Aurora", tag = "NIGHT", glyph = "極", shape = "diamond", file = "aurora.jpg", dim = 0.5, particle = "snow",
        palette = {
            win0 = 0x0B1A20, win1 = 0x12303A, winStroke = 0x9FF0D2, hairline = 0x9FF0D2,
            sidebar = 0x0A161C, card = 0x10262E, cardStroke = 0x9ED9CB,
            text = 0xEFFBF7, text2 = 0xC4E3DB, text3 = 0x8FB3AC,
            accent = 0x5EE6B0, accent2 = 0x9C8CFF,
            segTrack = 0x041014, segPill = 0xB5F2DC, field = 0xE4FBF4, fieldStroke = 0xB6E6D9,
            good = 0x7CF0B8, warn = 0xFFD28A, toast = 0x0A161C,
        },
    },
    {
        key = "Dusk", tag = "SUNSET", glyph = "霞", shape = "circle", file = "dusk.jpg", dim = 0.55, particle = "ember",
        palette = {
            win0 = 0x2A1426, win1 = 0x5A2A35, winStroke = 0xF6BFA6, hairline = 0xF7C9A8,
            sidebar = 0x22101F, card = 0x3A1C2C, cardStroke = 0xF1B7A2,
            text = 0xFFF1EA, text2 = 0xEFCFC4, text3 = 0xC49E9A,
            accent = 0xFF9F7A, accent2 = 0xC58BFF,
            segTrack = 0x160A14, segPill = 0xFFC2A6, field = 0xFFE9DF, fieldStroke = 0xF0BCA8,
            good = 0xD9E6A0, warn = 0xFFC56E, toast = 0x22101F,
        },
    },
    {
        key = "Abyss", tag = "OCEAN", glyph = "海", shape = "circle", file = "abyss.jpg", dim = 0.5, particle = "bubble",
        palette = {
            win0 = 0x04121F, win1 = 0x0A2A44, winStroke = 0x8FD3FF, hairline = 0x8FD3FF,
            sidebar = 0x030E19, card = 0x082036, cardStroke = 0x8CC6EE,
            text = 0xEAF6FF, text2 = 0xBFD8EC, text3 = 0x86A6C2,
            accent = 0x56C8FF, accent2 = 0x7BE0D6,
            segTrack = 0x010810, segPill = 0xA8E0FF, field = 0xE0F3FF, fieldStroke = 0xA9D2F0,
            good = 0x7EE3C4, warn = 0xFFD08A, toast = 0x030E19,
        },
    },
    {
        key = "Nebula", tag = "SPACE", glyph = "星", shape = "diamond", file = "nebula.jpg", dim = 0.45, particle = "glow",
        palette = {
            win0 = 0x120B24, win1 = 0x2A1448, winStroke = 0xD6B8FF, hairline = 0xE3C6FF,
            sidebar = 0x0D0819, card = 0x1D1236, cardStroke = 0xC9AEF2,
            text = 0xF6F0FF, text2 = 0xD9CCF2, text3 = 0xA697C7,
            accent = 0xC48CFF, accent2 = 0xFF8CC8,
            segTrack = 0x07040F, segPill = 0xE2C8FF, field = 0xF1E8FF, fieldStroke = 0xCDB6F0,
            good = 0x9FE8C8, warn = 0xFFD18A, toast = 0x0D0819,
        },
    },
    {
        key = "Sakura", tag = "SPRING", glyph = "櫻", shape = "circle", file = "sakura.jpg", dim = 0.35, particle = "petal",
        palette = { -- 亮色主題
            win0 = 0xFFF4F7, win1 = 0xF7E6EE, winStroke = 0x6B3A4E, winStrokeT = 0.85,
            sidebar = 0xFFF7FA, sidebarT = 0.25, hairline = 0x9C5A74, hairlineT = 0.85,
            divider = 0x6B3A4E, dividerT = 0.88, card = 0xFFFFFF, cardT = 0.35,
            cardStroke = 0x9C5A74, cardStrokeT = 0.85, trackOff = 0x6B3A4E, trackOffT = 0.84,
            knob = 0xFFFFFF, knobStroke = 0x6B3A4E, knobStrokeT = 0.8,
            segTrack = 0x6B3A4E, segTrackT = 0.9, segPill = 0xFFFFFF, segPillT = 0,
            field = 0x6B3A4E, fieldT = 0.94, fieldStroke = 0x6B3A4E, fieldStrokeT = 0.88,
            text = 0x3A1F2B, text2 = 0x6E4B5A, text3 = 0x9C7F8B,
            accent = 0xE0578A, accent2 = 0xF29BB8, good = 0x2FA87A, warn = 0xD98A2B,
            toast = 0xFFFFFF, toastT = 0,
        },
    },
}
for _, spec in ipairs(BASIC_WALLPAPER_THEMES) do
    table.insert(THEMES, {
        key = spec.key, i18n = "theme." .. spec.key, nameCn = LOCALES["zh-TW"]["theme." .. spec.key],
        nameEn = spec.key:upper(), tag = spec.tag,
        groups = { "Basic" }, glyph = spec.glyph, character = true, shape = spec.shape,
        caption = "",
        constellation = "S E N K O   U I", regionKey = "region.workspace",
        palette = makePalette(BASE_PALETTE, spec.palette),
    })
end

for _, def in ipairs(THEMES) do
    def.palette.def = def
end

-- 主題庫篩選列的分類；「全部」固定在最前面，其餘依 order、再依註冊順序排列
-- 名稱可用 SenkoUI:AddGroup({ Key = ..., Label = ... }) 自訂或改名；labelKey 為核心字典的鍵（隨語言切換）
local GROUP_ALL = { key = "All", labelKey = "group.all" }
local GROUPS = {
    { key = "Basic", labelKey = "group.basic", order = 0 },
}

local function findGroup(key)
    for _, g in ipairs(GROUPS) do
        if g.key == key then
            return g
        end
    end
    return nil
end

local function sortedGroups()
    local index = {}
    for i, g in ipairs(GROUPS) do
        index[g] = i
    end
    local list = table.clone(GROUPS)
    table.sort(list, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        return index[a] < index[b]
    end)
    return list
end

local function themeInGroup(def, key)
    for _, g in ipairs(def.groups or {}) do
        if g == key then
            return true
        end
    end
    return false
end

-- 以下依目前語言取顯示文字（語言切換時重新呼叫即可更新）
local function groupLabel(g)
    if g.labelKey then
        return T(g.labelKey)
    end
    return localized(g.label) or g.key
end

-- 主題卡第一行：角色 / 主題名稱
local function themeName(def)
    if def.i18n then
        return T(def.i18n)
    end
    return localized(def.names) or def.nameCn
end


-- 主題卡第三行：簡易說明
local function themeMotto(def)
    if def.i18n then
        return T(def.i18n .. ".motto")
    end
    return localized(def.motto) or ""
end

-- 側欄底部預設文字：主題的 region，沒有時用分類名稱
local function themeRegion(def)
    if def.regionKey then
        return T(def.regionKey)
    end
    local region = localized(def.region)
    if region and region ~= "" then
        return region
    end
    local g = def.groups and def.groups[1] and findGroup(def.groups[1])
    return g and groupLabel(g) or ""
end

-- ============================================================
-- 壁紙
-- background / character 可以是：網址、workspace 路徑、{ 來源名稱, 檔名 }，或回傳上述值的函式
-- dim：遮罩濃度（越高越暗，保證文字可讀）
-- ============================================================
SenkoUI.AssetSources = { -- 來源名稱 → 網址或 workspace 資料夾，供 { 來源名稱, 檔名 } 使用
    senko = "https://raw.githubusercontent.com/Tseting-nil/senko-ui/main/assets/wallpapers/",
}

local WALLPAPERS = {}
for _, spec in ipairs(BASIC_WALLPAPER_THEMES) do
    WALLPAPERS[spec.key] = { background = { "senko", spec.file }, dim = spec.dim, particle = spec.particle }
end

-- 壁紙欄位 → 網址或 workspace 路徑：字串、函式（延遲計算）或 { 來源名稱, 檔名 }
local function resolveWallpaperUrl(entry)
    if type(entry) == "function" then
        local ok, value = pcall(entry)
        entry = ok and value or nil
    end
    if entry == nil or entry == "" then
        return nil
    end
    if type(entry) == "string" then
        return entry
    end
    local base = SenkoUI.AssetSources[entry[1]]
    if type(base) ~= "string" or base == "" then
        return nil
    end
    if base:sub(-1) ~= "/" then
        base = base .. "/"
    end
    return base .. entry[2]
end

-- 粒子樣式：dir -1 往上飄、1 往下落；shape 可用 dot / petal / diamond / ring
local PARTICLE_STYLES = {
    glow = { dir = -1, speed = 0.018, size = { 2, 4 }, sway = 0.01, shape = "dot", count = 18 },
    petal = { dir = 1, speed = 0.03, size = { 4, 7 }, sway = 0.04, shape = "petal", count = 14 },
    ember = { dir = -1, speed = 0.04, size = { 2, 4 }, sway = 0.015, shape = "diamond", count = 18 },
    bubble = { dir = -1, speed = 0.022, size = { 3, 7 }, sway = 0.012, shape = "ring", count = 14 },
    dust = { dir = -1, speed = 0.012, size = { 2, 3 }, sway = 0.02, shape = "diamond", count = 16 },
    snow = { dir = 1, speed = 0.02, size = { 2, 4 }, sway = 0.03, shape = "dot", count = 22 },
    spark = { dir = -1, speed = 0.03, size = { 2, 3 }, sway = 0.02, shape = "diamond", count = 20 },
}

local function findTheme(key)
    if type(key) == "number" then
        return THEMES[key]
    end
    if type(key) ~= "string" then
        return nil
    end
    local lower = key:lower()
    for _, def in ipairs(THEMES) do
        if def.key:lower() == lower or def.nameCn == key or def.nameEn:lower() == lower then
            return def
        end
    end
    -- 別名（AddTheme 的 Aliases）
    for _, def in ipairs(THEMES) do
        for _, alias in ipairs(def.aliases or {}) do
            if alias:lower() == lower then
                return def
            end
        end
    end
    return nil
end

SenkoUI.Themes = {}
for _, def in ipairs(THEMES) do
    table.insert(SenkoUI.Themes, def.key)
end

function SenkoUI:GetThemes()
    local list = {}
    for _, def in ipairs(THEMES) do
        table.insert(list, {
            Key = def.key,
            Name = themeName(def),
            English = def.nameEn,
            Groups = table.clone(def.groups or {}),
            Plugin = def.plugin,
        })
    end
    return list
end

-- ============================================================
-- 元素徽記（外環 + 菱形 + 四點 + 元素字）
-- ============================================================
local function buildEmblem(parent, size)
    local root = new("Frame", {
        Name = "Emblem",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(size, size),
        Parent = parent,
    })
    local ring = new("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, -2, 1, -2),
        Parent = root,
    })
    corner(ring, 999)
    local ringStroke = new("UIStroke", { Thickness = math.max(1, size / 26), Parent = ring })

    local spinner = new("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        Rotation = 0,
        Parent = root,
    })
    local dots = {}
    local dotSize = math.max(3, math.floor(size / 9))
    local spots = { { 0.5, 0 }, { 1, 0.5 }, { 0.5, 1 }, { 0, 0.5 } }
    for i, s in ipairs(spots) do
        local d = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(s[1], 0, s[2], 0),
            Size = UDim2.fromOffset(dotSize, dotSize),
            Rotation = 45,
            BorderSizePixel = 0,
            Parent = spinner,
        })
        dots[i] = d
    end

    local diamond = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.6, 0.6),
        Rotation = 45,
        BorderSizePixel = 0,
        Parent = root,
    })
    corner(diamond, math.max(2, math.floor(size / 14)))
    local diamondStroke = new("UIStroke", { Thickness = math.max(1, size / 30), Parent = diamond })

    local glyph = new("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.6, 0.6),
        Font = FONT_BOLD,
        TextSize = math.floor(size * 0.32),
        Text = "",
        Parent = root,
    })

    local emblem = { Frame = root, Spinner = spinner, Glyph = glyph }

    -- fade：整體不透明度倍率（1 = 正常，0.1 = 浮水印）
    function emblem.Refresh(p, glyphText, fade, instant)
        fade = fade or 1
        local function a(alpha)
            return 1 - alpha * fade
        end
        setp(ringStroke, { Color = p.accent, Transparency = a(0.6) }, instant)
        for _, d in ipairs(dots) do
            setp(d, { BackgroundColor3 = p.accent2, BackgroundTransparency = a(0.95) }, instant)
        end
        setp(diamond, { BackgroundColor3 = p.accent, BackgroundTransparency = a(0.2) }, instant)
        setp(diamondStroke, { Color = p.accent, Transparency = a(0.85) }, instant)
        setp(glyph, { TextColor3 = p.text, TextTransparency = a(1) }, instant)
        glyph.Text = glyphText or ""
    end

    return emblem
end

-- ============================================================
-- Gui 掛載（gethui → protect_gui → CoreGui → PlayerGui）
-- ============================================================
local function mountGui(gui)
    if type(gethui) == "function" then
        local ok, holder = pcall(gethui)
        if ok and holder then
            gui.Parent = holder
            return
        end
    end
    if syn and type(syn.protect_gui) == "function" then
        pcall(syn.protect_gui, gui)
    end
    local ok = pcall(function()
        gui.Parent = CoreGui
    end)
    if not ok or gui.Parent == nil then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

-- ============================================================
-- Window 類別
-- ============================================================
local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

-- ---------- 主題綁定 ----------
function Window:_resolve(token)
    if type(token) == "function" then
        return token(self.palette)
    end
    return self.palette[token]
end

function Window:_bind(obj, prop, token)
    table.insert(self._binds, { obj = obj, prop = prop, token = token })
    obj[prop] = self:_resolve(token)
end

function Window:_bg(obj, token)
    self:_bind(obj, "BackgroundColor3", token)
    self:_bind(obj, "BackgroundTransparency", function(p)
        return p[token .. "T"] or 0
    end)
end

function Window:_stroke(obj, token, thickness)
    local s = new("UIStroke", {
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = obj,
    })
    self:_bind(s, "Color", token)
    self:_bind(s, "Transparency", function(p)
        return p[token .. "T"] or 0
    end)
    return s
end

function Window:_corner(obj, token)
    local c = new("UICorner", { Parent = obj })
    self:_bind(c, "CornerRadius", function(p)
        return UDim.new(0, p[token] or 8)
    end)
    return c
end

function Window:_onTheme(fn)
    table.insert(self._listeners, fn)
    pcall(fn, self.palette, true)
end

function Window:_conn(connection)
    table.insert(self._connections, connection)
    return connection
end

function Window:_text(obj, size)
    table.insert(self._texts, { obj = obj, size = size })
    obj.TextSize = math.floor(size * self.fontScale + 0.5)
end

function Window:_label(parent, text, size, tone, props)
    local lbl = new("TextLabel", {
        BackgroundTransparency = 1,
        Text = text or "",
        Font = FONT,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = parent,
    })
    if props then
        for k, v in pairs(props) do
            lbl[k] = v
        end
    end
    self:_text(lbl, size or 13)
    if tone then
        self:_bind(lbl, "TextColor3", tone)
    end
    return lbl
end

function Window:_applyTheme(instant)
    local p = self.palette
    local grouped = {}
    for i = #self._binds, 1, -1 do
        local b = self._binds[i]
        if b.obj.Parent == nil then
            table.remove(self._binds, i)
        else
            local ok, value = pcall(self._resolve, self, b.token)
            if ok and value ~= nil then
                local kind = typeof(value)
                if instant or (kind ~= "Color3" and kind ~= "number") then
                    pcall(function()
                        b.obj[b.prop] = value
                    end)
                else
                    grouped[b.obj] = grouped[b.obj] or {}
                    grouped[b.obj][b.prop] = value
                end
            end
        end
    end
    for obj, props in pairs(grouped) do
        tween(obj, props, 0.45, Enum.EasingStyle.Sine)
    end
    for _, fn in ipairs(self._listeners) do
        pcall(fn, p, instant)
    end
end

function Window:SetFontScale(scale)
    self.fontScale = math.clamp(scale, 1, 1.25)
    for i = #self._texts, 1, -1 do
        local t = self._texts[i]
        if t.obj.Parent == nil then
            table.remove(self._texts, i)
        else
            t.obj.TextSize = math.floor(t.size * self.fontScale + 0.5)
        end
    end
    self:_saveSettings()
end

function Window:SetTheme(key)
    local def = findTheme(key)
    if not def then
        warn("[SenkoUI] 找不到主題：" .. tostring(key))
        return
    end
    if def == self.theme then
        return
    end
    self.theme = def
    self.palette = def.palette
    self:_applyTheme(false)
    self:_saveSettings()
    safeCall(self._onThemeChanged, def.key)
    fireHook("ThemeChanged", self, def.key)
end

function Window:GetTheme()
    return self.theme.key
end

-- 側欄底部文字：字串 = 固定（更換主題不變）、false = 隱藏、nil = 恢復跟隨主題
function Window:SetFooter(text)
    if text ~= nil and text ~= false then
        text = tostring(text)
    end
    self._footer = text
    if self._footerFrame then
        self._footerFrame.Visible = text ~= false
        self._footerLabel.Text = type(text) == "string" and text or themeRegion(self.theme)
    end
end

-- 目前左下角顯示的文字；隱藏時回傳 nil
function Window:GetFooter()
    if self._footer == false or not self._footerLabel then
        return nil
    end
    return self._footerLabel.Text
end

-- 語言切換時呼叫：重新套用綁定的文字（側欄副標、底部文字），並通知主題頁更新主題卡 / 分類 / 插件管理
function Window:_onLanguage(fn)
    table.insert(self._langListeners, fn)
end

function Window:_refreshLanguage()
    self:_applyTheme(true)
    for _, fn in ipairs(self._langListeners) do
        local ok, err = pcall(fn)
        if not ok then
            warn("[SenkoUI] 語言更新失敗：" .. tostring(err))
        end
    end
end

-- ---------- 偏好設定 ----------
function Window:_settingsPath()
    return SenkoUI.Folder .. "/settings.json"
end

function Window:_saveSettings()
    if not self._ready or not self.saveSettings then
        return
    end
    FS.ensureFolder(SenkoUI.Folder)
    FS.writeJson(self:_settingsPath(), {
        theme = self.theme.key,
        startupMode = self.startupMode,
        startupTheme = self.startupTheme,
        fontPercent = math.floor(self.fontScale * 100 + 0.5),
        animations = SenkoUI.Animations,
        wallpaper = self.wallpaperEnabled,
        wallStrength = self.wallStrength,
        wallMotion = self.wallMotion,
        particles = self.particlesEnabled,
        toggleKey = self.toggleKey and self.toggleKey.Name or nil,
        language = SenkoUI.Language,
    })
end

-- ---------- 拖曳 ----------
function Window:_draggable(handle, target, onMove)
    local dragging, startPos, startInput
    self:_conn(handle.InputBegan:Connect(function(input)
        if isPress(input) and not self._maximized then
            dragging = true
            startInput = input.Position
            startPos = target.Position
        end
    end))
    self:_conn(UserInputService.InputChanged:Connect(function(input)
        if dragging and isMove(input) then
            local delta = input.Position - startInput
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
            if onMove then
                onMove()
            end
        end
    end))
    self:_conn(UserInputService.InputEnded:Connect(function(input)
        if isPress(input) then
            dragging = false
        end
    end))
end

-- ---------- 建立視窗 ----------
function SenkoUI:CreateWindow(opts)
    opts = opts or {}
    local self = setmetatable({}, Window)
    self._binds, self._listeners, self._connections, self._texts = {}, {}, {}, {}
    self._langListeners = {}
    self.Tabs = {}
    self._keybinds = {}
    self._ready = false
    self.saveSettings = opts.SaveSettings ~= false
    self.toggleKey = Enum.KeyCode.LeftAlt
    if typeof(opts.ToggleKey) == "EnumItem" then
        self.toggleKey = opts.ToggleKey
    elseif type(opts.ToggleKey) == "string" then
        local ok, key = pcall(function()
            return Enum.KeyCode[opts.ToggleKey]
        end)
        if ok and key then
            self.toggleKey = key
        end
    end
    self._onThemeChanged = opts.OnThemeChanged

    -- 讀取偏好設定並決定啟動主題
    local settings = self.saveSettings and FS.readJson(SenkoUI.Folder .. "/settings.json") or nil
    self.startupMode = 0
    self.startupTheme = opts.Theme or "Obsidian"
    local themeKey = opts.Theme or "Obsidian"
    local fontPercent = opts.FontPercent or 112
    self.wallpaperEnabled = opts.Wallpaper ~= false
    self.wallStrength = opts.WallpaperStrength or 0.82
    self.wallMotion = opts.WallpaperMotion ~= false
    self.particlesEnabled = opts.Particles ~= false
    -- 圖片來源：AssetSources = { 名稱 = 網址 }；AssetSource / ExtraAssetSource 是舊參數，等同 origin / extra
    for name, base in pairs(opts.AssetSources or {}) do
        SenkoUI.AssetSources[name] = base
    end
    if opts.AssetSource then
        SenkoUI.AssetSources.origin = opts.AssetSource
    end
    if opts.ExtraAssetSource then
        SenkoUI.AssetSources.extra = opts.ExtraAssetSource
    end
    -- 每個視窗自己的壁紙表，可用 opts.Wallpapers 覆寫
    self._wallpapers = {}
    self._wallpaperOff = {} -- opts.Wallpapers 設為 false 的主題，當場載入插件時也不補回
    self._libraryRefreshers, self._iconRetries = {}, {}
    for key, spec in pairs(WALLPAPERS) do
        local copy = {}
        for k, v in pairs(spec) do
            copy[k] = v
        end
        self._wallpapers[key] = copy
    end
    for key, override in pairs(opts.Wallpapers or {}) do
        local def = findTheme(key)
        if def then
            local spec = self._wallpapers[def.key] or { dim = 0.55, particle = "glow" }
            if override == false then
                spec = nil
                self._wallpaperOff[def.key] = true
            else
                spec.background = override.Background or override.background or spec.background
                spec.character = override.Character or override.character or spec.character
                spec.dim = override.Dim or spec.dim
                spec.particle = override.Particle or spec.particle
            end
            self._wallpapers[def.key] = spec
        end
    end
    if settings and not opts.ForceTheme then
        self.startupMode = tonumber(settings.startupMode) or 0
        self.startupTheme = settings.startupTheme or self.startupTheme
        if self.startupMode == 2 then
            local pool = {}
            for _, def in ipairs(THEMES) do
                if def.character then
                    table.insert(pool, def.key)
                end
            end
            -- 沒有任何壁紙主題（例如沒載入插件）時，從全部主題抽
            if #pool == 0 then
                for _, def in ipairs(THEMES) do
                    table.insert(pool, def.key)
                end
            end
            themeKey = pool[math.random(1, #pool)]
        elseif self.startupMode == 1 then
            themeKey = self.startupTheme
        else
            themeKey = settings.theme or themeKey
        end
        fontPercent = tonumber(settings.fontPercent) or fontPercent
        -- 使用者在主題頁改過的切換鍵優先於腳本預設
        if type(settings.toggleKey) == "string" then
            local ok, key = pcall(function()
                return Enum.KeyCode[settings.toggleKey]
            end)
            if ok and key then
                self.toggleKey = key
            end
        end
        if settings.animations ~= nil then
            SenkoUI.Animations = settings.animations and true or false
        end
        if settings.wallpaper ~= nil and opts.Wallpaper ~= false then
            self.wallpaperEnabled = settings.wallpaper and true or false
        end
        self.wallStrength = tonumber(settings.wallStrength) or self.wallStrength
        if settings.wallMotion ~= nil then
            self.wallMotion = settings.wallMotion and true or false
        end
        if settings.particles ~= nil then
            self.particlesEnabled = settings.particles and true or false
        end
    end
    -- 上次儲存的主題若來自這次沒載入的插件，退回腳本指定的主題，再退回曜石
    self.theme = findTheme(themeKey) or findTheme(opts.Theme) or THEMES[1]
    self.palette = self.theme.palette
    self.fontScale = math.clamp(fontPercent / 100, 1, 1.25)

    local size = opts.Size or Vector2.new(640, 430)
    if typeof(size) == "UDim2" then
        size = Vector2.new(size.X.Offset, size.Y.Offset)
    end
    self.minSize = opts.MinSize or Vector2.new(500, 330)
    local SIDEBAR = 172
    local TOPBAR = 54

    -- 根 ScreenGui
    local guiName = opts.GuiName or "SenkoUI"
    local gui = new("ScreenGui", {
        Name = guiName,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999,
    })
    mountGui(gui)
    if opts.Unique ~= false and gui.Parent then
        for _, other in ipairs(gui.Parent:GetChildren()) do
            if other ~= gui and other.Name == guiName and other:IsA("ScreenGui") then
                other:Destroy()
            end
        end
    end
    self.Gui = gui

    -- 外框容器（拖曳、縮放都作用在這裡）
    local holder = new("Frame", {
        Name = "Holder",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(size.X, size.Y),
        BackgroundTransparency = 1,
        Parent = gui,
    })
    self.Holder = holder
    local holderScale = new("UIScale", { Parent = holder })
    self._holderScale = holderScale
    local function fitScreen()
        local vp = viewport()
        local s = math.min(1, (vp.X - 24) / holder.Size.X.Offset, (vp.Y - 24) / holder.Size.Y.Offset)
        holderScale.Scale = math.max(0.45, s)
    end
    fitScreen()
    if workspace.CurrentCamera then
        self:_conn(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScreen))
    end
    self._fitScreen = fitScreen

    -- 陰影
    local shadow = new("ImageLabel", {
        Name = "Shadow",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 6),
        Size = UDim2.new(1, 60, 1, 60),
        Image = "rbxassetid://6014261993",
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 0.45,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        ZIndex = 0,
        Parent = holder,
    })
    self.Shadow = shadow

    -- 主畫布（CanvasGroup 讓圓角裁切與整體淡入淡出都正確）
    local main = new("CanvasGroup", {
        Name = "Main",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = holder,
    })
    self.Main = main
    self:_corner(main, "radius")
    local mainScale = new("UIScale", { Parent = main })
    self._mainScale = mainScale

    -- 平面畫布：CanvasGroup 會先渲染成貼圖，視窗放大時解析度被壓低而糊掉；
    -- 最大化時把內容搬到這個一般 Frame 原生渲染，淡入淡出前再搬回 CanvasGroup
    self._flat = new("Frame", {
        Name = "Flat",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        Parent = holder,
    })
    self._isFlat = false

    -- 視窗底色：UIGradient 若直接掛在 CanvasGroup 上會把所有子物件一起染色，所以拆成獨立底板
    local background = new("Frame", {
        Name = "Background",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        Parent = main,
    })
    local winGrad = new("UIGradient", { Rotation = 115, Parent = background })
    self:_bind(winGrad, "Color", function(p)
        return ColorSequence.new(p.win0, p.win1)
    end)

    -- 角色壁紙層（背景圖 → 角色圖 → 遮罩 → 粒子）
    self:_buildWallpaper(main)

    -- 邊框（內縮 1px，避免被畫布裁掉）
    local border = new("Frame", {
        Name = "Border",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(1, 1),
        Size = UDim2.new(1, -2, 1, -2),
        ZIndex = 50,
        Parent = main,
    })
    self:_bind(new("UICorner", { Parent = border }), "CornerRadius", function(p)
        return UDim.new(0, math.max(0, p.radius - 1))
    end)
    self:_stroke(border, "winStroke", 1)

    -- 浮水印徽記（右下角，對應原版 Chrome 花紋）
    local watermark = buildEmblem(main, 230)
    watermark.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
    watermark.Frame.Position = UDim2.new(1, -40, 1, -30)
    watermark.Frame.ZIndex = 0
    self:_onTheme(function(p, instant)
        watermark.Refresh(p, "", 0.12, instant)
    end)

    -- ===== 側欄 =====
    local sidebar = new("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, SIDEBAR, 1, 0),
        BorderSizePixel = 0,
        Parent = main,
    })
    self:_bg(sidebar, "sidebar")
    local sideLine = new("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BorderSizePixel = 0,
        Parent = sidebar,
    })
    self:_bg(sideLine, "hairline")

    local logoArea = new("Frame", {
        Name = "Logo",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 80),
        Parent = sidebar,
    })
    local emblem = buildEmblem(logoArea, 38)
    emblem.Frame.Position = UDim2.fromOffset(16, 16)
    self._emblem = emblem
    self._emblemFade = 1
    self:_onTheme(function(p, instant)
        emblem.Refresh(p, p.def.glyph, self._emblemFade, instant)
    end)

    self:_label(logoArea, opts.Title or "Senko UI", 15, "text", {
        Font = FONT_BOLD,
        Position = UDim2.fromOffset(62, 17),
        Size = UDim2.new(1, -70, 0, 18),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local subLabel = self:_label(logoArea, "", 11, "text3", {
        Position = UDim2.fromOffset(62, 36),
        Size = UDim2.new(1, -70, 0, 14),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    self:_bind(subLabel, "Text", function(p)
        if opts.Subtitle then
            return opts.Subtitle
        end
        local name = themeName(p.def)
        return p.def.tag ~= "" and (name .. " · " .. p.def.tag) or name
    end)
    local constellation = self:_label(logoArea, "", 8, "text3", {
        Position = UDim2.fromOffset(17, 61),
        Size = UDim2.new(1, -24, 0, 10),
        TextTransparency = 0.25,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    self:_bind(constellation, "Text", function(p)
        return p.def.constellation
    end)

    -- 導覽列
    local navHolder = new("Frame", {
        Name = "Nav",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 86),
        Size = UDim2.new(1, -20, 1, -128),
        Parent = sidebar,
    })
    local indicator = new("Frame", {
        Name = "Indicator",
        Size = UDim2.new(1, 0, 0, 34),
        BorderSizePixel = 0,
        Visible = false,
        Parent = navHolder,
    })
    self:_bg(indicator, "segPill")
    self:_corner(indicator, "cardRadius")
    local indicatorBar = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 3, 0, 16),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        Parent = indicator,
    })
    corner(indicatorBar, 2)
    local barGrad = new("UIGradient", { Rotation = 90, Parent = indicatorBar })
    self:_bind(barGrad, "Color", function(p)
        return ColorSequence.new(p.accent, p.accent2)
    end)

    local navList = new("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = navHolder,
    })
    new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = navList })
    self._navList = navList
    self._indicator = indicator
    self:_conn(navList:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        self:_moveIndicator(true)
    end))

    -- 側欄底部文字（Footer）：字串 = 固定文字，false = 隱藏，nil = 跟隨主題的 region
    self._footer = opts.Footer
    local footer = new("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 18, 1, -14),
        Size = UDim2.new(1, -30, 0, 16),
        Parent = sidebar,
    })
    local footDot = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 1, 0.5, 0),
        Size = UDim2.fromOffset(6, 6),
        Rotation = 45,
        BorderSizePixel = 0,
        Parent = footer,
    })
    self:_bind(footDot, "BackgroundColor3", "accent")
    local footLabel = self:_label(footer, "", 11, "text3", {
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(1, -16, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    self:_bind(footLabel, "Text", function(p)
        if type(self._footer) == "string" then
            return self._footer
        end
        return themeRegion(p.def)
    end)
    footer.Visible = self._footer ~= false
    self._footerFrame, self._footerLabel = footer, footLabel

    -- ===== 頂欄 =====
    local topbar = new("Frame", {
        Name = "Topbar",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(SIDEBAR, 0),
        Size = UDim2.new(1, -SIDEBAR, 0, TOPBAR),
        Parent = main,
    })
    self._pageTitle = self:_label(topbar, "", 18, "text", {
        Font = FONT_BOLD,
        Position = UDim2.fromOffset(18, 9),
        Size = UDim2.new(1, -140, 0, 22),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    self._pageSub = self:_label(topbar, "", 11, "text3", {
        Position = UDim2.fromOffset(18, 31),
        Size = UDim2.new(1, -140, 0, 14),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local topLine = new("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 16, 1, 0),
        Size = UDim2.new(1, -32, 0, 1),
        BorderSizePixel = 0,
        Parent = topbar,
    })
    self:_bg(topLine, "hairline")

    -- 視窗按鈕（造型依主題：菱形 / 圓形 / 方形）
    local controls = new("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, -1),
        Size = UDim2.fromOffset(24 * 3 + 6 * 2, 24),
        Parent = topbar,
    })
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = controls,
    })

    local function controlButton(kind, order, onClick)
        local btn = new("TextButton", {
            Text = "",
            AutoButtonColor = false,
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(24, 24),
            LayoutOrder = order,
            Parent = controls,
        })
        local shape = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(18, 18),
            BorderSizePixel = 0,
            Parent = btn,
        })
        local shapeCorner = corner(shape, 9)
        local shapeStroke = new("UIStroke", { Thickness = 1, Parent = shape })
        local glyphs = {}
        local function line(w, h, rot, pos)
            local l = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = pos or UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(w, h),
                Rotation = rot or 0,
                BorderSizePixel = 0,
                Parent = btn,
            })
            table.insert(glyphs, l)
            return l
        end
        local boxStroke
        if kind == "min" then
            line(8, 1.5)
        elseif kind == "max" then
            local box = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(7, 7),
                BackgroundTransparency = 1,
                Parent = btn,
            })
            corner(box, 2)
            boxStroke = new("UIStroke", { Thickness = 1.3, Parent = box })
        else
            line(10, 1.5, 45)
            line(10, 1.5, -45)
        end
        local hovered = false
        local function refresh(instant)
            local p = self.palette
            local shapeKind = p.def.shape
            if shapeKind == "diamond" then
                shape.Rotation = 45
                shape.Size = UDim2.fromOffset(15, 15)
                shapeCorner.CornerRadius = UDim.new(0, 4)
            elseif shapeKind == "square" then
                shape.Rotation = 0
                shape.Size = UDim2.fromOffset(18, 18)
                shapeCorner.CornerRadius = UDim.new(0, 5)
            else
                shape.Rotation = 0
                shape.Size = UDim2.fromOffset(18, 18)
                shapeCorner.CornerRadius = UDim.new(0, 9)
            end
            local hoverColor = kind == "close" and p.warn or p.accent
            setp(shape, {
                BackgroundColor3 = hovered and hoverColor or p.field,
                BackgroundTransparency = hovered and 0.7 or p.fieldT,
            }, instant, 0.2)
            setp(shapeStroke, {
                Color = hovered and hoverColor or p.fieldStroke,
                Transparency = hovered and 0.3 or p.fieldStrokeT,
            }, instant, 0.2)
            local gc = hovered and p.text or p.text2
            for _, g in ipairs(glyphs) do
                setp(g, { BackgroundColor3 = gc }, instant, 0.2)
            end
            if boxStroke then
                setp(boxStroke, { Color = gc }, instant, 0.2)
            end
        end
        self:_onTheme(function(_, instant)
            refresh(instant)
        end)
        self:_conn(btn.MouseEnter:Connect(function()
            hovered = true
            refresh(false)
        end))
        self:_conn(btn.MouseLeave:Connect(function()
            hovered = false
            refresh(false)
        end))
        self:_conn(btn.MouseButton1Click:Connect(onClick))
        return btn
    end

    controlButton("min", 1, function()
        self:Minimize()
    end)
    controlButton("max", 2, function()
        self:ToggleMaximize()
    end)
    controlButton("close", 3, function()
        self:Destroy()
    end)

    -- ===== 頁面容器 =====
    local pages = new("Frame", {
        Name = "Pages",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(SIDEBAR, TOPBAR),
        Size = UDim2.new(1, -SIDEBAR, 1, -TOPBAR),
        ClipsDescendants = true,
        Parent = main,
    })
    self._pages = pages

    -- ===== 縮放把手 =====
    local grip = new("TextButton", {
        Name = "Resize",
        Text = "",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -2, 1, -2),
        Size = UDim2.fromOffset(16, 16),
        ZIndex = 60,
        Parent = main,
    })
    for i = 1, 2 do
        local l = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5 + i * 0.12, 0, 0.5 + i * 0.12, 0),
            Size = UDim2.fromOffset(4 + i * 5, 1.2),
            Rotation = -45,
            BorderSizePixel = 0,
            ZIndex = 60,
            Parent = grip,
        })
        self:_bind(l, "BackgroundColor3", "text3")
    end
    do
        local resizing, startInput, startSize
        self:_conn(grip.InputBegan:Connect(function(input)
            if isPress(input) and not self._maximized then
                resizing = true
                startInput = input.Position
                startSize = holder.Size
            end
        end))
        self:_conn(UserInputService.InputChanged:Connect(function(input)
            if resizing and isMove(input) then
                local scale = holderScale.Scale
                local delta = (input.Position - startInput) / scale
                -- 以中心錨點縮放時，位置跟著補償一半，讓左上角保持不動
                local w = math.max(self.minSize.X, startSize.X.Offset + delta.X)
                local h = math.max(self.minSize.Y, startSize.Y.Offset + delta.Y)
                local dw = (w - holder.Size.X.Offset) * scale / 2
                local dh = (h - holder.Size.Y.Offset) * scale / 2
                holder.Size = UDim2.fromOffset(w, h)
                holder.Position = holder.Position + UDim2.fromOffset(dw, dh)
                self:_moveIndicator(true)
            end
        end))
        self:_conn(UserInputService.InputEnded:Connect(function(input)
            if isPress(input) then
                resizing = false
            end
        end))
    end

    self:_draggable(topbar, holder)
    self:_draggable(logoArea, holder)

    -- ===== 通知容器 =====
    local toasts = new("Frame", {
        Name = "Notifications",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.new(0, 290, 1, -32),
        Parent = gui,
    })
    new("UIListLayout", {
        Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = toasts,
    })
    self._toasts = toasts
    self._toastOrder = 0

    -- ===== 手機 / 最小化懸浮按鈕 =====
    local floating = new("TextButton", {
        Name = "Toggle",
        Text = "",
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 46, 0.5, 0),
        Size = UDim2.fromOffset(48, 48),
        BorderSizePixel = 0,
        Visible = UserInputService.TouchEnabled and opts.MobileButton ~= false,
        Parent = gui,
    })
    corner(floating, 999)
    self:_bg(floating, "toast")
    self:_stroke(floating, "winStroke", 1)
    local floatEmblem = buildEmblem(floating, 32)
    floatEmblem.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
    floatEmblem.Frame.Position = UDim2.fromScale(0.5, 0.5)
    self:_onTheme(function(p, instant)
        floatEmblem.Refresh(p, p.def.glyph, 1, instant)
    end)
    self._floating = floating
    do
        -- 懸浮按鈕可拖曳；拖動距離很短才視為點擊
        local down, moved, startInput, startPos
        self:_conn(floating.InputBegan:Connect(function(input)
            if isPress(input) then
                down, moved = true, false
                startInput, startPos = input.Position, floating.Position
            end
        end))
        self:_conn(UserInputService.InputChanged:Connect(function(input)
            if down and isMove(input) then
                local delta = input.Position - startInput
                if delta.Magnitude > 6 then
                    moved = true
                end
                if moved then
                    floating.Position = UDim2.new(
                        startPos.X.Scale, startPos.X.Offset + delta.X,
                        startPos.Y.Scale, startPos.Y.Offset + delta.Y
                    )
                end
            end
        end))
        self:_conn(UserInputService.InputEnded:Connect(function(input)
            if down and isPress(input) then
                down = false
                if not moved then
                    self:Toggle()
                end
            end
        end))
    end

    -- ===== 全域按鍵（切換鍵、按鍵綁定）=====
    self:_conn(UserInputService.InputBegan:Connect(function(input, processed)
        if self._recording then
            return
        end
        if processed then
            return
        end
        if input.KeyCode == self.toggleKey then
            self:Toggle()
            return
        end
        for _, kb in ipairs(self._keybinds) do
            kb:_handle(input)
        end
    end))

    -- 徽記外圈緩慢旋轉
    local clock = 0
    self:_conn(RunService.Heartbeat:Connect(function(dt)
        if not SenkoUI.Animations then
            return
        end
        clock = clock + dt
        emblem.Spinner.Rotation = (clock * 14) % 360
        watermark.Spinner.Rotation = (-clock * 4) % 360
        floatEmblem.Spinner.Rotation = (clock * 14) % 360
        if self.Visible then
            self:_animateWallpaper(clock, dt)
        end
    end))

    self:_applyTheme(true)
    self.Visible = true

    -- 開場動畫
    if opts.Intro ~= false and SenkoUI.Animations then
        self:_playIntro()
    end

    self._ready = true
    createdWindows = createdWindows + 1
    openWindows[self] = true
    fireHook("WindowCreated", self, opts)
    return self
end

-- ============================================================
-- 壁紙
-- ============================================================
function Window:_buildWallpaper(main)
    local wall = new("Frame", {
        Name = "Wallpaper",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ClipsDescendants = true,
        Parent = main,
    })
    local function layer(z)
        return new("ImageLabel", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(1.08, 1.08),
            ScaleType = Enum.ScaleType.Crop,
            ImageTransparency = 1,
            ZIndex = z,
            Parent = wall,
        })
    end
    local bg = layer(1)
    local ch = layer(2)
    local scrim = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = WHITE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = wall,
    })
    local scrimGrad = new("UIGradient", { Rotation = 115, Parent = scrim })
    self:_bind(scrimGrad, "Color", function(p)
        return ColorSequence.new(p.win0, p.win1)
    end)
    local particles = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 5,
        Parent = wall,
    })
    self._wall = { frame = wall, bg = bg, ch = ch, scrim = scrim, particles = particles, token = 0, dots = {} }
    self._parallax = Vector2.new(0, 0)
    -- 不立即呼叫；CreateWindow 最後的 _applyTheme(true) 會觸發第一次載入
    table.insert(self._listeners, function()
        self:_updateWallpaper()
    end)
end

function Window:_wallpaperUrl(entry)
    return resolveWallpaperUrl(entry)
end

-- 遮罩透明度：強度越高壁紙越清楚，但保留壁紙主題的最低遮罩
function Window:_wallScrim()
    local spec = self._wallSpec
    if not spec or not self._wallShown then
        return 1
    end
    local dim = spec.dim or 0.55
    local alpha = dim + (1 - dim) * (1 - self.wallStrength) * 0.85
    return 1 - math.clamp(alpha, 0, 1)
end

function Window:_updateWallpaper()
    local w = self._wall
    if not w then
        return
    end
    w.token = w.token + 1
    local token = w.token
    local spec = self.wallpaperEnabled and self._wallpapers[self.theme.key] or nil
    self._wallSpec = spec
    self._wallShown = false
    tween(w.bg, { ImageTransparency = 1 }, 0.3)
    tween(w.ch, { ImageTransparency = 1 }, 0.3)
    tween(w.scrim, { BackgroundTransparency = 1 }, 0.3)
    self:_buildParticles(spec)
    if not spec or not Assets.available then
        return
    end
    local started = os.clock()
    task.spawn(function()
        local folder = self.theme.plugin or "Basic" -- 壁紙快取到 assets/<插件名稱>/，內建主題放 assets/Basic/
        local bgId = Assets.load(self:_wallpaperUrl(spec.background), folder)
        local chId = spec.character and Assets.load(self:_wallpaperUrl(spec.character), folder) or nil
        if token ~= w.token or self._destroyed or not bgId then
            return
        end
        -- 快取命中時等舊圖淡出再換
        local remain = 0.3 - (os.clock() - started)
        if SenkoUI.Animations and remain > 0 then
            task.wait(remain)
        end
        if token ~= w.token or self._destroyed then
            return
        end
        w.bg.Image = bgId
        w.ch.Image = chId or ""
        self._wallShown = true
        tween(w.scrim, { BackgroundTransparency = self:_wallScrim() }, 0.6, Enum.EasingStyle.Sine)
        tween(w.bg, { ImageTransparency = 0 }, 0.7, Enum.EasingStyle.Sine)
        if chId then
            tween(w.ch, { ImageTransparency = 0 }, 0.9, Enum.EasingStyle.Sine)
        end
    end)
end

function Window:_buildParticles(spec)
    local w = self._wall
    for _, d in ipairs(w.dots) do
        d.frame:Destroy()
    end
    w.dots = {}
    if not spec or not self.particlesEnabled then
        return
    end
    local style = PARTICLE_STYLES[spec.particle] or PARTICLE_STYLES.glow
    local p = self.palette
    for i = 1, style.count do
        local s = math.random(style.size[1] * 10, style.size[2] * 10) / 10
        local f = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(math.random(), math.random()),
            Size = UDim2.fromOffset(s, style.shape == "petal" and s * 1.4 or s),
            Rotation = (style.shape == "diamond" or style.shape == "petal") and 45 or 0,
            BackgroundColor3 = (i % 3 == 0) and p.accent2 or (style.shape == "dot" and p.text or p.accent),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 5,
            Parent = w.particles,
        })
        local ring
        if style.shape == "dot" or style.shape == "ring" then
            corner(f, 999)
        elseif style.shape == "petal" then
            corner(f, math.floor(s))
        end
        if style.shape == "ring" then
            ring = new("UIStroke", { Color = p.accent, Thickness = 1, Transparency = 1, Parent = f })
        end
        table.insert(w.dots, {
            frame = f,
            ring = ring,
            x = math.random(),
            y = math.random(),
            phase = math.random() * 6.283,
            speed = style.speed * (0.6 + math.random() * 0.8),
            style = style,
        })
    end
end

function Window:_animateWallpaper(clock, dt)
    local w = self._wall
    if not w then
        return
    end
    -- 背景緩慢漂移 + 滑鼠視差，角色多一層呼吸與較大視差，形成前後景深
    if self._wallShown and self.wallMotion then
        local ok, mouse = pcall(function()
            return UserInputService:GetMouseLocation()
        end)
        local vp = viewport()
        local tx, ty = 0, 0
        if ok and mouse then
            tx = math.clamp(mouse.X / math.max(1, vp.X) - 0.5, -0.5, 0.5)
            ty = math.clamp(mouse.Y / math.max(1, vp.Y) - 0.5, -0.5, 0.5)
        end
        local k = math.min(1, dt * 3)
        local px = self._parallax.X + (tx - self._parallax.X) * k
        local py = self._parallax.Y + (ty - self._parallax.Y) * k
        self._parallax = Vector2.new(px, py)
        local driftX = math.sin(clock * 0.05) * 0.008
        local driftY = math.cos(clock * 0.043) * 0.006
        w.bg.Position = UDim2.fromScale(0.5 + driftX - px * 0.012, 0.5 + driftY - py * 0.01)
        local breathe = 1.08 * (1 + math.sin(clock * 1.1) * 0.004)
        w.ch.Size = UDim2.fromScale(breathe, breathe)
        w.ch.Position = UDim2.fromScale(
            0.5 + driftX - px * 0.026,
            0.5 + driftY - py * 0.02 + math.sin(clock * 0.9) * 0.002
        )
    end
    for _, d in ipairs(w.dots) do
        d.y = d.y + d.style.dir * d.speed * dt
        if d.y < -0.05 then
            d.y, d.x = 1.05, math.random()
        elseif d.y > 1.05 then
            d.y, d.x = -0.05, math.random()
        end
        local x = d.x + math.sin(clock * 0.8 + d.phase) * d.style.sway
        d.frame.Position = UDim2.fromScale(x, d.y)
        local twinkle = 0.5 + 0.5 * math.sin(clock * 1.6 + d.phase)
        local edge = math.clamp(math.min(d.y, 1 - d.y) * 8, 0, 1)
        local alpha = (0.2 + 0.55 * twinkle) * edge
        if d.ring then
            d.ring.Transparency = 1 - alpha
        else
            d.frame.BackgroundTransparency = 1 - alpha
        end
        if d.style.shape == "petal" then
            d.frame.Rotation = 45 + math.sin(clock * 0.9 + d.phase) * 50
        end
    end
end

function Window:SetWallpaperEnabled(v)
    self.wallpaperEnabled = v and true or false
    self:_updateWallpaper()
    self:_saveSettings()
end

function Window:SetWallpaperStrength(v)
    self.wallStrength = math.clamp(v, 0, 1)
    if self._wallShown then
        tween(self._wall.scrim, { BackgroundTransparency = self:_wallScrim() }, 0.2)
    end
    self:_saveSettings()
end

function Window:SetWallpaper(themeKey, background, character)
    local def = findTheme(themeKey)
    if not def then
        return
    end
    local spec = self._wallpapers[def.key] or { dim = 0.55, particle = "glow" }
    spec.background = background
    spec.character = character
    self._wallpapers[def.key] = spec
    if def == self.theme then
        self:_updateWallpaper()
    end
end

-- ---------- 導覽指示器 ----------
function Window:_moveIndicator(instant)
    local tab = self.ActiveTab
    if not tab then
        return
    end
    local ind = self._indicator
    ind.Visible = true
    -- AbsolutePosition 已含 UIScale，換算回未縮放的座標
    local scale = self._holderScale.Scale * self._mainScale.Scale
    local y = (tab._button.AbsolutePosition.Y - ind.Parent.AbsolutePosition.Y) / math.max(0.01, scale)
    setp(ind, { Position = UDim2.fromOffset(0, y) }, instant, 0.38, Enum.EasingStyle.Quint)
end

-- ============================================================
-- 開場動畫：徽記展開 → 名稱與短句 → 徽記停駐側欄
-- ============================================================
function Window:_playIntro()
    local p = self.palette
    local def = self.theme
    local gui = self.Gui
    local main = self.Main
    main.GroupTransparency = 1
    self._mainScale.Scale = 0.96
    self.Shadow.ImageTransparency = 1
    self._emblemFade = 0
    self._emblem.Refresh(p, def.glyph, 0, true)

    local overlay = new("TextButton", {
        Name = "Intro",
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 100,
        Parent = gui,
    })
    local vp = gui.AbsoluteSize
    if vp.X < 1 then
        vp = viewport()
    end
    local center = Vector2.new(vp.X / 2, vp.Y / 2 - 20)

    local bigSize = 112
    local big = buildEmblem(overlay, bigSize)
    big.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
    big.Frame.Position = UDim2.fromOffset(center.X, center.Y)
    big.Frame.ZIndex = 102
    for _, d in ipairs(big.Frame:GetDescendants()) do
        if d:IsA("GuiObject") then
            d.ZIndex = 102
        end
    end
    big.Refresh(p, def.glyph, 0, true)
    local bigScale = new("UIScale", { Scale = 0.35, Parent = big.Frame })

    -- 擴散光環
    local rings = {}
    for i = 1, 2 do
        local r = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(center.X, center.Y),
            Size = UDim2.fromOffset(40, 40),
            BackgroundTransparency = 1,
            ZIndex = 101,
            Parent = overlay,
        })
        corner(r, 999)
        local s = new("UIStroke", { Color = i == 1 and p.accent or p.accent2, Thickness = 2, Transparency = 1, Parent = r })
        rings[i] = { frame = r, stroke = s }
    end

    -- 元素碎晶
    local shards = {}
    for i = 1, 10 do
        local angle = (i / 10) * math.pi * 2
        local shard = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(center.X, center.Y),
            Size = UDim2.fromOffset(7, 7),
            Rotation = 45,
            BackgroundColor3 = (i % 2 == 0) and p.accent or p.accent2,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 101,
            Parent = overlay,
        })
        shards[i] = { frame = shard, angle = angle }
    end

    local nameLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromOffset(center.X, center.Y + bigSize / 2 + 18),
        Size = UDim2.fromOffset(400, 34),
        Font = FONT_BOLD,
        TextSize = 28,
        TextColor3 = WHITE,
        TextTransparency = 1,
        Text = themeName(def),
        ZIndex = 102,
        Parent = overlay,
    })
    local enLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromOffset(center.X, center.Y + bigSize / 2 + 54),
        Size = UDim2.fromOffset(400, 14),
        Font = FONT_MED,
        TextSize = 10,
        TextColor3 = p.accent,
        TextTransparency = 1,
        Text = def.constellation,
        ZIndex = 102,
        Parent = overlay,
    })
    local mottoLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromOffset(center.X, center.Y + bigSize / 2 + 74),
        Size = UDim2.fromOffset(400, 18),
        Font = FONT,
        TextSize = 13,
        TextColor3 = Color3.fromRGB(225, 232, 240),
        TextTransparency = 1,
        Text = (themeMotto(def) ~= "" and (themeMotto(def) .. "  ·  ") or "") .. T("intro.skip"),
        ZIndex = 102,
        Parent = overlay,
    })

    local finished = false
    local spinConn = RunService.Heartbeat:Connect(function(dt)
        big.Spinner.Rotation = big.Spinner.Rotation + dt * 60
    end)

    local function finish()
        if finished then
            return
        end
        finished = true
        -- 計算側欄徽記的螢幕中心，讓大徽記飛過去停駐
        local target = self._emblem.Frame
        local tCenter = target.AbsolutePosition + target.AbsoluteSize / 2
        local targetScale = target.AbsoluteSize.X / bigSize
        tween(big.Frame, { Position = UDim2.fromOffset(tCenter.X, tCenter.Y) }, 0.6, Enum.EasingStyle.Quint)
        tween(bigScale, { Scale = targetScale }, 0.6, Enum.EasingStyle.Quint)
        for _, lbl in ipairs({ nameLabel, enLabel, mottoLabel }) do
            tween(lbl, { TextTransparency = 1 }, 0.25)
        end
        for _, s in ipairs(shards) do
            tween(s.frame, { BackgroundTransparency = 1 }, 0.25)
        end
        tween(overlay, { BackgroundTransparency = 1 }, 0.5)
        tween(main, { GroupTransparency = 0 }, 0.5)
        tween(self._mainScale, { Scale = 1 }, 0.55, Enum.EasingStyle.Quint)
        tween(self.Shadow, { ImageTransparency = 0.45 }, 0.6)
        task.delay(0.62, function()
            spinConn:Disconnect()
            self._emblemFade = 1
            self._emblem.Refresh(self.palette, self.theme.glyph, 1, true)
            overlay:Destroy()
            self:_moveIndicator(true)
        end)
    end

    overlay.MouseButton1Click:Connect(finish)

    -- 第一幕：暗場與徽記成形
    tween(overlay, { BackgroundTransparency = 0.4 }, 0.4, Enum.EasingStyle.Sine)
    tween(bigScale, { Scale = 1 }, 0.7, Enum.EasingStyle.Back)
    task.delay(0.08, function()
        if finished then
            return
        end
        big.Refresh(p, def.glyph, 1, false)
        for i, r in ipairs(rings) do
            task.delay((i - 1) * 0.18, function()
                if finished then
                    return
                end
                r.stroke.Transparency = 0.2
                tween(r.frame, { Size = UDim2.fromOffset(320, 320) }, 1.1, Enum.EasingStyle.Quint)
                tween(r.stroke, { Transparency = 1 }, 1.1, Enum.EasingStyle.Sine)
            end)
        end
        for _, s in ipairs(shards) do
            local dist = 90 + math.random() * 40
            s.frame.BackgroundTransparency = 0.1
            tween(s.frame, {
                Position = UDim2.fromOffset(center.X + math.cos(s.angle) * dist, center.Y + math.sin(s.angle) * dist),
                Rotation = 45 + 180,
                BackgroundTransparency = 0.6,
            }, 1.0, Enum.EasingStyle.Quint)
        end
    end)
    -- 第二幕：名稱
    task.delay(0.45, function()
        if finished then
            return
        end
        tween(nameLabel, { TextTransparency = 0 }, 0.45)
        tween(enLabel, { TextTransparency = 0.1 }, 0.55)
        tween(mottoLabel, { TextTransparency = 0.25 }, 0.65)
    end)
    -- 第三幕：停駐
    task.delay(1.9, finish)
end

-- ============================================================
-- 視窗操作
-- ============================================================
-- 在 CanvasGroup 與平面 Frame 之間搬移視窗內容
function Window:_setFlat(on)
    on = on and true or false
    if self._isFlat == on then
        return
    end
    self._isFlat = on
    local from, to = self.Main, self._flat
    if not on then
        from, to = self._flat, self.Main
    end
    for _, child in ipairs(from:GetChildren()) do
        if not child:IsA("UICorner") and not child:IsA("UIScale") then
            child.Parent = to
        end
    end
    self._flat.Visible = on
    self.Main.Visible = not on
end

function Window:Minimize()
    if not self.Visible then
        return
    end
    self:_setFlat(false)
    self.Visible = false
    tween(self.Main, { GroupTransparency = 1 }, 0.28, Enum.EasingStyle.Quint)
    tween(self._mainScale, { Scale = 0.9 }, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    tween(self.Shadow, { ImageTransparency = 1 }, 0.25)
    task.delay(SenkoUI.Animations and 0.3 or 0, function()
        if not self.Visible then
            self.Holder.Visible = false
        end
    end)
    self._floating.Visible = true
end

function Window:Restore()
    if self.Visible then
        return
    end
    self.Visible = true
    self.Holder.Visible = true
    self._mainScale.Scale = 0.94
    tween(self.Main, { GroupTransparency = 0 }, 0.32)
    tween(self._mainScale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
    tween(self.Shadow, { ImageTransparency = 0.45 }, 0.4)
    if not UserInputService.TouchEnabled then
        self._floating.Visible = false
    end
    task.delay(0.05, function()
        self:_moveIndicator(true)
    end)
    -- 淡入結束後，最大化狀態換回平面畫布
    task.delay(SenkoUI.Animations and 0.42 or 0, function()
        if self.Visible and self._maximized and not self._destroyed then
            self:_setFlat(true)
        end
    end)
end

function Window:Toggle()
    if self.Visible then
        self:Minimize()
    else
        self:Restore()
    end
end

function Window:ToggleMaximize()
    local holder = self.Holder
    if self._maximized then
        self._maximized = false
        self:_setFlat(false)
        tween(holder, { Size = self._prevSize, Position = self._prevPos }, 0.4)
    else
        self._maximized = true
        self._prevSize, self._prevPos = holder.Size, holder.Position
        local vp = viewport()
        local scale = self._holderScale.Scale
        self:_setFlat(true)
        tween(holder, {
            Size = UDim2.fromOffset((vp.X - 40) / scale, (vp.Y - 40) / scale),
            Position = UDim2.fromScale(0.5, 0.5),
        }, 0.4)
    end
    task.delay(0.42, function()
        self:_moveIndicator(true)
    end)
end

function Window:SetToggleKey(key)
    if type(key) == "string" then
        local ok, k = pcall(function()
            return Enum.KeyCode[key]
        end)
        key = ok and k or nil
    end
    self.toggleKey = key
    self:_saveSettings()
end

function Window:Destroy()
    if self._destroyed then
        return
    end
    self._destroyed = true
    fireHook("WindowDestroyed", self)
    openWindows[self] = nil
    self:_setFlat(false)
    tween(self.Main, { GroupTransparency = 1 }, 0.25)
    tween(self._mainScale, { Scale = 0.92 }, 0.25)
    tween(self.Shadow, { ImageTransparency = 1 }, 0.2)
    task.delay(SenkoUI.Animations and 0.27 or 0, function()
        for _, c in ipairs(self._connections) do
            pcall(function()
                c:Disconnect()
            end)
        end
        self.Gui:Destroy()
    end)
end

-- ============================================================
-- 通知
-- ============================================================
function Window:Notify(opts)
    if type(opts) == "string" then
        opts = { Title = opts }
    end
    opts = opts or {}
    local duration = opts.Duration or 4
    self._toastOrder = self._toastOrder + 1

    local slot = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self._toastOrder,
        Parent = self._toasts,
    })
    local card = new("TextButton", {
        Text = "",
        AutoButtonColor = false,
        Position = UDim2.fromOffset(320, 0),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        Parent = slot,
    })
    self:_bg(card, "toast")
    self:_corner(card, "cardRadius")
    self:_stroke(card, "cardStroke", 1)

    -- 左側元素色條
    local bar = new("Frame", {
        Position = UDim2.fromOffset(8, 12),
        Size = UDim2.new(0, 3, 1, -24),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        Parent = card,
    })
    corner(bar, 2)
    local barGrad = new("UIGradient", { Rotation = 90, Parent = bar })
    self:_bind(barGrad, "Color", function(p)
        return ColorSequence.new(p.accent, p.accent2)
    end)

    local body = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = card,
    })
    pad(body, 11, 14, 12, 20)
    new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })

    self:_label(body, opts.Title or T("notify.title"), 13, "text", {
        Font = FONT_BOLD,
        Size = UDim2.new(1, 0, 0, 16),
        LayoutOrder = 1,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    if opts.Content and opts.Content ~= "" then
        self:_label(body, opts.Content, 12, "text2", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
            LayoutOrder = 2,
        })
    end
    local progress = new("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 3,
        Parent = body,
    })
    local fill = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Parent = progress,
    })
    corner(fill, 1)
    self:_bind(fill, "BackgroundColor3", "accent")

    local closed = false
    local function close()
        if closed then
            return
        end
        closed = true
        tweenThen(card, { Position = UDim2.fromOffset(320, 0) }, 0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.In, function()
            slot:Destroy()
        end)
    end
    card.MouseButton1Click:Connect(close)

    tween(card, { Position = UDim2.fromOffset(0, 0) }, 0.45, Enum.EasingStyle.Quint)
    tween(fill, { Size = UDim2.fromScale(0, 1) }, duration, Enum.EasingStyle.Linear)
    task.delay(duration, close)
    safeCall(opts.Callback)
end

-- ============================================================
-- 分頁
-- ============================================================
function Window:AddTab(opts)
    if type(opts) == "string" then
        opts = { Title = opts }
    end
    opts = opts or {}
    local tab = setmetatable({}, Tab)
    tab.Window = self
    tab.Title = opts.Title or T("tab.default", #self.Tabs + 1)
    tab.Subtitle = opts.Subtitle or ""
    table.insert(self.Tabs, tab)
    local index = #self.Tabs

    -- 導覽按鈕
    local btn = new("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 34),
        LayoutOrder = index,
        Parent = self._navList,
    })
    -- 圖示：Lucide 名稱 / rbxassetid / 文字；都沒有或找不到時取標題第一個字（以 UTF-8 切字，避免中文被切壞）
    local image = resolveIcon(opts.Icon)
    -- 圖示表沒有、但有解析器（例如 Lucide 線上下載）時，先放空圖片，下載完再補上
    local pending = image == false and #iconResolvers > 0
    if image == false and not pending then
        warnIcon(opts.Icon)
    end
    local iconText = (image == nil and opts.Icon) or tab.Title:match(utf8.charpattern) or "◆"
    local function makeText()
        return self:_label(btn, iconText, 13, nil, {
            Font = FONT_BOLD,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 10, 0.5, 0),
            Size = UDim2.fromOffset(20, 20),
            TextXAlignment = Enum.TextXAlignment.Center,
        })
    end
    local function makeImage(img)
        return new("ImageLabel", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 12, 0.5, 0),
            Size = UDim2.fromOffset(16, 16),
            ScaleType = Enum.ScaleType.Fit,
            Image = img or "",
            Parent = btn,
        })
    end
    local icon
    if image or pending then
        icon = makeImage(image)
    else
        icon = makeText()
    end
    local title = self:_label(btn, tab.Title, 13, nil, {
        Font = FONT_MED,
        Position = UDim2.fromOffset(38, 0),
        Size = UDim2.new(1, -44, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    tab._button = btn

    local hovered = false
    local function refresh(instant)
        local p = self.palette
        local active = self.ActiveTab == tab
        local tc = active and p.text or (hovered and p.text or p.text2)
        local ic = active and p.accent or p.text3
        setp(title, { TextColor3 = tc }, instant, 0.22)
        if icon:IsA("ImageLabel") then
            setp(icon, { ImageColor3 = ic }, instant, 0.22)
        else
            setp(icon, { TextColor3 = ic }, instant, 0.22)
        end
    end
    tab._refresh = refresh
    self:_onTheme(function(_, instant)
        refresh(instant)
    end)
    if pending then
        task.spawn(function()
            local found = lookupIcon(opts.Icon)
            if btn.Parent == nil then
                return
            end
            if found then
                icon.Image = found
            else
                icon:Destroy()
                icon = makeText()
                refresh(true)
            end
        end)
    elseif image == false then
        -- 之後在插件管理當場載入圖示插件（如 Lucide）時再試一次
        table.insert(self._iconRetries, function()
            local found = lookupIcon(opts.Icon)
            if found and btn.Parent then
                icon:Destroy()
                icon = makeImage(found)
                refresh(true)
            end
        end)
    end
    self:_conn(btn.MouseEnter:Connect(function()
        hovered = true
        refresh(false)
    end))
    self:_conn(btn.MouseLeave:Connect(function()
        hovered = false
        refresh(false)
    end))
    self:_conn(btn.MouseButton1Click:Connect(function()
        self:SelectTab(tab)
    end))

    -- 頁面
    local page = new("ScrollingFrame", {
        Name = tab.Title,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false,
        Parent = self._pages,
    })
    self:_bind(page, "ScrollBarImageColor3", "text3")
    pad(page, 12, 16, 16, 16)
    new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
    tab.Page = page
    tab._order = 0

    if not self.ActiveTab then
        self:SelectTab(tab)
    end
    return tab
end

function Window:SelectTab(tab)
    if type(tab) == "number" then
        tab = self.Tabs[tab]
    end
    if not tab or self.ActiveTab == tab then
        return
    end
    local previous = self.ActiveTab
    self.ActiveTab = tab
    if previous then
        previous.Page.Visible = false
        previous._refresh(false)
    end
    tab._refresh(false)
    local page = tab.Page
    page.Visible = true
    page.Position = UDim2.fromOffset(0, 10)
    tween(page, { Position = UDim2.fromOffset(0, 0) }, 0.35, Enum.EasingStyle.Quint)

    self._pageTitle.Text = tab.Title
    self._pageSub.Text = tab.Subtitle
    self._pageTitle.TextTransparency = 0.6
    self._pageSub.TextTransparency = 0.6
    tween(self._pageTitle, { TextTransparency = 0 }, 0.3)
    tween(self._pageSub, { TextTransparency = 0 }, 0.4)
    task.defer(function()
        self:_moveIndicator(previous == nil)
    end)
end

-- 分頁上直接呼叫控件時，自動建立預設區塊
function Tab:_default()
    if not self._defaultSection then
        self._defaultSection = self:AddSection({})
    end
    return self._defaultSection
end

local ELEMENT_METHODS = {
    "AddToggle", "AddSlider", "AddSegment", "AddDropdown", "AddButton", "AddKeybind",
    "AddInput", "AddChips", "AddLabel", "AddParagraph", "AddDivider",
    "AddProgress", "AddStats", "AddColorPicker", "AddSlots", "AddConsole",
}
for _, name in ipairs(ELEMENT_METHODS) do
    Tab[name] = function(self, ...)
        local section = self:_default()
        return section[name](section, ...)
    end
end

-- ============================================================
-- 區塊（卡片）
-- ============================================================
function Tab:AddSection(opts)
    if type(opts) == "string" then
        opts = { Title = opts }
    end
    opts = opts or {}
    local win = self.Window
    self._order = self._order + 1

    local section = setmetatable({}, Section)
    section.Window = win
    section.Tab = self
    section._order = 0

    local card = new("Frame", {
        Name = "Section",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        LayoutOrder = self._order,
        Parent = self.Page,
    })
    win:_bg(card, "card")
    win:_corner(card, "cardRadius")
    win:_stroke(card, "cardStroke", 1)
    pad(card, 12, 14, 14, 14)
    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })
    section.Body = card
    section.Frame = card

    -- 區塊標題：大寫英文 + 漸隱分隔線 + 中文說明（對應原版 SectionLabel）
    if (opts.Title and opts.Title ~= "") or (opts.Caption and opts.Caption ~= "") then
        local header = new("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            LayoutOrder = 0,
            Parent = card,
        })
        local caps = win:_label(header, (opts.Title or ""):upper(), 9.5, "text3", {
            Font = FONT_BOLD,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
        })
        local cn = win:_label(header, opts.Caption or "", 11.5, "text3", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTransparency = 0.1,
        })
        local line = new("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = WHITE,
            BorderSizePixel = 0,
            Parent = header,
        })
        local lineGrad = new("UIGradient", {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Parent = line,
        })
        win:_bind(lineGrad, "Color", function(p)
            return ColorSequence.new(p.divider)
        end)
        win:_bind(line, "BackgroundTransparency", function(p)
            return math.max(0, p.dividerT - 0.25)
        end)
        local function layoutLine()
            local left = caps.TextBounds.X > 0 and caps.TextBounds.X + 9 or 0
            local right = cn.TextBounds.X > 0 and cn.TextBounds.X + 9 or 0
            line.Position = UDim2.new(0, left, 0.5, 0)
            line.Size = UDim2.new(1, -(left + right), 0, 1)
        end
        caps:GetPropertyChangedSignal("TextBounds"):Connect(layoutLine)
        cn:GetPropertyChangedSignal("TextBounds"):Connect(layoutLine)
        layoutLine()
        section.Header = header
    end

    return section
end

function Section:_row(height)
    self._order = self._order + 1
    return new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, height),
        LayoutOrder = self._order,
        Parent = self.Body,
    })
end

-- 控件共用：註冊旗標
local function register(opts, element)
    if opts.Flag then
        SenkoUI.Flags[opts.Flag] = element.Value
        SenkoUI.Options[opts.Flag] = element
        element.Flag = opts.Flag
    end
end

local function updateFlag(element)
    if element.Flag then
        SenkoUI.Flags[element.Flag] = element.Value
    end
end

-- 控件共用方法
local ElementBase = {}
ElementBase.__index = ElementBase
function ElementBase:SetVisible(v)
    self.Row.Visible = v and true or false
end
function ElementBase:Get()
    return self.Value
end
function ElementBase:OnChanged(fn)
    table.insert(self._changed, fn)
end
function ElementBase:_fire()
    updateFlag(self)
    safeCall(self.Callback, self.Value)
    for _, fn in ipairs(self._changed) do
        safeCall(fn, self.Value)
    end
end
function ElementBase:Destroy()
    if self.Flag then
        SenkoUI.Flags[self.Flag] = nil
        SenkoUI.Options[self.Flag] = nil
    end
    self.Row:Destroy()
end

local function element(kind, row, opts)
    return setmetatable({
        Type = kind,
        Row = row,
        Callback = opts.Callback,
        _changed = {},
    }, ElementBase)
end

-- 標題 + 說明（左側）
local function titleBlock(win, row, opts, rightWidth)
    local hasDesc = opts.Description and opts.Description ~= ""
    win:_label(row, opts.Title or "", 13, "text", {
        Font = FONT_MED,
        Position = UDim2.fromOffset(0, hasDesc and 3 or 0),
        Size = UDim2.new(1, -(rightWidth or 0), 0, hasDesc and 18 or row.Size.Y.Offset),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    if hasDesc then
        win:_label(row, opts.Description, 11, "text3", {
            Position = UDim2.fromOffset(0, 22),
            Size = UDim2.new(1, -(rightWidth or 0), 0, 16),
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
    end
end

-- 欄位外觀（輸入框、按鍵帽、下拉框共用）
local function fieldStyle(win, obj)
    win:_bg(obj, "field")
    win:_corner(obj, "cardRadius")
    return win:_stroke(obj, "fieldStroke", 1)
end

-- ---------- 開關 ----------
function Section:AddToggle(opts)
    opts = opts or {}
    local win = self.Window
    local hasDesc = opts.Description and opts.Description ~= ""
    local row = self:_row(hasDesc and 42 or 30)
    local el = element("Toggle", row, opts)
    el.Value = opts.Default == true

    titleBlock(win, row, opts, 56)

    local track = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(40, 22),
        BorderSizePixel = 0,
        Parent = row,
    })
    corner(track, 11)
    local trackStroke = new("UIStroke", { Thickness = 1, Parent = track })
    local fill = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(fill, 11)
    local grad = new("UIGradient", { Parent = fill })
    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.fromOffset(18, 18),
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = track,
    })
    corner(knob, 9)
    local knobStroke = new("UIStroke", { Thickness = 1, Parent = knob })

    local function refresh(instant)
        local p = win.palette
        setp(track, { BackgroundColor3 = p.trackOff, BackgroundTransparency = p.trackOffT }, instant)
        setp(trackStroke, { Color = p.cardStroke, Transparency = math.min(1, p.cardStrokeT + 0.05) }, instant)
        grad.Color = ColorSequence.new(p.accent, p.accent2)
        setp(knob, { BackgroundColor3 = p.knob }, instant)
        setp(knobStroke, { Color = p.knobStroke, Transparency = p.knobStrokeT }, instant)
        setp(fill, { BackgroundTransparency = el.Value and 0 or 1 }, instant, 0.25)
        setp(knob, { Position = el.Value and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) },
            instant, 0.4, Enum.EasingStyle.Back)
    end
    win:_onTheme(function(_, instant)
        refresh(instant)
    end)

    local hit = new("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 5,
        Parent = row,
    })
    hit.MouseButton1Down:Connect(function()
        tween(knob, { Size = UDim2.fromOffset(20, 18) }, 0.15)
    end)
    hit.MouseButton1Click:Connect(function()
        tween(knob, { Size = UDim2.fromOffset(18, 18) }, 0.2)
        el:Set(not el.Value)
    end)
    hit.MouseLeave:Connect(function()
        tween(knob, { Size = UDim2.fromOffset(18, 18) }, 0.2)
    end)

    function el:Set(v, silent)
        v = v and true or false
        local changed = v ~= self.Value
        self.Value = v
        refresh(false)
        if changed and not silent then
            self:_fire()
        else
            updateFlag(self)
        end
    end

    register(opts, el)
    if el.Value and opts.FireOnInit then
        el:_fire()
    end
    return el
end

-- ---------- 滑桿 ----------
function Section:AddSlider(opts)
    opts = opts or {}
    local win = self.Window
    local min, max = opts.Min or 0, opts.Max or 100
    local decimals = opts.Decimals or opts.Rounding or 0
    local increment = opts.Increment
    local unit = opts.Unit or opts.Suffix or ""
    local row = self:_row(42)
    local el = element("Slider", row, opts)

    local function round(v)
        if increment and increment > 0 then
            v = math.floor((v - min) / increment + 0.5) * increment + min
        end
        local m = 10 ^ decimals
        return math.clamp(math.floor(v * m + 0.5) / m, min, max)
    end
    local function fmt(v)
        local s
        if decimals <= 0 then
            s = tostring(math.floor(v + 0.5))
        else
            s = string.format("%." .. decimals .. "f", v)
        end
        if unit ~= "" then
            s = s .. " " .. unit
        end
        return s
    end
    el.Value = round(opts.Default or min)

    win:_label(row, opts.Title or "", 12.5, "text2", {
        Font = FONT_MED,
        Size = UDim2.new(1, -96, 0, 18),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local box = new("TextBox", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 92, 0, 18),
        BackgroundTransparency = 1,
        Font = FONT_MED,
        TextXAlignment = Enum.TextXAlignment.Right,
        ClearTextOnFocus = false,
        Text = fmt(el.Value),
        Parent = row,
    })
    win:_text(box, 12)

    local rail = new("Frame", {
        Position = UDim2.new(0, 7, 0, 29),
        Size = UDim2.new(1, -14, 0, 4),
        BorderSizePixel = 0,
        Parent = row,
    })
    corner(rail, 2)
    win:_bg(rail, "trackOff")
    local fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        Parent = rail,
    })
    corner(fill, 2)
    local fillGrad = new("UIGradient", { Parent = fill })
    win:_bind(fillGrad, "Color", function(p)
        return ColorSequence.new(p.accent, p.accent2)
    end)
    local glow = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(26, 26),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = rail,
    })
    corner(glow, 13)
    win:_bind(glow, "BackgroundColor3", "accent")
    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = rail,
    })
    corner(knob, 7)
    win:_bind(knob, "BackgroundColor3", "knob")
    local knobStroke = new("UIStroke", { Thickness = 1, Parent = knob })
    win:_bind(knobStroke, "Color", "knobStroke")
    win:_bind(knobStroke, "Transparency", "knobStrokeT")

    local dragging = false
    local function visual(instant)
        local ratio = (el.Value - min) / math.max(1e-9, max - min)
        local dur = dragging and 0.06 or 0.3
        setp(fill, { Size = UDim2.new(ratio, 0, 1, 0) }, instant, dur)
        setp(knob, { Position = UDim2.new(ratio, 0, 0.5, 0) }, instant, dur)
        setp(glow, { Position = UDim2.new(ratio, 0, 0.5, 0) }, instant, dur)
        if not box:IsFocused() then
            box.Text = fmt(el.Value)
        end
    end
    local function stateColors(instant)
        local p = win.palette
        setp(box, { TextColor3 = dragging and p.accent or p.text2 }, instant, 0.2)
        setp(glow, { BackgroundTransparency = dragging and 0.8 or 1 }, instant, 0.2)
        setp(knob, { Size = dragging and UDim2.fromOffset(16, 16) or UDim2.fromOffset(14, 14) }, instant, 0.2)
    end
    win:_onTheme(function(_, instant)
        stateColors(instant)
    end)

    function el:Set(v, silent)
        v = round(tonumber(v) or self.Value)
        local changed = v ~= self.Value
        self.Value = v
        visual(false)
        if changed and not silent then
            self:_fire()
        else
            updateFlag(self)
        end
    end

    local hit = new("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 20),
        Size = UDim2.new(1, 0, 0, 22),
        ZIndex = 5,
        Parent = row,
    })
    local function fromX(x)
        local ratio = math.clamp((x - rail.AbsolutePosition.X) / math.max(1, rail.AbsoluteSize.X), 0, 1)
        el:Set(min + ratio * (max - min))
    end
    hit.InputBegan:Connect(function(input)
        if isPress(input) then
            dragging = true
            stateColors(false)
            fromX(input.Position.X)
        end
    end)
    win:_conn(UserInputService.InputChanged:Connect(function(input)
        if dragging and isMove(input) then
            fromX(input.Position.X)
        end
    end))
    win:_conn(UserInputService.InputEnded:Connect(function(input)
        if dragging and isPress(input) then
            dragging = false
            stateColors(false)
            visual(false)
        end
    end))
    box.FocusLost:Connect(function()
        local n = tonumber((box.Text:gsub("[^%d%.%-]", "")))
        if n then
            el:Set(n)
        end
        box.Text = fmt(el.Value)
    end)

    visual(true)
    register(opts, el)
    return el
end

-- ---------- 分段選擇 ----------
function Section:AddSegment(opts)
    opts = opts or {}
    local win = self.Window
    local options = opts.Options or opts.Values or { "A", "B" }
    local hasTitle = opts.Title and opts.Title ~= ""
    local row = self:_row(hasTitle and 56 or 32)
    local el = element("Segment", row, opts)
    local n = #options

    local function indexOf(v)
        for i, o in ipairs(options) do
            if o == v then
                return i
            end
        end
        return 1
    end
    el.Value = opts.Default and options[indexOf(opts.Default)] or options[1]

    if hasTitle then
        win:_label(row, opts.Title, 12.5, "text2", { Font = FONT_MED, Size = UDim2.new(1, 0, 0, 18) })
    end
    local track = new("Frame", {
        Position = UDim2.fromOffset(0, hasTitle and 24 or 0),
        Size = UDim2.new(1, 0, 0, 32),
        BorderSizePixel = 0,
        Parent = row,
    })
    win:_bg(track, "segTrack")
    win:_corner(track, "cardRadius")
    local pill = new("Frame", {
        Size = UDim2.new(1 / n, -6, 1, -6),
        Position = UDim2.new(0, 3, 0, 3),
        BorderSizePixel = 0,
        Parent = track,
    })
    win:_bg(pill, "segPill")
    win:_bind(new("UICorner", { Parent = pill }), "CornerRadius", function(p)
        return UDim.new(0, math.max(3, p.cardRadius - 3))
    end)
    win:_stroke(pill, "cardStroke", 1)

    local labels = {}
    for i, o in ipairs(options) do
        local b = new("TextButton", {
            Text = "",
            AutoButtonColor = false,
            BackgroundTransparency = 1,
            Position = UDim2.new((i - 1) / n, 0, 0, 0),
            Size = UDim2.new(1 / n, 0, 1, 0),
            ZIndex = 2,
            Parent = track,
        })
        labels[i] = win:_label(b, tostring(o), 12.5, nil, {
            Font = FONT_MED,
            Size = UDim2.fromScale(1, 1),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 2,
        })
        b.MouseButton1Click:Connect(function()
            el:Set(o)
        end)
    end

    local function refresh(instant)
        local p = win.palette
        local idx = indexOf(el.Value)
        setp(pill, { Position = UDim2.new((idx - 1) / n, 3, 0, 3) }, instant, 0.36, Enum.EasingStyle.Quint)
        for i, lbl in ipairs(labels) do
            setp(lbl, { TextColor3 = i == idx and p.text or p.text2 }, instant, 0.2)
        end
    end
    win:_onTheme(function(_, instant)
        refresh(instant)
    end)

    function el:Set(v, silent)
        if type(v) == "number" then
            v = options[v]
        end
        v = options[indexOf(v)]
        local changed = v ~= self.Value
        self.Value = v
        refresh(false)
        if changed and not silent then
            self:_fire()
        else
            updateFlag(self)
        end
    end

    register(opts, el)
    return el
end

-- ---------- 下拉選單 ----------
function Section:AddDropdown(opts)
    opts = opts or {}
    local win = self.Window
    local options = opts.Options or opts.Values or {}
    local multi = opts.Multi == true
    local CLOSED_H = 58
    local OPTION_H = 28
    local row = self:_row(CLOSED_H)
    row.ClipsDescendants = true
    local el = element("Dropdown", row, opts)
    local open = false

    if multi then
        el.Value = {}
        for _, v in ipairs(type(opts.Default) == "table" and opts.Default or {}) do
            table.insert(el.Value, v)
        end
    else
        el.Value = opts.Default
    end

    win:_label(row, opts.Title or "", 12.5, "text2", { Font = FONT_MED, Size = UDim2.new(1, 0, 0, 18) })
    local field = new("TextButton", {
        Text = "",
        AutoButtonColor = false,
        Position = UDim2.fromOffset(1, 24),
        Size = UDim2.new(1, -2, 0, 32),
        BorderSizePixel = 0,
        Parent = row,
    })
    local fieldStroke = fieldStyle(win, field)
    local display = win:_label(field, "", 12.5, "text", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -40, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local arrow = win:_label(field, "›", 16, "text3", {
        Font = FONT_BOLD,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        TextXAlignment = Enum.TextXAlignment.Center,
        Rotation = 90,
    })

    local list = new("ScrollingFrame", {
        Position = UDim2.fromOffset(1, CLOSED_H + 4),
        Size = UDim2.new(1, -2, 0, 0),
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        Parent = row,
    })
    win:_bg(list, "field")
    win:_corner(list, "cardRadius")
    win:_bind(list, "ScrollBarImageColor3", "text3")
    pad(list, 4, 4, 4, 4)
    new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

    local optionRows = {}
    local function isSelected(v)
        if multi then
            for _, s in ipairs(el.Value) do
                if s == v then
                    return true
                end
            end
            return false
        end
        return el.Value == v
    end

    local function refreshDisplay()
        if multi then
            display.Text = #el.Value > 0 and table.concat(el.Value, ", ") or (opts.Placeholder or T("dropdown.none"))
        else
            display.Text = el.Value ~= nil and tostring(el.Value) or (opts.Placeholder or T("dropdown.placeholder"))
        end
    end

    local function refreshOptions(instant)
        local p = win.palette
        for _, o in ipairs(optionRows) do
            local sel = isSelected(o.value)
            setp(o.button, {
                BackgroundColor3 = p.accent,
                BackgroundTransparency = sel and 0.84 or (o.hover and 0.93 or 1),
            }, instant, 0.18)
            setp(o.label, { TextColor3 = sel and p.text or p.text2 }, instant, 0.18)
            setp(o.dot, { BackgroundColor3 = p.accent, BackgroundTransparency = sel and 0 or 1 }, instant, 0.18)
        end
    end

    local function listHeight()
        return math.min(#options, opts.MaxVisible or 6) * (OPTION_H + 2) + 8
    end

    local function setOpen(v)
        open = v
        local h = open and (CLOSED_H + 4 + listHeight()) or CLOSED_H
        tween(row, { Size = UDim2.new(1, 0, 0, h) }, 0.32, Enum.EasingStyle.Quint)
        tween(list, { Size = UDim2.new(1, -2, 0, open and listHeight() or 0) }, 0.32, Enum.EasingStyle.Quint)
        tween(arrow, { Rotation = open and -90 or 90 }, 0.3)
        local p = win.palette
        tween(fieldStroke, {
            Color = open and p.accent or p.fieldStroke,
            Transparency = open and 0.4 or p.fieldStrokeT,
        }, 0.2)
    end

    local function build()
        for _, o in ipairs(optionRows) do
            o.button:Destroy()
        end
        optionRows = {}
        for i, v in ipairs(options) do
            local b = new("TextButton", {
                Text = "",
                AutoButtonColor = false,
                Size = UDim2.new(1, 0, 0, OPTION_H),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = i,
                Parent = list,
            })
            win:_corner(b, "cardRadius")
            local dot = new("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 10, 0.5, 0),
                Size = UDim2.fromOffset(6, 6),
                Rotation = 45,
                BorderSizePixel = 0,
                BackgroundTransparency = 1,
                Parent = b,
            })
            local lbl = win:_label(b, tostring(v), 12.5, nil, {
                Position = UDim2.fromOffset(24, 0),
                Size = UDim2.new(1, -28, 1, 0),
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
            local o = { button = b, label = lbl, dot = dot, value = v, hover = false }
            table.insert(optionRows, o)
            b.MouseEnter:Connect(function()
                o.hover = true
                refreshOptions(false)
            end)
            b.MouseLeave:Connect(function()
                o.hover = false
                refreshOptions(false)
            end)
            b.MouseButton1Click:Connect(function()
                if multi then
                    local copy, found = {}, false
                    for _, s in ipairs(el.Value) do
                        if s == v then
                            found = true
                        else
                            table.insert(copy, s)
                        end
                    end
                    if not found then
                        table.insert(copy, v)
                    end
                    el:Set(copy)
                else
                    el:Set(v)
                    setOpen(false)
                end
            end)
        end
        refreshOptions(true)
    end

    field.MouseButton1Click:Connect(function()
        setOpen(not open)
    end)
    win:_onTheme(function(_, instant)
        refreshOptions(instant)
        if open then
            local p = win.palette
            setp(fieldStroke, { Color = p.accent, Transparency = 0.4 }, instant)
        end
    end)

    function el:Set(v, silent)
        if multi then
            self.Value = type(v) == "table" and v or { v }
        else
            self.Value = v
        end
        refreshDisplay()
        refreshOptions(false)
        if not silent then
            self:_fire()
        else
            updateFlag(self)
        end
    end

    function el:Refresh(newOptions, keepValue)
        options = newOptions or {}
        if not keepValue then
            if multi then
                self.Value = {}
            else
                self.Value = nil
            end
            updateFlag(self)
        end
        build()
        refreshDisplay()
        if open then
            setOpen(true)
        end
    end

    build()
    refreshDisplay()
    register(opts, el)
    return el
end

-- ---------- 按鈕 ----------
function Section:AddButton(opts)
    opts = opts or {}
    local win = self.Window
    local row = self:_row(34)
    local el = element("Button", row, opts)
    local primary = opts.Style == "Primary" or opts.Primary == true

    local btn = new("TextButton", {
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        Parent = row,
    })
    win:_corner(btn, "cardRadius")
    local stroke = new("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = btn })
    local grad = new("UIGradient", { Enabled = primary, Parent = btn })
    local label = win:_label(btn, opts.Title or "Button", 13, nil, {
        Font = FONT_MED,
        Size = UDim2.fromScale(1, 1),
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    local scale = new("UIScale", { Parent = btn })

    local hovered = false
    local function refresh(instant)
        local p = win.palette
        if primary then
            btn.BackgroundColor3 = WHITE
            grad.Color = ColorSequence.new(p.accent, p.accent2)
            setp(btn, { BackgroundTransparency = hovered and 0 or 0.08 }, instant, 0.18)
            setp(stroke, { Color = p.accent, Transparency = 0.6 }, instant)
            setp(label, { TextColor3 = p.win0 }, instant)
        else
            setp(btn, {
                BackgroundColor3 = hovered and p.accent or p.field,
                BackgroundTransparency = hovered and 0.86 or p.fieldT,
            }, instant, 0.18)
            setp(stroke, {
                Color = hovered and p.accent or p.fieldStroke,
                Transparency = hovered and 0.45 or p.fieldStrokeT,
            }, instant, 0.18)
            setp(label, { TextColor3 = p.text }, instant)
        end
    end
    win:_onTheme(function(_, instant)
        refresh(instant)
    end)
    btn.MouseEnter:Connect(function()
        hovered = true
        refresh(false)
    end)
    btn.MouseLeave:Connect(function()
        hovered = false
        refresh(false)
        tween(scale, { Scale = 1 }, 0.2)
    end)
    btn.MouseButton1Down:Connect(function()
        tween(scale, { Scale = 0.97 }, 0.12)
    end)
    btn.MouseButton1Up:Connect(function()
        tween(scale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
    end)
    btn.MouseButton1Click:Connect(function()
        safeCall(opts.Callback)
    end)

    function el:SetTitle(text)
        label.Text = text
    end
    return el
end

-- ---------- 按鍵錄入 ----------
local KEY_ALIAS = {
    LeftControl = "LCtrl", RightControl = "RCtrl", LeftShift = "LShift", RightShift = "RShift",
    LeftAlt = "LAlt", RightAlt = "RAlt", MouseButton1 = "MB1", MouseButton2 = "MB2", MouseButton3 = "MB3",
}

local function keyName(key)
    if key == nil then
        return T("key.none")
    end
    return KEY_ALIAS[key.Name] or key.Name
end

local function parseKey(v)
    if typeof(v) == "EnumItem" then
        return v
    end
    if type(v) == "string" then
        local ok, k = pcall(function()
            return Enum.KeyCode[v]
        end)
        if ok and k then
            return k
        end
        local ok2, m = pcall(function()
            return Enum.UserInputType[v]
        end)
        if ok2 and m then
            return m
        end
    end
    return nil
end

function Section:AddKeybind(opts)
    opts = opts or {}
    local win = self.Window
    local hasDesc = opts.Description and opts.Description ~= ""
    local row = self:_row(hasDesc and 42 or 30)
    local el = element("Keybind", row, opts)
    el.Value = parseKey(opts.Default)
    el.Mode = opts.Mode or "Press" -- Press：按下觸發；Toggle：切換狀態；Hold：按住期間為 true
    el.State = false

    titleBlock(win, row, opts, 100)

    local cap = new("TextButton", {
        Text = "",
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(64, 26),
        AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
        Parent = row,
    })
    local capStroke = fieldStyle(win, cap)
    pad(cap, 0, 10, 0, 10)
    local capLabel = win:_label(cap, keyName(el.Value), 11.5, nil, {
        Font = FONT_MED,
        Size = UDim2.new(0, 44, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    local recording = false
    local function refresh(instant)
        local p = win.palette
        capLabel.Text = recording and T("key.recording") or keyName(el.Value)
        setp(capLabel, { TextColor3 = recording and p.accent or p.text }, instant, 0.18)
        setp(capStroke, {
            Color = recording and p.accent or p.fieldStroke,
            Transparency = recording and 0.3 or p.fieldStrokeT,
        }, instant, 0.18)
    end
    win:_onTheme(function(_, instant)
        refresh(instant)
    end)

    function el:Set(v, silent)
        self.Value = parseKey(v)
        refresh(false)
        updateFlag(self)
        if not silent then
            safeCall(opts.ChangedCallback, self.Value)
        end
    end

    function el:_handle(input)
        if not self.Value or recording then
            return
        end
        local match = input.KeyCode == self.Value or input.UserInputType == self.Value
        if not match then
            return
        end
        if self.Mode == "Toggle" then
            self.State = not self.State
            safeCall(opts.Callback, self.State)
        elseif self.Mode == "Hold" then
            self.State = true
            safeCall(opts.Callback, true)
            local conn
            conn = UserInputService.InputEnded:Connect(function(ended)
                if ended.KeyCode == self.Value or ended.UserInputType == self.Value then
                    conn:Disconnect()
                    self.State = false
                    safeCall(opts.Callback, false)
                end
            end)
        else
            safeCall(opts.Callback, self.Value)
        end
    end

    -- 覆寫 Flags 存值：存按鍵名稱字串方便序列化
    function el:_serialize()
        return self.Value and self.Value.Name or nil
    end

    cap.MouseButton1Click:Connect(function()
        if recording then
            return
        end
        recording = true
        win._recording = true
        refresh(false)
        local conn
        conn = UserInputService.InputBegan:Connect(function(input)
            local key
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Escape then
                    key = el.Value
                elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
                    key = nil
                else
                    key = input.KeyCode
                end
            elseif input.UserInputType == Enum.UserInputType.MouseButton2
                or input.UserInputType == Enum.UserInputType.MouseButton3 then
                key = input.UserInputType
            else
                return
            end
            conn:Disconnect()
            recording = false
            el:Set(key)
            task.defer(function()
                win._recording = false
            end)
        end)
    end)

    table.insert(win._keybinds, el)
    register(opts, el)
    return el
end

-- ---------- 輸入框 ----------
function Section:AddInput(opts)
    opts = opts or {}
    local win = self.Window
    local hasTitle = opts.Title and opts.Title ~= ""
    local row = self:_row(hasTitle and 58 or 32)
    local el = element("Input", row, opts)
    el.Value = opts.Default or ""

    if hasTitle then
        win:_label(row, opts.Title, 12.5, "text2", { Font = FONT_MED, Size = UDim2.new(1, 0, 0, 18) })
    end
    local frame = new("Frame", {
        Position = UDim2.fromOffset(0, hasTitle and 24 or 0),
        Size = UDim2.new(1, 0, 0, 32),
        BorderSizePixel = 0,
        Parent = row,
    })
    local stroke = fieldStyle(win, frame)
    local box = new("TextBox", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -24, 1, 0),
        Font = FONT,
        Text = tostring(el.Value),
        PlaceholderText = opts.Placeholder or "",
        ClearTextOnFocus = opts.ClearOnFocus == true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = frame,
    })
    win:_text(box, 12.5)
    win:_bind(box, "TextColor3", "text")
    win:_bind(box, "PlaceholderColor3", "text3")

    box.Focused:Connect(function()
        local p = win.palette
        tween(stroke, { Color = p.accent, Transparency = 0.35 }, 0.2)
    end)
    box.FocusLost:Connect(function(enter)
        local p = win.palette
        tween(stroke, { Color = p.fieldStroke, Transparency = p.fieldStrokeT }, 0.2)
        local text = box.Text
        if opts.Numeric then
            local n = tonumber(text)
            if not n then
                box.Text = tostring(el.Value)
                return
            end
            text = n
        end
        el.Value = text
        if opts.Finished ~= false then
            el:_fire()
        end
    end)
    if opts.Finished == false then
        box:GetPropertyChangedSignal("Text"):Connect(function()
            el.Value = opts.Numeric and (tonumber(box.Text) or el.Value) or box.Text
            el:_fire()
        end)
    end

    function el:Set(v, silent)
        self.Value = v
        box.Text = tostring(v)
        if not silent then
            self:_fire()
        else
            updateFlag(self)
        end
    end

    register(opts, el)
    return el
end

-- ---------- 標籤選擇（多選小膠囊，對應原版 Chip）----------
function Section:AddChips(opts)
    opts = opts or {}
    local win = self.Window
    local options = opts.Options or opts.Values or {}
    local multi = opts.Multi ~= false
    local hasTitle = opts.Title and opts.Title ~= ""
    local row = self:_row(0)
    row.AutomaticSize = Enum.AutomaticSize.Y
    local el = element("Chips", row, opts)

    if multi then
        el.Value = {}
        for _, v in ipairs(type(opts.Default) == "table" and opts.Default or {}) do
            table.insert(el.Value, v)
        end
    else
        el.Value = opts.Default or options[1]
    end

    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
    if hasTitle then
        win:_label(row, opts.Title, 12.5, "text2", { Font = FONT_MED, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 0 })
    end
    local wrap = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1,
        Parent = row,
    })
    local layout = new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = wrap,
    })
    pcall(function()
        layout.Wraps = true
    end)

    local function isSelected(v)
        if multi then
            for _, s in ipairs(el.Value) do
                if s == v then
                    return true
                end
            end
            return false
        end
        return el.Value == v
    end

    local chips = {}
    local function refresh(instant)
        local p = win.palette
        for _, c in ipairs(chips) do
            local sel = isSelected(c.value)
            setp(c.button, {
                BackgroundColor3 = sel and p.accent or p.field,
                BackgroundTransparency = sel and 0.8 or p.fieldT,
            }, instant, 0.2)
            setp(c.stroke, {
                Color = sel and p.accent or p.fieldStroke,
                Transparency = sel and 0.35 or p.fieldStrokeT,
            }, instant, 0.2)
            setp(c.label, { TextColor3 = sel and p.text or p.text2 }, instant, 0.2)
        end
    end

    for i, v in ipairs(options) do
        local b = new("TextButton", {
            Text = "",
            AutoButtonColor = false,
            Size = UDim2.fromOffset(0, 26),
            AutomaticSize = Enum.AutomaticSize.X,
            BorderSizePixel = 0,
            LayoutOrder = i,
            Parent = wrap,
        })
        corner(b, 13)
        local s = new("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
        pad(b, 0, 12, 0, 12)
        local lbl = win:_label(b, tostring(v), 12, nil, {
            Font = FONT_MED,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
        })
        table.insert(chips, { button = b, stroke = s, label = lbl, value = v })
        b.MouseButton1Click:Connect(function()
            if multi then
                local copy, found = {}, false
                for _, x in ipairs(el.Value) do
                    if x == v then
                        found = true
                    else
                        table.insert(copy, x)
                    end
                end
                if not found then
                    table.insert(copy, v)
                end
                el:Set(copy)
            else
                el:Set(v)
            end
        end)
    end
    win:_onTheme(function(_, instant)
        refresh(instant)
    end)

    function el:Set(v, silent)
        self.Value = v
        refresh(false)
        if not silent then
            self:_fire()
        else
            updateFlag(self)
        end
    end

    register(opts, el)
    return el
end

-- ---------- 文字 ----------
function Section:AddLabel(text)
    local opts = type(text) == "table" and text or { Text = text }
    local win = self.Window
    local row = self:_row(0)
    row.AutomaticSize = Enum.AutomaticSize.Y
    local el = element("Label", row, opts)
    local lbl = win:_label(row, opts.Text or opts.Title or "", opts.Size or 12.5, opts.Tone or "text2", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        RichText = true,
        TextYAlignment = Enum.TextYAlignment.Top,
    })
    function el:Set(t)
        lbl.Text = t
        self.Value = t
    end
    el.Value = lbl.Text
    return el
end

function Section:AddParagraph(opts)
    if type(opts) == "string" then
        opts = { Content = opts }
    end
    opts = opts or {}
    local win = self.Window
    local row = self:_row(0)
    row.AutomaticSize = Enum.AutomaticSize.Y
    local el = element("Paragraph", row, opts)
    new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
    local title
    if opts.Title and opts.Title ~= "" then
        title = win:_label(row, opts.Title, 13, "text", {
            Font = FONT_BOLD,
            Size = UDim2.new(1, 0, 0, 18),
            LayoutOrder = 1,
        })
    end
    local body = win:_label(row, opts.Content or "", 12, "text2", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        RichText = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = 2,
    })
    function el:Set(newTitle, newContent)
        if title and newTitle then
            title.Text = newTitle
        end
        if newContent then
            body.Text = newContent
        end
    end
    return el
end

-- ---------- 控制台（對應 ReGui Console）----------
function Section:AddConsole(opts)
    opts = opts or {}
    local win = self.Window
    local hasTitle = opts.Title and opts.Title ~= ""
    local maxLines = opts.MaxLines == nil and 300 or opts.MaxLines
    local format = opts.LinesFormat or "%s"
    local wrapped = opts.TextWrapped == true
    local row = self:_row(0)
    row.AutomaticSize = Enum.AutomaticSize.Y
    local el = element("Console", row, opts)
    el.ReadOnly = opts.ReadOnly == true
    el.LineNumbers = opts.LineNumbers == true
    el.AutoScroll = opts.AutoScroll == true
    el.MaxLines = maxLines
    el.LinesFormat = format
    el.Enabled = opts.Enabled ~= false

    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
    if hasTitle then
        win:_label(row, opts.Title, 12.5, "text2", { Font = FONT_MED, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 0 })
    end
    local scroll = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, opts.Height or 150),
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = wrapped and Enum.AutomaticSize.Y or Enum.AutomaticSize.XY,
        ScrollingDirection = wrapped and Enum.ScrollingDirection.Y or Enum.ScrollingDirection.XY,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        ScrollBarThickness = 4,
        LayoutOrder = 1,
        Parent = row,
    })
    win:_bg(scroll, "field")
    win:_corner(scroll, "cardRadius")
    win:_bind(scroll, "ScrollBarImageColor3", "text3")
    local stroke = opts.Border ~= false and win:_stroke(scroll, "fieldStroke", 1) or nil
    pad(scroll, 6, 8, 6, 8)

    local lines = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        Font = Enum.Font.Code,
        Text = "",
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Top,
        Visible = el.LineNumbers,
        Parent = scroll,
    })
    win:_text(lines, 12.5)
    win:_bind(lines, "TextColor3", "text3")

    local source = new("TextBox", {
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        Text = "",
        PlaceholderText = opts.Placeholder or "",
        MultiLine = true,
        ClearTextOnFocus = false,
        TextEditable = not el.ReadOnly,
        TextWrapped = wrapped,
        RichText = opts.RichText == true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = scroll,
    })
    win:_text(source, 12.5)
    win:_bind(source, "TextColor3", "text")
    win:_bind(source, "PlaceholderColor3", "text3")

    -- 行號寬度變動時，原始碼欄位往右推；用 offset 填滿可視區，避免與 AutomaticCanvasSize 互相撐大
    -- TextBox 在 ScrollingFrame 內的 AutomaticSize 不會撐大，改用 TextService 自行量測
    local function layoutSource()
        local w = lines.Visible and (lines.AbsoluteSize.X + 10) or 0
        local view = scroll.AbsoluteWindowSize
        -- 先扣掉直向捲軸寬度，避免捲軸出現前量到的寬度多出幾 px 而產生多餘的水平捲動
        local width = math.max(0, scroll.AbsoluteSize.X - scroll.ScrollBarThickness - 16 - w)
        local height = math.max(0, view.Y - 12)
        local plain = source.RichText and source.Text:gsub("<[^>]->", "") or source.Text
        local bounds = wrapped and Vector2.new(width, math.huge) or Vector2.new(math.huge, math.huge)
        local need = TextService:GetTextSize(plain, source.TextSize, source.Font, bounds)
        height = math.max(height, need.Y)
        if not wrapped then
            -- 只在真的有長行時才開水平捲動，否則畫布會以外框寬度為準而多出捲軸寬度
            local overflow = need.X + 4 > width
            scroll.ScrollingDirection = overflow and Enum.ScrollingDirection.XY or Enum.ScrollingDirection.Y
            if not overflow and scroll.CanvasPosition.X ~= 0 then
                scroll.CanvasPosition = Vector2.new(0, scroll.CanvasPosition.Y)
            end
            width = math.max(width, need.X + 4)
        end
        source.Position = UDim2.fromOffset(w, 0)
        source.Size = UDim2.fromOffset(width, height)
    end
    lines:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutSource)
    lines:GetPropertyChangedSignal("Visible"):Connect(layoutSource)
    scroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(layoutSource)

    source.Focused:Connect(function()
        if not el.ReadOnly and stroke then
            tween(stroke, { Color = win.palette.accent, Transparency = 0.35 }, 0.2)
        end
    end)
    source.FocusLost:Connect(function()
        if stroke then
            local p = win.palette
            tween(stroke, { Color = p.fieldStroke, Transparency = p.fieldStrokeT }, 0.2)
        end
    end)

    -- 超過 MaxLines 時只保留最後幾行
    local function trim(text)
        local limit = el.MaxLines
        if not limit or limit <= 0 then
            return text
        end
        local parts = string.split(text, "\n")
        if #parts <= limit then
            return text
        end
        return table.concat(parts, "\n", #parts - limit + 1)
    end

    function el:UpdateLineNumbers()
        lines.Visible = self.LineNumbers
        if not self.LineNumbers then
            return self
        end
        local count = #string.split(source.Text, "\n")
        local out = table.create(count)
        for i = 1, count do
            out[i] = string.format(self.LinesFormat, i)
        end
        lines.Text = table.concat(out, "\n")
        return self
    end

    function el:UpdateScroll()
        -- 等 AutomaticCanvasSize 重算後再捲到底
        task.defer(function()
            scroll.CanvasPosition = Vector2.new(0, math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y))
        end)
        return self
    end

    function el:Update()
        self:UpdateLineNumbers()
        layoutSource()
        if self.AutoScroll then
            self:UpdateScroll()
        end
        return self
    end

    function el:CheckLineCount()
        local cut = trim(source.Text)
        if cut ~= source.Text then
            source.Text = cut
        end
        return self
    end

    function el:SetValue(text)
        if not self.Enabled then
            return self
        end
        source.Text = trim(tostring(text == nil and "" or text))
        return self
    end

    function el:GetValue()
        return source.Text
    end

    function el:Clear()
        source.Text = ""
        return self
    end

    function el:AppendText(...)
        local args = table.pack(...)
        local parts = table.create(args.n)
        for i = 1, args.n do
            parts[i] = tostring(args[i])
        end
        local line = table.concat(parts, " ")
        local current = source.Text
        return self:SetValue(current == "" and line or (current .. "\n" .. line))
    end

    function el:SetReadOnly(v)
        self.ReadOnly = v and true or false
        source.TextEditable = not self.ReadOnly
        return self
    end

    function el:SetLineNumbers(v)
        self.LineNumbers = v and true or false
        return self:UpdateLineNumbers()
    end

    function el:Set(v)
        return self:SetValue(v)
    end

    source:GetPropertyChangedSignal("Text"):Connect(function()
        el.Value = source.Text
        el:Update()
        el:_fire()
    end)

    el.Value = ""
    source.Text = trim(tostring(opts.Value or opts.Default or ""))
    el.Value = source.Text
    el:Update()
    layoutSource()

    return el
end

function Section:AddDivider()
    local win = self.Window
    local row = self:_row(9)
    local line = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 0, 1),
        BorderSizePixel = 0,
        Parent = row,
    })
    win:_bg(line, "divider")
    return element("Divider", row, {})
end

-- ---------- 進度（長條 / 環形儀表）----------
function Section:AddProgress(opts)
    opts = opts or {}
    local win = self.Window
    local min, max = opts.Min or 0, opts.Max or 100
    local decimals = opts.Decimals or 0
    local unit = opts.Unit or ""
    local ring = opts.Style == "Ring"
    local hasDesc = opts.Description and opts.Description ~= ""
    local row = self:_row(ring and 76 or (hasDesc and 46 or 34))
    local el = element("Progress", row, opts)
    local tone = opts.Tone -- "accent"（預設）/ "good" / "warn"

    local function ratioOf(v)
        return math.clamp((v - min) / math.max(1e-9, max - min), 0, 1)
    end
    local function fmt(v)
        local s = decimals <= 0 and tostring(math.floor(v + 0.5)) or string.format("%." .. decimals .. "f", v)
        return unit ~= "" and (s .. " " .. unit) or s
    end
    el.Value = math.clamp(tonumber(opts.Default) or min, min, max)

    local anim = new("NumberValue", { Value = ratioOf(el.Value), Parent = row })
    local valueLabel, centerLabel
    local onRatio -- 依 anim 更新外觀

    if ring then
        local holder = new("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 2),
            Size = UDim2.fromOffset(72, 72),
            Parent = row,
        })
        -- UIStroke 畫在框外，圓框要內縮一個線寬，否則半圓裁切框會把弧線外緣切掉，跟底環對不齊
        local SIZE, THICK = 72, 6
        local inner = SIZE - THICK * 2
        local trackCircle = new("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(THICK, THICK),
            Size = UDim2.fromOffset(inner, inner),
            Parent = holder,
        })
        new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = trackCircle })
        local trackStroke = new("UIStroke", {
            Thickness = THICK,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = trackCircle,
        })
        win:_bind(trackStroke, "Color", "trackOff")
        win:_bind(trackStroke, "Transparency", "trackOffT")

        -- 兩個半圓，各自用漸層旋轉裁出弧度
        local stops = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(0.501, 1),
            NumberSequenceKeypoint.new(1, 1),
        })
        local function half(isRight)
            local clip = new("Frame", {
                BackgroundTransparency = 1,
                ClipsDescendants = true,
                Position = UDim2.fromScale(isRight and 0.5 or 0, 0),
                Size = UDim2.fromScale(0.5, 1),
                Parent = holder,
            })
            -- 與底環同一個圓：holder 座標 (THICK, THICK)，換算成這個半邊裁切框的座標
            local circle = new("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(isRight and (THICK - SIZE / 2) or THICK, THICK),
                Size = UDim2.fromOffset(inner, inner),
                Parent = clip,
            })
            new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = circle })
            local stroke = new("UIStroke", {
                Thickness = THICK,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                Parent = circle,
            })
            local grad = new("UIGradient", { Transparency = stops, Parent = stroke })
            return stroke, grad
        end
        local strokeR, gradR = half(true)
        local strokeL, gradL = half(false)

        centerLabel = win:_label(holder, "", 13, "text", {
            Font = FONT_BOLD,
            Size = UDim2.fromScale(1, 1),
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        win:_label(row, opts.Title or "", 13, "text", {
            Font = FONT_BOLD,
            Position = UDim2.fromOffset(88, hasDesc and 10 or 16),
            Size = UDim2.new(1, -88, 0, 18),
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
        valueLabel = win:_label(row, "", 12, "text2", {
            Position = UDim2.fromOffset(88, hasDesc and 30 or 36),
            Size = UDim2.new(1, -88, 0, 16),
        })
        if hasDesc then
            win:_label(row, opts.Description, 11, "text3", {
                Position = UDim2.fromOffset(88, 48),
                Size = UDim2.new(1, -88, 0, 16),
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
        end

        onRatio = function(r)
            gradR.Rotation = math.clamp(360 * r, 0, 180)
            gradL.Rotation = 180 + math.clamp(360 * r - 180, 0, 180)
            centerLabel.Text = math.floor(r * 100 + 0.5) .. "%"
        end
        win:_onTheme(function(p, instant)
            local c = p[tone or "accent"] or p.accent
            setp(strokeR, { Color = c }, instant)
            setp(strokeL, { Color = c }, instant)
        end)
    else
        win:_label(row, opts.Title or "", 12.5, "text2", {
            Font = FONT_MED,
            Size = UDim2.new(1, -90, 0, 18),
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
        valueLabel = win:_label(row, "", 12, "text2", {
            Font = FONT_MED,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.new(0, 90, 0, 18),
            TextXAlignment = Enum.TextXAlignment.Right,
        })
        local barY = 25
        if hasDesc then
            win:_label(row, opts.Description, 11, "text3", {
                Position = UDim2.fromOffset(0, 19),
                Size = UDim2.new(1, 0, 0, 16),
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
            barY = 38
        end
        local rail = new("Frame", {
            Position = UDim2.new(0, 0, 0, barY),
            Size = UDim2.new(1, 0, 0, 6),
            BorderSizePixel = 0,
            Parent = row,
        })
        corner(rail, 3)
        win:_bg(rail, "trackOff")
        local fill = new("Frame", {
            Size = UDim2.fromScale(0, 1),
            BackgroundColor3 = WHITE,
            BorderSizePixel = 0,
            Parent = rail,
        })
        corner(fill, 3)
        local grad = new("UIGradient", { Parent = fill })
        onRatio = function(r)
            fill.Size = UDim2.fromScale(r, 1)
        end
        win:_onTheme(function(p, instant)
            if tone and p[tone] then
                grad.Color = ColorSequence.new(p[tone])
            else
                grad.Color = ColorSequence.new(p.accent, p.accent2)
            end
        end)
    end

    anim.Changed:Connect(function()
        onRatio(anim.Value)
    end)
    onRatio(anim.Value)
    valueLabel.Text = ring and fmt(el.Value) .. " / " .. fmt(max) or fmt(el.Value)

    function el:Set(v, silent)
        v = math.clamp(tonumber(v) or self.Value, min, max)
        local changed = v ~= self.Value
        self.Value = v
        valueLabel.Text = ring and fmt(v) .. " / " .. fmt(max) or fmt(v)
        tween(anim, { Value = ratioOf(v) }, 0.45)
        if changed and not silent then
            self:_fire()
        else
            updateFlag(self)
        end
    end

    if opts.Flag then
        register(opts, el)
    end
    return el
end

-- ---------- 統計區塊（一排數值卡片，對應原版 Stat）----------
function Section:AddStats(opts)
    opts = opts or {}
    local win = self.Window
    local items = opts.Items or {}
    local n = math.max(1, #items)
    local gap = 6
    local row = self:_row(52)
    local el = element("Stats", row, opts)
    el.Value = {}

    new("UIGridLayout", {
        CellSize = UDim2.new(1 / n, -gap * (n - 1) / n, 1, 0),
        CellPadding = UDim2.fromOffset(gap, 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = row,
    })
    local cells = {}
    for i, item in ipairs(items) do
        local key = item.Key or item.Title or tostring(i)
        local card = new("Frame", { BorderSizePixel = 0, LayoutOrder = i, Parent = row })
        fieldStyle(win, card)
        local value = win:_label(card, tostring(item.Value or "-"), 16, item.Tone or "text", {
            Font = FONT_BOLD,
            Position = UDim2.fromOffset(10, 7),
            Size = UDim2.new(1, -20, 0, 22),
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
        win:_label(card, item.Title or "", 10.5, "text3", {
            Position = UDim2.fromOffset(10, 29),
            Size = UDim2.new(1, -20, 0, 16),
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
        cells[key] = { label = value, tone = item.Tone or "text" }
        el.Value[key] = item.Value
    end

    -- el:Set("FPS", 60, "good")；Tone 可省略以保留原本顏色
    function el:Set(key, v, newTone)
        local cell = cells[key]
        if not cell then
            return
        end
        cell.label.Text = tostring(v)
        self.Value[key] = v
        if newTone then
            cell.tone = newTone
            win:_bind(cell.label, "TextColor3", newTone)
        end
    end
    return el
end

-- ---------- 色彩選擇器 ----------
function Section:AddColorPicker(opts)
    opts = opts or {}
    local win = self.Window
    local hasDesc = opts.Description and opts.Description ~= ""
    local baseH = hasDesc and 42 or 30
    local PANEL_H = 104
    local row = self:_row(baseH)
    row.ClipsDescendants = true
    local el = element("ColorPicker", row, opts)

    local function toHex(c)
        return string.format("%02X%02X%02X",
            math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
    end
    local function parse(x)
        if typeof(x) == "Color3" then
            return x
        elseif type(x) == "string" then
            local hex = (x:gsub("#", ""))
            if #hex == 6 and hex:match("^%x+$") then
                return Color3.fromRGB(
                    tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
            end
        elseif type(x) == "table" then
            local r, g, b = x.R or x[1], x.G or x[2], x.B or x[3]
            if tonumber(r) and tonumber(g) and tonumber(b) then
                return Color3.fromRGB(r, g, b)
            end
        end
        return nil
    end

    el.Value = parse(opts.Default) or Color3.fromRGB(255, 255, 255)
    local h, s, v = el.Value:ToHSV()

    titleBlock(win, row, opts, 120)

    local swatch = new("TextButton", {
        Text = "",
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, (baseH - 22) / 2),
        Size = UDim2.fromOffset(38, 22),
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = row,
    })
    corner(swatch, 6)
    local swatchStroke = new("UIStroke", { Thickness = 1, Parent = swatch })
    win:_bind(swatchStroke, "Color", "fieldStroke")
    win:_bind(swatchStroke, "Transparency", "fieldStrokeT")

    local hexBox = new("TextBox", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -46, 0, (baseH - 22) / 2),
        Size = UDim2.fromOffset(70, 22),
        BackgroundTransparency = 1,
        Font = FONT_MED,
        TextXAlignment = Enum.TextXAlignment.Right,
        ClearTextOnFocus = false,
        ZIndex = 3,
        Parent = row,
    })
    win:_text(hexBox, 12)
    win:_bind(hexBox, "TextColor3", "text2")

    -- 調色盤面板
    local panel = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, baseH + 6),
        Size = UDim2.new(1, 0, 0, PANEL_H),
        Visible = false,
        Parent = row,
    })
    local sv = new("Frame", {
        Size = UDim2.new(1, -26, 1, 0),
        BorderSizePixel = 0,
        Parent = panel,
    })
    corner(sv, 6)
    local white = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        Parent = sv,
    })
    corner(white, 6)
    new("UIGradient", {
        Transparency = NumberSequence.new(0, 1),
        Parent = white,
    })
    local black = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        Parent = sv,
    })
    corner(black, 6)
    new("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new(1, 0),
        Parent = black,
    })
    local svCursor = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(12, 12),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = sv,
    })
    corner(svCursor, 6)
    new("UIStroke", { Color = WHITE, Thickness = 2, Parent = svCursor })

    local hueBar = new("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, 14, 1, 0),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        Parent = panel,
    })
    corner(hueBar, 6)
    new("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
            ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
            ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
            ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
            ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
            ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 1, 1)),
        }),
        Parent = hueBar,
    })
    local hueCursor = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(1, 6, 0, 4),
        Position = UDim2.fromScale(0.5, 0),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = hueBar,
    })
    corner(hueCursor, 2)
    new("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.5, Thickness = 1, Parent = hueCursor })

    local function visual()
        swatch.BackgroundColor3 = el.Value
        sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        svCursor.Position = UDim2.fromScale(s, 1 - v)
        hueCursor.Position = UDim2.fromScale(0.5, h)
        if not hexBox:IsFocused() then
            hexBox.Text = "#" .. toHex(el.Value)
        end
    end

    local function commit()
        local c = Color3.fromHSV(h, s, v)
        local changed = c ~= el.Value
        el.Value = c
        visual()
        if changed then
            el:_fire()
        end
    end

    local dragging -- "sv" / "hue"
    local function drag(input)
        if dragging == "sv" then
            s = math.clamp((input.Position.X - sv.AbsolutePosition.X) / math.max(1, sv.AbsoluteSize.X), 0, 1)
            v = 1 - math.clamp((input.Position.Y - sv.AbsolutePosition.Y) / math.max(1, sv.AbsoluteSize.Y), 0, 1)
            commit()
        elseif dragging == "hue" then
            h = math.clamp((input.Position.Y - hueBar.AbsolutePosition.Y) / math.max(1, hueBar.AbsoluteSize.Y), 0, 1)
            commit()
        end
    end
    sv.InputBegan:Connect(function(input)
        if isPress(input) then
            dragging = "sv"
            drag(input)
        end
    end)
    hueBar.InputBegan:Connect(function(input)
        if isPress(input) then
            dragging = "hue"
            drag(input)
        end
    end)
    win:_conn(UserInputService.InputChanged:Connect(function(input)
        if dragging and isMove(input) then
            drag(input)
        end
    end))
    win:_conn(UserInputService.InputEnded:Connect(function(input)
        if dragging and isPress(input) then
            dragging = nil
        end
    end))

    local open = false
    swatch.MouseButton1Click:Connect(function()
        open = not open
        if open then
            panel.Visible = true
            tween(row, { Size = UDim2.new(1, 0, 0, baseH + 6 + PANEL_H) }, 0.3)
        else
            tweenThen(row, { Size = UDim2.new(1, 0, 0, baseH) }, 0.25, nil, nil, function()
                if not open then
                    panel.Visible = false
                end
            end)
        end
    end)
    hexBox.FocusLost:Connect(function()
        local c = parse(hexBox.Text)
        if c then
            el:Set(c)
        end
        hexBox.Text = "#" .. toHex(el.Value)
    end)

    function el:Set(value, silent)
        local c = parse(value)
        if not c then
            return
        end
        local changed = c ~= self.Value
        self.Value = c
        h, s, v = c:ToHSV()
        visual()
        if changed and not silent then
            self:_fire()
        else
            updateFlag(self)
        end
    end

    -- 設定檔以十六進位字串儲存
    function el:_serialize()
        return toHex(self.Value)
    end

    visual()
    register(opts, el)
    return el
end

-- ---------- Slots 槽位選擇（對應原版 Slots）----------
function Section:AddSlots(opts)
    opts = opts or {}
    local win = self.Window
    local labels = opts.Labels or {}
    local count = math.max(1, opts.Count or (#labels > 0 and #labels or 6))
    local columns = math.clamp(opts.Columns or math.min(count, 6), 1, count)
    local gap = 6
    local hasTitle = opts.Title and opts.Title ~= ""
    local row = self:_row(0)
    row.AutomaticSize = Enum.AutomaticSize.Y
    local el = element("Slots", row, opts)
    el.Value = opts.Default

    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
    if hasTitle then
        win:_label(row, opts.Title, 12.5, "text2", { Font = FONT_MED, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 0 })
    end
    local wrap = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1,
        Parent = row,
    })
    new("UIGridLayout", {
        CellSize = UDim2.new(1 / columns, -gap * (columns - 1) / columns, 0, 40),
        CellPadding = UDim2.fromOffset(gap, gap),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = wrap,
    })

    local slots = {}
    local function refresh(instant)
        local p = win.palette
        for i, sl in ipairs(slots) do
            local sel = el.Value == i
            setp(sl.button, {
                BackgroundColor3 = sel and p.accent or p.field,
                BackgroundTransparency = sel and 0.8 or p.fieldT,
            }, instant, 0.2)
            setp(sl.stroke, {
                Color = sel and p.accent or p.fieldStroke,
                Transparency = sel and 0.35 or p.fieldStrokeT,
            }, instant, 0.2)
            setp(sl.num, { TextColor3 = sel and p.accent or p.text2 }, instant, 0.2)
            setp(sl.name, { TextColor3 = sel and p.text or p.text3 }, instant, 0.2)
        end
    end

    for i = 1, count do
        local b = new("TextButton", {
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0,
            LayoutOrder = i,
            Parent = wrap,
        })
        win:_corner(b, "cardRadius")
        local stroke = new("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
        local num = win:_label(b, tostring(i), 14, nil, {
            Font = FONT_BOLD,
            Position = UDim2.fromOffset(0, 4),
            Size = UDim2.new(1, 0, 0, 18),
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        local name = win:_label(b, tostring(labels[i] or ""), 10.5, nil, {
            Position = UDim2.fromOffset(4, 22),
            Size = UDim2.new(1, -8, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
        slots[i] = { button = b, stroke = stroke, num = num, name = name }
        b.MouseButton1Click:Connect(function()
            if el.Value == i and opts.AllowDeselect then
                el:Set(nil)
            else
                el:Set(i)
            end
        end)
    end
    win:_onTheme(function(_, instant)
        refresh(instant)
    end)

    function el:Set(index, silent)
        if type(index) == "number" then
            index = math.clamp(math.floor(index), 1, count)
        else
            index = nil
        end
        local changed = index ~= self.Value
        self.Value = index
        refresh(false)
        if changed and not silent then
            self:_fire()
        else
            updateFlag(self)
        end
    end

    function el:GetLabel()
        return self.Value and labels[self.Value] or nil
    end

    register(opts, el)
    return el
end

-- ============================================================
-- 設定檔
-- ============================================================
function Window:_configPath(name)
    return SenkoUI.Folder .. "/configs/" .. name .. ".json"
end

function Window:SaveConfig(name)
    if not FS.available then
        self:Notify({ Title = T("config.noFile.title"), Content = T("config.noFile.content") })
        return false
    end
    name = (name and name ~= "") and name or "default"
    FS.ensureFolder(SenkoUI.Folder)
    FS.ensureFolder(SenkoUI.Folder .. "/configs")
    local data = {}
    for flag, el in pairs(SenkoUI.Options) do
        if el._serialize then
            data[flag] = el:_serialize()
        else
            data[flag] = el.Value
        end
    end
    local ok = FS.writeJson(self:_configPath(name), data)
    self:Notify({ Title = ok and T("config.saved") or T("config.saveFailed"), Content = name, Duration = 3 })
    return ok
end

function Window:LoadConfig(name)
    name = (name and name ~= "") and name or "default"
    local data = FS.readJson(self:_configPath(name))
    if not data then
        self:Notify({ Title = T("config.notFound"), Content = name, Duration = 3 })
        return false
    end
    for flag, value in pairs(data) do
        local el = SenkoUI.Options[flag]
        if el and el.Set then
            pcall(function()
                el:Set(value)
            end)
        end
    end
    self:Notify({ Title = T("config.loaded"), Content = name, Duration = 3 })
    return true
end

function Window:ListConfigs()
    return FS.list(SenkoUI.Folder .. "/configs")
end

-- ============================================================
-- 內建主題頁（對應原版主題庫 + 外觀 + 啟動選擇）
-- ============================================================
function Window:AddThemeTab(opts)
    opts = opts or {}
    local win = self
    local tab = self:AddTab({
        Title = opts.Title or T("themeTab.title"),
        Subtitle = opts.Subtitle or T("themeTab.subtitle"),
        -- 「✦」在 Gotham 字型會顯示成方框；有 Lucide 時用 palette 圖示
        Icon = opts.Icon or (SenkoUI.Icons["lucide-palette"] and "palette") or "◈",
    })

    -- 主題庫
    local lib = tab:AddSection({ Title = "Themes", Caption = T("section.themes") })
    local filterRow = lib:_row(28)
    local filterScroll = new("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.X,
        Parent = filterRow,
    })
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = filterScroll,
    })

    local gridRow = lib:_row(0)
    gridRow.AutomaticSize = Enum.AutomaticSize.Y
    local grid = new("UIGridLayout", {
        CellSize = UDim2.new(0.5, -5, 0, 60),
        CellPadding = UDim2.fromOffset(10, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = gridRow,
    })
    local function adaptGrid()
        grid.CellSize = gridRow.AbsoluteSize.X < 400 and UDim2.new(1, 0, 0, 60) or UDim2.new(0.5, -5, 0, 60)
    end
    gridRow:GetPropertyChangedSignal("AbsoluteSize"):Connect(adaptGrid)
    task.defer(adaptGrid)

    local currentFilter = "All"
    local cards = {}
    local filterButtons = {}

    local function refreshFilters(instant)
        local p = win.palette
        for _, f in ipairs(filterButtons) do
            local sel = f.key == currentFilter
            setp(f.button, {
                BackgroundColor3 = sel and p.accent or p.field,
                BackgroundTransparency = sel and 0.8 or p.fieldT,
            }, instant, 0.2)
            setp(f.stroke, {
                Color = sel and p.accent or p.fieldStroke,
                Transparency = sel and 0.35 or p.fieldStrokeT,
            }, instant, 0.2)
            setp(f.label, { TextColor3 = sel and p.text or p.text2 }, instant, 0.2)
        end
        for _, c in ipairs(cards) do
            c.frame.Visible = currentFilter == GROUP_ALL.key or themeInGroup(c.def, currentFilter)
        end
    end

    -- 篩選列：「全部」+ 至少有一個主題的分類（名稱用 SenkoUI:AddGroup 自訂）
    -- 插件開啟 / 關閉、語言切換後會重建，讓分類即時出現或消失
    local function buildFilters()
        for _, f in ipairs(filterButtons) do
            f.button:Destroy()
        end
        table.clear(filterButtons)
        local filters = { GROUP_ALL }
        for _, g in ipairs(sortedGroups()) do
            for _, def in ipairs(THEMES) do
                if themeInGroup(def, g.key) then
                    table.insert(filters, g)
                    break
                end
            end
        end
        local exists = false
        for _, f in ipairs(filters) do
            if f.key == currentFilter then
                exists = true
            end
        end
        if not exists then
            currentFilter = GROUP_ALL.key
        end
        for i, f in ipairs(filters) do
            local b = new("TextButton", {
                Text = "",
                AutoButtonColor = false,
                Size = UDim2.fromOffset(0, 26),
                AutomaticSize = Enum.AutomaticSize.X,
                BorderSizePixel = 0,
                LayoutOrder = i,
                Parent = filterScroll,
            })
            corner(b, 13)
            local s = new("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
            pad(b, 0, 12, 0, 12)
            local lbl = win:_label(b, groupLabel(f), 12, nil, {
                Font = FONT_MED,
                Size = UDim2.new(0, 0, 1, 0),
                AutomaticSize = Enum.AutomaticSize.X,
            })
            table.insert(filterButtons, { key = f.key, button = b, stroke = s, label = lbl })
            b.MouseButton1Click:Connect(function()
                currentFilter = f.key
                refreshFilters(false)
            end)
        end
    end
    buildFilters()

    -- 長方形主題卡：預覽漸層 + 兩行文字（名稱 / 說明 description，依目前語言）+ 徽記
    local carded = {} -- def → card
    local function setCardText(card)
        -- 名稱後接「| 作者」（character.json 的 creator，標示壁紙來源），作者以較淡的提示色顯示
        local name = themeName(card.def):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
        local creator = card.def.creator
        if creator then
            creator = creator:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
            name = string.format('%s  <font color="#%s">|  %s</font>', name, card.def.palette.text3:ToHex(), creator)
        end
        card.name.Text = name
        card.motto.Text = themeMotto(card.def)
    end
    local function addCard(def, i)
        local tp = def.palette
        local cardBtn = new("TextButton", {
            Text = "",
            AutoButtonColor = false,
            BackgroundColor3 = WHITE,
            BorderSizePixel = 0,
            LayoutOrder = i,
            ClipsDescendants = true,
            Parent = gridRow,
        })
        corner(cardBtn, math.max(6, tp.cardRadius))
        new("UIGradient", { Rotation = 115, Color = ColorSequence.new(tp.win0, tp.win1), Parent = cardBtn })
        local stroke = new("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = cardBtn })
        local mini = buildEmblem(cardBtn, 30)
        mini.Frame.AnchorPoint = Vector2.new(1, 0.5)
        mini.Frame.Position = UDim2.new(1, -12, 0.5, 0)
        mini.Refresh(tp, def.glyph, 1, true)
        local nameLbl = new("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 11),
            Size = UDim2.new(1, -60, 0, 18),
            Font = FONT_BOLD,
            TextColor3 = tp.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = cardBtn,
        })
        win:_text(nameLbl, 14)
        nameLbl.RichText = true
        local mottoLbl = new("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 33),
            Size = UDim2.new(1, -60, 0, 16),
            Font = FONT,
            TextColor3 = tp.text2,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = cardBtn,
        })
        win:_text(mottoLbl, 11.5)
        local scale = new("UIScale", { Parent = cardBtn })
        local card = {
            frame = cardBtn, def = def, stroke = stroke, scale = scale,
            name = nameLbl, motto = mottoLbl,
        }
        setCardText(card)
        table.insert(cards, card)
        carded[def] = card
        cardBtn.MouseEnter:Connect(function()
            tween(scale, { Scale = 1.02 }, 0.25)
        end)
        cardBtn.MouseLeave:Connect(function()
            tween(scale, { Scale = 1 }, 0.25)
        end)
        cardBtn.MouseButton1Click:Connect(function()
            win:SetTheme(def.key)
        end)
    end
    for i, def in ipairs(THEMES) do
        addCard(def, i)
    end

    local function refreshCards(instant)
        local p = win.palette
        for _, c in ipairs(cards) do
            local sel = c.def == win.theme
            setp(c.stroke, {
                Color = sel and p.accent or c.def.palette.winStroke,
                Transparency = sel and 0 or 0.7,
                Thickness = sel and 2 or 1,
            }, instant, 0.25)
        end
    end
    win:_onTheme(function(_, instant)
        refreshFilters(instant)
        refreshCards(instant)
    end)
    -- 插件開啟 / 關閉後：補上新主題卡、銷毀已移除主題的卡片、重建篩選列
    table.insert(win._libraryRefreshers, function()
        local present = {}
        for i, def in ipairs(THEMES) do
            present[def] = true
            if carded[def] then
                carded[def].frame.LayoutOrder = i
            else
                addCard(def, i)
            end
        end
        for i = #cards, 1, -1 do
            local c = cards[i]
            if not present[c.def] then
                c.frame:Destroy()
                carded[c.def] = nil
                table.remove(cards, i)
            end
        end
        buildFilters()
        refreshFilters(true)
        refreshCards(true)
    end)
    win:_onLanguage(function()
        for _, c in ipairs(cards) do
            setCardText(c)
        end
        buildFilters()
        refreshFilters(true)
    end)

    -- 壁紙（載入的主題中有壁紙或粒子，或有插件清單可當場開啟時才顯示）
    if next(win._wallpapers) ~= nil or #SenkoUI:GetPluginCatalog() > 0 then
        local wallSec = tab:AddSection({ Title = "Wallpaper", Caption = T("section.wallpaper") })
        if not Assets.available then
            wallSec:AddLabel(T("wall.noSupport"))
        end
        wallSec:AddToggle({
            Title = T("wall.show"),
            Description = T("wall.showDesc"),
            Default = win.wallpaperEnabled,
            Callback = function(v)
                win:SetWallpaperEnabled(v)
            end,
        })
        wallSec:AddSlider({
            Title = T("wall.strength"),
            Min = 0, Max = 100, Default = math.floor(win.wallStrength * 100 + 0.5), Unit = "%",
            Callback = function(v)
                win:SetWallpaperStrength(v / 100)
            end,
        })
        wallSec:AddToggle({
            Title = T("wall.motion"),
            Description = T("wall.motionDesc"),
            Default = win.wallMotion,
            Callback = function(v)
                win.wallMotion = v
                win:_saveSettings()
            end,
        })
        wallSec:AddToggle({
            Title = T("wall.particles"),
            Default = win.particlesEnabled,
            Callback = function(v)
                win.particlesEnabled = v
                win:_buildParticles(win._wallSpec)
                win:_saveSettings()
            end,
        })
    end

    -- 插件管理：只列出 plugins/index.json 的角色壁紙插件
    -- 每列：插件名稱 + 「%d 位角色與壁紙」+ 膠囊開關；開啟時下載並顯示進度，關閉立即移除主題
    local catalog = SenkoUI:GetPluginCatalog()
    if #catalog > 0 then
        local pm = tab:AddSection({ Title = "Plugins", Caption = T("section.plugins") })
        local SWITCH_ON, SWITCH_OFF = Color3.fromHex("#FFA352"), Color3.fromHex("#473B3A")
        local cacheUpdaters = {} -- 快取鍵（插件名稱 / "Basic" / "" = 未分類）→ 重新計算清除按鈕的文字

        local function updateCache(key)
            local fn = cacheUpdaters[key or ""]
            if fn then
                task.spawn(fn)
            end
        end

        for _, entry in ipairs(catalog) do
            local name = entry.Name
            local busy = false
            local on = entry.Loaded

            local row = pm:_row(42)
            local titleLbl = win:_label(row, "", 13, "text", {
                Font = FONT_MED,
                Position = UDim2.fromOffset(0, 3),
                Size = UDim2.new(1, -110, 0, 18),
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
            local descLbl = win:_label(row, "", 11, "text3", {
                Position = UDim2.fromOffset(0, 22),
                Size = UDim2.new(1, -110, 0, 16),
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
            local stateLbl = win:_label(row, "", 11, "text2", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -54, 0.5, 0),
                Size = UDim2.fromOffset(50, 16),
                TextXAlignment = Enum.TextXAlignment.Right,
            })
            local track = new("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.fromOffset(44, 24),
                BackgroundColor3 = on and SWITCH_ON or SWITCH_OFF,
                BorderSizePixel = 0,
                Parent = row,
            })
            corner(track, 12)
            local knob = new("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = on and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
                Size = UDim2.fromOffset(18, 18),
                BackgroundColor3 = WHITE,
                BorderSizePixel = 0,
                Parent = track,
            })
            corner(knob, 9)
            new("UIStroke", { Thickness = 1, Color = WHITE, Transparency = 0.35, Parent = knob }) -- 圓鈕高光外框
            local hit = new("TextButton", {
                Text = "",
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                ZIndex = 5,
                Parent = row,
            })

            -- 下載進度條（開啟時展開）
            local barRow = pm:_row(18)
            barRow.Visible = false
            local barTrack = new("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.new(1, -110, 0, 6),
                BorderSizePixel = 0,
                Parent = barRow,
            })
            corner(barTrack, 3)
            win:_bg(barTrack, "segTrack")
            local barFill = new("Frame", {
                Size = UDim2.fromScale(0, 1),
                BackgroundColor3 = SWITCH_ON,
                BorderSizePixel = 0,
                Parent = barTrack,
            })
            corner(barFill, 3)
            local barText = win:_label(barRow, "", 11, "text2", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.fromOffset(100, 16),
                TextXAlignment = Enum.TextXAlignment.Right,
            })

            local function setSwitch(v, instant)
                on = v
                setp(track, { BackgroundColor3 = v and SWITCH_ON or SWITCH_OFF }, instant, 0.25)
                setp(knob, { Position = v and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) },
                    instant, 0.3, Enum.EasingStyle.Quad)
                stateLbl.Text = T(v and "plugin.on" or "plugin.off")
            end
            local function refreshText()
                local label = localized(entry.Label) or name
                titleLbl.Text = label
                descLbl.Text = T(entry.Characters == 1 and "plugin.countOne" or "plugin.count", entry.Characters)
                stateLbl.Text = T(on and "plugin.on" or "plugin.off")
            end
            refreshText()
            win:_onLanguage(refreshText)
            -- 腳本直接呼叫 EnablePlugin / DisablePlugin 時，開關跟著插件實際狀態
            table.insert(win._libraryRefreshers, function()
                if busy then
                    return
                end
                for _, e in ipairs(SenkoUI:GetPluginCatalog()) do
                    if e.Name == name and e.Loaded ~= on then
                        setSwitch(e.Loaded)
                        updateCache(name)
                    end
                end
            end)

            local function setProgress(done, total)
                barRow.Visible = true
                local ratio = total > 0 and done / total or 0
                setp(barFill, { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1) }, false, 0.2)
                barText.Text = T("plugin.downloading", done, total)
            end

            hit.MouseButton1Click:Connect(function()
                if busy then
                    return
                end
                local label = localized(entry.Label) or name
                if on then
                    setSwitch(false)
                    SenkoUI:DisablePlugin(name)
                    win:Notify({ Title = T("section.plugins"), Content = T("plugin.disabled", label), Duration = 3 })
                    return
                end
                busy = true
                setSwitch(true)
                setProgress(0, entry.Characters)
                task.spawn(function()
                    local ok, result = SenkoUI:EnablePlugin(name, setProgress)
                    busy = false
                    task.delay(0.8, function()
                        barRow.Visible = false
                        barFill.Size = UDim2.fromScale(0, 1)
                    end)
                    if not ok then
                        setSwitch(false)
                        win:Notify({ Title = T("section.plugins"), Content = T("plugin.failed", label), Duration = 4 })
                        return
                    end
                    updateCache(name)
                    local content = result.failed > 0 and T("plugin.enabledFailed", label, result.characters, result.failed)
                        or T("plugin.enabled", label, result.characters)
                    win:Notify({ Title = T("section.plugins"), Content = content, Duration = 3 })
                end)
            end)
        end

        -- 快取清單：各插件 + 基礎主題 + 未分類（assets 根目錄）
        local targets = {}
        for _, entry in ipairs(catalog) do
            table.insert(targets, { key = entry.Name, label = entry.Label })
        end
        table.insert(targets, { key = "Basic", labelKey = "group.basic" })
        table.insert(targets, { key = nil, labelKey = "plugin.uncategorized" })
        for _, target in ipairs(targets) do
            local button, size
            local function targetLabel()
                return target.labelKey and T(target.labelKey) or localized(target.label) or target.key
            end
            local function setTitle()
                local suffix = T("plugin.calculating")
                if size then
                    suffix = size.count > 0 and T("plugin.clearSize", formatBytes(size.bytes), size.count) or T("plugin.clearEmpty")
                end
                button:SetTitle(T("plugin.clear", targetLabel()) .. suffix)
            end
            -- 讀檔計算大小可能較久，在背景執行；沒有快取時顯示「無快取」，下載後會再更新
            local function update()
                local bytes, count = SenkoUI:GetCacheSize(target.key)
                size = { bytes = bytes, count = count }
                setTitle()
            end
            button = pm:AddButton({
                Title = T("plugin.clear", targetLabel()) .. T("plugin.calculating"),
                Callback = function()
                    local removed = SenkoUI:ClearCache(target.key)
                    update()
                    win:Notify({ Title = T("plugin.cleared"), Content = T("plugin.clearedContent", targetLabel(), removed), Duration = 3 })
                end,
            })
            cacheUpdaters[target.key or ""] = update
            win:_onLanguage(setTitle)
            task.spawn(update)
        end
        if type(delfile) ~= "function" then
            pm:AddLabel(T("plugin.noDelfile", SenkoUI.Folder))
        end
        pm:AddLabel(T("plugin.note"))
    end

    -- 外觀
    local look = tab:AddSection({ Title = "Appearance", Caption = T("section.appearance") })
    look:AddSlider({
        Title = T("look.fontSize"),
        Min = 100, Max = 125, Default = math.floor(win.fontScale * 100 + 0.5), Unit = "%",
        Callback = function(v)
            win:SetFontScale(v / 100)
        end,
    })
    look:AddToggle({
        Title = T("look.animations"),
        Description = T("look.animationsDesc"),
        Default = SenkoUI.Animations,
        Callback = function(v)
            SenkoUI.Animations = v
            win:_saveSettings()
        end,
    })
    local languages = SenkoUI:GetLanguages()
    if #languages > 1 then
        local names, codeOf, current = {}, {}, nil
        for _, lang in ipairs(languages) do
            table.insert(names, lang.Name)
            codeOf[lang.Name] = lang.Code
            if lang.Code == SenkoUI.Language then
                current = lang.Name
            end
        end
        look:AddSegment({
            Title = T("look.language"),
            Options = names,
            Default = current or names[1],
            Callback = function(v)
                SenkoUI:SetLanguage(codeOf[v])
                win:Notify({ Title = T("look.language"), Content = T("look.languageChanged", v), Duration = 3 })
            end,
        })
        look:AddLabel({ Text = T("look.languageDesc"), Size = 11, Tone = "text3" })
    end

    -- 啟動
    local boot = tab:AddSection({ Title = "Startup", Caption = T("section.startup") })
    local modeNames = { T("boot.follow"), T("boot.fixed"), T("boot.random") }
    boot:AddSegment({
        Title = T("boot.when"),
        Options = modeNames,
        Default = modeNames[win.startupMode + 1],
        Callback = function(v)
            for i, name in ipairs(modeNames) do
                if name == v then
                    win.startupMode = i - 1
                end
            end
            if win.startupMode == 1 then
                win.startupTheme = win.theme.key
            end
            win:_saveSettings()
        end,
    })
    boot:AddLabel(T("boot.note"))

    -- 設定檔
    if opts.Configs ~= false then
        local cfg = tab:AddSection({ Title = "Config", Caption = T("section.config") })
        local nameInput = cfg:AddInput({ Title = T("cfg.name"), Placeholder = "default", Default = "" })
        local listDrop = cfg:AddDropdown({ Title = T("cfg.list"), Options = win:ListConfigs(), Placeholder = T("cfg.empty") })
        listDrop:OnChanged(function(v)
            if v then
                nameInput:Set(v, true)
            end
        end)
        cfg:AddButton({
            Title = T("cfg.save"),
            Style = "Primary",
            Callback = function()
                win:SaveConfig(nameInput.Value)
                listDrop:Refresh(win:ListConfigs(), true)
            end,
        })
        cfg:AddButton({
            Title = T("cfg.load"),
            Callback = function()
                win:LoadConfig(nameInput.Value)
            end,
        })
        cfg:AddButton({
            Title = T("cfg.refresh"),
            Callback = function()
                listDrop:Refresh(win:ListConfigs())
            end,
        })
    end

    -- 切換鍵
    local keys = tab:AddSection({ Title = "Window", Caption = T("section.window") })
    keys:AddKeybind({
        Title = T("keys.toggle"),
        Description = T("keys.toggleDesc"),
        Default = win.toggleKey,
        ChangedCallback = function(k)
            if k then
                win:SetToggleKey(k)
            end
        end,
    })

    win._themeTab = tab
    fireHook("ThemeTabBuilt", win, tab)
    return tab
end

-- ============================================================
-- 插件與擴充（完整說明見 PLUGINS.md）
-- ============================================================

-- 公開給插件的主題綁定方法（與內部 _ 開頭的方法相同）
Window.Bind = Window._bind
Window.BindBackground = Window._bg
Window.AddStroke = Window._stroke
Window.AddCorner = Window._corner
Window.Label = Window._label
Window.ScaleText = Window._text
Window.OnTheme = Window._onTheme
Window.Track = Window._conn
ElementBase.Fire = ElementBase._fire

-- 插件與進階腳本用的工具
local Kit = {
    New = new,
    Corner = corner,
    Pad = pad,
    Tween = tween,
    TweenThen = tweenThen,
    SetProps = setp,
    SafeCall = safeCall,
    Rgb = rgb,
    IsPress = isPress,
    IsMove = isMove,
    Viewport = viewport,
    LoadImage = Assets.load,
    Icon = lookupIcon,
    FS = FS,
    Fonts = { Regular = FONT, Medium = FONT_MED, Bold = FONT_BOLD, Code = Enum.Font.Code },
    Services = {
        TweenService = TweenService,
        UserInputService = UserInputService,
        RunService = RunService,
        HttpService = HttpService,
        TextService = TextService,
        Players = Players,
    },
    -- 自訂控件骨架
    Row = function(section, height)
        return section:_row(height or 30)
    end,
    Element = element,
    Register = register,
    UpdateFlag = updateFlag,
    TitleBlock = titleBlock,
    FieldStyle = fieldStyle,
    Emblem = buildEmblem,
}
SenkoUI.Kit = Kit

-- 插件管理當場載入時為 true：這時在 CreateWindow 之後註冊主題是預期行為，不 warn
local liveLoading = false

-- ---------- 分類 ----------
-- 新增或改名主題庫分類；Key = "All" 可改「全部」按鈕的文字
function SenkoUI:AddGroup(opts)
    if type(opts) == "string" then
        opts = { Key = opts }
    end
    opts = opts or {}
    local key = opts.Key
    if type(key) ~= "string" or key == "" then
        warn("[SenkoUI] AddGroup 需要 Key")
        return nil
    end
    if key == GROUP_ALL.key then
        if opts.Label then
            GROUP_ALL.label, GROUP_ALL.labelKey = opts.Label, nil
        end
        return key
    end
    local g = findGroup(key)
    if g then
        -- 腳本直接呼叫一律視為改名；插件只能改自己建立的分類，不會蓋掉使用者或其他插件取的名稱
        if not opts.Plugin or opts.Plugin == g.plugin then
            if opts.Label then
                g.label, g.labelKey = opts.Label, nil
            end
            g.order = opts.Order or g.order
        end
        return key
    end
    table.insert(GROUPS, {
        key = key,
        label = opts.Label or key, -- 字串或語系表 { ["zh-TW"] = ..., en = ... }
        labelKey = opts.LabelKey,
        order = opts.Order or #GROUPS * 10,
        plugin = opts.Plugin,
    })
    return key
end

function SenkoUI:GetGroups()
    local list = { { Key = GROUP_ALL.key, Label = groupLabel(GROUP_ALL) } }
    for _, g in ipairs(sortedGroups()) do
        table.insert(list, { Key = g.key, Label = groupLabel(g), Order = g.order, Plugin = g.plugin })
    end
    return list
end

-- ---------- 主題 ----------
-- 需在 CreateWindow 之前呼叫（壁紙表在建立視窗時複製，主題卡在 AddThemeTab 時建立）
function SenkoUI:AddTheme(opts)
    opts = opts or {}
    local key = opts.Key
    if type(key) ~= "string" or key == "" then
        warn("[SenkoUI] AddTheme 需要 Key")
        return nil
    end
    if findTheme(key) then
        warn("[SenkoUI] 主題已存在：" .. key)
        return nil
    end
    if createdWindows > 0 and not liveLoading then
        warn("[SenkoUI] AddTheme(" .. key .. ") 在 CreateWindow 之後呼叫，已開啟的視窗不會出現它的壁紙與主題卡")
    end
    local baseDef = opts.Base and findTheme(opts.Base)
    if opts.Base and not baseDef then
        warn("[SenkoUI] 找不到 Base 主題：" .. tostring(opts.Base) .. "，改用預設色票")
    end
    local overrides = {}
    for k, v in pairs(opts.Palette or {}) do
        overrides[k] = type(v) == "string" and Color3.fromHex(v) or v
    end
    -- 分類：Groups（清單）> Group（單一）> 舊版 Element；都沒有時歸到「自訂」
    local groups = opts.Groups or opts.Group or opts.Element or "Custom"
    groups = type(groups) == "string" and { groups } or table.clone(groups)
    for _, g in ipairs(groups) do
        if not findGroup(g) then
            SenkoUI:AddGroup({
                Key = g,
                Label = opts.GroupLabel or opts.ElementLabel or g,
                LabelKey = g == "Custom" and "group.custom" or nil,
                Plugin = opts.Plugin,
            })
        end
    end
    -- Name / Motto / Region 可以是字串或語系表 { ["zh-TW"] = ..., en = ... }，主題卡依目前語言顯示
    local names = opts.Name or key
    local def = {
        key = key,
        names = names,
        nameCn = type(names) == "table" and (names["zh-TW"] or names.en or key) or names,
        nameEn = (opts.English or key):upper(),
        tag = opts.Tag or "",
        groups = groups,
        glyph = opts.Glyph or "★",
        character = opts.Background ~= nil,
        shape = opts.Shape or "circle",
        motto = opts.Motto or "",
        caption = opts.Caption or "",
        constellation = opts.Constellation or "",
        creator = type(opts.Creator) == "string" and opts.Creator ~= "" and opts.Creator or nil, -- 主題卡名稱後顯示的作者 / 來源
        region = opts.Region or "",
        aliases = opts.Aliases,
        plugin = opts.Plugin,
        palette = makePalette(baseDef and baseDef.palette or BASE_PALETTE, overrides),
    }
    def.palette.def = def
    -- 只有粒子、沒有背景圖也會建立壁紙設定，讓粒子能顯示
    if opts.Background or opts.Particle then
        WALLPAPERS[key] = {
            background = opts.Background,
            character = opts.Character,
            dim = opts.Dim or 0.55,
            particle = opts.Particle or "glow",
        }
    end
    table.insert(THEMES, def)
    table.insert(SenkoUI.Themes, key)
    return key
end

-- ---------- 圖示 ----------
-- map = { 名稱 = "rbxassetid://..." 或數字 }；名稱不分大小寫，查詢時也會自動嘗試加上 "lucide-" 前綴
function SenkoUI:AddIcons(map)
    local count = 0
    for name, image in pairs(map or {}) do
        if type(name) == "string" and (type(image) == "string" or type(image) == "number") then
            SenkoUI.Icons[name:lower()] = type(image) == "number" and ("rbxassetid://" .. image) or image
            count = count + 1
        end
    end
    return count
end

-- 圖示表找不到時的解析器：fn(name) 回傳圖片位址或 nil，可 yield（例如下載後 getcustomasset）
function SenkoUI:AddIconResolver(fn, plugin)
    if type(fn) ~= "function" then
        warn("[SenkoUI] AddIconResolver 需要函式")
        return
    end
    table.insert(iconResolvers, { fn = fn, plugin = plugin or "script" })
end

-- 名稱 → 圖片位址；找不到時回傳 nil（表裡沒有時會呼叫解析器，可能 yield）
function SenkoUI:GetIcon(name)
    return lookupIcon(name)
end

-- ---------- 粒子 ----------
function SenkoUI:AddParticle(name, style)
    if type(name) ~= "string" or type(style) ~= "table" then
        warn("[SenkoUI] AddParticle(名稱, 樣式表)")
        return nil
    end
    local base = PARTICLE_STYLES.glow
    PARTICLE_STYLES[name] = {
        dir = style.Dir or base.dir,
        speed = style.Speed or base.speed,
        size = style.Size or base.size,
        sway = style.Sway or base.sway,
        shape = style.Shape or base.shape,
        count = style.Count or base.count,
    }
    return name
end

-- ---------- 自訂控件 ----------
local pluginElements = {}

-- builder(section, opts, Kit) 需回傳控件物件；之後 Section / Tab 都能呼叫 section:名稱(opts)
function SenkoUI:AddElement(name, builder, settings)
    settings = settings or {}
    if type(name) ~= "string" or name == "" or type(builder) ~= "function" then
        warn("[SenkoUI] AddElement(名稱, 建構函式)")
        return nil
    end
    if Section[name] ~= nil and not pluginElements[name] and not settings.Override then
        warn("[SenkoUI] 控件 " .. name .. " 已存在；要覆寫內建控件請傳 { Override = true }")
        return nil
    end
    pluginElements[name] = settings.Plugin or true
    Section[name] = function(section, elementOpts)
        return builder(section, elementOpts or {}, Kit)
    end
    Tab[name] = function(tab, ...)
        local section = tab:_default()
        return section[name](section, ...)
    end
    return name
end

-- ---------- 插件載入 ----------
SenkoUI.Plugins = {}
local pluginList = {}
local VALID_EVENTS = { WindowCreated = true, WindowDestroyed = true, ThemeChanged = true, ThemeTabBuilt = true }

local function versionAtLeast(have, need)
    local a, b = string.split(tostring(have), "."), string.split(tostring(need), ".")
    for i = 1, math.max(#a, #b) do
        local x, y = tonumber(a[i]) or 0, tonumber(b[i]) or 0
        if x ~= y then
            return x > y
        end
    end
    return true
end

-- 傳給插件 Setup 的 api：註冊的東西會自動標記來源插件
local function makePluginApi(name, options, locales)
    local api = { Name = name, Options = options, SenkoUI = SenkoUI, Kit = Kit, Version = SenkoUI.Version, Language = SenkoUI.Language }
    -- 插件自己的字典：插件表的 Locales = { ["zh-TW"] = {...}, en = {...} }
    locales = locales or {}
    function api:T(key, ...)
        local s = (locales[SenkoUI.Language] or {})[key]
        if s == nil then
            s = (locales.en or {})[key]
        end
        if s == nil then
            s = (locales["zh-TW"] or {})[key]
        end
        if s == nil then
            return key
        end
        if select("#", ...) > 0 then
            return string.format(s, ...)
        end
        return s
    end
    function api:AddLocale(lang, dict)
        locales[lang] = locales[lang] or {}
        for k, v in pairs(dict or {}) do
            locales[lang][k] = v
        end
    end
    local function tagged(t)
        local copy = table.clone(t or {})
        copy.Plugin = name
        return copy
    end
    function api:AddTheme(def)
        return SenkoUI:AddTheme(tagged(def))
    end
    function api:AddGroup(def)
        return SenkoUI:AddGroup(tagged(type(def) == "string" and { Key = def } or def))
    end
    function api:AddParticle(particleName, style)
        return SenkoUI:AddParticle(particleName, style)
    end
    function api:AddIcons(map)
        return SenkoUI:AddIcons(map)
    end
    function api:AddIconResolver(fn)
        return SenkoUI:AddIconResolver(fn, name)
    end
    -- 下載並快取圖片到 assets/<插件名稱>/，插件管理可分別清除
    function api:LoadImage(url)
        return Assets.load(url, name)
    end
    function api:AddElement(elementName, builder, settings)
        return SenkoUI:AddElement(elementName, builder, tagged(settings))
    end
    -- force = false 時只在尚未設定過才寫入，讓 CreateWindow 的 AssetSources 能覆寫插件預設
    function api:SetAssetSource(source, base, force)
        if force or SenkoUI.AssetSources[source] == nil then
            SenkoUI.AssetSources[source] = base
        end
    end
    function api:On(event, fn)
        if not VALID_EVENTS[event] or type(fn) ~= "function" then
            warn("[SenkoUI] 插件 " .. name .. " 註冊了不存在的事件：" .. tostring(event))
            return
        end
        Hooks[event] = Hooks[event] or {}
        table.insert(Hooks[event], { fn = fn, plugin = name })
    end
    function api:Log(...)
        print("[SenkoUI:" .. name .. "]", ...)
    end
    function api:Warn(...)
        warn("[SenkoUI:" .. name .. "]", ...)
    end
    return api
end

-- 載入插件：plugin 可以是插件表，或直接傳 Setup 函式；回傳插件紀錄（含 Setup 的回傳值 Exports）
function SenkoUI:Use(plugin, options)
    if type(plugin) == "function" then
        plugin = { Setup = plugin }
    end
    if type(plugin) ~= "table" or type(plugin.Setup) ~= "function" then
        warn("[SenkoUI] Use：插件需要 Setup 函式")
        return nil
    end
    local name = plugin.Name or ("Plugin" .. (#pluginList + 1))
    if SenkoUI.Plugins[name] then
        return SenkoUI.Plugins[name]
    end
    if plugin.Requires and not versionAtLeast(SenkoUI.Version, plugin.Requires) then
        warn(string.format("[SenkoUI] 插件 %s 需要 SenkoUI %s 以上（目前 %s）", name, plugin.Requires, SenkoUI.Version))
        return nil
    end
    if createdWindows > 0 and not liveLoading then
        warn("[SenkoUI] 插件 " .. name .. " 在 CreateWindow 之後才載入，已開啟的視窗不會出現它的主題，也收不到 WindowCreated")
    end
    options = options or {}
    local locales = {}
    for lang, dict in pairs(plugin.Locales or {}) do
        locales[lang] = table.clone(dict)
    end
    local ok, result = pcall(plugin.Setup, makePluginApi(name, options, locales), options)
    if not ok then
        warn("[SenkoUI] 插件 " .. name .. " 載入失敗：" .. tostring(result))
        return nil
    end
    local record = {
        Name = name,
        Version = plugin.Version,
        Author = plugin.Author,
        Description = localized(plugin.Description),
        Credit = localized(plugin.Credit),
        Exports = result,
    }
    SenkoUI.Plugins[name] = record
    table.insert(pluginList, record)
    return record
end

local function compilePlugin(source)
    local code
    if source:match("^https?://") then
        code = game:HttpGet(source)
    else
        if not FS.available or not isfile(source) then
            error("找不到插件檔：" .. source)
        end
        code = readfile(source)
    end
    local chunk, err = loadstring(code, "=" .. source)
    if not chunk then
        error("語法錯誤：" .. tostring(err))
    end
    return chunk()
end

-- 從網址或 workspace 路徑載入插件
function SenkoUI:LoadPlugin(source, options)
    local ok, plugin = pcall(compilePlugin, source)
    if not ok then
        warn("[SenkoUI] 插件載入失敗（" .. tostring(source) .. "）：" .. tostring(plugin))
        return nil
    end
    return self:Use(plugin, options)
end

-- 載入資料夾內所有 .lua 插件（預設 SenkoUI/plugins）；optionsByName 以插件 Name 為鍵
function SenkoUI:LoadPluginFolder(folder, optionsByName)
    folder = folder or (SenkoUI.Folder .. "/plugins")
    optionsByName = optionsByName or {}
    local loaded = {}
    if not FS.available or type(listfiles) ~= "function" then
        return loaded
    end
    FS.ensureFolder(SenkoUI.Folder)
    FS.ensureFolder(folder)
    local ok, files = pcall(listfiles, folder)
    if not ok or type(files) ~= "table" then
        return loaded
    end
    table.sort(files)
    for _, file in ipairs(files) do
        local path = tostring(file)
        if path:lower():sub(-4) == ".lua" then
            local okCompile, plugin = pcall(compilePlugin, path)
            if okCompile and type(plugin) == "table" then
                local record = self:Use(plugin, optionsByName[plugin.Name or ""])
                if record then
                    table.insert(loaded, record)
                end
            else
                warn("[SenkoUI] 插件載入失敗（" .. path .. "）：" .. tostring(plugin))
            end
        end
    end
    return loaded
end

function SenkoUI:GetPlugins()
    return table.clone(pluginList)
end

function SenkoUI:HasPlugin(name)
    return SenkoUI.Plugins[name] ~= nil
end

-- ---------- 角色壁紙插件（純 JSON，不執行任何外部程式碼）----------
-- plugins/index.json 列出插件與其角色資料夾；每個角色資料夾有 character.json（含完整色票）與圖片
local pluginCatalog = {}

local function pluginStatePath()
    return SenkoUI.Folder .. "/plugins.json"
end

local function cacheDir(name)
    if type(name) ~= "string" or name == "" then
        return SenkoUI.Folder .. "/assets"
    end
    return SenkoUI.Folder .. "/assets/" .. (name:gsub("[^%w%._%-]", "_"))
end

local function findCatalog(name)
    for _, e in ipairs(pluginCatalog) do
        if e.name == name then
            return e
        end
    end
    return nil
end

-- 官方插件清單；LoadPlugins() 不帶參數時讀取
SenkoUI.PluginIndex = "https://raw.githubusercontent.com/Tseting-nil/senko-ui/main/plugins/index.json"

-- 移除 JSON 裡的 // 與 /* */ 註解（略過字串內容，網址裡的 // 不受影響），讓 character.json 可以寫註解
local function stripJsonComments(text)
    local out, i, n = {}, 1, #text
    local inString = false
    while i <= n do
        local c = text:sub(i, i)
        if inString then
            table.insert(out, c)
            if c == "\\" then
                table.insert(out, text:sub(i + 1, i + 1))
                i = i + 1
            elseif c == '"' then
                inString = false
            end
            i = i + 1
        elseif c == '"' then
            inString = true
            table.insert(out, c)
            i = i + 1
        elseif text:sub(i, i + 1) == "//" then
            local stop = text:find("\n", i, true)
            i = stop or n + 1
        elseif text:sub(i, i + 1) == "/*" then
            local _, stop = text:find("*/", i + 2, true)
            i = (stop or n) + 1
        else
            table.insert(out, c)
            i = i + 1
        end
    end
    -- 註解拿掉後可能留下結尾逗號（例如 [ "a.jpg", // 註解 ]），一併清除
    return (table.concat(out):gsub(",(%s*[%]}])", "%1"))
end

-- 讀取網址或 workspace 路徑的 JSON；成功時寫入快取，失敗時改用上次的快取
local function fetchJson(source, cachePath)
    local ok, data = pcall(function()
        local text
        if source:match("^https?://") then
            text = game:HttpGet(source)
        else
            if not FS.available or not isfile(source) then
                error("找不到檔案：" .. source)
            end
            text = readfile(source)
        end
        return HttpService:JSONDecode(stripJsonComments(text))
    end)
    if ok and type(data) == "table" then
        if cachePath and FS.available then
            pcall(function()
                FS.ensureFolder(SenkoUI.Folder)
                FS.ensureFolder(SenkoUI.Folder .. "/assets")
                FS.ensureFolder(cachePath:match("^(.*)/") or SenkoUI.Folder)
                writefile(cachePath, HttpService:JSONEncode(data))
            end)
        end
        return data
    end
    local cached = cachePath and FS.readJson(cachePath)
    if type(cached) == "table" then
        warn("[SenkoUI] 無法讀取 " .. source .. "，改用上次的快取")
        return cached
    end
    warn("[SenkoUI] 無法讀取 " .. source .. "：" .. tostring(data))
    return nil
end

-- 讀取插件清單：{ plugins = { { name, label, label_en, characters = { 角色資料夾 }, default } } }
local function fetchPluginIndex(source)
    local safe = source:gsub("[^%w]", "_"):sub(-60)
    local data = fetchJson(source, SenkoUI.Folder .. "/plugin-index/" .. safe .. ".json")
    if not data then
        return {}
    end
    local base = source:match("^(.*[/\\])") or ""
    local entries = {}
    for _, p in ipairs(data.plugins or data) do
        if type(p) == "table" and type(p.name) == "string" and p.name ~= "" then
            local characters = {}
            for _, c in ipairs(p.characters or {}) do
                if type(c) == "string" and c ~= "" then
                    table.insert(characters, c)
                end
            end
            table.insert(entries, {
                name = p.name,
                label = { ["zh-TW"] = p.label or p.name, en = p.label_en or p.name },
                characters = characters,
                default = p.default == true,
                base = base .. p.name .. "/",
            })
        else
            warn("[SenkoUI] 插件清單項目缺少 name：" .. source)
        end
    end
    return entries
end

-- 角色資料夾內的檔案網址；images 也可以直接寫完整網址
local function characterFile(entry, character, file)
    if file:match("^https?://") then
        return file
    end
    return entry.base .. character .. "/" .. file
end

local function fetchCharacter(entry, character)
    local cachePath = cacheDir(entry.name) .. "/" .. character:gsub("[^%w%._%-]", "_") .. ".json"
    local data = fetchJson(characterFile(entry, character, "character.json"), cachePath)
    if type(data) ~= "table" then
        return nil
    end
    if type(data.palette) ~= "table" then
        warn("[SenkoUI] " .. entry.name .. "/" .. character .. "/character.json 缺少 palette")
        return nil
    end
    return data
end

-- character.json → 主題（色票的 #RRGGBB 由 AddTheme 轉成 Color3）
local function registerCharacter(entry, character, data)
    local images = type(data.images) == "table" and data.images or {}
    local function pair(zh, en)
        if zh == nil and en == nil then
            return nil
        end
        return { ["zh-TW"] = zh or en, en = en or zh }
    end
    return SenkoUI:AddTheme({
        Key = data.key or character,
        Name = pair(data.name or character, data.name_en),
        English = data.name_en or data.key or character,
        Tag = data.tag,
        Glyph = data.glyph,
        Shape = data.shape,
        Group = entry.name,
        GroupLabel = entry.label,
        Motto = pair(data.description, data.description_en),
        Region = pair(data.region, data.region_en),
        Constellation = data.constellation,
        Creator = data.creator,
        Background = images[1] and characterFile(entry, character, images[1]) or nil,
        Character = images[2] and characterFile(entry, character, images[2]) or nil,
        Dim = tonumber(data.dim),
        Particle = data.particle,
        Palette = data.palette,
        Plugin = entry.name,
    })
end

-- 讀取並註冊插件所有角色；onCharacter(角色, 資料) 每讀完一個角色呼叫一次
local function loadCharacters(entry, onCharacter)
    local loaded = {}
    for _, character in ipairs(entry.characters) do
        local data = fetchCharacter(entry, character)
        if data then
            table.insert(loaded, { name = character, data = data })
        end
        if onCharacter then
            onCharacter(character, data)
        end
    end
    local keys = {}
    for _, item in ipairs(loaded) do
        local key = registerCharacter(entry, item.name, item.data)
        if key then
            table.insert(keys, key)
        end
    end
    return keys, loaded
end

-- source：清單網址或 workspace 路徑（字串），或多份清單 { 網址, ... }；不帶參數時讀取官方清單 SenkoUI.PluginIndex
-- 需在 CreateWindow 之前呼叫：已啟用的插件會先註冊主題（圖片在切換到該主題時才下載）
-- 使用者在主題頁的開關存於 SenkoUI/plugins.json，優先於清單的 default
function SenkoUI:LoadPlugins(source)
    local sources = source == nil and { SenkoUI.PluginIndex } or source
    if type(sources) == "string" then
        sources = { sources }
    end
    local state = FS.readJson(pluginStatePath()) or {}
    local loaded = {}
    for _, src in ipairs(sources) do
        if type(src) == "table" then
            src = src.Index -- 相容 { Index = 網址 } 的寫法
        end
        if type(src) ~= "string" then
            continue
        end
        for _, entry in ipairs(fetchPluginIndex(src)) do
            if findCatalog(entry.name) then
                continue
            end
            local enabled = state[entry.name]
            if enabled == nil then
                enabled = entry.default
            end
            entry.enabled = enabled and true or false
            entry.loaded = false
            table.insert(pluginCatalog, entry)
            if entry.enabled then
                local keys = loadCharacters(entry)
                entry.loaded = #keys > 0
                if entry.loaded then
                    table.insert(loaded, entry.name)
                end
            end
        end
    end
    return loaded
end

-- 已開啟的視窗補上新插件的壁紙、主題卡、分類與分頁圖示
function Window:_pluginLoaded()
    for key, spec in pairs(WALLPAPERS) do
        if self._wallpapers[key] == nil and not self._wallpaperOff[key] then
            self._wallpapers[key] = table.clone(spec)
        end
    end
    for _, refresh in ipairs(self._libraryRefreshers) do
        local ok, err = pcall(refresh)
        if not ok then
            warn("[SenkoUI] 更新主題庫失敗：" .. tostring(err))
        end
    end
    local retries = self._iconRetries
    self._iconRetries = {}
    for _, retry in ipairs(retries) do
        task.spawn(retry)
    end
end

-- 插件關閉後：移除壁紙與主題卡（正在使用的主題已由 DisablePlugin 先換掉）
function Window:_pluginUnloaded(keys)
    for _, key in ipairs(keys) do
        self._wallpapers[key] = nil
    end
    for _, refresh in ipairs(self._libraryRefreshers) do
        local ok, err = pcall(refresh)
        if not ok then
            warn("[SenkoUI] 更新主題庫失敗：" .. tostring(err))
        end
    end
end

-- 開啟插件：下載所有角色的 character.json 與圖片，註冊主題並即時加入已開啟的視窗（也會記住，下次執行自動載入）
-- onProgress(done, total)；回傳 ok, { characters, images, failed }
function SenkoUI:EnablePlugin(name, onProgress)
    local entry = findCatalog(name)
    if not entry then
        warn("[SenkoUI] 插件清單裡沒有：" .. tostring(name))
        return false
    end
    self:SetPluginEnabled(name, true)
    local result = { characters = 0, images = 0, failed = 0 }
    if entry.loaded then
        for _, def in ipairs(THEMES) do
            if def.plugin == name then
                result.characters = result.characters + 1
            end
        end
        return true, result
    end
    local done, total = 0, #entry.characters
    local function report()
        if onProgress then
            pcall(onProgress, done, total)
        end
    end
    report()
    -- 1. 角色 json（讀到後才知道每個角色有幾張圖，總數隨之增加）
    local items = {}
    for _, character in ipairs(entry.characters) do
        local data = fetchCharacter(entry, character)
        done = done + 1
        if data then
            table.insert(items, { name = character, data = data })
            if Assets.available and type(data.images) == "table" then
                total = total + #data.images
            end
        end
        report()
    end
    if #items == 0 then
        self:SetPluginEnabled(name, false)
        return false
    end
    -- 2. 圖片（快取在 SenkoUI/assets/<插件名稱>/，已下載的直接略過）
    if Assets.available then
        for _, item in ipairs(items) do
            for _, file in ipairs(type(item.data.images) == "table" and item.data.images or {}) do
                if Assets.load(characterFile(entry, item.name, file), name) then
                    result.images = result.images + 1
                else
                    result.failed = result.failed + 1
                end
                done = done + 1
                report()
            end
        end
    end
    -- 3. 註冊主題，已開啟的視窗即時加入分類與主題卡
    liveLoading = true
    for _, item in ipairs(items) do
        if registerCharacter(entry, item.name, item.data) then
            result.characters = result.characters + 1
        end
    end
    liveLoading = false
    entry.loaded = result.characters > 0
    for win in pairs(openWindows) do
        win:_pluginLoaded()
    end
    return entry.loaded, result
end

-- 關閉插件：立即移除它的主題、分類與主題卡（已下載的圖片保留，要清除快取才會刪除）
function SenkoUI:DisablePlugin(name)
    self:SetPluginEnabled(name, false)
    local entry = findCatalog(name)
    local keys = {}
    for i = #THEMES, 1, -1 do
        local def = THEMES[i]
        if def.plugin == name then
            table.insert(keys, def.key)
        end
    end
    if #keys == 0 then
        if entry then
            entry.loaded = false
        end
        return 0
    end
    -- 先讓視窗換掉正在使用的主題，再從主題表移除
    for win in pairs(openWindows) do
        local removing = false
        for _, key in ipairs(keys) do
            if win.theme.key == key then
                removing = true
            end
        end
        if removing then
            local fallback = findTheme(win.startupTheme)
            if not fallback or fallback.plugin == name then
                fallback = THEMES[1]
            end
            win:SetTheme(fallback.key)
        end
    end
    for i = #THEMES, 1, -1 do
        if THEMES[i].plugin == name then
            WALLPAPERS[THEMES[i].key] = nil
            table.remove(THEMES, i)
        end
    end
    for i = #SenkoUI.Themes, 1, -1 do
        if table.find(keys, SenkoUI.Themes[i]) then
            table.remove(SenkoUI.Themes, i)
        end
    end
    for i = #GROUPS, 1, -1 do
        if GROUPS[i].plugin == name then
            table.remove(GROUPS, i)
        end
    end
    if entry then
        entry.loaded = false
    end
    for win in pairs(openWindows) do
        win:_pluginUnloaded(keys)
    end
    return #keys
end

-- { { Name, Label, Characters = 角色數, CharacterList, Enabled, Loaded } }；Label 為語系表
function SenkoUI:GetPluginCatalog()
    local list = {}
    for _, e in ipairs(pluginCatalog) do
        table.insert(list, {
            Name = e.name,
            Label = table.clone(e.label),
            Characters = #e.characters,
            CharacterList = table.clone(e.characters),
            Enabled = e.enabled,
            Loaded = e.loaded,
        })
    end
    return list
end

-- 只記錄下次執行是否載入（不會當場載入 / 移除；當場切換請用 EnablePlugin / DisablePlugin）
function SenkoUI:SetPluginEnabled(name, enabled)
    local state = FS.readJson(pluginStatePath()) or {}
    state[name] = enabled and true or false
    FS.ensureFolder(SenkoUI.Folder)
    FS.writeJson(pluginStatePath(), state)
    local entry = findCatalog(name)
    if entry then
        entry.enabled = state[name]
    end
end

-- 圖片快取大小：name = 插件名稱（assets/<名稱>/），nil = 未分類（assets/ 根目錄）；回傳位元組數、檔案數
function SenkoUI:GetCacheSize(name)
    return FS.folderSize(cacheDir(name))
end

-- 刪除圖片快取（需要執行器支援 delfile），回傳刪除的檔案數
function SenkoUI:ClearCache(name)
    local removed = FS.clearFolder(cacheDir(name))
    local key = type(name) == "string" and name or ""
    for url, folder in pairs(Assets.folders) do
        if folder == key then
            Assets.cache[url] = nil
            Assets.folders[url] = nil
        end
    end
    return removed
end

-- ---------- 多語系 ----------
-- 新增語言或補充字串：SenkoUI:AddLocale("ja", { _name = "日本語", ["section.themes"] = "テーマ", ... })
function SenkoUI:AddLocale(lang, dict)
    if type(lang) ~= "string" or type(dict) ~= "table" then
        warn("[SenkoUI] AddLocale(語言代碼, 字典)")
        return
    end
    LOCALES[lang] = LOCALES[lang] or { _name = lang }
    for k, v in pairs(dict) do
        LOCALES[lang][k] = v
    end
end

-- 可選的語言清單 { { Code, Name } }，English、繁體中文排前面
function SenkoUI:GetLanguages()
    local list = {}
    for code, dict in pairs(LOCALES) do
        table.insert(list, { Code = code, Name = dict._name or code })
    end
    local rank = { en = 1, ["zh-TW"] = 2 }
    table.sort(list, function(a, b)
        local ra, rb = rank[a.Code] or 9, rank[b.Code] or 9
        if ra ~= rb then
            return ra < rb
        end
        return a.Code < b.Code
    end)
    return list
end

-- 切換語言並存入 settings.json；已開啟視窗的主題卡、分類、插件管理、側欄文字即時更新
-- （其他已建立的控件文字在重新執行腳本後套用）
function SenkoUI:SetLanguage(lang)
    if type(lang) ~= "string" or not LOCALES[lang] then
        warn("[SenkoUI] 沒有這個語言：" .. tostring(lang))
        return
    end
    SenkoUI.Language = lang
    local path = SenkoUI.Folder .. "/settings.json"
    local saved = FS.readJson(path) or {}
    saved.language = lang
    FS.ensureFolder(SenkoUI.Folder)
    FS.writeJson(path, saved)
    for win in pairs(openWindows) do
        win:_refreshLanguage()
    end
end

-- 取核心字典的字串（給腳本與插件共用介面用語）
function SenkoUI:T(key, ...)
    return T(key, ...)
end

SenkoUI.FormatBytes = formatBytes

-- ============================================================
-- 內建 Lucide 圖示（UI 庫內部基礎設施，不列入插件管理）
-- 分頁圖示可直接寫 https://lucide.dev/icons/ 的名稱：Icon = "settings" 或 "lucide-eye"
--   1. 內建表：Roblox 上已上傳的 Lucide 圖示（821 個 asset，載入即時）；改名的常用圖示已加上別名
--   2. 線上補抓：表裡沒有的名稱向 api.iconify.design 取 SVG，經 images.weserv.nl 轉成 PNG，
--      再用 writefile + getcustomasset 載入，快取在 SenkoUI/assets/Lucide/
--      SenkoUI.LucideOnline = false 可關閉線上補抓
-- 圖示：Lucide（ISC 授權）
-- ============================================================
local LUCIDE_ICONS = {
    ["accessibility"] = "rbxassetid://10709751939",
    ["activity"] = "rbxassetid://10709752035",
    ["air-vent"] = "rbxassetid://10709752131",
    ["airplay"] = "rbxassetid://10709752254",
    ["alarm-check"] = "rbxassetid://10709752405",
    ["alarm-clock"] = "rbxassetid://10709752630",
    ["alarm-clock-off"] = "rbxassetid://10709752508",
    ["alarm-minus"] = "rbxassetid://10709752732",
    ["alarm-plus"] = "rbxassetid://10709752825",
    ["album"] = "rbxassetid://10709752906",
    ["alert-circle"] = "rbxassetid://10709752996",
    ["alert-octagon"] = "rbxassetid://10709753064",
    ["alert-triangle"] = "rbxassetid://10709753149",
    ["align-center"] = "rbxassetid://10709753570",
    ["align-center-horizontal"] = "rbxassetid://10709753272",
    ["align-center-vertical"] = "rbxassetid://10709753421",
    ["align-end-horizontal"] = "rbxassetid://10709753692",
    ["align-end-vertical"] = "rbxassetid://10709753808",
    ["align-horizontal-distribute-center"] = "rbxassetid://10747779791",
    ["align-horizontal-distribute-end"] = "rbxassetid://10747784534",
    ["align-horizontal-distribute-start"] = "rbxassetid://10709754118",
    ["align-horizontal-justify-center"] = "rbxassetid://10709754204",
    ["align-horizontal-justify-end"] = "rbxassetid://10709754317",
    ["align-horizontal-justify-start"] = "rbxassetid://10709754436",
    ["align-horizontal-space-around"] = "rbxassetid://10709754590",
    ["align-horizontal-space-between"] = "rbxassetid://10709754749",
    ["align-justify"] = "rbxassetid://10709759610",
    ["align-left"] = "rbxassetid://10709759764",
    ["align-right"] = "rbxassetid://10709759895",
    ["align-start-horizontal"] = "rbxassetid://10709760051",
    ["align-start-vertical"] = "rbxassetid://10709760244",
    ["align-vertical-distribute-center"] = "rbxassetid://10709760351",
    ["align-vertical-distribute-end"] = "rbxassetid://10709760434",
    ["align-vertical-distribute-start"] = "rbxassetid://10709760612",
    ["align-vertical-justify-center"] = "rbxassetid://10709760814",
    ["align-vertical-justify-end"] = "rbxassetid://10709761003",
    ["align-vertical-justify-start"] = "rbxassetid://10709761176",
    ["align-vertical-space-around"] = "rbxassetid://10709761324",
    ["align-vertical-space-between"] = "rbxassetid://10709761434",
    ["anchor"] = "rbxassetid://10709761530",
    ["angry"] = "rbxassetid://10709761629",
    ["annoyed"] = "rbxassetid://10709761722",
    ["aperture"] = "rbxassetid://10709761813",
    ["apple"] = "rbxassetid://10709761889",
    ["archive"] = "rbxassetid://10709762233",
    ["archive-restore"] = "rbxassetid://10709762058",
    ["armchair"] = "rbxassetid://10709762327",
    ["arrow-big-down"] = "rbxassetid://10747796644",
    ["arrow-big-left"] = "rbxassetid://10709762574",
    ["arrow-big-right"] = "rbxassetid://10709762727",
    ["arrow-big-up"] = "rbxassetid://10709762879",
    ["arrow-down"] = "rbxassetid://10709767827",
    ["arrow-down-circle"] = "rbxassetid://10709763034",
    ["arrow-down-left"] = "rbxassetid://10709767656",
    ["arrow-down-right"] = "rbxassetid://10709767750",
    ["arrow-left"] = "rbxassetid://10709768114",
    ["arrow-left-circle"] = "rbxassetid://10709767936",
    ["arrow-left-right"] = "rbxassetid://10709768019",
    ["arrow-right"] = "rbxassetid://10709768347",
    ["arrow-right-circle"] = "rbxassetid://10709768226",
    ["arrow-up"] = "rbxassetid://10709768939",
    ["arrow-up-circle"] = "rbxassetid://10709768432",
    ["arrow-up-down"] = "rbxassetid://10709768538",
    ["arrow-up-left"] = "rbxassetid://10709768661",
    ["arrow-up-right"] = "rbxassetid://10709768787",
    ["asterisk"] = "rbxassetid://10709769095",
    ["at-sign"] = "rbxassetid://10709769286",
    ["award"] = "rbxassetid://10709769406",
    ["axe"] = "rbxassetid://10709769508",
    ["axis-3d"] = "rbxassetid://10709769598",
    ["baby"] = "rbxassetid://10709769732",
    ["backpack"] = "rbxassetid://10709769841",
    ["baggage-claim"] = "rbxassetid://10709769935",
    ["banana"] = "rbxassetid://10709770005",
    ["banknote"] = "rbxassetid://10709770178",
    ["bar-chart"] = "rbxassetid://10709773755",
    ["bar-chart-2"] = "rbxassetid://10709770317",
    ["bar-chart-3"] = "rbxassetid://10709770431",
    ["bar-chart-4"] = "rbxassetid://10709770560",
    ["bar-chart-horizontal"] = "rbxassetid://10709773669",
    ["barcode"] = "rbxassetid://10747360675",
    ["baseline"] = "rbxassetid://10709773863",
    ["bath"] = "rbxassetid://10709773963",
    ["battery"] = "rbxassetid://10709774640",
    ["battery-charging"] = "rbxassetid://10709774068",
    ["battery-full"] = "rbxassetid://10709774206",
    ["battery-low"] = "rbxassetid://10709774370",
    ["battery-medium"] = "rbxassetid://10709774513",
    ["beaker"] = "rbxassetid://10709774756",
    ["bed"] = "rbxassetid://10709775036",
    ["bed-double"] = "rbxassetid://10709774864",
    ["bed-single"] = "rbxassetid://10709774968",
    ["beer"] = "rbxassetid://10709775167",
    ["bell"] = "rbxassetid://10709775704",
    ["bell-minus"] = "rbxassetid://10709775241",
    ["bell-off"] = "rbxassetid://10709775320",
    ["bell-plus"] = "rbxassetid://10709775448",
    ["bell-ring"] = "rbxassetid://10709775560",
    ["bike"] = "rbxassetid://10709775894",
    ["binary"] = "rbxassetid://10709776050",
    ["bitcoin"] = "rbxassetid://10709776126",
    ["bluetooth"] = "rbxassetid://10709776655",
    ["bluetooth-connected"] = "rbxassetid://10709776240",
    ["bluetooth-off"] = "rbxassetid://10709776344",
    ["bluetooth-searching"] = "rbxassetid://10709776501",
    ["bold"] = "rbxassetid://10747813908",
    ["bomb"] = "rbxassetid://10709781460",
    ["bone"] = "rbxassetid://10709781605",
    ["book"] = "rbxassetid://10709781824",
    ["book-open"] = "rbxassetid://10709781717",
    ["bookmark"] = "rbxassetid://10709782154",
    ["bookmark-minus"] = "rbxassetid://10709781919",
    ["bookmark-plus"] = "rbxassetid://10709782044",
    ["bot"] = "rbxassetid://10709782230",
    ["box"] = "rbxassetid://10709782497",
    ["box-select"] = "rbxassetid://10709782342",
    ["boxes"] = "rbxassetid://10709782582",
    ["briefcase"] = "rbxassetid://10709782662",
    ["brush"] = "rbxassetid://10709782758",
    ["bug"] = "rbxassetid://10709782845",
    ["building"] = "rbxassetid://10709783051",
    ["building-2"] = "rbxassetid://10709782939",
    ["bus"] = "rbxassetid://10709783137",
    ["cake"] = "rbxassetid://10709783217",
    ["calculator"] = "rbxassetid://10709783311",
    ["calendar"] = "rbxassetid://10709789505",
    ["calendar-check"] = "rbxassetid://10709783474",
    ["calendar-check-2"] = "rbxassetid://10709783392",
    ["calendar-clock"] = "rbxassetid://10709783577",
    ["calendar-days"] = "rbxassetid://10709783673",
    ["calendar-heart"] = "rbxassetid://10709783835",
    ["calendar-minus"] = "rbxassetid://10709783959",
    ["calendar-off"] = "rbxassetid://10709788784",
    ["calendar-plus"] = "rbxassetid://10709788937",
    ["calendar-range"] = "rbxassetid://10709789053",
    ["calendar-search"] = "rbxassetid://10709789200",
    ["calendar-x"] = "rbxassetid://10709789407",
    ["calendar-x-2"] = "rbxassetid://10709789329",
    ["camera"] = "rbxassetid://10709789686",
    ["camera-off"] = "rbxassetid://10747822677",
    ["car"] = "rbxassetid://10709789810",
    ["carrot"] = "rbxassetid://10709789960",
    ["cast"] = "rbxassetid://10709790097",
    ["charge"] = "rbxassetid://10709790202",
    ["check"] = "rbxassetid://10709790644",
    ["check-circle"] = "rbxassetid://10709790387",
    ["check-circle-2"] = "rbxassetid://10709790298",
    ["check-square"] = "rbxassetid://10709790537",
    ["chef-hat"] = "rbxassetid://10709790757",
    ["cherry"] = "rbxassetid://10709790875",
    ["chevron-down"] = "rbxassetid://10709790948",
    ["chevron-first"] = "rbxassetid://10709791015",
    ["chevron-last"] = "rbxassetid://10709791130",
    ["chevron-left"] = "rbxassetid://10709791281",
    ["chevron-right"] = "rbxassetid://10709791437",
    ["chevron-up"] = "rbxassetid://10709791523",
    ["chevrons-down"] = "rbxassetid://10709796864",
    ["chevrons-down-up"] = "rbxassetid://10709791632",
    ["chevrons-left"] = "rbxassetid://10709797151",
    ["chevrons-left-right"] = "rbxassetid://10709797006",
    ["chevrons-right"] = "rbxassetid://10709797382",
    ["chevrons-right-left"] = "rbxassetid://10709797274",
    ["chevrons-up"] = "rbxassetid://10709797622",
    ["chevrons-up-down"] = "rbxassetid://10709797508",
    ["chrome"] = "rbxassetid://10709797725",
    ["circle"] = "rbxassetid://10709798174",
    ["circle-dot"] = "rbxassetid://10709797837",
    ["circle-ellipsis"] = "rbxassetid://10709797985",
    ["circle-slashed"] = "rbxassetid://10709798100",
    ["citrus"] = "rbxassetid://10709798276",
    ["clapperboard"] = "rbxassetid://10709798350",
    ["clipboard"] = "rbxassetid://10709799288",
    ["clipboard-check"] = "rbxassetid://10709798443",
    ["clipboard-copy"] = "rbxassetid://10709798574",
    ["clipboard-edit"] = "rbxassetid://10709798682",
    ["clipboard-list"] = "rbxassetid://10709798792",
    ["clipboard-signature"] = "rbxassetid://10709798890",
    ["clipboard-type"] = "rbxassetid://10709798999",
    ["clipboard-x"] = "rbxassetid://10709799124",
    ["clock"] = "rbxassetid://10709805144",
    ["clock-1"] = "rbxassetid://10709799535",
    ["clock-10"] = "rbxassetid://10709799718",
    ["clock-11"] = "rbxassetid://10709799818",
    ["clock-12"] = "rbxassetid://10709799962",
    ["clock-2"] = "rbxassetid://10709803876",
    ["clock-3"] = "rbxassetid://10709803989",
    ["clock-4"] = "rbxassetid://10709804164",
    ["clock-5"] = "rbxassetid://10709804291",
    ["clock-6"] = "rbxassetid://10709804435",
    ["clock-7"] = "rbxassetid://10709804599",
    ["clock-8"] = "rbxassetid://10709804784",
    ["clock-9"] = "rbxassetid://10709804996",
    ["cloud"] = "rbxassetid://10709806740",
    ["cloud-cog"] = "rbxassetid://10709805262",
    ["cloud-drizzle"] = "rbxassetid://10709805371",
    ["cloud-fog"] = "rbxassetid://10709805477",
    ["cloud-hail"] = "rbxassetid://10709805596",
    ["cloud-lightning"] = "rbxassetid://10709805727",
    ["cloud-moon"] = "rbxassetid://10709805942",
    ["cloud-moon-rain"] = "rbxassetid://10709805838",
    ["cloud-off"] = "rbxassetid://10709806060",
    ["cloud-rain"] = "rbxassetid://10709806277",
    ["cloud-rain-wind"] = "rbxassetid://10709806166",
    ["cloud-snow"] = "rbxassetid://10709806374",
    ["cloud-sun"] = "rbxassetid://10709806631",
    ["cloud-sun-rain"] = "rbxassetid://10709806475",
    ["cloudy"] = "rbxassetid://10709806859",
    ["clover"] = "rbxassetid://10709806995",
    ["code"] = "rbxassetid://10709810463",
    ["code-2"] = "rbxassetid://10709807111",
    ["codepen"] = "rbxassetid://10709810534",
    ["codesandbox"] = "rbxassetid://10709810676",
    ["coffee"] = "rbxassetid://10709810814",
    ["cog"] = "rbxassetid://10709810948",
    ["coins"] = "rbxassetid://10709811110",
    ["columns"] = "rbxassetid://10709811261",
    ["command"] = "rbxassetid://10709811365",
    ["compass"] = "rbxassetid://10709811445",
    ["component"] = "rbxassetid://10709811595",
    ["concierge-bell"] = "rbxassetid://10709811706",
    ["connection"] = "rbxassetid://10747361219",
    ["contact"] = "rbxassetid://10709811834",
    ["contrast"] = "rbxassetid://10709811939",
    ["cookie"] = "rbxassetid://10709812067",
    ["copy"] = "rbxassetid://10709812159",
    ["copyleft"] = "rbxassetid://10709812251",
    ["copyright"] = "rbxassetid://10709812311",
    ["corner-down-left"] = "rbxassetid://10709812396",
    ["corner-down-right"] = "rbxassetid://10709812485",
    ["corner-left-down"] = "rbxassetid://10709812632",
    ["corner-left-up"] = "rbxassetid://10709812784",
    ["corner-right-down"] = "rbxassetid://10709812939",
    ["corner-right-up"] = "rbxassetid://10709813094",
    ["corner-up-left"] = "rbxassetid://10709813185",
    ["corner-up-right"] = "rbxassetid://10709813281",
    ["cpu"] = "rbxassetid://10709813383",
    ["croissant"] = "rbxassetid://10709818125",
    ["crop"] = "rbxassetid://10709818245",
    ["cross"] = "rbxassetid://10709818399",
    ["crosshair"] = "rbxassetid://10709818534",
    ["crown"] = "rbxassetid://10709818626",
    ["cup-soda"] = "rbxassetid://10709818763",
    ["curly-braces"] = "rbxassetid://10709818847",
    ["currency"] = "rbxassetid://10709818931",
    ["database"] = "rbxassetid://10709818996",
    ["delete"] = "rbxassetid://10709819059",
    ["diamond"] = "rbxassetid://10709819149",
    ["dice-1"] = "rbxassetid://10709819266",
    ["dice-2"] = "rbxassetid://10709819361",
    ["dice-3"] = "rbxassetid://10709819508",
    ["dice-4"] = "rbxassetid://10709819670",
    ["dice-5"] = "rbxassetid://10709819801",
    ["dice-6"] = "rbxassetid://10709819896",
    ["dices"] = "rbxassetid://10723343321",
    ["diff"] = "rbxassetid://10723343416",
    ["disc"] = "rbxassetid://10723343537",
    ["divide"] = "rbxassetid://10723343805",
    ["divide-circle"] = "rbxassetid://10723343636",
    ["divide-square"] = "rbxassetid://10723343737",
    ["dollar-sign"] = "rbxassetid://10723343958",
    ["download"] = "rbxassetid://10723344270",
    ["download-cloud"] = "rbxassetid://10723344088",
    ["droplet"] = "rbxassetid://10723344432",
    ["droplets"] = "rbxassetid://10734883356",
    ["drumstick"] = "rbxassetid://10723344737",
    ["earth"] = "rbxassetid://115986292591138",
    ["edit"] = "rbxassetid://10734883598",
    ["edit-2"] = "rbxassetid://10723344885",
    ["edit-3"] = "rbxassetid://10723345088",
    ["egg"] = "rbxassetid://10723345518",
    ["egg-fried"] = "rbxassetid://10723345347",
    ["electricity"] = "rbxassetid://10723345749",
    ["electricity-off"] = "rbxassetid://10723345643",
    ["equal"] = "rbxassetid://10723345990",
    ["equal-not"] = "rbxassetid://10723345866",
    ["eraser"] = "rbxassetid://10723346158",
    ["euro"] = "rbxassetid://10723346372",
    ["expand"] = "rbxassetid://10723346553",
    ["external-link"] = "rbxassetid://10723346684",
    ["eye"] = "rbxassetid://10723346959",
    ["eye-off"] = "rbxassetid://10723346871",
    ["factory"] = "rbxassetid://10723347051",
    ["fan"] = "rbxassetid://10723354359",
    ["fast-forward"] = "rbxassetid://10723354521",
    ["feather"] = "rbxassetid://10723354671",
    ["figma"] = "rbxassetid://10723354801",
    ["file"] = "rbxassetid://10723374641",
    ["file-archive"] = "rbxassetid://10723354921",
    ["file-audio"] = "rbxassetid://10723355148",
    ["file-audio-2"] = "rbxassetid://10723355026",
    ["file-axis-3d"] = "rbxassetid://10723355272",
    ["file-badge"] = "rbxassetid://10723355622",
    ["file-badge-2"] = "rbxassetid://10723355451",
    ["file-bar-chart"] = "rbxassetid://10723355887",
    ["file-bar-chart-2"] = "rbxassetid://10723355746",
    ["file-box"] = "rbxassetid://10723355989",
    ["file-check"] = "rbxassetid://10723356210",
    ["file-check-2"] = "rbxassetid://10723356100",
    ["file-clock"] = "rbxassetid://10723356329",
    ["file-code"] = "rbxassetid://10723356507",
    ["file-cog"] = "rbxassetid://10723356830",
    ["file-cog-2"] = "rbxassetid://10723356676",
    ["file-diff"] = "rbxassetid://10723357039",
    ["file-digit"] = "rbxassetid://10723357151",
    ["file-down"] = "rbxassetid://10723357322",
    ["file-edit"] = "rbxassetid://10723357495",
    ["file-heart"] = "rbxassetid://10723357637",
    ["file-image"] = "rbxassetid://10723357790",
    ["file-input"] = "rbxassetid://10723357933",
    ["file-json"] = "rbxassetid://10723364435",
    ["file-json-2"] = "rbxassetid://10723364361",
    ["file-key"] = "rbxassetid://10723364605",
    ["file-key-2"] = "rbxassetid://10723364515",
    ["file-line-chart"] = "rbxassetid://10723364725",
    ["file-lock"] = "rbxassetid://10723364957",
    ["file-lock-2"] = "rbxassetid://10723364861",
    ["file-minus"] = "rbxassetid://10723365254",
    ["file-minus-2"] = "rbxassetid://10723365086",
    ["file-output"] = "rbxassetid://10723365457",
    ["file-pie-chart"] = "rbxassetid://10723365598",
    ["file-plus"] = "rbxassetid://10723365877",
    ["file-plus-2"] = "rbxassetid://10723365766",
    ["file-question"] = "rbxassetid://10723365987",
    ["file-scan"] = "rbxassetid://10723366167",
    ["file-search"] = "rbxassetid://10723366550",
    ["file-search-2"] = "rbxassetid://10723366340",
    ["file-signature"] = "rbxassetid://10723366741",
    ["file-spreadsheet"] = "rbxassetid://10723366962",
    ["file-symlink"] = "rbxassetid://10723367098",
    ["file-terminal"] = "rbxassetid://10723367244",
    ["file-text"] = "rbxassetid://10723367380",
    ["file-type"] = "rbxassetid://10723367606",
    ["file-type-2"] = "rbxassetid://10723367509",
    ["file-up"] = "rbxassetid://10723367734",
    ["file-video"] = "rbxassetid://10723373884",
    ["file-video-2"] = "rbxassetid://10723367834",
    ["file-volume"] = "rbxassetid://10723374172",
    ["file-volume-2"] = "rbxassetid://10723374030",
    ["file-warning"] = "rbxassetid://10723374276",
    ["file-x"] = "rbxassetid://10723374544",
    ["file-x-2"] = "rbxassetid://10723374378",
    ["files"] = "rbxassetid://10723374759",
    ["film"] = "rbxassetid://10723374981",
    ["filter"] = "rbxassetid://10723375128",
    ["fingerprint"] = "rbxassetid://10723375250",
    ["flag"] = "rbxassetid://10723375890",
    ["flag-off"] = "rbxassetid://10723375443",
    ["flag-triangle-left"] = "rbxassetid://10723375608",
    ["flag-triangle-right"] = "rbxassetid://10723375727",
    ["flame"] = "rbxassetid://10723376114",
    ["flashlight"] = "rbxassetid://10723376471",
    ["flashlight-off"] = "rbxassetid://10723376365",
    ["flask-conical"] = "rbxassetid://10734883986",
    ["flask-round"] = "rbxassetid://10723376614",
    ["flip-horizontal"] = "rbxassetid://10723376884",
    ["flip-horizontal-2"] = "rbxassetid://10723376745",
    ["flip-vertical"] = "rbxassetid://10723377138",
    ["flip-vertical-2"] = "rbxassetid://10723377026",
    ["flower"] = "rbxassetid://10747830374",
    ["flower-2"] = "rbxassetid://10723377305",
    ["focus"] = "rbxassetid://10723377537",
    ["folder"] = "rbxassetid://10723387563",
    ["folder-archive"] = "rbxassetid://10723384478",
    ["folder-check"] = "rbxassetid://10723384605",
    ["folder-clock"] = "rbxassetid://10723384731",
    ["folder-closed"] = "rbxassetid://10723384893",
    ["folder-cog"] = "rbxassetid://10723385213",
    ["folder-cog-2"] = "rbxassetid://10723385036",
    ["folder-down"] = "rbxassetid://10723385338",
    ["folder-edit"] = "rbxassetid://10723385445",
    ["folder-heart"] = "rbxassetid://10723385545",
    ["folder-input"] = "rbxassetid://10723385721",
    ["folder-key"] = "rbxassetid://10723385848",
    ["folder-lock"] = "rbxassetid://10723386005",
    ["folder-minus"] = "rbxassetid://10723386127",
    ["folder-open"] = "rbxassetid://10723386277",
    ["folder-output"] = "rbxassetid://10723386386",
    ["folder-plus"] = "rbxassetid://10723386531",
    ["folder-search"] = "rbxassetid://10723386787",
    ["folder-search-2"] = "rbxassetid://10723386674",
    ["folder-symlink"] = "rbxassetid://10723386930",
    ["folder-tree"] = "rbxassetid://10723387085",
    ["folder-up"] = "rbxassetid://10723387265",
    ["folder-x"] = "rbxassetid://10723387448",
    ["folders"] = "rbxassetid://10723387721",
    ["form-input"] = "rbxassetid://10723387841",
    ["forward"] = "rbxassetid://10723388016",
    ["frame"] = "rbxassetid://10723394389",
    ["framer"] = "rbxassetid://10723394565",
    ["frown"] = "rbxassetid://10723394681",
    ["fuel"] = "rbxassetid://10723394846",
    ["function-square"] = "rbxassetid://10723395041",
    ["gamepad"] = "rbxassetid://10723395457",
    ["gamepad-2"] = "rbxassetid://10723395215",
    ["gauge"] = "rbxassetid://10723395708",
    ["gavel"] = "rbxassetid://10723395896",
    ["gem"] = "rbxassetid://10723396000",
    ["ghost"] = "rbxassetid://10723396107",
    ["gift"] = "rbxassetid://10723396402",
    ["gift-card"] = "rbxassetid://10723396225",
    ["git-branch"] = "rbxassetid://10723396676",
    ["git-branch-plus"] = "rbxassetid://10723396542",
    ["git-commit"] = "rbxassetid://10723396812",
    ["git-compare"] = "rbxassetid://10723396954",
    ["git-fork"] = "rbxassetid://10723397049",
    ["git-merge"] = "rbxassetid://10723397165",
    ["git-pull-request"] = "rbxassetid://10723397431",
    ["git-pull-request-closed"] = "rbxassetid://10723397268",
    ["git-pull-request-draft"] = "rbxassetid://10734884302",
    ["glass"] = "rbxassetid://10723397788",
    ["glass-2"] = "rbxassetid://10723397529",
    ["glass-water"] = "rbxassetid://10723397678",
    ["glasses"] = "rbxassetid://10723397895",
    ["globe"] = "rbxassetid://10723404337",
    ["globe-2"] = "rbxassetid://10723398002",
    ["grab"] = "rbxassetid://10723404472",
    ["graduation-cap"] = "rbxassetid://10723404691",
    ["grape"] = "rbxassetid://10723404822",
    ["grid"] = "rbxassetid://10723404936",
    ["grip-horizontal"] = "rbxassetid://10723405089",
    ["grip-vertical"] = "rbxassetid://10723405236",
    ["hammer"] = "rbxassetid://10723405360",
    ["hand"] = "rbxassetid://10723405649",
    ["hand-metal"] = "rbxassetid://10723405508",
    ["hard-drive"] = "rbxassetid://10723405749",
    ["hard-hat"] = "rbxassetid://10723405859",
    ["hash"] = "rbxassetid://10723405975",
    ["haze"] = "rbxassetid://10723406078",
    ["headphones"] = "rbxassetid://10723406165",
    ["heart"] = "rbxassetid://10723406885",
    ["heart-crack"] = "rbxassetid://10723406299",
    ["heart-handshake"] = "rbxassetid://10723406480",
    ["heart-off"] = "rbxassetid://10723406662",
    ["heart-pulse"] = "rbxassetid://10723406795",
    ["help-circle"] = "rbxassetid://10723406988",
    ["hexagon"] = "rbxassetid://10723407092",
    ["highlighter"] = "rbxassetid://10723407192",
    ["history"] = "rbxassetid://10723407335",
    ["home"] = "rbxassetid://10723407389",
    ["hourglass"] = "rbxassetid://10723407498",
    ["ice-cream"] = "rbxassetid://10723414308",
    ["image"] = "rbxassetid://10723415040",
    ["image-minus"] = "rbxassetid://10723414487",
    ["image-off"] = "rbxassetid://10723414677",
    ["image-plus"] = "rbxassetid://10723414827",
    ["import"] = "rbxassetid://10723415205",
    ["inbox"] = "rbxassetid://10723415335",
    ["indent"] = "rbxassetid://10723415494",
    ["indian-rupee"] = "rbxassetid://10723415642",
    ["infinity"] = "rbxassetid://10723415766",
    ["info"] = "rbxassetid://10723415903",
    ["inspect"] = "rbxassetid://10723416057",
    ["internet"] = "rbxassetid://12785195438",
    ["italic"] = "rbxassetid://10723416195",
    ["japanese-yen"] = "rbxassetid://10723416363",
    ["joystick"] = "rbxassetid://10723416527",
    ["key"] = "rbxassetid://10723416652",
    ["keyboard"] = "rbxassetid://10723416765",
    ["lamp"] = "rbxassetid://10723417513",
    ["lamp-ceiling"] = "rbxassetid://10723416922",
    ["lamp-desk"] = "rbxassetid://10723417016",
    ["lamp-floor"] = "rbxassetid://10723417131",
    ["lamp-wall-down"] = "rbxassetid://10723417240",
    ["lamp-wall-up"] = "rbxassetid://10723417356",
    ["landmark"] = "rbxassetid://10723417608",
    ["languages"] = "rbxassetid://10723417703",
    ["laptop"] = "rbxassetid://10723423881",
    ["laptop-2"] = "rbxassetid://10723417797",
    ["lasso"] = "rbxassetid://10723424235",
    ["lasso-select"] = "rbxassetid://10723424058",
    ["laugh"] = "rbxassetid://10723424372",
    ["layers"] = "rbxassetid://10723424505",
    ["layout"] = "rbxassetid://10723425376",
    ["layout-dashboard"] = "rbxassetid://10723424646",
    ["layout-grid"] = "rbxassetid://10723424838",
    ["layout-list"] = "rbxassetid://10723424963",
    ["layout-template"] = "rbxassetid://10723425187",
    ["leaf"] = "rbxassetid://10723425539",
    ["library"] = "rbxassetid://10723425615",
    ["life-buoy"] = "rbxassetid://10723425685",
    ["lightbulb"] = "rbxassetid://10723425852",
    ["lightbulb-off"] = "rbxassetid://10723425762",
    ["line-chart"] = "rbxassetid://10723426393",
    ["link"] = "rbxassetid://10723426722",
    ["link-2"] = "rbxassetid://10723426595",
    ["link-2-off"] = "rbxassetid://10723426513",
    ["list"] = "rbxassetid://10723433811",
    ["list-checks"] = "rbxassetid://10734884548",
    ["list-end"] = "rbxassetid://10723426886",
    ["list-minus"] = "rbxassetid://10723426986",
    ["list-music"] = "rbxassetid://10723427081",
    ["list-ordered"] = "rbxassetid://10723427199",
    ["list-plus"] = "rbxassetid://10723427334",
    ["list-start"] = "rbxassetid://10723427494",
    ["list-video"] = "rbxassetid://10723427619",
    ["list-x"] = "rbxassetid://10723433655",
    ["loader"] = "rbxassetid://10723434070",
    ["loader-2"] = "rbxassetid://10723433935",
    ["locate"] = "rbxassetid://10723434557",
    ["locate-fixed"] = "rbxassetid://10723434236",
    ["locate-off"] = "rbxassetid://10723434379",
    ["lock"] = "rbxassetid://10723434711",
    ["log-in"] = "rbxassetid://10723434830",
    ["log-out"] = "rbxassetid://10723434906",
    ["luggage"] = "rbxassetid://10723434993",
    ["magnet"] = "rbxassetid://10723435069",
    ["mail"] = "rbxassetid://10734885430",
    ["mail-check"] = "rbxassetid://10723435182",
    ["mail-minus"] = "rbxassetid://10723435261",
    ["mail-open"] = "rbxassetid://10723435342",
    ["mail-plus"] = "rbxassetid://10723435443",
    ["mail-question"] = "rbxassetid://10723435515",
    ["mail-search"] = "rbxassetid://10734884739",
    ["mail-warning"] = "rbxassetid://10734885015",
    ["mail-x"] = "rbxassetid://10734885247",
    ["mails"] = "rbxassetid://10734885614",
    ["map"] = "rbxassetid://10734886202",
    ["map-pin"] = "rbxassetid://10734886004",
    ["map-pin-off"] = "rbxassetid://10734885803",
    ["maximize"] = "rbxassetid://10734886735",
    ["maximize-2"] = "rbxassetid://10734886496",
    ["medal"] = "rbxassetid://10734887072",
    ["megaphone"] = "rbxassetid://10734887454",
    ["megaphone-off"] = "rbxassetid://10734887311",
    ["meh"] = "rbxassetid://10734887603",
    ["menu"] = "rbxassetid://10734887784",
    ["message-circle"] = "rbxassetid://10734888000",
    ["message-square"] = "rbxassetid://10734888228",
    ["mic"] = "rbxassetid://10734888864",
    ["mic-2"] = "rbxassetid://10734888430",
    ["mic-off"] = "rbxassetid://10734888646",
    ["microscope"] = "rbxassetid://10734889106",
    ["microwave"] = "rbxassetid://10734895076",
    ["milestone"] = "rbxassetid://10734895310",
    ["minimize"] = "rbxassetid://10734895698",
    ["minimize-2"] = "rbxassetid://10734895530",
    ["minus"] = "rbxassetid://10734896206",
    ["minus-circle"] = "rbxassetid://10734895856",
    ["minus-square"] = "rbxassetid://10734896029",
    ["monitor"] = "rbxassetid://10734896881",
    ["monitor-off"] = "rbxassetid://10734896360",
    ["monitor-speaker"] = "rbxassetid://10734896512",
    ["moon"] = "rbxassetid://10734897102",
    ["more-horizontal"] = "rbxassetid://10734897250",
    ["more-vertical"] = "rbxassetid://10734897387",
    ["mountain"] = "rbxassetid://10734897956",
    ["mountain-snow"] = "rbxassetid://10734897665",
    ["mouse"] = "rbxassetid://10734898592",
    ["mouse-2"] = "rbxassetid://10088146939",
    ["mouse-pointer"] = "rbxassetid://10734898476",
    ["mouse-pointer-2"] = "rbxassetid://10734898194",
    ["mouse-pointer-click"] = "rbxassetid://10734898355",
    ["move"] = "rbxassetid://10734900011",
    ["move-3d"] = "rbxassetid://10734898756",
    ["move-diagonal"] = "rbxassetid://10734899164",
    ["move-diagonal-2"] = "rbxassetid://10734898934",
    ["move-horizontal"] = "rbxassetid://10734899414",
    ["move-vertical"] = "rbxassetid://10734899821",
    ["music"] = "rbxassetid://10734905958",
    ["music-2"] = "rbxassetid://10734900215",
    ["music-3"] = "rbxassetid://10734905665",
    ["music-4"] = "rbxassetid://10734905823",
    ["navigation"] = "rbxassetid://10734906744",
    ["navigation-2"] = "rbxassetid://10734906332",
    ["navigation-2-off"] = "rbxassetid://10734906144",
    ["navigation-off"] = "rbxassetid://10734906580",
    ["network"] = "rbxassetid://10734906975",
    ["newspaper"] = "rbxassetid://10734907168",
    ["octagon"] = "rbxassetid://10734907361",
    ["option"] = "rbxassetid://10734907649",
    ["outdent"] = "rbxassetid://10734907933",
    ["package"] = "rbxassetid://10734909540",
    ["package-2"] = "rbxassetid://10734908151",
    ["package-check"] = "rbxassetid://10734908384",
    ["package-minus"] = "rbxassetid://10734908626",
    ["package-open"] = "rbxassetid://10734908793",
    ["package-plus"] = "rbxassetid://10734909016",
    ["package-search"] = "rbxassetid://10734909196",
    ["package-x"] = "rbxassetid://10734909375",
    ["paint-bucket"] = "rbxassetid://10734909847",
    ["paintbrush"] = "rbxassetid://10734910187",
    ["paintbrush-2"] = "rbxassetid://10734910030",
    ["palette"] = "rbxassetid://10734910430",
    ["palmtree"] = "rbxassetid://10734910680",
    ["paperclip"] = "rbxassetid://10734910927",
    ["party-popper"] = "rbxassetid://10734918735",
    ["pause"] = "rbxassetid://10734919336",
    ["pause-circle"] = "rbxassetid://10735024209",
    ["pause-octagon"] = "rbxassetid://10734919143",
    ["pen-tool"] = "rbxassetid://10734919503",
    ["pencil"] = "rbxassetid://10734919691",
    ["percent"] = "rbxassetid://10734919919",
    ["person-standing"] = "rbxassetid://10734920149",
    ["phone"] = "rbxassetid://10734921524",
    ["phone-call"] = "rbxassetid://10734920305",
    ["phone-forwarded"] = "rbxassetid://10734920508",
    ["phone-incoming"] = "rbxassetid://10734920694",
    ["phone-missed"] = "rbxassetid://10734920845",
    ["phone-off"] = "rbxassetid://10734921077",
    ["phone-outgoing"] = "rbxassetid://10734921288",
    ["pie-chart"] = "rbxassetid://10734921727",
    ["piggy-bank"] = "rbxassetid://10734921935",
    ["pin"] = "rbxassetid://10734922324",
    ["pin-off"] = "rbxassetid://10734922180",
    ["pipette"] = "rbxassetid://10734922497",
    ["pizza"] = "rbxassetid://10734922774",
    ["plane"] = "rbxassetid://10734922971",
    ["play"] = "rbxassetid://10734923549",
    ["play-circle"] = "rbxassetid://10734923214",
    ["plus"] = "rbxassetid://10734924532",
    ["plus-circle"] = "rbxassetid://10734923868",
    ["plus-square"] = "rbxassetid://10734924219",
    ["podcast"] = "rbxassetid://10734929553",
    ["pointer"] = "rbxassetid://10734929723",
    ["pound-sterling"] = "rbxassetid://10734929981",
    ["power"] = "rbxassetid://10734930466",
    ["power-off"] = "rbxassetid://10734930257",
    ["printer"] = "rbxassetid://10734930632",
    ["puzzle"] = "rbxassetid://10734930886",
    ["quote"] = "rbxassetid://10734931234",
    ["radio"] = "rbxassetid://10734931596",
    ["radio-receiver"] = "rbxassetid://10734931402",
    ["rectangle-horizontal"] = "rbxassetid://10734931777",
    ["rectangle-vertical"] = "rbxassetid://10734932081",
    ["recycle"] = "rbxassetid://10734932295",
    ["redo"] = "rbxassetid://10734932822",
    ["redo-2"] = "rbxassetid://10734932586",
    ["refresh-ccw"] = "rbxassetid://10734933056",
    ["refresh-cw"] = "rbxassetid://10734933222",
    ["refrigerator"] = "rbxassetid://10734933465",
    ["regex"] = "rbxassetid://10734933655",
    ["repeat"] = "rbxassetid://10734933966",
    ["repeat-1"] = "rbxassetid://10734933826",
    ["reply"] = "rbxassetid://10734934252",
    ["reply-all"] = "rbxassetid://10734934132",
    ["rewind"] = "rbxassetid://10734934347",
    ["rocket"] = "rbxassetid://10734934585",
    ["rocking-chair"] = "rbxassetid://10734939942",
    ["rotate-3d"] = "rbxassetid://10734940107",
    ["rotate-ccw"] = "rbxassetid://10734940376",
    ["rotate-cw"] = "rbxassetid://10734940654",
    ["rss"] = "rbxassetid://10734940825",
    ["ruler"] = "rbxassetid://10734941018",
    ["russian-ruble"] = "rbxassetid://10734941199",
    ["sailboat"] = "rbxassetid://10734941354",
    ["save"] = "rbxassetid://10734941499",
    ["scale"] = "rbxassetid://10734941912",
    ["scale-3d"] = "rbxassetid://10734941739",
    ["scaling"] = "rbxassetid://10734942072",
    ["scan"] = "rbxassetid://10734942565",
    ["scan-face"] = "rbxassetid://10734942198",
    ["scan-line"] = "rbxassetid://10734942351",
    ["scissors"] = "rbxassetid://10734942778",
    ["screen-share"] = "rbxassetid://10734943193",
    ["screen-share-off"] = "rbxassetid://10734942967",
    ["scroll"] = "rbxassetid://10734943448",
    ["search"] = "rbxassetid://10734943674",
    ["send"] = "rbxassetid://10734943902",
    ["separator-horizontal"] = "rbxassetid://10734944115",
    ["separator-vertical"] = "rbxassetid://10734944326",
    ["server"] = "rbxassetid://10734949856",
    ["server-cog"] = "rbxassetid://10734944444",
    ["server-crash"] = "rbxassetid://10734944554",
    ["server-off"] = "rbxassetid://10734944668",
    ["settings"] = "rbxassetid://10734950309",
    ["settings-2"] = "rbxassetid://10734950020",
    ["settings-3"] = "rbxassetid://14007344336",
    ["share"] = "rbxassetid://10734950813",
    ["share-2"] = "rbxassetid://10734950553",
    ["sheet"] = "rbxassetid://10734951038",
    ["shield"] = "rbxassetid://10734951847",
    ["shield-alert"] = "rbxassetid://10734951173",
    ["shield-check"] = "rbxassetid://10734951367",
    ["shield-close"] = "rbxassetid://10734951535",
    ["shield-off"] = "rbxassetid://10734951684",
    ["shirt"] = "rbxassetid://10734952036",
    ["shopping-bag"] = "rbxassetid://10734952273",
    ["shopping-cart"] = "rbxassetid://10734952479",
    ["shovel"] = "rbxassetid://10734952773",
    ["shower-head"] = "rbxassetid://10734952942",
    ["shrink"] = "rbxassetid://10734953073",
    ["shrub"] = "rbxassetid://10734953241",
    ["shuffle"] = "rbxassetid://10734953451",
    ["sidebar"] = "rbxassetid://10734954301",
    ["sidebar-close"] = "rbxassetid://10734953715",
    ["sidebar-open"] = "rbxassetid://10734954000",
    ["sigma"] = "rbxassetid://10734954538",
    ["signal"] = "rbxassetid://10734961133",
    ["signal-high"] = "rbxassetid://10734954807",
    ["signal-low"] = "rbxassetid://10734955080",
    ["signal-medium"] = "rbxassetid://10734955336",
    ["signal-zero"] = "rbxassetid://10734960878",
    ["siren"] = "rbxassetid://10734961284",
    ["skip-back"] = "rbxassetid://10734961526",
    ["skip-forward"] = "rbxassetid://10734961809",
    ["skull"] = "rbxassetid://10734962068",
    ["slack"] = "rbxassetid://10734962339",
    ["slash"] = "rbxassetid://10734962600",
    ["slice"] = "rbxassetid://10734963024",
    ["sliders"] = "rbxassetid://10734963400",
    ["sliders-horizontal"] = "rbxassetid://10734963191",
    ["smartphone"] = "rbxassetid://10734963940",
    ["smartphone-charging"] = "rbxassetid://10734963671",
    ["smile"] = "rbxassetid://10734964441",
    ["smile-plus"] = "rbxassetid://10734964188",
    ["snowflake"] = "rbxassetid://10734964600",
    ["sofa"] = "rbxassetid://10734964852",
    ["sort-asc"] = "rbxassetid://10734965115",
    ["sort-desc"] = "rbxassetid://10734965287",
    ["speaker"] = "rbxassetid://10734965419",
    ["sprout"] = "rbxassetid://10734965572",
    ["square"] = "rbxassetid://10734965702",
    ["star"] = "rbxassetid://10734966248",
    ["star-half"] = "rbxassetid://10734965897",
    ["star-off"] = "rbxassetid://10734966097",
    ["stethoscope"] = "rbxassetid://10734966384",
    ["sticker"] = "rbxassetid://10734972234",
    ["sticky-note"] = "rbxassetid://10734972463",
    ["stop-circle"] = "rbxassetid://10734972621",
    ["stretch-horizontal"] = "rbxassetid://10734972862",
    ["stretch-vertical"] = "rbxassetid://10734973130",
    ["strikethrough"] = "rbxassetid://10734973290",
    ["subscript"] = "rbxassetid://10734973457",
    ["sun"] = "rbxassetid://10734974297",
    ["sun-dim"] = "rbxassetid://10734973645",
    ["sun-medium"] = "rbxassetid://10734973778",
    ["sun-moon"] = "rbxassetid://10734973999",
    ["sun-snow"] = "rbxassetid://10734974130",
    ["sunrise"] = "rbxassetid://10734974522",
    ["sunset"] = "rbxassetid://10734974689",
    ["superscript"] = "rbxassetid://10734974850",
    ["swiss-franc"] = "rbxassetid://10734975024",
    ["switch-camera"] = "rbxassetid://10734975214",
    ["sword"] = "rbxassetid://10734975486",
    ["swords"] = "rbxassetid://10734975692",
    ["syringe"] = "rbxassetid://10734975932",
    ["table"] = "rbxassetid://10734976230",
    ["table-2"] = "rbxassetid://10734976097",
    ["tablet"] = "rbxassetid://10734976394",
    ["tag"] = "rbxassetid://10734976528",
    ["tags"] = "rbxassetid://10734976739",
    ["target"] = "rbxassetid://10734977012",
    ["tent"] = "rbxassetid://10734981750",
    ["terminal"] = "rbxassetid://10734982144",
    ["terminal-square"] = "rbxassetid://10734981995",
    ["text-cursor"] = "rbxassetid://10734982395",
    ["text-cursor-input"] = "rbxassetid://10734982297",
    ["thermometer"] = "rbxassetid://10734983134",
    ["thermometer-snowflake"] = "rbxassetid://10734982571",
    ["thermometer-sun"] = "rbxassetid://10734982771",
    ["thumbs-down"] = "rbxassetid://10734983359",
    ["thumbs-up"] = "rbxassetid://10734983629",
    ["ticket"] = "rbxassetid://10734983868",
    ["timer"] = "rbxassetid://10734984606",
    ["timer-off"] = "rbxassetid://10734984138",
    ["timer-reset"] = "rbxassetid://10734984355",
    ["toggle-left"] = "rbxassetid://10734984834",
    ["toggle-right"] = "rbxassetid://10734985040",
    ["tornado"] = "rbxassetid://10734985247",
    ["toy-brick"] = "rbxassetid://10747361919",
    ["train"] = "rbxassetid://10747362105",
    ["trash"] = "rbxassetid://10747362393",
    ["trash-2"] = "rbxassetid://10747362241",
    ["tree-deciduous"] = "rbxassetid://10747362534",
    ["tree-pine"] = "rbxassetid://10747362748",
    ["trees"] = "rbxassetid://10747363016",
    ["trending-down"] = "rbxassetid://10747363205",
    ["trending-up"] = "rbxassetid://10747363465",
    ["triangle"] = "rbxassetid://10747363621",
    ["trophy"] = "rbxassetid://10747363809",
    ["truck"] = "rbxassetid://10747364031",
    ["tv"] = "rbxassetid://10747364593",
    ["tv-2"] = "rbxassetid://10747364302",
    ["type"] = "rbxassetid://10747364761",
    ["umbrella"] = "rbxassetid://10747364971",
    ["underline"] = "rbxassetid://10747365191",
    ["undo"] = "rbxassetid://10747365484",
    ["undo-2"] = "rbxassetid://10747365359",
    ["unlink"] = "rbxassetid://10747365771",
    ["unlink-2"] = "rbxassetid://10747397871",
    ["unlock"] = "rbxassetid://10747366027",
    ["upload"] = "rbxassetid://10747366434",
    ["upload-cloud"] = "rbxassetid://10747366266",
    ["usb"] = "rbxassetid://10747366606",
    ["user"] = "rbxassetid://10747373176",
    ["user-check"] = "rbxassetid://10747371901",
    ["user-cog"] = "rbxassetid://10747372167",
    ["user-minus"] = "rbxassetid://10747372346",
    ["user-plus"] = "rbxassetid://10747372702",
    ["user-x"] = "rbxassetid://10747372992",
    ["users"] = "rbxassetid://10747373426",
    ["utensils"] = "rbxassetid://10747373821",
    ["utensils-crossed"] = "rbxassetid://10747373629",
    ["venetian-mask"] = "rbxassetid://10747374003",
    ["verified"] = "rbxassetid://10747374131",
    ["vibrate"] = "rbxassetid://10747374489",
    ["vibrate-off"] = "rbxassetid://10747374269",
    ["video"] = "rbxassetid://10747374938",
    ["video-off"] = "rbxassetid://10747374721",
    ["view"] = "rbxassetid://10747375132",
    ["voicemail"] = "rbxassetid://10747375281",
    ["volume"] = "rbxassetid://10747376008",
    ["volume-1"] = "rbxassetid://10747375450",
    ["volume-2"] = "rbxassetid://10747375679",
    ["volume-x"] = "rbxassetid://10747375880",
    ["wallet"] = "rbxassetid://10747376205",
    ["wand"] = "rbxassetid://10747376565",
    ["wand-2"] = "rbxassetid://10747376349",
    ["watch"] = "rbxassetid://10747376722",
    ["waves"] = "rbxassetid://10747376931",
    ["webcam"] = "rbxassetid://10747381992",
    ["wifi"] = "rbxassetid://10747382504",
    ["wifi-off"] = "rbxassetid://10747382268",
    ["wind"] = "rbxassetid://10747382750",
    ["wrap-text"] = "rbxassetid://10747383065",
    ["wrench"] = "rbxassetid://10747383470",
    ["x"] = "rbxassetid://10747384394",
    ["x-circle"] = "rbxassetid://10747383819",
    ["x-octagon"] = "rbxassetid://10747384037",
    ["x-square"] = "rbxassetid://10747384217",
    ["zoom-in"] = "rbxassetid://10747384552",
}

-- lucide.dev 新名稱 → 這份圖示集裡的舊名稱
local LUCIDE_ALIASES = {
    ["chart-bar"] = "bar-chart",
    ["chart-column"] = "bar-chart",
    ["chart-line"] = "line-chart",
    ["chart-pie"] = "pie-chart",
    ["circle-alert"] = "alert-circle",
    ["circle-check"] = "check-circle",
    ["circle-check-big"] = "check-circle",
    ["circle-help"] = "help-circle",
    ["circle-minus"] = "minus-circle",
    ["circle-play"] = "play-circle",
    ["circle-plus"] = "plus-circle",
    ["circle-x"] = "x-circle",
    ["ellipsis"] = "more-horizontal",
    ["ellipsis-vertical"] = "more-vertical",
    ["funnel"] = "filter",
    ["grid-3x3"] = "grid",
    ["house"] = "home",
    ["loader-circle"] = "loader-2",
    ["octagon-alert"] = "alert-octagon",
    ["pencil-line"] = "edit-3",
    ["square-check"] = "check-square",
    ["square-check-big"] = "check-square",
    ["square-pen"] = "edit",
    ["triangle-alert"] = "alert-triangle",
    ["wand-sparkles"] = "wand-2",
}

do
    local map = {}
    for name, image in pairs(LUCIDE_ICONS) do
        map["lucide-" .. name] = image
    end
    for name, target in pairs(LUCIDE_ALIASES) do
        map["lucide-" .. name] = LUCIDE_ICONS[target]
    end
    SenkoUI:AddIcons(map)
end

SenkoUI.LucideOnline = true
SenkoUI:AddIconResolver(function(name)
    if not SenkoUI.LucideOnline then
        return nil
    end
    local key = name:lower():gsub("^lucide%-", "")
    if not key:match("^[%w%-]+$") then
        return nil
    end
    local svg = string.format("https://api.iconify.design/lucide/%s.svg?color=white&width=96&height=96", key)
    local png = "https://images.weserv.nl/?url=" .. HttpService:UrlEncode(svg) .. "&output=png"
    return Assets.load(png, "Lucide")
end, "Lucide")

return SenkoUI
