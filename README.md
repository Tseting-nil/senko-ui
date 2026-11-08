# Senko UI · 插件式 Roblox 執行器 UI 庫

> **致謝**：Senko UI 的設計語言、主題配色數值與原神主題素材來自桌面專案 [**HanaBi-ui-Genshin**](https://github.com/xiaoyeuzixi/HanaBi-ui-Genshin)（作者 [xiaoyeuzixi](https://github.com/xiaoyeuzixi)，C++20 / Direct3D 11 / Dear ImGui）。程式碼為以 Roblox Luau 獨立重寫，沒有使用原版的 C++ 程式碼。詳見[致謝與授權](#致謝與授權)。

以 HanaBi-ui 設計語言為基礎的 Roblox UI 庫。

```lua
local SenkoUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Tseting-nil/senko-ui/main/SenkoUI.lua"))()
```

目前版本：**v1.0.0**

- 內建「基礎」主題：**曜石（黑）**、**雲母（白）**，以及極光、暮霞、深海、星雲、櫻霧 5 張原創壁紙主題
- **角色壁紙插件**：純 JSON（`plugins/<插件>/<角色>/character.json`），完整色票內嵌，不執行任何外部程式碼
- **插件管理**：主題頁以膠囊開關即時開啟 / 關閉插件，開啟時顯示下載進度，關閉時主題卡與分類立即移除
- **多語系**：English（預設）/ 繁體中文，主題卡、分類、插件管理即時切換
- **內建 Lucide 圖示**：分頁 `Icon = "settings"` 直接可用，不需另外載入
- **側欄底部文字（Footer）**：可固定、隱藏或跟隨主題
- 壁紙（漂移、視差、角色呼吸、主題粒子）、元素徽記、側欄滑動指示器、主題專屬視窗按鈕造型
- 開場動畫、主題庫頁（分類篩選、字號 100%–125%、啟動模式、壁紙強度、設定檔）
- 拖曳、縮放、最小化、最大化、通知、手機懸浮按鈕、小螢幕自動縮放

---

## 目錄

1. [設計語言來源](#設計語言來源)
2. [檔案結構](#檔案結構)
3. [快速開始](#快速開始)
4. [執行器需求](#執行器需求)
5. [API：函式庫](#api函式庫)
6. [API：視窗 Window](#api視窗-window)
7. [API：分頁與區塊](#api分頁與區塊)
8. [API：控件](#api控件)
9. [主題與壁紙](#主題與壁紙)
10. [插件](#插件)（完整說明：[PLUGINS.md](PLUGINS.md)）
11. [多語系](#多語系)
12. [設定檔與本機檔案](#設定檔與本機檔案)
13. [與 HanaBi-ui 的差別](#與-hanabi-ui-的差別)
14. [更新紀錄](#更新紀錄)
15. [致謝與授權](#致謝與授權)

---

## 設計語言來源

| 項目 | 內容 |
|---|---|
| 名稱 | HanaBi UI（設計語言來源） |
| 作者 | [xiaoyeuzixi](https://github.com/xiaoyeuzixi) |
| 倉庫 | https://github.com/xiaoyeuzixi/HanaBi-ui-Genshin |
| 技術 | C++20、Win32 API、Direct3D 11 / DXGI、HLSL、Dear ImGui、stb_image |
| 平台 | Windows 10 / 11 x64 桌面程式 |
| 內容 | 七套角色主題 + 白、黑兩套基礎外觀，角色專屬開場、動態壁紙、主題庫 |

Senko UI 的配色數值取自原版各角色的 `*_ui.cpp` 與 `ui/theme.cpp`，主題文案、元素分類與互動規範參考原版 `docs/UI设计要求.md`。原神插件的壁紙來自原版 `assets/tex/`，或由原版資源轉檔而來。

---

## 檔案結構

倉庫 [Tseting-nil/senko-ui](https://github.com/Tseting-nil/senko-ui)（自行 fork 時保持同樣的相對路徑即可）：

```
senko-ui/
├─ SenkoUI.lua                UI 庫本體（基礎主題、內建 Lucide 圖示、JSON 插件載入器）
├─ Example.lua                範例腳本（涵蓋所有控件）
├─ LocalTest.lua              本機測試載入器（127.0.0.1:8000/SenkoUI/）
├─ README.md                  本文件
├─ PLUGINS.md                 插件開發說明
├─ plugins/                   角色壁紙插件（純 JSON）
│  ├─ index.json              插件清單
│  ├─ Genshin/                原神：Ganyu、Yae、Yoimiya、Nahida、Furina、Faruzan、Zhongli
│  │  └─ <角色>/character.json + 圖片
│  ├─ Endfield/               終末地：Rossi、Si
│  └─ Template/               插件範本：Ember（只有色票與粒子，沒有圖片）
├─ extensions/
│  └─ Template.lua            Lua 擴充範本（粒子、自訂控件、事件）
└─ assets/
   └─ wallpapers/             基礎主題的原創壁紙
```

---

## 快速開始

```lua
local SenkoUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Tseting-nil/senko-ui/main/SenkoUI.lua"))()

-- 讀取官方角色壁紙插件清單（必須在 CreateWindow 之前）
-- 玩家在「主題 → 插件管理」開啟插件後即當場下載，下次執行自動載入
SenkoUI:LoadPlugins()

local Window = SenkoUI:CreateWindow({
    Title = "Senko UI",
    Theme = "Ganyu",              -- 沒開啟原神插件時自動退回曜石
    Footer = "Senko UI v1.0",     -- 側欄底部固定文字；false = 隱藏；省略 = 跟隨主題
    ToggleKey = Enum.KeyCode.LeftAlt,
})

local Main = Window:AddTab({ Title = "Main", Subtitle = "常用功能", Icon = "home" })
local Sec = Main:AddSection({ Title = "Combat", Caption = "戰鬥" })

Sec:AddToggle({
    Title = "啟用",
    Description = "說明文字",
    Default = true,
    Flag = "Enabled",
    Callback = function(value)
        print(value)
    end,
})

Window:AddThemeTab()   -- 內建主題頁（主題庫、壁紙、插件管理、外觀、啟動、設定檔）
```

完整範例請看 `Example.lua`。

---

## 執行器需求

| 函式 | 用途 | 缺少時 |
|---|---|---|
| `game:HttpGet` | 載入庫、插件清單、角色 JSON、壁紙 | 無法使用 |
| `writefile` / `readfile` / `isfile` | 偏好設定、設定檔、圖片與 JSON 快取 | 不儲存設定，不顯示壁紙 |
| `makefolder` / `isfolder` | 建立 `SenkoUI/` 資料夾 | 自動略過 |
| `listfiles` | 列出設定檔、計算快取大小 | 清單為空 |
| `delfile` | 清除圖片快取 | 無法在介面清除 |
| `getcustomasset`（或 `getsynasset`） | 把下載的圖片轉成 `rbxasset://` | 不顯示壁紙，改用主題漸層 |
| `gethui` / `syn.protect_gui` | 隱藏 GUI | 依序退回 `CoreGui`、`PlayerGui` |
| `cloneref` | 取得服務 | 直接使用原服務 |

> Roblox 的 `ImageLabel.Image` 不能直接填 http 網址，所以壁紙一定要經過 `HttpGet → writefile → getcustomasset`。圖片只下載一次，之後從 `SenkoUI/assets/` 讀取。

---

## API：函式庫

| 成員 | 說明 |
|---|---|
| `SenkoUI:CreateWindow(opts)` | 建立視窗，回傳 `Window` |
| `SenkoUI.Flags` | `{ [Flag] = 值 }`，所有設了 `Flag` 的控件目前的值 |
| `SenkoUI.Options` | `{ [Flag] = 控件物件 }`，可呼叫 `:Set()` |
| `SenkoUI.Themes` | 主題鍵名清單 `{ "Obsidian", "Mica", ... }`（含已開啟插件的主題） |
| `SenkoUI:GetThemes()` | 回傳 `{ Key, Name, English, Groups, Plugin }` 清單（`Name` 依目前語言） |
| `SenkoUI:GetGroups()` | 主題庫分類清單 `{ Key, Label, Order, Plugin }`（第一筆為「全部」） |
| `SenkoUI:LoadPlugins(source)` | 讀取角色壁紙插件清單，見[插件](#插件) |
| `SenkoUI:EnablePlugin(name, onProgress)` / `DisablePlugin(name)` | 當場開啟（下載並加入主題）/ 關閉（立即移除主題） |
| `SenkoUI:GetPluginCatalog()` | 插件清單 `{ Name, Label, Characters, CharacterList, Enabled, Loaded }` |
| `SenkoUI:GetCacheSize(name)` / `ClearCache(name)` | 圖片快取大小 / 清除（`nil` = 未分類） |
| `SenkoUI.Language` / `SetLanguage(code)` / `GetLanguages()` / `AddLocale(code, dict)` / `T(key, ...)` | 多語系，見[多語系](#多語系) |
| `SenkoUI:AddTheme(def)` / `AddGroup(def)` / `AddParticle(name, style)` / `AddElement(name, fn)` | 腳本直接擴充，見 [PLUGINS.md](PLUGINS.md) |
| `SenkoUI:Use(plugin)` / `LoadPlugin(source)` / `LoadPluginFolder(folder)` | 載入 Lua 擴充（進階），見 [PLUGINS.md](PLUGINS.md#lua-擴充進階) |
| `SenkoUI.Kit` | 自訂控件用的工具集 |
| `SenkoUI:AddIcons(map)` / `AddIconResolver(fn)` / `GetIcon(name)` / `SenkoUI.Icons` | 圖示表：名稱 → `rbxassetid://`；Lucide 821 個內建 |
| `SenkoUI.LucideOnline` | `false` 時關閉 Lucide 線上補抓（只用內建表） |
| `SenkoUI.Animations` | 全域動畫開關 |
| `SenkoUI.Folder` | 本機資料夾名稱，預設 `"SenkoUI"` |
| `SenkoUI.PluginIndex` | 官方插件清單網址 |
| `SenkoUI.AssetSources` | 圖片來源表 `{ 名稱 = 網址或 workspace 資料夾 }` |
| `SenkoUI.Assets.load(url, folder)` | 下載並快取 PNG / JPG，回傳 `rbxasset://`（會等待下載） |
| `SenkoUI.Version` | `"1.0.0"` |

### `CreateWindow` 參數

| 參數 | 型別 | 預設 | 說明 |
|---|---|---|---|
| `Title` | string | `"Senko UI"` | 側欄標題 |
| `Subtitle` | string | 主題名 · 標籤 | 標題下方小字 |
| `Footer` | string / false | 跟隨主題 | 側欄底部文字：字串 = 固定（更換主題不變）；`false` = 隱藏菱形與文字；省略 = 顯示主題的 region |
| `Theme` | string | `"Obsidian"` | 初始主題；插件主題需該插件已開啟 |
| `ForceTheme` | bool | `false` | `true` 時忽略上次儲存的主題與啟動模式 |
| `Size` | Vector2 / UDim2 | `640 × 430` | 視窗大小 |
| `MinSize` | Vector2 | `500 × 330` | 拖曳縮放的最小尺寸 |
| `ToggleKey` | KeyCode / string | `LeftAlt` | 顯示 / 隱藏介面；主題頁可改並存入 `settings.json` |
| `Intro` | bool | `true` | 開場動畫 |
| `FlatRender` | bool | `true` | 平面渲染：視窗內容直接原生渲染，避免 CanvasGroup 每幀重新合成導致捲動掉 FPS；縮小/還原仍用 CanvasGroup 淡入淡出。可用 `Window:SetFlatRender(bool)` 切換 |
| `FontPercent` | number | `112` | 字號百分比（100–125） |
| `SaveSettings` | bool | `true` | 是否讀寫 `SenkoUI/settings.json` |
| `MobileButton` | bool | `true` | 觸控裝置顯示懸浮按鈕 |
| `GuiName` | string | `"SenkoUI"` | ScreenGui 名稱 |
| `Unique` | bool | `true` | 重新執行時刪除同名舊介面 |
| `OnThemeChanged` | function(key) | – | 切換主題時呼叫 |
| `Wallpaper` | bool | `true` | 顯示壁紙 |
| `WallpaperStrength` | number | `0.82` | 壁紙強度 0–1 |
| `WallpaperMotion` | bool | `true` | 漂移、視差、角色呼吸 |
| `Particles` | bool | `true` | 主題粒子 |
| `AssetSources` | table | – | 覆寫圖片來源 `{ 名稱 = 網址 }` |
| `Wallpapers` | table | – | 自訂壁紙，見[自訂壁紙](#自訂壁紙) |

---

## API：視窗 Window

| 方法 | 說明 |
|---|---|
| `Window:AddTab(opts)` | 新增分頁。`opts`：`Title`、`Subtitle`、`Icon`（[Lucide](https://lucide.dev/icons/) 名稱如 `"settings"`、`rbxassetid://`、數字 ID 或單一文字）；也可直接傳字串 |
| `Window:AddThemeTab(opts)` | 新增內建主題頁。`opts`：`Title`、`Subtitle`、`Icon`、`Configs`（`false` 時隱藏設定檔區塊） |
| `Window:SelectTab(tab 或索引)` | 切換分頁 |
| `Window:SetTheme(key)` / `GetTheme()` | 切換主題（鍵名、中文名、英文名、別名皆可）/ 目前主題鍵名 |
| `Window:SetFooter(text)` | 側欄底部文字：字串 = 固定；`false` = 隱藏；`nil` = 恢復跟隨主題 |
| `Window:GetFooter()` | 目前左下角顯示的文字（隱藏時為 `nil`） |
| `Window:SetFontScale(n)` | 字號倍率 1.00–1.25 |
| `Window:Notify(opts)` | 通知。`opts`：`Title`、`Content`、`Duration`（秒，預設 4）、`Callback`；也可直接傳字串 |
| `Window:Minimize()` / `Restore()` / `Toggle()` | 最小化、還原、切換 |
| `Window:ToggleMaximize()` | 最大化 / 還原大小 |
| `Window:SetToggleKey(keycode)` | 更改切換鍵，寫入 `settings.json` |
| `Window:SaveConfig(name)` / `LoadConfig(name)` / `ListConfigs()` | 設定檔（`SenkoUI/configs/<name>.json`） |
| `Window:SetWallpaperEnabled(bool)` / `SetWallpaperStrength(0~1)` | 壁紙開關與強度 |
| `Window:SetWallpaper(theme, bgUrl, charUrl)` | 執行時更換某主題的壁紙 |
| `Window:Destroy()` | 淡出並移除介面、斷開所有連線 |

---

## API：分頁與區塊

```lua
local Tab = Window:AddTab({ Title = "Visual", Subtitle = "ESP 顯示項目", Icon = "eye" })

-- 區塊 = 一張卡片。Title 顯示為大寫英文，Caption 顯示在右側
local Section = Tab:AddSection({ Title = "ESP", Caption = "顯示項目" })
Section:AddToggle({ ... })

-- 不建立區塊也可以：直接在分頁上加控件，會自動放進一張預設卡片
Tab:AddButton({ ... })
```

`Tab` 與 `Section` 都有以下所有 `Add*` 方法。

---

## API：控件

### 共用

所有帶值的控件回傳物件，具有：

| 成員 | 說明 |
|---|---|
| `.Value` | 目前的值 |
| `:Set(value, silent)` | 設定值；`silent = true` 時不觸發 Callback |
| `:Get()` | 取得值 |
| `:OnChanged(fn)` | 額外的變更監聽 |
| `:SetVisible(bool)` | 顯示 / 隱藏 |
| `:Destroy()` | 移除（同時清除 Flag） |

設了 `Flag` 的控件會同步寫入 `SenkoUI.Flags[Flag]`，並可被設定檔儲存、載入。

### AddToggle 開關

```lua
local t = Section:AddToggle({
    Title = "自動拾取",
    Description = "可省略",
    Default = false,
    Flag = "AutoPick",
    FireOnInit = false,      -- Default 為 true 時，是否在建立時就呼叫一次 Callback
    Callback = function(on) end,
})
t:Set(true)
```

### AddSlider 滑桿

```lua
Section:AddSlider({
    Title = "視野範圍",
    Min = 1, Max = 30, Default = 12,
    Decimals = 1,            -- 小數位數（別名 Rounding）
    Increment = 0.5,         -- 步進，可省略
    Unit = "°",              -- 單位（別名 Suffix）
    Flag = "Fov",
    Callback = function(v) end,
})
```

右側數值可以直接點擊輸入。

### AddSegment 分段選擇

```lua
local seg = Section:AddSegment({
    Title = "鎖定部位",      -- 可省略
    Options = { "頭部", "頸部", "胸口" },
    Default = "頭部",
    Flag = "Bone",
    Callback = function(v) end,
})
seg:Set(2)                   -- 可用索引或值
```

### AddDropdown 下拉選單

```lua
local dd = Section:AddDropdown({
    Title = "隊伍過濾",
    Options = { "全部", "僅敵人", "僅隊友" },
    Default = "僅敵人",
    Multi = false,           -- true 時 Value 為陣列
    Placeholder = "請選擇…",
    MaxVisible = 6,          -- 展開後最多顯示幾列
    Flag = "Team",
    Callback = function(v) end,
})
dd:Refresh({ "A", "B", "C" }, keepValue)   -- 更新選項
```

`Options` 也可以傳函式，每次展開時才呼叫，用來顯示會變動的清單（例如玩家名單）：

```lua
local dd = Section:AddDropdown({
    Title = "鎖定敵人",
    Options = function()     -- 必須回傳陣列
        local names = {}
        for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
            table.insert(names, plr.Name)
        end
        return names
    end,
    Callback = function(v) end,
})
dd:Refresh(nil, true)        -- 不用展開，立即重新呼叫函式（true = 保留目前選取）
dd:Refresh(otherFunction, true)   -- 換成另一個函式；傳陣列則改回固定清單
```

- 要傳函式本身：寫 `Options = GetAllplayer`，不要加括號。`GetAllplayer()` 會在建立時呼叫一次，之後就是固定清單。
- 函式出錯或沒有回傳陣列時，會在主控台警告，並保留上一次的清單。
- 已選取的值不在新清單中時不會被清除，也不會觸發 `Callback`。

### AddChips 標籤選擇

```lua
Section:AddChips({
    Title = "顯示內容",
    Options = { "方框", "骨架", "名稱", "血量" },
    Default = { "方框", "名稱" },
    Multi = true,            -- false 時為單選，Value 為字串
    Flag = "EspItems",
    Callback = function(list) end,
})
```

### AddKeybind 按鍵錄入

```lua
Section:AddKeybind({
    Title = "自瞄按鍵",
    Description = "可省略",
    Default = Enum.UserInputType.MouseButton2,   -- KeyCode、UserInputType 或名稱字串
    Mode = "Hold",           -- "Press" 按下觸發 / "Toggle" 切換 / "Hold" 按住
    Flag = "AimKey",
    Callback = function(state) end,         -- Press 傳按鍵；Toggle / Hold 傳 true / false
    ChangedCallback = function(key) end,    -- 綁定的按鍵被修改時
})
```

點擊按鍵帽開始錄入。**Esc** 取消，**Backspace / Delete** 清除。支援鍵盤與滑鼠右鍵、中鍵。輸入框聚焦或在聊天中時不會觸發。

### AddInput 輸入框

```lua
Section:AddInput({
    Title = "WalkSpeed",     -- 可省略
    Default = "",
    Placeholder = "16",
    Numeric = true,          -- 只接受數字，Value 為 number
    Finished = true,         -- true：失去焦點才觸發；false：每次輸入都觸發
    ClearOnFocus = false,
    Flag = "Speed",
    Callback = function(v) end,
})
```

### AddButton 按鈕

```lua
local b = Section:AddButton({
    Title = "傳送",
    Style = "Primary",       -- 主色漸層按鈕，可省略
    Callback = function() end,
})
b:SetTitle("新文字")
```

### AddProgress 進度條 / 環形儀表

```lua
local hp = Section:AddProgress({
    Title = "生命值",
    Description = "可省略",
    Min = 0, Max = 100, Default = 80,
    Decimals = 0,
    Unit = "HP",
    Style = "Bar",           -- "Bar" 長條（預設）/ "Ring" 環形儀表
    Tone = "good",           -- 省略為主題漸層；"accent" / "good" / "warn" 為單色
})
hp:Set(55)                   -- 以補間動畫更新
```

### AddStats 統計區塊

```lua
local stats = Section:AddStats({
    Items = {
        { Key = "FPS", Title = "FPS", Value = "60" },
        { Key = "Ping", Title = "延遲", Value = "32 ms", Tone = "good" },
        { Key = "Mem", Title = "記憶體", Value = "812 MB", Tone = "warn" },
    },
})
stats:Set("FPS", "58", "warn")   -- Key, 新數值, 顏色（可省略）
```

### AddColorPicker 色彩選擇器

```lua
local cp = Section:AddColorPicker({
    Title = "方框顏色",
    Default = Color3.fromRGB(143, 230, 246),   -- Color3、"#RRGGBB" 或 {R, G, B}
    Flag = "EspColor",
    Callback = function(color) end,
})
cp:Set("#FF8844")
```

點擊右側色塊展開調色盤（飽和度 / 明度方塊 + 色相條），十六進位欄位可直接輸入。設定檔以 `"RRGGBB"` 字串儲存。

### AddSlots 槽位選擇

```lua
local slots = Section:AddSlots({
    Title = "配置",
    Count = 6,               -- 槽位數；省略時依 Labels 數量
    Labels = { "戰鬥", "採集", "探索" },
    Columns = 3,
    Default = 1,
    AllowDeselect = false,   -- true 時再點一次可取消選擇（Value 為 nil）
    Flag = "Slot",
    Callback = function(index) end,
})
slots:Set(2)
slots:GetLabel()
```

### AddLabel / AddParagraph / AddDivider

```lua
local lbl = Section:AddLabel("支援 <b>RichText</b>")
lbl:Set("新文字")

local para = Section:AddParagraph({ Title = "關於", Content = "多行說明文字……" })
para:Set("新標題", "新內容")

Section:AddDivider()
```

### AddConsole 控制台

```lua
local console = Section:AddConsole({
    Title = "日誌",
    Value = "",
    Placeholder = "尚無輸出",
    Height = 150,
    ReadOnly = true,
    AutoScroll = true,
    LineNumbers = true,
    LinesFormat = "%d.",
    MaxLines = 300,           -- 0 / false 表示不限
    TextWrapped = false,
    RichText = true,
    Border = true,
    Callback = function(text) end,
})

console:AppendText("新訊息", 123)
console:SetValue("全部取代")
console:GetValue()
console:Clear()
console:SetReadOnly(false)
console:SetLineNumbers(false)
```

控制台不會寫入設定檔（沒有 `Flag`）。

---

## 主題與壁紙

### 主題清單

**內建（核心 `SenkoUI.lua`）**

| 鍵名 | 名稱 | 短句 | 視窗按鈕 / 壁紙 / 粒子 |
|---|---|---|---|
| `Obsidian` | 曜石 Obsidian（預設） | 靜夜 | 圓形 |
| `Mica` | 雲母 Mica | 晨光 | 圓形 |
| `Aurora` | 極光 Aurora | 夜空下的綠 | 菱形 · `aurora.jpg` · 細雪 |
| `Dusk` | 暮霞 Dusk | 落日餘暉 | 圓形 · `dusk.jpg` · 火星 |
| `Abyss` | 深海 Abyss | 光落入海 | 圓形 · `abyss.jpg` · 水泡 |
| `Nebula` | 星雲 Nebula | 遠方的塵埃 | 菱形 · `nebula.jpg` · 微光 |
| `Sakura` | 櫻霧 Sakura Mist | 春霧裡的花 | 圓形 · `sakura.jpg` · 花瓣（亮色） |

基礎壁紙是本專案以程式繪製的原創圖（`assets/wallpapers/`），選到該主題時才下載，快取在 `SenkoUI/assets/Basic/`。

**原神插件（`plugins/Genshin/`）**：甘雨 `Ganyu`、八重神子 `Yae`、宵宮 `Yoimiya`、納西妲 `Nahida`、芙寧娜 `Furina`、珐露珊 `Faruzan`、鍾離 `Zhongli`

**終末地插件（`plugins/Endfield/`）**：洛西 `Rossi`、祀 `Si`（壁紙來源：Steam Wallpaper Engine · 作者：Gong Wong）

**插件範本（`plugins/Template/`）**：餘燼 `Ember`（無圖片，示範色票與粒子）

### 主題卡

主題庫的每張卡片兩行文字依目前語言顯示（分類由上方篩選列區分）：

| 行 | English（預設） | 繁體中文 |
|---|---|---|
| 第一行 | `name_en`（無則 `name`），後接「\| creator」 | `name`，後接「\| creator」 |
| 第二行 | `description_en`（無則 `description`） | `description` |

### 主題庫篩選列

上方按鈕為「全部」+「基礎」+ 已開啟插件的分類。插件關閉時該分類按鈕與主題卡立即移除，開啟時即時加入。分類名稱可自訂：

```lua
SenkoUI:AddGroup({ Key = "Basic", Label = "預設" })
SenkoUI:AddGroup({ Key = "All", Label = { en = "Everything", ["zh-TW"] = "所有" } })
```

### 啟動模式

在主題頁的「啟動選擇」設定，存於 `settings.json`：

- **跟隨目前**：下次啟動使用最後選擇的主題
- **固定主題**：記住切換當下的主題，之後固定使用
- **隨機主題**：每次從有壁紙的主題中隨機挑一個

腳本若需固定主題，請在 `CreateWindow` 加上 `ForceTheme = true`。

### 自訂壁紙

```lua
SenkoUI:CreateWindow({
    Wallpapers = {
        Aurora = { Background = "https://.../my-bg.jpg", Dim = 0.5 },
        Sakura = false,  -- 關閉這個主題的壁紙
    },
})
```

| 欄位 | 說明 |
|---|---|
| `Background` | 背景圖（網址或 workspace 路徑，PNG / JPG，建議 16:9） |
| `Character` | 角色層（透明 PNG，與背景同尺寸對齊） |
| `Dim` | 遮罩最低濃度 0–1 |
| `Particle` | `glow` / `petal` / `ember` / `bubble` / `dust` / `snow` / `spark` |

### 壁紙解析度與壓縮

**建議規格：1920 × 1080（16:9）JPG，單張約 150–750 KB。** 角色層用同尺寸的透明 PNG。

Roblox 會把 `getcustomasset` 載入的圖片縮到最長邊 **1024 px**（例如 16:9 壁紙在遊戲內是 1024 × 576），這是引擎限制，所有電腦與手機都一樣；畫質設定較低的裝置可能再降一級。所以 4K 原圖在遊戲裡和 1080p 看起來相同，只會讓第一次下載更久（原神 6 張背景從 4K 壓到 1080p，約 11.6 MB → 2.4 MB）。

| 情況 | 結果 |
|---|---|
| 正方形預覽圖（例如 Wallpaper Engine 的 `preview.jpg`） | 被拉伸成 16:9，看起來模糊 → 請改用原始影片 / 圖片 |
| 4K 原圖 | 遊戲內與 1080p 相同，但下載大 2–4 倍 → 縮成 1080p |
| 1080p JPG（`-q:v 2`） | 畫質與大小最平衡 |

用 ffmpeg 處理：

```bash
# 4K 圖片縮成 1080p（Lanczos 縮放，高品質 JPG）
ffmpeg -i ganyu-bg-4k.jpg -vf "scale=1920:1080:flags=lanczos" -q:v 2 ganyu-bg-1080.jpg

# 從動態壁紙影片擷取一張完整解析度的畫面（-ss = 秒數，避開開頭的淡入）
ffmpeg -ss 4 -i rossi.mp4 -frames:v 1 -q:v 2 rossi-1080.jpg

# 影片是 4K 時，擷取同時縮成 1080p
ffmpeg -ss 13.3 -i si.mp4 -frames:v 1 -vf "scale=1920:1080:flags=lanczos" -q:v 2 si-1080.jpg

# 查看圖片解析度
ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 rossi-1080.jpg
```

> **更新圖片時一定要改檔名**（例如 `rossi.jpg` → `rossi-1080.jpg`，並同步修改 `character.json` 的 `images`）。快取檔名由網址產生，Roblox 也以路徑快取材質；沿用舊檔名的話，已下載過的玩家會一直看到舊圖。

---

## 插件

插件**只限角色壁紙主題包**，每個插件是 `plugins/` 下的一個資料夾，每位角色一個子資料夾，內含 `character.json`（完整色票）與圖片。核心只解析 JSON，不執行任何外部程式碼。

```
plugins/
├─ index.json
└─ Genshin/
   ├─ Ganyu/
   │  ├─ character.json
   │  └─ ganyu-bg-4k.jpg
   └─ Yae/
      ├─ character.json
      ├─ yae-bg-4k.jpg
      └─ yae-character.png
```

```lua
SenkoUI:LoadPlugins()                       -- 官方清單 SenkoUI.PluginIndex
SenkoUI:LoadPlugins("https://raw.githubusercontent.com/你的帳號/你的倉庫/main/plugins/index.json")
SenkoUI:LoadPlugins({ 清單1, 清單2 })        -- 多份清單（網址或 workspace 路徑）
local Window = SenkoUI:CreateWindow({ ... })
Window:AddThemeTab()                        -- 主題頁出現「插件管理」
```

主題頁「插件管理」：

- 每列顯示**插件名稱**與自動計算的角色數（`7 characters & wallpapers` / `7 位角色與壁紙`），右側為膠囊開關（開啟：橘色 `#FFA352`；關閉：深灰 `#473B3A`）。
- **開啟**：依序下載各角色的 `character.json` 與圖片，下方進度條顯示 `Downloading 5/14`；完成後主題卡與分類按鈕即時加入，並記住下次自動載入。
- **關閉**：立即移除該插件的主題卡與分類；正在使用的主題會退回啟動主題（或曜石）。
- **清除圖片快取**：各插件的圖片與 JSON 快取在 `SenkoUI/assets/<插件名稱>/`，可分別清除（需要 `delfile`）。
- **離線**：讀不到清單或角色 JSON 時使用上次成功的快取。

角色 JSON 規格、`index.json` 格式與 Lua 擴充見 **[PLUGINS.md](PLUGINS.md)**。

---

## 多語系

- 預設語言為 **English（`en`）**，另內建 **繁體中文（`zh-TW`）**。
- 在「主題 → 外觀 → 語言」或 `SenkoUI:SetLanguage("zh-TW")` 切換，存於 `settings.json`。
- 切換後**即時更新**：主題卡文字、分類按鈕、插件管理、側欄副標與底部文字；其他已建立的控件文字在重新執行腳本後套用。
- `SenkoUI:AddLocale("ja", { _name = "日本語", ["section.themes"] = "テーマ" })` 可新增語言或補字。

---

## 設定檔與本機檔案

```
SenkoUI/
├─ settings.json        主題、啟動模式、字號、動畫、壁紙、語言
├─ configs/<名稱>.json  Window:SaveConfig 儲存的控件值
├─ plugins.json         插件管理的開關狀態
├─ plugin-index/        插件清單的離線快取
├─ plugins/             SenkoUI:LoadPluginFolder() 預設載入的 Lua 擴充資料夾
├─ wallpapers/          自己放的本機壁紙（不會被清除快取刪掉）
└─ assets/              下載快取
   ├─ Basic/            基礎主題壁紙
   ├─ Genshin/          各插件的圖片與角色 JSON
   └─ Lucide/           線上補抓的圖示
```

---

## 與 HanaBi-ui 的差別

| 項目 | HanaBi-ui（C++ / D3D11） | Senko UI（Roblox Luau） |
|---|---|---|
| 平台 | Windows 桌面 exe | Roblox 執行器 `loadstring` |
| 繪製 | Dear ImGui 即時繪製 + HLSL shader | Roblox Instance（Frame、UIStroke、UIGradient、CanvasGroup） |
| 主題配色 | 9 套 Skin | 數值取自原版，透明度針對 Roblox 重新校正；角色主題改由 JSON 插件提供 |
| 主題切換 | 分段混色 | 全部顏色同步補間 0.45 秒 |
| 角色壁紙 | 4K 貼圖，原生渲染器播放 | 同一批圖，經 `getcustomasset` 載入 |
| 壁紙動態 | shader 驅動的眨眼、擺動、漣漪 | 背景漂移、滑鼠視差、角色呼吸與主題粒子 |
| 八重、宵宮角色 | `.hbc` 網格動畫 | 取第一幀靜止姿勢，光柵化成透明 PNG |
| 鍾離壁紙 | `.hbw` 12 層分層壁紙 | 合成成單張 JPG |
| 開場動畫 | 每個角色專屬演出，6.20 秒 | 共用徽記展開 + 光環，約 2 秒，可跳過 |
| 視窗按鈕 | 每個角色獨立造型 | 菱形、圓形、方形三種造型 |
| 設定儲存 | `%LOCALAPPDATA%\HanaBi\settings.ini` | 執行器工作區 `SenkoUI/settings.json` |
| 功能頁 | 演示頁 + 無臉模特部位選擇 | 不內建功能頁，由你用 API 自行組裝 |
| 新增功能 | – | Flags / 設定檔、通知、按鍵模式、手機懸浮按鈕、自動縮放、JSON 插件、Footer API、即時語言切換 |
| 語言 | 簡體中文 | English / 繁體中文 |
| 字型 | Source Sans 3 + 內嵌中文字型 | Roblox Gotham（中文由系統字型補字） |

---

## 更新紀錄

### v1.0.0 初版發布
- 以 **Senko UI** 名稱正式發布：核心 `SenkoUI.lua`、物件 `SenkoUI`、本機資料夾 `SenkoUI/`
- 角色壁紙插件改為純 JSON 資料夾結構（`plugins/<插件>/<角色>/character.json`），完整色票內嵌，不執行外部程式碼
- 插件管理：膠囊開關、自動計算角色數、下載進度條，開啟 / 關閉即時增刪主題卡與分類
- Lucide 圖示改為核心內建
- 多語系預設 English，主題卡、分類、插件管理即時切換
- 新增 `CreateWindow({ Footer })`、`Window:SetFooter` / `GetFooter`

---

## 致謝與授權

- **設計語言來源**：[xiaoyeuzixi / HanaBi-ui-Genshin](https://github.com/xiaoyeuzixi/HanaBi-ui-Genshin)。主題配色數值、設計語言、主題文案與原神壁紙素材皆來自原版，感謝原作者。原版另有 QQ 交流群：835775657。
- **原版使用的第三方元件**：Dear ImGui（MIT）、stb_image（Public Domain / MIT）、Source Sans 3（SIL OFL 1.1）。本庫沒有使用這些元件的程式碼。
- **原版倉庫目前沒有附 LICENSE 檔**。公開散布原神插件的圖片前，建議先取得原作者同意。
- **圖示**：[Lucide](https://lucide.dev/)（ISC）；線上補抓使用 Iconify 與 images.weserv.nl。
- **終末地壁紙**：Steam Wallpaper Engine · 作者：Gong Wong，版權屬於原作者。
- 《原神》角色、名稱與相關美術版權屬於 **HoYoverse**；《明日方舟：終末地》屬於 **鷹角網絡（Hypergryph）**。本專案為非官方的同人作品，與上述公司及 Roblox 無關。
