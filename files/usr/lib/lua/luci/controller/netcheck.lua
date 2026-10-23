module("luci.controller.netcheck", package.seeall)

function index()
	entry({"admin", "services", "netcheck"}, template("netcheck"), translate("网络检测"), 90)
	entry({"admin", "services", "netcheck", "data"}, call("action_data")).leaf = true
end

local function trim(s)
	return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function pick(s, pattern)
	local v = trim(s):match(pattern)
	return v or "-"
end

-- 返回 JSON：外网 IP、归属地，以及国内/国外站点的连通性
function action_data()
	local http = require "luci.http"
	local sys  = require "luci.sys"

	local geo = sys.exec("curl -s --max-time 6 https://ip-api.com/json/ 2>/dev/null")
	if trim(geo) == "" or geo:match('"status"%s*:%s*"fail"') then
		geo = sys.exec("curl -s --max-time 6 https://ipinfo.io/json 2>/dev/null")
	end

	local ip = pick(geo, '"query"%s*:%s*"([^"]+)"')
	if ip == "-" then ip = pick(geo, '"ip"%s*:%s*"([^"]+)"') end

	local country = pick(geo, '"country"%s*:%s*"([^"]+)"')
	local region  = pick(geo, '"regionName"%s*:%s*"([^"]+)"')
	if region == "-" then region = pick(geo, '"region"%s*:%s*"([^"]+)"') end
	local city = pick(geo, '"city"%s*:%s*"([^"]+)"')
	local isp  = pick(geo, '"isp"%s*:%s*"([^"]+)"')
	if isp == "-" then isp = pick(geo, '"org"%s*:%s*"([^"]+)"') end

	local cn = sys.exec("curl -s -o /dev/null -w '%{http_code}' --max-time 6 https://www.baidu.com 2>/dev/null")
	local gw = sys.exec("curl -s -o /dev/null -w '%{http_code}' --max-time 6 https://www.google.com/generate_204 2>/dev/null")

	http.prepare_content("application/json")
	http.write_json({
		ip      = ip,
		country = country,
		region  = region,
		city    = city,
		isp     = isp,
		cn_ok   = (tonumber(trim(cn)) ~= nil),
		gw_ok   = (tonumber(trim(gw)) ~= nil)
	})
end
