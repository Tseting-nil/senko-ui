--[[
    Senko UI · Lua 擴充範本  v1.0.0
    ------------------------------------------------------------
    角色 / 壁紙主題請改用純 JSON 插件（plugins/<插件>/<角色>/character.json，見 PLUGINS.md）。
    這個範本示範 JSON 做不到的進階擴充，複製改名後就能開始寫：
      1. Locales      多語系字典（English / 繁中，可再加其他語言），用 api:T("鍵") 取字
      2. AddParticle  自訂壁紙粒子（character.json 的 "particle" 可直接使用）
      3. AddElement   新增控件：Section:AddInfo（左標題、右數值的唯讀資訊列）
      4. On           監聽事件：WindowCreated / ThemeChanged / ThemeTabBuilt
      5. 回傳 Exports 給腳本呼叫
    完整 API 見 PLUGINS.md

    用法（需在 CreateWindow 之前）：
      local ext = SenkoUI:LoadPlugin("https://raw.githubusercontent.com/Tseting-nil/senko-ui/main/extensions/Template.lua")
      ext.Exports.Hello()
]]

return {
    Name = "Template",
    Version = "1.0.0",
    Author = "Senko UI",
    Requires = "1.0.0",

    -- 1. 多語系：鍵名自訂；目前語言找不到時依序退回 English、繁體中文
    Locales = {
        ["zh-TW"] = {
            ["section.caption"] = "插件範本",
            ["info.version"] = "插件版本",
            ["info.language"] = "目前語言",
            ["info.theme"] = "目前主題",
            welcome = "插件範本已載入，主題頁最下方有示範區塊",
            changed = "主題切換為 %s",
        },
        en = {
            ["section.caption"] = "Plugin template",
            ["info.version"] = "Plugin version",
            ["info.language"] = "Language",
            ["info.theme"] = "Current theme",
            welcome = "Plugin template loaded – see the demo section at the bottom of the theme tab",
            changed = "Theme changed to %s",
        },
    },
    -- 說明與來源（字串或語系表），可由 SenkoUI:GetPlugins() 取得
    Description = { ["zh-TW"] = "Lua 擴充範本：多語系、粒子、控件與事件", en = "Lua extension template: i18n, particle, control and events" },
    Credit = { ["zh-TW"] = "作者：Senko UI", en = "By: Senko UI" },

    Setup = function(api, options)
        -- 2. 粒子：緩慢飄動的螢火（主題的 Particle = "firefly" 即可使用）
        api:AddParticle("firefly", { Dir = -1, Speed = 0.015, Size = { 2, 4 }, Sway = 0.05, Shape = "dot", Count = 12 })

        -- 3. 控件：Section:AddInfo({ Title, Description, Value })，唯讀、不存設定檔
        api:AddElement("AddInfo", function(section, opts, Kit)
            local win = section.Window
            local hasDesc = opts.Description and opts.Description ~= ""
            local row = Kit.Row(section, hasDesc and 42 or 30)
            local el = Kit.Element("Info", row, opts)
            Kit.TitleBlock(win, row, opts, 160)
            local value = win:Label(row, tostring(opts.Value or ""), 12.5, "accent", {
                Font = Kit.Fonts.Medium,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.fromOffset(160, 20),
                TextXAlignment = Enum.TextXAlignment.Right,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
            el.Value = value.Text
            function el:Set(v)
                self.Value = tostring(v)
                value.Text = self.Value
            end
            return el
        end)

        -- 4. 事件
        local themeInfo
        api:On("WindowCreated", function(win)
            if options.Welcome ~= false then
                win:Notify({ Title = "Template", Content = api:T("welcome"), Duration = 3 })
            end
        end)
        api:On("ThemeChanged", function(_, key)
            api:Log(api:T("changed", key))
            if themeInfo then
                themeInfo:Set(key)
            end
        end)
        api:On("ThemeTabBuilt", function(win, tab)
            local sec = tab:AddSection({ Title = "Template", Caption = api:T("section.caption") })
            sec:AddInfo({ Title = api:T("info.version"), Value = "1.0.0" })
            sec:AddInfo({ Title = api:T("info.language"), Value = api.Language })
            themeInfo = sec:AddInfo({ Title = api:T("info.theme"), Value = win:GetTheme() })
        end)

        -- 5. Exports：腳本可用 SenkoUI.Plugins.Template.Exports.Hello()
        return {
            Hello = function()
                api:Log("Hello from Template")
            end,
        }
    end,
}
