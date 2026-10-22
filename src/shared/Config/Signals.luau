--!nonstrict
local Signals = {
	{ id = "here", text = "Сюда", color = Color3.fromRGB(90, 200, 255) },
	{ id = "threat", text = "Обнаружена угроза", color = Color3.fromRGB(255, 70, 60) },
	{ id = "help", text = "Нужна помощь", color = Color3.fromRGB(255, 200, 60) },
	{ id = "tool", text = "Нужен инструмент", color = Color3.fromRGB(200, 200, 210) },
	{ id = "retreat", text = "Отступаем", color = Color3.fromRGB(255, 120, 60) },
	{ id = "done", text = "Задача выполнена", color = Color3.fromRGB(90, 230, 120) },
	{ id = "check", text = "Проверь помещение", color = Color3.fromRGB(180, 160, 255) },
	{ id = "nolight", text = "Не включай свет", color = Color3.fromRGB(255, 240, 120) },
	{ id = "blocked", text = "Путь закрыт", color = Color3.fromRGB(255, 90, 90) },
	{ id = "evac", text = "Готов к эвакуации", color = Color3.fromRGB(120, 255, 200) },
}

local ById = {}
for _, s in Signals do
	ById[s.id] = s
end

return { List = Signals, ById = ById }
