-- ============================================================================
-- ZywiSasiedzi.lua — Główny skrypt moda "Żywi Sąsiedzi"
-- Odpowiada za inicjalizację, pętlę update i cleanup
-- ============================================================================

-- Zapisujemy nazwę moda podczas ładowania pliku (potem niedostępna!)
local modName = g_currentModName

ZywiSasiedzi = {}

-- Flaga informująca czy mod jest załadowany
ZywiSasiedzi.isLoaded = false

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

    return "OK"
end

-- Rejestracja jako listener eventów moda
addModEventListener(ZywiSasiedzi)
