module("luci.controller.netcheck", package.seeall)

local sys = require "luci.sys"

-- 只提供数据接口，供 PassWall 页面底部调用；不注册菜单，界面里不单独出现
function index()
	entry({"admin", "services", "netcheck", "data"}, call("action_data")).leaf = true
end

-- 出口 IP 源：全部实测可用，按实测速度排序，前面的优先。全部并发请求，
-- 取第一个返回合法 IPv4 的结果，任何一个挂掉都不影响整体。
--
-- 只用境外源，是刻意的：实测境外源与境内源（3322 / oray）看到的出口 IP 不同，
-- 开着代理时前者走代理、后者走直连。混用会让显示的 IP 随"哪个先返回"而变，
-- 无法判断代理是否生效。统一用境外源后：
--   未开代理 -> 显示真实公网 IP；开了代理 -> 显示代理节点的 IP。
-- 并发数也控制在 4 个：实测并发太多（十几个）会集体超时。
local IP_SOURCES = {
	"https://checkip.amazonaws.com/",
	"https://ipv4.icanhazip.com/",
	"https://api.ipify.org",
	"https://ipinfo.io/ip"
}

-- 归属地源（JSON）。三条都实测 200，但只留最快的两条：并发请求数要留余量，
-- 实测并发过多时会出现集体超时。ip-api.com 实测 403，已剔除。
local GEO_SOURCES = {
	"https://ipinfo.io/json",
	"https://ipapi.co/json"
}

local function trim(s)
	return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function pick(s, pattern)
	local v = trim(s):match(pattern)
	return (v ~= nil and v ~= "") and v or nil
end

-- 拼出一条并发命令：所有请求同时发出，总耗时约等于单个超时（4 秒）
local function build_cmd(t)
	local p = { "( rm -f " .. t .. ".ip* " .. t .. ".geo* " .. t .. ".cn " .. t .. ".gw; " }
	for i, u in ipairs(IP_SOURCES) do
		p[#p + 1] = "( curl -s --max-time 4 '" .. u .. "' > " .. t .. ".ip" .. i .. " 2>/dev/null ) & "
	end
	for i, u in ipairs(GEO_SOURCES) do
		p[#p + 1] = "( curl -s --max-time 4 '" .. u .. "' > " .. t .. ".geo" .. i .. " 2>/dev/null ) & "
	end
	p[#p + 1] = "( curl -s -o /dev/null -w '%{http_code}' --max-time 4 https://www.baidu.com > " .. t .. ".cn 2>/dev/null ) & "
	p[#p + 1] = "( curl -s -o /dev/null -w '%{http_code}' --max-time 4 https://www.google.com/generate_204 > " .. t .. ".gw 2>/dev/null ) & "
	p[#p + 1] = "wait ) 2>/dev/null"
	return table.concat(p)
end

local function collect()
	local t = "/tmp/pw_nc"
	sys.exec(build_cmd(t))

	local function rd(name)
		return trim(sys.exec("head -c 4096 " .. t .. "." .. name .. " 2>/dev/null"))
	end

	-- 依次看每个 IP 源，取第一个含合法 IPv4 的响应
	-- （用 match 而不是整串匹配，这样 "Current IP Address: 1.2.3.4" 也能取出来）
	local ip = nil
	for i = 1, #IP_SOURCES do
		local m = rd("ip" .. i):match("%d+%.%d+%.%d+%.%d+")
		if m then
			ip = m
			break
		end
	end

	-- 归属地：逐个源尝试，各家字段名不同（country / country_name），都试一遍
	local country, region, city, isp
	for i = 1, #GEO_SOURCES do
		local g = rd("geo" .. i)
		if g:sub(1, 1) == "{" then
			country = country or pick(g, '"country_name"%s*:%s*"([^"]+)"')
			       or pick(g, '"country"%s*:%s*"([^"]+)"')
			region  = region  or pick(g, '"region_name"%s*:%s*"([^"]+)"')
			       or pick(g, '"regionName"%s*:%s*"([^"]+)"')
			       or pick(g, '"region"%s*:%s*"([^"]+)"')
			city    = city    or pick(g, '"city"%s*:%s*"([^"]+)"')
			isp     = isp     or pick(g, '"org"%s*:%s*"([^"]+)"')
			       or pick(g, '"isp"%s*:%s*"([^"]+)"')
			if country and city then break end
		end
	end

	-- curl 连不上时 http_code 是 000，不能当成成功
	local function reachable(v)
		local n = tonumber(v)
		return n ~= nil and n >= 200 and n < 400
	end

	return {
		ip      = ip,
		country = country,
		region  = region,
		city    = city,
		isp     = isp,
		cn_ok   = reachable(rd("cn")),
		gw_ok   = reachable(rd("gw"))
	}
end

function action_data()
	local http = require "luci.http"

	-- 任何异常都要返回合法 JSON，否则前端拿不到数据只会显示"检测失败"
	local ok, res = pcall(collect)
	if not ok or type(res) ~= "table" then
		res = { cn_ok = false, gw_ok = false }
	end

	http.prepare_content("application/json")
	http.write_json(res)
end
