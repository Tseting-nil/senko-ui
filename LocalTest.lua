-- 本機測試載入器：從 Local RAW files 伺服器（127.0.0.1:8000，路由 SenkoUI）載入 Example.lua
-- 範例與核心 SenkoUI.lua 裡的 GitHub raw 網址都換成本機網址（含 plugins/ 角色壁紙插件與 assets/ 壁紙）。
local BASE = "http://127.0.0.1:8000/SenkoUI/"
local GITHUB = "https://raw%.githubusercontent%.com/Tseting%-nil/senko%-ui/main/"

local function fetch(url)
    url = url:gsub(GITHUB, BASE)
    local src = game:HttpGet(url)
    if url:match("%.lua$") then
        src = src:gsub(GITHUB, BASE)
    end
    return src
end
getgenv().__senkoFetch = fetch

local src = fetch(BASE .. "Example.lua")
src = src:gsub("game:HttpGet%(", "getgenv().__senkoFetch(")
loadstring(src)()
