local uci  = require "luci.model.uci".cursor()
local sys  = require "luci.sys"
local http = require "luci.http"

m = Map("network", translate("设置向导"),
	translate("选择路由器的工作模式并一键应用。旁路由模式会关闭本机 DHCP，并把网关指向主路由；AP 模式把本机当交换机使用。"))

s = m:section(NamedSection, "lan", "interface", translate("工作模式"))

mode = s:option(ListValue, "_mode", translate("工作模式"))
mode:value("router", translate("正常路由（默认：LAN 开启 DHCP，WAN 自动获取）"))
mode:value("bypass", translate("旁路由（关闭 DHCP，LAN 设静态 IP 并指向主路由网关）"))
mode:value("ap",     translate("无线接入点 AP（当交换机用，IP 由主路由分配）"))
mode.default = "router"

ipaddr = s:option(Value, "_ipaddr", translate("本机 LAN IP"))
ipaddr.default = "192.168.10.2"
ipaddr.datatype = "ipaddr"
ipaddr:depends("_mode", "bypass")
ipaddr:depends("_mode", "ap")

gateway = s:option(Value, "_gateway", translate("主路由 IP（网关）"))
gateway.default = "192.168.10.1"
gateway.datatype = "ipaddr"
gateway:depends("_mode", "bypass")

dns = s:option(Value, "_dns", translate("DNS 服务器"))
dns.default = "223.5.5.5 119.29.29.29"
dns:depends("_mode", "bypass")
dns:depends("_mode", "ap")

m.on_commit = function(self)
	local mode = http.formvalue("cbid.network.lan._mode") or "router"
	local ip   = http.formvalue("cbid.network.lan._ipaddr") or "192.168.10.2"
	local gw   = http.formvalue("cbid.network.lan._gateway") or "192.168.10.1"
	local dnsv = http.formvalue("cbid.network.lan._dns") or "223.5.5.5 119.29.29.29"

	if mode == "bypass" then
		uci:set("network", "lan", "proto", "static")
		uci:set("network", "lan", "ipaddr", ip)
		uci:set("network", "lan", "netmask", "255.255.255.0")
		uci:set("network", "lan", "gateway", gw)
		uci:set("network", "lan", "dns", dnsv)
		uci:commit("network")
		uci:set("dhcp", "lan", "ignore", "1")
		uci:commit("dhcp")
		sys.call("/etc/init.d/firewall enable >/dev/null 2>&1")
	elseif mode == "ap" then
		uci:set("network", "lan", "proto", "static")
		uci:set("network", "lan", "ipaddr", ip)
		uci:set("network", "lan", "netmask", "255.255.255.0")
		uci:delete("network", "lan", "gateway")
		uci:delete("network", "lan", "dns")
		uci:commit("network")
		uci:set("dhcp", "lan", "ignore", "1")
		uci:commit("dhcp")
		sys.call("/etc/init.d/firewall disable >/dev/null 2>&1")
	else
		uci:set("network", "lan", "proto", "static")
		uci:set("network", "lan", "ipaddr", "192.168.10.1")
		uci:set("network", "lan", "netmask", "255.255.255.0")
		uci:delete("network", "lan", "gateway")
		uci:delete("network", "lan", "dns")
		uci:commit("network")
		uci:delete("dhcp", "lan", "ignore")
		uci:commit("dhcp")
		sys.call("/etc/init.d/firewall enable >/dev/null 2>&1")
	end

	sys.call("(sleep 1; /etc/init.d/network restart; /etc/init.d/dnsmasq restart; /etc/init.d/firewall restart) >/dev/null 2>&1 &")
end

return m
