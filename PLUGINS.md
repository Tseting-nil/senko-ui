# Senko UI 插件開發說明

> 適用 Senko UI **v1.0.0**。
> **插件 = 角色壁紙主題包**：純 JSON 與圖片，核心只解析資料、不執行任何外部程式碼。
> Lucide 圖示是 UI 庫內建的基礎設施，不屬於插件，也不會出現在插件管理。
> 需要自訂粒子、控件或事件時，請用 [Lua 擴充（進階）](#lua-擴充進階)。

---

## 目錄

1. [資料夾結構](#資料夾結構)
2. [插件清單 index.json](#插件清單-indexjson)
3. [角色 character.json](#角色-characterjson)
4. [色票 Palette](#色票-palette)
5. [載入流程](#載入流程)
6. [API 參考](#api-參考)
7. [新增一個插件](#新增一個插件)
8. [Lua 擴充（進階）](#lua-擴充進階)
9. [注意事項與除錯](#注意事項與除錯)

---

## 資料夾結構

```
plugins/
├─ index.json                  全域插件清單（只列角色壁紙插件）
├─ Genshin/                    第一層：插件名稱
│  ├─ Ganyu/                   第二層：角色名稱（英文或代號）
│  │  ├─ character.json        第三層：單一角色的 JSON
│  │  └─ ganyu-bg-4k.jpg       　　　　＋ 圖片
│  └─ Yae/
│     ├─ character.json
│     ├─ yae-bg-4k.jpg         images[1] = 背景
│     └─ yae-character.png     images[2] = 角色層（透明 PNG）
├─ Endfield/
│  ├─ Rossi/
│  └─ Si/
└─ Template/
   └─ Ember/                   範本：只有 character.json，沒有圖片
```

每個角色資料夾完全自給自足：增減角色只要新增 / 刪除資料夾，並更新 `index.json` 的 `characters`。

---

## 插件清單 index.json

```json
{
    "plugins": [
        {
            "name": "Genshin",
            "label": "原神",
            "label_en": "Genshin",
            "characters": ["Ganyu", "Yae", "Yoimiya", "Nahida", "Furina", "Faruzan", "Zhongli"],
            "default": false
        }
    ]
}
```

| 欄位 | 必填 | 說明 |
|---|---|---|
| `name` | ✓ | 插件資料夾名稱，也是分類鍵名與快取資料夾名稱 |
| `characters` | ✓ | 角色資料夾清單；插件管理以此自動計算「%d 位角色與壁紙」 |
| `label` | – | 繁體中文名稱（插件管理標題、分類按鈕）；省略時用 `name` |
| `label_en` | – | 英文名稱；省略時用 `name` |
| `default` | – | 玩家還沒選過時是否載入，預設 `false`（會下載大量圖片，建議維持 `false`） |

角色 JSON 的網址 = `index.json` 所在資料夾 + `<name>/<角色>/character.json`，圖片同理。所以 fork 後只要保持相對路徑，換成自己倉庫的 `index.json` 網址即可。

---

## 角色 character.json

允許 `//` 與 `/* */` 註解，以及註解造成的結尾逗號（核心解析前會先移除）。

```jsonc
{
    // === 必填 ===
    "source": "plugins/Genshin/Faruzan/character.json",  // 自身路徑或 raw 網址（標記用）
    "creator": "Senko UI",                               // 創作者 / 壁紙來源：主題卡名稱後顯示為「名稱  |  creator」
    "description": "風起，翻開新章 · 青金機關與風閱古卷",   // 主題卡名稱下方的說明（繁體中文）

    // === 選填 ===
    "source_url": "https://example.com/original-work",   // 壁紙原始作品頁面（只供查證來源，介面不顯示）
    "description_en": "The wind rises, a new chapter opens", // 英文模式的說明

    // === 主題屬性 ===
    "key": "Faruzan",          // 唯一鍵名（SetTheme / Theme 用）；省略時用資料夾名稱
    "name": "珐露珊",           // 第一行（繁體中文）
    "name_en": "Faruzan",       // 第一行（English）
    "tag": "ANEMO",             // 側欄副標「名稱 · 標籤」
    "glyph": "風",              // 徽記中央的字
    "shape": "square",          // 徽記與視窗按鈕造型：square / circle / diamond
    "dim": 0.52,                // 壁紙遮罩濃度 0–1（越高文字越清楚）
    "particle": "dust",         // 粒子：glow / petal / ember / bubble / dust / snow / spark
    "constellation": "S I N U S   U N I C O R N I S", // 側欄小字與開場動畫（選填）
    "region": "須彌 · 教令院",   // 側欄底部文字（選填；省略時顯示插件名稱）
    "region_en": "Sumeru",      // 英文模式的側欄底部文字（選填）

    // === 完整色票（必填）===
    "palette": {
        "win0": "#143C3D", "win1": "#29574E",
        "winStroke": "#D3DCC5", "hairline": "#E9D4A1",
        "sidebar": "#123C43", "card": "#1A484E", "cardStroke": "#B9D8C8",
        "text": "#F7F6E9", "text2": "#D6E7DD", "text3": "#ABC8C1",
        "accent": "#B1F0D6", "accent2": "#E6CB94",
        "segTrack": "#082C34", "segPill": "#B4E7D6", "field": "#DAEEDC", "fieldStroke": "#C6D8BD",
        "good": "#B7E4C7", "warn": "#E8CF9F", "toast": "#102E36",
        "radius": 12, "cardRadius": 9
    },

    // === 圖片（同資料夾的檔名，或完整網址）===
    "images": [
        "faruzan-bg.jpg"         // 第一張 = 背景；第二張（選填）= 角色層透明 PNG
    ]
}
```

| 欄位 | 必填 | 說明 |
|---|---|---|
| `source` / `creator` / `description` | ✓ | 身分與說明 |
| `source_url` | – | 壁紙原始作品頁面，方便查證來源；使用第三方素材時建議填寫 |
| `palette` | ✓ | 色票，缺少時整個角色略過 |
| `description_en` / `name_en` / `region_en` | – | 英文模式使用，缺少時退回中文欄位 |
| `key` | – | 主題鍵名，不可與其他主題重複 |
| `images` | – | 沒有圖片時（如 `Template/Ember`）只顯示漸層與粒子 |

---

## 色票 Palette

色值寫 `"#RRGGBB"`。以 `T` 結尾的是透明度（0 = 不透明），沒寫的欄位沿用內建骨架。

| 欄位 | 用途 |
|---|---|
| `win0` / `win1` | 視窗底色漸層（左上 → 右下），主題卡與壁紙遮罩也用這兩色 |
| `winStroke` / `winStrokeT` | 視窗外框、未選中主題卡的外框 |
| `sidebar` / `sidebarT` | 側欄底色 |
| `hairline` / `hairlineT` | 側欄與頂列的細分隔線 |
| `divider` / `dividerT` | 區塊內分隔線 |
| `card` / `cardT`、`cardStroke` / `cardStrokeT` | 區塊卡片底色與外框 |
| `trackOff` / `trackOffT` | 開關、滑桿、進度條未填滿的軌道 |
| `knob`、`knobStroke` / `knobStrokeT` | 開關與滑桿的圓鈕 |
| `segTrack` / `segTrackT`、`segPill` / `segPillT` | 分段選擇的底槽 / 選中膠囊；`segPill` 也是側欄選中指示器 |
| `field` / `fieldT`、`fieldStroke` / `fieldStrokeT` | 輸入框、下拉、按鍵帽、篩選按鈕等欄位 |
| `text` / `text2` / `text3` | 主要 / 次要 / 提示文字 |
| `accent` / `accent2` | 強調色 / 第二強調色 |
| `good` / `warn` | 正向 / 警告色 |
| `toast` / `toastT` | 通知卡與手機懸浮按鈕底色 |
| `radius` / `cardRadius` | 視窗 / 卡片圓角（px，數字） |

---

## 載入流程

```
SenkoUI:LoadPlugins()
  ├─ 1. 讀取 plugins/index.json → 插件與角色清單（失敗時用 SenkoUI/plugin-index/ 快取）
  ├─ 2. 讀取 SenkoUI/plugins.json（玩家開關狀態，優先於 default）
  └─ 3. 已開啟的插件：讀取各角色 character.json → 色票轉 Color3 → 註冊主題
         → 在背景補下載快取裡沒有的圖片，不會擋住介面啟動

主題頁「插件管理」開關
  ├─ 開啟：下載各角色 character.json → 下載 images → 註冊主題
  │        → 即時加入分類按鈕與主題卡，進度條顯示「下載中 n/N」
  └─ 關閉：立即移除主題卡、分類與壁紙設定；正在使用的主題退回啟動主題 / 曜石

主題頁「檢查插件更新」按鈕（SenkoUI:UpdatePlugins）
  ├─ 重新讀取 index.json 與已開啟插件的 character.json，下載缺少的圖片
  └─ 只更新有變動的角色：內容不同 → 替換；清單新增 → 加入；清單移除 → 刪除
     正在使用的主題有變動時會當場重新套用，沒有變動的主題不受影響
```

快取位置：角色 JSON 與圖片都在 `SenkoUI/assets/<插件名稱>/`，可在插件管理分別清除。

### 上傳更新後，使用者什麼時候拿到？

- **重新執行腳本或按「檢查插件更新」：** 取得新參數、新角色與新圖片，不必關閉再開啟插件。腳本執行中不會自動檢查。
- **GitHub 延遲：** raw 檔案有約 5 分鐘快取（`max-age=300`），剛推送時可能還讀到舊檔。
- **同檔名換圖不會更新：** 圖片以網址為快取鍵，所以換圖時要**改檔名**並更新 `images`。沿用舊檔名的話，使用者要先清除快取才看得到新圖。
- **新插件：** 按鈕能載入新插件的主題（已開啟時），但插件管理要重新執行腳本才會出現它的開關。

---

## API 參考

| 函式 | 說明 |
|---|---|
| `SenkoUI:LoadPlugins(source)` | `source`：清單網址或 workspace 路徑（字串）、多份清單（表），省略時讀取 `SenkoUI.PluginIndex`；回傳這次已載入的插件名稱。需在 `CreateWindow` 之前 |
| `SenkoUI:EnablePlugin(name, onProgress)` | 當場開啟：`onProgress(done, total)`；回傳 `ok, { characters, images, failed }` |
| `SenkoUI:DisablePlugin(name)` | 當場關閉並移除主題，回傳移除的主題數 |
| `SenkoUI:UpdatePlugins(onProgress)` | 當場檢查更新：`onProgress(done, total)`；回傳 `ok, { updated, added, removed, images, failed, newPlugins }`。需要先呼叫過 `LoadPlugins`；正在檢查時會回傳 `false` |
| `SenkoUI:SetPluginEnabled(name, bool)` | 只記錄下次執行是否載入 |
| `SenkoUI:GetPluginCatalog()` | `{ Name, Label = { ["zh-TW"], en }, Characters, CharacterList, Enabled, Loaded }` |
| `SenkoUI:GetCacheSize(name)` / `ClearCache(name)` | 快取大小（位元組、檔案數）/ 清除；`nil` = 未分類 |
| `SenkoUI.PluginIndex` | 官方清單網址 |

腳本也可以不透過插件，直接註冊主題（`Name` / `Motto` / `Region` 可寫成語系表）：

```lua
SenkoUI:AddTheme({
    Key = "Rose",
    Name = { ["zh-TW"] = "玫瑰", en = "Rose" },
    Motto = { ["zh-TW"] = "花開的午後", en = "An afternoon in bloom" },
    Group = "Mine",
    GroupLabel = { ["zh-TW"] = "我的主題", en = "Mine" },
    Base = "Mica",
    Palette = { accent = "#E0457B", accent2 = "#F59AB8" },
    Background = "SenkoUI/wallpapers/rose.jpg",   -- 網址或 workspace 路徑
    Particle = "petal",
})
```

---

## 新增一個插件

1. 在 `plugins/` 建立資料夾，例如 `plugins/MyPack/`。
2. 每位角色一個子資料夾，放入 `character.json` 與圖片（可複製 `plugins/Template/Ember/character.json` 開始）。圖片建議 1920 × 1080 JPG，壓縮方式與 ffmpeg 指令見 [README · 壁紙解析度與壓縮](README.md#壁紙解析度與壓縮)。
3. 在 `plugins/index.json` 加一筆：

   ```json
   { "name": "MyPack", "label": "我的主題包", "label_en": "My Pack", "characters": ["Alice", "Bob"], "default": false }
   ```

4. 推上 GitHub，所有呼叫 `SenkoUI:LoadPlugins()` 的腳本都會在插件管理看到它。

本機測試：用 `LocalTest.lua` 從 `http://127.0.0.1:8000/SenkoUI/` 載入，或把整個 `plugins/` 複製到執行器 workspace 後 `SenkoUI:LoadPlugins("SenkoUI/plugins/index.json")`。

---

## Lua 擴充（進階）

JSON 插件無法做到的事（自訂粒子、控件、事件）可以寫成 Lua 擴充，以 `SenkoUI:LoadPlugin` 載入。Lua 擴充**不會出現在插件管理**，也無法當場卸載。範本：[`extensions/Template.lua`](extensions/Template.lua)。

```lua
SenkoUI:LoadPlugin("https://raw.githubusercontent.com/Tseting-nil/senko-ui/main/extensions/Template.lua")
SenkoUI:LoadPluginFolder()   -- 載入 <執行器>\workspace\SenkoUI\plugins\ 內所有 .lua
SenkoUI:Use({ Name = "Mine", Setup = function(api) ... end })
```

```lua
return {
    Name = "MyExtension",
    Version = "1.0.0",
    Author = "你的名字",
    Requires = "1.0.0",                -- 最低 Senko UI 版本
    Locales = {                        -- api:T("鍵")；退回順序：目前語言 → en → zh-TW → 鍵名
        en = { hello = "Hello, %s" },
        ["zh-TW"] = { hello = "你好，%s" },
    },
    Setup = function(api, options)
        api:AddParticle("firefly", { Dir = -1, Speed = 0.015, Size = { 2, 4 }, Sway = 0.05, Shape = "dot", Count = 12 })
        api:Log(api:T("hello", "Senko"))
        return { Ping = function() return "pong" end }   -- → SenkoUI.Plugins.MyExtension.Exports
    end,
}
```

### api 參考

| 成員 | 說明 |
|---|---|
| `api:AddTheme(def)` / `api:AddGroup(def)` | 註冊主題 / 分類（自動標記來源） |
| `api:AddParticle(name, style)` | 粒子：`Dir`（-1 上 / 1 下）、`Speed`、`Size = { min, max }`、`Sway`、`Shape`（`dot` / `petal` / `diamond` / `ring`）、`Count` |
| `api:AddIcons(map)` / `api:AddIconResolver(fn)` | 註冊圖示 / 找不到時的解析器（可 yield） |
| `api:AddElement(name, builder, settings)` | 新控件：`builder(section, opts, Kit)` 回傳控件物件，之後 `Section:名稱(opts)` 可用；覆寫內建需 `{ Override = true }` |
| `api:On(event, fn)` | `WindowCreated(win, opts)`、`WindowDestroyed(win)`、`ThemeChanged(win, key)`、`ThemeTabBuilt(win, tab)` |
| `api:LoadImage(url)` | 下載圖片到 `SenkoUI/assets/<擴充名稱>/` |
| `api:SetAssetSource(name, base, force)` | 設定 `{ 來源名稱, 檔名 }` 的圖片來源 |
| `api:T(key, ...)` / `api:AddLocale(lang, dict)` / `api.Language` | 擴充自己的字典 |
| `api:Log(...)` / `api:Warn(...)` | 帶 `[SenkoUI:名稱]` 前綴 |
| `api.Name` / `api.Options` / `api.Version` / `api.SenkoUI` / `api.Kit` | 名稱、選項、版本、函式庫本體、工具集 |

### 自訂控件範例

```lua
api:AddElement("AddInfo", function(section, opts, Kit)
    local win = section.Window
    local row = Kit.Row(section, 30)
    local el = Kit.Element("Info", row, opts)
    Kit.TitleBlock(win, row, opts, 160)
    local value = win:Label(row, tostring(opts.Value or ""), 12.5, "accent", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(160, 20),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    function el:Set(v)
        self.Value = tostring(v)
        value.Text = self.Value
    end
    el:Set(opts.Value or "")
    return el
end)
```

### Kit 工具

| 成員 | 說明 |
|---|---|
| `Kit.New(class, props)` / `Kit.Corner` / `Kit.Pad` | 建立 Instance、圓角、內距 |
| `Kit.Tween` / `Kit.TweenThen` / `Kit.SetProps` | 補間（關閉動畫時直接套用） |
| `Kit.SafeCall(fn, ...)` / `Kit.Rgb(0xRRGGBB)` | 安全呼叫 / 轉 `Color3` |
| `Kit.LoadImage(url)` / `Kit.Icon(name)` | 下載圖片 / 圖示名稱 → 圖片位址 |
| `Kit.FS` | `readJson` / `writeJson` / `ensureFolder` / `list` / `available` |
| `Kit.Fonts` / `Kit.Services` | 字型 / 常用服務 |
| `Kit.Row` / `Kit.Element` / `Kit.Register` / `Kit.UpdateFlag` / `Kit.TitleBlock` / `Kit.FieldStyle` / `Kit.Emblem` | 自訂控件骨架 |

視窗上的主題綁定方法（`win = section.Window`）：`win.palette`、`win:Bind(obj, prop, token)`、`win:BindBackground(obj, token)`、`win:AddStroke(obj, token, thickness)`、`win:AddCorner(obj, token)`、`win:Label(parent, text, size, tone, props)`、`win:ScaleText(obj, size)`、`win:OnTheme(fn)`、`win:Track(connection)`。

---

## 注意事項與除錯

- **載入順序**：`SenkoUI.lua` → `LoadPlugins` / Lua 擴充 → `CreateWindow` → `AddThemeTab`。插件管理的開關會在建立視窗後當場加入 / 移除主題。
- **主題消失**：上次存的主題來自這次沒開啟的插件時，改用腳本指定的 `Theme`，再退回曜石。
- **錯誤訊息**：以 `[SenkoUI]` 或 `[SenkoUI:名稱]` 開頭，按 F9 查看；JSON 讀取失敗會列出網址。
- **檢查載入結果**：

  ```lua
  for _, p in ipairs(SenkoUI:GetPluginCatalog()) do print(p.Name, p.Characters, p.Enabled, p.Loaded) end
  for _, t in ipairs(SenkoUI:GetThemes()) do print(t.Key, t.Name, table.concat(t.Groups, ","), t.Plugin) end
  for _, g in ipairs(SenkoUI:GetGroups()) do print(g.Key, g.Label) end
  ```
