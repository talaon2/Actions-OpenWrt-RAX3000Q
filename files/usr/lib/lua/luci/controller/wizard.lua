module("luci.controller.wizard", package.seeall)

function index()
	entry({"admin", "system", "wizard"}, cbi("wizard"), translate("设置向导"), 1).index = true
end
