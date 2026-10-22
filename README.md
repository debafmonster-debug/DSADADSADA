# NIGHT SHIFT: BLACKSITE

Кооперативный survival-horror для Roblox (1–4 игрока, строго от первого лица).
Игроки — техники ночной смены на закрытом подземном объекте **COMPLEX-17**:
выполняют реальные технические задания, ищут документы, выживают при встрече
со **Смотрителем** и эвакуируются через шлюз E-1.

Проект — вертикальный срез, собранный целиком из кода: лобби, процедурная карта
из 25 модулей, 5 типов заданий, ИИ существа, спасение, прогрессия, HUD и меню.
Среда разработки не имела доступа к Roblox Studio, поэтому вся геометрия
строится скриптами при старте сервера, а логика проверяется headless-тестами.

## Запуск в Roblox Studio

1. Установите инструменты (версии в `rokit.toml`): `rokit install`
   или вручную Rojo 7.4.x, Lune 0.9.x, selene, luau-lsp.
2. Соберите place-файл:
   ```
   rojo build default.project.json -o build/NightShift.rbxl
   ```
   или откройте Studio, установите плагин Rojo и выполните `rojo serve`.
3. Откройте `build/NightShift.rbxl` в Studio → **Play** (F5) или
   **Test → Local Server (2–4 players)** для кооператива.
4. В лобби: доска смен (север) → «Создать» → «Я готов» → «Начать смену».
   Инструмент выбирается в комнате экипировки (запад), брифинг — восток,
   архив — северо-восток.

Управление: WASD, Shift — бег (выносливость), C — присесть, F — фонарь,
E / F / Q — взаимодействие (удержание), T — командные сигналы, M — меню/настройки.
Геймпад: L3 бег, B присесть, Y фонарь, X взаимодействие, DPad↑ сигналы.
Мобильные: экранные кнопки, промпты срабатывают касанием.

### Режимы серверов

`GameConfig.UseTeleportForShifts = false` (по умолчанию): смена запускается на
том же сервере, карта строится на расстоянии (`Grid.MapOrigin`) от лобби —
это тестируемый в Studio режим.
`true` + `MissionPlaceId`: лобби резервирует отдельный сервер миссии через
`TeleportService` и передаёт только `missionId/seed/shiftId`. Требует
опубликованного места-миссии и включённых API; в Studio не проверяется.

DataStore: при недоступности API профиль помечается `transient` и
не сохраняется (игрок видит предупреждение в терминале регистрации).
Для сохранения включите **Game Settings → Security → Enable Studio Access to API Services**.

## Структура

```
src/shared/Config        GameConfig, Missions (главы/миссии), Tools, Documents, Signals, SoundLibrary
src/shared/Utilities     Net (реестр Remote + валидаторы), Builder (геометрия), SeededRandom, Signal, RateLimiter
src/server/Bootstrap.server.luau    порядок инициализации сервисов
src/server/Services
  PlayerDataService      DataStore, версионирование, валидация, идемпотентные награды
  LayoutGenerator/Validator  seed-генерация графа комнат + fallback-планировка
  FacilityService        сборка карты в Workspace.ActiveMap, двери, питание, тревога, шлюз
  TaskService            PowerRestore, Diagnostics, CameraRepair, DoorRepair, Ventilation
  CreatureService        ИИ Смотрителя (FSM, зрение/слух, PathfindingService, двери)
  RescueService          выведение из строя, помощь, самоспасение, наблюдатель
  RoundManager           Prep → Briefing → Active → Incident → Evacuation → Results
  MatchmakingService     доска смен (создание/приват/готовность/старт, телепорт)
  LobbyService, StoryService, EquipmentService, CommunicationService, RewardService, DebugService
src/server/MapModules    Catalog (25 модулей по секторам A–E), Common, Props
src/server/Lobby/LobbyBuilder.luau   трёхмерное лобби (атриум, регистрация, доска смен, экипировка, брифинг, архив, зона ожидания)
src/server/Creatures/WardenModel.luau  процедурный риг Смотрителя с Motor6D-походкой
src/client/Controllers   Camera, Interaction, HUD, LobbyUI, Menu, Audio, Spectator, ToolView, SettingsStore
src/client/UI/Theme.luau программный UI-тулкит (промышленный стиль, адаптация под мобильные)
tests/*.spec.luau        headless-тесты (Lune): генератор, билдеры, сервисы
```

## Проверка

```
./tools/check.sh
```
Собирает place, запускает selene, luau-lsp и Lune-тесты:
- `layout.spec` — 120 seed × 3 миссии: валидность, достижимость задач/эвакуации,
  единственный security-вход в сектор D, воспроизводимость seed, fallback.
- `builders.spec` — лобби и каждый модуль в 3 вариантах дверей: бюджет деталей,
  маркеры патруля/задач/спавнов, согласованность конфигов.
- `services.spec` — загрузка всего графа require, миграция данных, награды, риг.

Что проверено только статически (нет Studio в среде): поведение Humanoid/Pathfinding
Смотрителя, твины дверей, DataStore, TeleportService, UI на устройствах. См. `TODO.md`.

## Отладка

Установите атрибут `NS_DebugLayout = true` на `Workspace` во время смены —
появится граф планировки (узлы, рёбра, старт, задачи, эвакуация, патрульные точки)
и трекер состояния Смотрителя. Seed смены печатается в Output и виден в HUD.
