-- ============================================================================
-- ZywiSasiedzi.lua — Główny skrypt moda "Żywi Sąsiedzi"
-- Odpowiada za inicjalizację, pętlę update i cleanup
-- ============================================================================

-- Ładujemy moduły moda
local modDir = g_currentModDirectory
source(modDir .. "scripts/FieldScanner.lua")
source(modDir .. "scripts/NeighborManager.lua")

-- Zapisujemy nazwę moda podczas ładowania pliku (potem niedostępna!)
local modName = g_currentModName

ZywiSasiedzi = {}

-- Flaga informująca czy mod jest załadowany
ZywiSasiedzi.isLoaded = false

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

    -- Automatyczne skanowanie pól po załadowaniu mapy
    self:scanFields()

    -- Inicjalizacja systemu sąsiadów — przypisanie pól NPC
    local npcFields = FieldScanner.getNpcFields(ZywiSasiedzi.scannedFields)
    NeighborManager.init(modDir, npcFields)
    NeighborManager.printReport()
end

--- Wywoływane co klatkę, dt = delta time w milisekundach
function ZywiSasiedzi:update(dt)
    -- Na razie puste — tu będzie logika dispatching prac sąsiadów
end

--- Wywoływane przy zamykaniu mapy — sprzątamy zasoby
function ZywiSasiedzi:deleteMap()
    -- Usuwamy komendy konsolowe
    removeConsoleCommand("zsTest")
    removeConsoleCommand("zsStatus")
    removeConsoleCommand("zsScanFields")
    removeConsoleCommand("zsNeighbors")

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

-- Rejestracja jako listener eventów moda
addModEventListener(ZywiSasiedzi)
