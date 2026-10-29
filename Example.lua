--[[
    Senko UI 範例腳本
    展示所有控件、通知、設定檔、主題頁與插件。
    直接執行即可；fork 後把網址換成你自己倉庫的 raw 連結。
]]

local SenkoUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Tseting-nil/senko-ui/main/SenkoUI.lua"))()

-- 角色壁紙插件：讀取倉庫的插件清單 plugins/index.json，玩家在「主題 → 插件管理」開啟即當場下載
-- （不用改腳本；Lucide 圖示已內建，不需另外載入）
SenkoUI:LoadPlugins("https://raw.githubusercontent.com/Tseting-nil/senko-ui/main/plugins/index.json")
-- 不帶參數 SenkoUI:LoadPlugins() 也會讀同一份官方清單

local Window = SenkoUI:CreateWindow({
    Title = "Senko UI",
    Theme = "Ganyu",            -- 沒開啟原神插件時自動退回曜石
    Footer = "Senko UI v1.0",   -- 側欄底部固定文字；false = 隱藏，不填 = 跟隨主題
    ToggleKey = Enum.KeyCode.LeftAlt,
})

-- ============================================================
-- 主要：開關、滑桿、分段、按鈕
-- ============================================================
local Main = Window:AddTab({ Title = "主要", Subtitle = "常用功能", Icon = "home" })

local Combat = Main:AddSection({ Title = "Combat", Caption = "戰鬥" })

Combat:AddToggle({
    Title = "自動攻擊",
    Description = "靠近目標時自動出手",
    Default = false,
    Flag = "AutoAttack",
    Callback = function(on)
        print("AutoAttack", on)
    end,
})

Combat:AddSlider({
    Title = "攻擊範圍",
    Min = 1, Max = 30, Default = 12,
    Decimals = 1, Increment = 0.5, Unit = "m",
    Flag = "Range",
    Callback = function(v)
        print("Range", v)
    end,
})

Combat:AddSegment({
    Title = "鎖定部位",
    Options = { "頭部", "頸部", "胸口" },
    Default = "頭部",
    Flag = "Bone",
})

Combat:AddKeybind({
    Title = "觸發按鍵",
    Default = Enum.KeyCode.E,
    Mode = "Hold",
    Flag = "AttackKey",
    Callback = function(state)
        print("按鍵狀態", state)
    end,
})

local Actions = Main:AddSection({ Title = "Actions", Caption = "操作" })

Actions:AddButton({
    Title = "傳送通知",
    Style = "Primary",
    Callback = function()
        Window:Notify({ Title = "Senko UI", Content = "這是一則通知", Duration = 3 })
    end,
})

-- ============================================================
-- 視覺：下拉、標籤、輸入框、色彩選擇器
-- ============================================================
local Visual = Window:AddTab({ Title = "視覺", Subtitle = "顯示項目", Icon = "eye" })

local Esp = Visual:AddSection({ Title = "ESP", Caption = "顯示項目" })

Esp:AddDropdown({
    Title = "隊伍過濾",
    Options = { "全部", "僅敵人", "僅隊友" },
    Default = "僅敵人",
    Flag = "Team",
})

Esp:AddChips({
    Title = "顯示內容",
    Options = { "方框", "骨架", "名稱", "血量" },
    Default = { "方框", "名稱" },
    Multi = true,
    Flag = "EspItems",
})

Esp:AddColorPicker({
    Title = "方框顏色",
    Description = "點擊色塊展開調色盤，也可直接輸入 #RRGGBB",
    Default = Color3.fromRGB(143, 230, 246),
    Flag = "EspColor",
    Callback = function(color)
        print("顏色", color)
    end,
})

Esp:AddInput({
    Title = "最大距離",
    Placeholder = "500",
    Numeric = true,
    Flag = "EspDistance",
})

-- ============================================================
-- 狀態：進度、環形儀表、統計區塊、Slots
-- ============================================================
local Status = Window:AddTab({ Title = "狀態", Subtitle = "即時資訊", Icon = "activity" })

local Overview = Status:AddSection({ Title = "Overview", Caption = "總覽" })

local stats = Overview:AddStats({
    Items = {
        { Key = "FPS", Title = "FPS", Value = "60" },
        { Key = "Ping", Title = "延遲", Value = "32 ms", Tone = "good" },
        { Key = "Mem", Title = "記憶體", Value = "812 MB", Tone = "warn" },
    },
})

local hp = Overview:AddProgress({
    Title = "生命值",
    Description = "Tone 可選 accent / good / warn",
    Min = 0, Max = 100, Default = 80, Unit = "HP",
    Tone = "good",
})

local gauge = Overview:AddProgress({
    Title = "任務進度",
    Style = "Ring",
    Min = 0, Max = 10, Default = 4,
    Description = "完成 10 個目標",
})

local Logs = Status:AddSection({ Title = "Console", Caption = "控制台" })

local console = Logs:AddConsole({
    ReadOnly = true,
    AutoScroll = true,
    LineNumbers = true,
    RichText = true,
    MaxLines = 50,
    Placeholder = "尚無輸出",
})
task.spawn(function()
    while console.Row.Parent do
        local t = DateTime.now():FormatLocalTime("HH:mm:ss", "zh-tw")
        console:AppendText("<font color='#8aa4ff'>[" .. t .. "]</font>", "隨機值", math.random(1, 100))
        task.wait(1)
    end
end)
Logs:AddButton({
    Title = "清空控制台",
    Callback = function()
        console:Clear()
    end,
})

local Loadout = Status:AddSection({ Title = "Loadout", Caption = "配置槽位" })

Loadout:AddSlots({
    Title = "配置",
    Labels = { "戰鬥", "採集", "探索", "農場", "BOSS", "待機" },
    Default = 1,
    Columns = 3,
    Flag = "Slot",
    Callback = function(index)
        Window:Notify({ Title = "已切換配置", Content = "槽位 " .. index, Duration = 2 })
    end,
})

-- 即時更新範例
task.spawn(function()
    local n = 0
    while Window and Window.Gui and Window.Gui.Parent do
        n = (n % 10) + 1
        gauge:Set(n)
        local life = math.random(10, 100)
        hp:Set(life)
        stats:Set("FPS", tostring(math.random(55, 60)))
        task.wait(2)
    end
end)

-- ============================================================
-- 設定：設定檔與內建主題頁
-- ============================================================
local Config = Window:AddTab({ Title = "設定", Subtitle = "設定檔", Icon = "settings" })
local Cfg = Config:AddSection({ Title = "Config", Caption = "設定檔" })

Cfg:AddButton({
    Title = "儲存設定",
    Callback = function()
        Window:SaveConfig("default")
    end,
})
Cfg:AddButton({
    Title = "載入設定",
    Callback = function()
        Window:LoadConfig("default")
    end,
})
Cfg:AddParagraph({
    Title = "提示",
    Content = "所有設了 <b>Flag</b> 的控件都會一起儲存。目前共 " .. #Window:ListConfigs() .. " 份設定檔。",
})

Window:AddThemeTab()

-- 語言（預設 English）：主題卡、分類與插件管理即時切換
-- SenkoUI:SetLanguage("zh-TW")

Window:Notify({ Title = "Senko UI", Content = "已載入完成，按 LeftAlt 隱藏 / 顯示（主題頁可改）", Duration = 4 })
