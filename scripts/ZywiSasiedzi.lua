-- ============================================================================
-- ZywiSasiedzi.lua — Główny skrypt moda "Żywi Sąsiedzi"
-- Odpowiada za inicjalizację, pętlę update i cleanup
-- ============================================================================

-- Ładujemy moduły moda
local modDir = g_currentModDirectory
source(modDir .. "scripts/FieldScanner.lua")
source(modDir .. "scripts/NeighborManager.lua")
source(modDir .. "scripts/WorkDispatcher.lua")

-- Zapisujemy nazwę moda podczas ładowania pliku (potem niedostępna!)
local modName = g_currentModName

ZywiSasiedzi = {}

-- Flaga informująca czy mod jest załadowany
ZywiSasiedzi.isLoaded = false

-- Katalog moda (do wczytywania konfiguracji)
ZywiSasiedzi.modDir = modDir

-- Wyniki ostatniego skanowania pól
ZywiSasiedzi.scannedFields = {}

--- Wywoływane przy ładowaniu mapy
function ZywiSasiedzi:loadMap(name)
    print("[ZywiSasiedzi] ======================================")
    print("[ZywiSasiedzi] Mod 'Żywi Sąsiedzi' załadowany!")
    print("[ZywiSasiedzi] Nazwa moda: " .. tostring(modName))
    print("[ZywiSasiedzi] Mapa: " .. tostring(name))
    print("[ZywiSasiedzi] ======================================")

    ZywiSasiedzi.isLoaded = true
    ZywiSasiedzi.modName = modName

    -- Rejestracja komend konsolowych do testowania
    -- Użyj klawisza ~ w grze, wpisz komendę
    addConsoleCommand("zsTest", "Testowa komenda moda Żywi Sąsiedzi", "consoleCommandTest", self)
    addConsoleCommand("zsStatus", "Wyświetla status moda Żywi Sąsiedzi", "consoleCommandStatus", self)
    addConsoleCommand("zsScanFields", "Skanuje pola na mapie i wyświetla raport", "consoleCommandScanFields", self)
    addConsoleCommand("zsNeighbors", "Wyświetla raport o sąsiadach i ich polach", "consoleCommandNeighbors", self)
    addConsoleCommand("zsSpawn", "Spawnuje traktor na polu sąsiada: zsSpawn [fieldId] [setIndex]", "consoleCommandSpawn", self)
    addConsoleCommand("zsDespawn", "Usuwa pojazdy z pola: zsDespawn [fieldId] lub zsDespawn all", "consoleCommandDespawn", self)
    addConsoleCommand("zsVehicles", "Wyświetla status aktywnych pojazdów", "consoleCommandVehicles", self)
    addConsoleCommand("zsStore", "Listuje pojazdy dostępne w sklepie (do sprawdzania XML)", "consoleCommandStore", self)

    -- Automatyczne skanowanie pól po załadowaniu mapy
    self:scanFields()

    -- Inicjalizacja systemu sąsiadów — odkrywamy właścicieli pól NPC z gry
    local npcFields = FieldScanner.getNpcFields(ZywiSasiedzi.scannedFields)
    NeighborManager.init(npcFields)
    NeighborManager.printReport()

    -- Inicjalizacja systemu spawnowania pojazdów
    WorkDispatcher.init()
end

--- Wywoływane co klatkę, dt = delta time w milisekundach
function ZywiSasiedzi:update(dt)
    -- Na razie puste — tu będzie logika dispatching prac sąsiadów
end

--- Wywoływane przy zamykaniu mapy — sprzątamy zasoby
function ZywiSasiedzi:deleteMap()
    -- Despawnuj wszystkie pojazdy sąsiadów
    WorkDispatcher.despawnAll()

    -- Usuwamy komendy konsolowe
    removeConsoleCommand("zsTest")
    removeConsoleCommand("zsStatus")
    removeConsoleCommand("zsScanFields")
    removeConsoleCommand("zsNeighbors")
    removeConsoleCommand("zsSpawn")
    removeConsoleCommand("zsDespawn")
    removeConsoleCommand("zsVehicles")
    removeConsoleCommand("zsStore")

    ZywiSasiedzi.isLoaded = false
    print("[ZywiSasiedzi] Mod wyładowany. Do zobaczenia!")
end

--- Komenda konsolowa: zsTest
-- Służy do ręcznego testowania podczas developmentu
function ZywiSasiedzi:consoleCommandTest()
    print("[ZywiSasiedzi] Komenda testowa działa!")
    print("[ZywiSasiedzi] g_currentMission istnieje: " .. tostring(g_currentMission ~= nil))
    return "OK"
end

--- Skanuje pola i zapisuje wynik
function ZywiSasiedzi:scanFields()
    print("[ZywiSasiedzi] Rozpoczynam skanowanie pól...")
    ZywiSasiedzi.scannedFields = FieldScanner.scanAllFields()
    FieldScanner.printReport(ZywiSasiedzi.scannedFields)
    return ZywiSasiedzi.scannedFields
end

--- Komenda konsolowa: zsScanFields
-- Ponowne skanowanie pól na żądanie
function ZywiSasiedzi:consoleCommandScanFields()
    self:scanFields()
    return "OK"
end

--- Komenda konsolowa: zsStatus
-- Wyświetla aktualny status moda
function ZywiSasiedzi:consoleCommandStatus()
    print("[ZywiSasiedzi] === STATUS MODA ===")
    print("[ZywiSasiedzi] Załadowany: " .. tostring(ZywiSasiedzi.isLoaded))
    print("[ZywiSasiedzi] Nazwa moda: " .. tostring(ZywiSasiedzi.modName))

    if g_currentMission ~= nil then
        print("[ZywiSasiedzi] Misja aktywna: TAK")
    else
        print("[ZywiSasiedzi] Misja aktywna: NIE")
    end

    -- Informacje o zeskanowanych polach
    local npcFields = FieldScanner.getNpcFields(ZywiSasiedzi.scannedFields)
    local playerFields = FieldScanner.getPlayerFields(ZywiSasiedzi.scannedFields)
    print(string.format("[ZywiSasiedzi] Zeskanowane pola: %d (gracz: %d, NPC: %d)",
        #ZywiSasiedzi.scannedFields, #playerFields, #npcFields))

    -- Informacje o sąsiadach
    local neighbors = NeighborManager.getNeighbors()
    print(string.format("[ZywiSasiedzi] Sąsiedzi: %d", #neighbors))
    for _, n in ipairs(neighbors) do
        print(string.format("[ZywiSasiedzi]   - %s: %d pól (%.1f ha)", n.name, #n.fields, n.totalAreaHa))
    end

    return "OK"
end

--- Komenda konsolowa: zsNeighbors
-- Wyświetla szczegółowy raport o sąsiadach i ich polach
function ZywiSasiedzi:consoleCommandNeighbors()
    NeighborManager.printReport()
    return "OK"
end

--- Komenda konsolowa: zsSpawn [fieldId] [setIndex]
-- Spawnuje traktor z narzędziem na polu sąsiada
-- Użycie: zsSpawn 3        — spawn na polu #3 z domyślnym zestawem
--         zsSpawn 3 2      — spawn na polu #3 z zestawem #2
function ZywiSasiedzi:consoleCommandSpawn(fieldIdStr, setIndexStr)
    local fieldId = tonumber(fieldIdStr)
    local setIndex = tonumber(setIndexStr) or 1

    if fieldId == nil then
        -- Bez argumentu: spawnuj na pierwszym dostępnym polu sąsiada
        local neighbors = NeighborManager.getNeighbors()
        if #neighbors == 0 then
            print("[ZywiSasiedzi] Brak sąsiadów — nie ma gdzie spawnować")
            return "Brak sąsiadów"
        end

        -- Znajdź pierwsze pole bez aktywnego pojazdu
        for _, neighbor in ipairs(neighbors) do
            for _, field in ipairs(neighbor.fields) do
                local hasVehicle = false
                for _, record in ipairs(WorkDispatcher.activeVehicles) do
                    if record.fieldId == field.fieldId then
                        hasVehicle = true
                        break
                    end
                end

                if not hasVehicle then
                    fieldId = field.fieldId
                    break
                end
            end
            if fieldId ~= nil then break end
        end

        if fieldId == nil then
            print("[ZywiSasiedzi] Wszystkie pola sąsiadów mają pojazdy")
            return "Wszystkie pola zajęte"
        end
    end

    -- Znajdź dane pola po ID
    local fieldData = nil
    for _, fd in ipairs(ZywiSasiedzi.scannedFields) do
        if fd.fieldId == fieldId then
            fieldData = fd
            break
        end
    end

    if fieldData == nil then
        print(string.format("[ZywiSasiedzi] Nie znaleziono pola #%d", fieldId))
        return "Pole nie znalezione"
    end

    if fieldData.isPlayerOwned then
        print(string.format("[ZywiSasiedzi] Pole #%d należy do gracza — pomijam", fieldId))
        return "Pole gracza"
    end

    local ok = WorkDispatcher.spawnAtField(fieldData, setIndex)
    return ok and "Spawn rozpoczęty" or "Spawn nieudany"
end

--- Komenda konsolowa: zsDespawn [fieldId|all]
-- Usuwa pojazdy z pola lub wszystkie
function ZywiSasiedzi:consoleCommandDespawn(arg)
    if arg == "all" or arg == nil then
        WorkDispatcher.despawnAll()
        return "Wszystkie pojazdy usunięte"
    end

    local fieldId = tonumber(arg)
    if fieldId == nil then
        print("[ZywiSasiedzi] Użycie: zsDespawn [fieldId] lub zsDespawn all")
        return "Błąd"
    end

    local ok = WorkDispatcher.despawnFromField(fieldId)
    return ok and "Pojazdy usunięte" or "Brak pojazdów na tym polu"
end

--- Komenda konsolowa: zsVehicles
-- Wyświetla status aktywnych pojazdów sąsiadów
function ZywiSasiedzi:consoleCommandVehicles()
    WorkDispatcher.printStatus()
    return "OK"
end

--- Komenda konsolowa: zsStore
-- Listuje pojazdy w sklepie (pomaga znaleźć prawidłowe ścieżki XML)
function ZywiSasiedzi:consoleCommandStore()
    WorkDispatcher.listStoreVehicles()
    return "OK"
end

-- Rejestracja jako listener eventów moda
addModEventListener(ZywiSasiedzi)
