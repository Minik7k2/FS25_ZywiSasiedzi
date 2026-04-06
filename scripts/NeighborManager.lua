-- ============================================================================
-- NeighborManager.lua — Zarządzanie sąsiadami i ich polami
-- Etap 3: Wirtualni sąsiedzi z imionami przypisani do pól NPC
-- ============================================================================

NeighborManager = {}

-- Lista sąsiadów (wypełniana z config.xml lub domyślnie)
NeighborManager.neighbors = {}

-- Ścieżka do pliku konfiguracyjnego
NeighborManager.configPath = nil

--- Inicjalizuje NeighborManager — ładuje config i przypisuje pola
-- @param modDir string — ścieżka do katalogu moda
-- @param npcFields table — pola NPC z FieldScanner
function NeighborManager.init(modDir, npcFields)
    NeighborManager.neighbors = {}
    NeighborManager.configPath = modDir .. "xml/config.xml"

    -- Wczytaj sąsiadów z pliku konfiguracyjnego
    local loaded = NeighborManager.loadFromConfig()

    if not loaded or #NeighborManager.neighbors == 0 then
        print("[ZywiSasiedzi] Nie znaleziono konfiguracji sąsiadów — używam domyślnych")
        NeighborManager.loadDefaults()
    end

    -- Przypisz pola NPC do sąsiadów
    NeighborManager.assignFields(npcFields)

    print(string.format("[ZywiSasiedzi] Zainicjalizowano %d sąsiadów", #NeighborManager.neighbors))
end

--- Wczytuje listę sąsiadów z xml/config.xml
-- @return boolean — true jeśli udało się wczytać
function NeighborManager.loadFromConfig()
    local path = NeighborManager.configPath

    if path == nil then
        return false
    end

    -- Sprawdzamy czy plik istnieje
    local xmlFile = XMLFile.loadIfExists("zywiSasiedziConfig", path, nil)
    if xmlFile == nil then
        print("[ZywiSasiedzi] Brak pliku config.xml: " .. tostring(path))
        return false
    end

    -- Odczyt ustawień
    local maxNeighbors = xmlFile:getInt("zywiSasiedzi.settings#maxNeighbors", 5)

    -- Odczyt listy sąsiadów
    local count = 0
    local i = 0
    while true do
        local key = string.format("zywiSasiedzi.neighbors.neighbor(%d)", i)
        local name = xmlFile:getString(key .. "#name")

        if name == nil then
            break
        end

        if count < maxNeighbors then
            local neighbor = NeighborManager.createNeighbor(count + 1, name)
            table.insert(NeighborManager.neighbors, neighbor)
            count = count + 1
        end

        i = i + 1
    end

    xmlFile:delete()

    print(string.format("[ZywiSasiedzi] Wczytano %d sąsiadów z config.xml (limit: %d)", count, maxNeighbors))
    return count > 0
end

--- Tworzy domyślną listę sąsiadów (fallback gdy brak config.xml)
function NeighborManager.loadDefaults()
    local defaultNames = {
        "Jan Kowalski",
        "Anna Nowak",
        "Piotr Wiśniewski",
        "Maria Zielińska",
        "Tomasz Lewandowski"
    }

    for i, name in ipairs(defaultNames) do
        local neighbor = NeighborManager.createNeighbor(i, name)
        table.insert(NeighborManager.neighbors, neighbor)
    end
end

--- Tworzy strukturę danych pojedynczego sąsiada
-- @param id number — identyfikator sąsiada
-- @param name string — imię i nazwisko
-- @return table — dane sąsiada
function NeighborManager.createNeighbor(id, name)
    return {
        id = id,
        name = name,
        fields = {},       -- przypisane pola (tablica fieldData z FieldScanner)
        totalAreaHa = 0,   -- łączna powierzchnia pól w hektarach
    }
end

--- Przypisuje pola NPC do sąsiadów — round-robin, ale wyrównując powierzchnię
-- Każdy sąsiad dostaje co najmniej 1 pole (jeśli starczy)
-- @param npcFields table — pola NPC z FieldScanner.getNpcFields()
function NeighborManager.assignFields(npcFields)
    if npcFields == nil or #npcFields == 0 then
        print("[ZywiSasiedzi] Brak pól NPC do przypisania")
        return
    end

    if #NeighborManager.neighbors == 0 then
        print("[ZywiSasiedzi] Brak sąsiadów — nie można przypisać pól")
        return
    end

    -- Czyścimy poprzednie przypisania
    for _, neighbor in ipairs(NeighborManager.neighbors) do
        neighbor.fields = {}
        neighbor.totalAreaHa = 0
    end

    -- Sortujemy pola malejąco po powierzchni — duże pola najpierw
    -- Dzięki temu lepsze wyrównanie powierzchni
    local sortedFields = {}
    for _, field in ipairs(npcFields) do
        table.insert(sortedFields, field)
    end
    table.sort(sortedFields, function(a, b) return a.areaHa > b.areaHa end)

    -- Przypisujemy każde pole sąsiadowi z najmniejszą łączną powierzchnią
    for _, fieldData in ipairs(sortedFields) do
        local bestNeighbor = NeighborManager.neighbors[1]

        for _, neighbor in ipairs(NeighborManager.neighbors) do
            if neighbor.totalAreaHa < bestNeighbor.totalAreaHa then
                bestNeighbor = neighbor
            end
        end

        -- Dodajemy pole do sąsiada
        table.insert(bestNeighbor.fields, fieldData)
        bestNeighbor.totalAreaHa = bestNeighbor.totalAreaHa + fieldData.areaHa

        -- Oznaczamy pole — zapisujemy id sąsiada w danych pola
        fieldData.neighborId = bestNeighbor.id
        fieldData.neighborName = bestNeighbor.name
    end
end

--- Zwraca sąsiada po ID
-- @param id number — identyfikator sąsiada
-- @return table|nil — dane sąsiada lub nil
function NeighborManager.getNeighborById(id)
    for _, neighbor in ipairs(NeighborManager.neighbors) do
        if neighbor.id == id then
            return neighbor
        end
    end
    return nil
end

--- Zwraca sąsiada przypisanego do danego pola
-- @param fieldId number — ID pola
-- @return table|nil — dane sąsiada lub nil
function NeighborManager.getNeighborByFieldId(fieldId)
    for _, neighbor in ipairs(NeighborManager.neighbors) do
        for _, field in ipairs(neighbor.fields) do
            if field.fieldId == fieldId then
                return neighbor
            end
        end
    end
    return nil
end

--- Zwraca listę wszystkich sąsiadów
-- @return table — lista sąsiadów
function NeighborManager.getNeighbors()
    return NeighborManager.neighbors
end

--- Wypisuje raport o sąsiadach do konsoli
function NeighborManager.printReport()
    print("[ZywiSasiedzi] ==========================================")
    print("[ZywiSasiedzi]       RAPORT SĄSIADÓW")
    print("[ZywiSasiedzi] ==========================================")
    print(string.format("[ZywiSasiedzi] Liczba sąsiadów: %d", #NeighborManager.neighbors))
    print("[ZywiSasiedzi] ------------------------------------------")

    for _, neighbor in ipairs(NeighborManager.neighbors) do
        -- Zbieramy numery pól
        local fieldIds = {}
        for _, field in ipairs(neighbor.fields) do
            table.insert(fieldIds, tostring(field.fieldId))
        end

        local fieldListStr = #fieldIds > 0 and table.concat(fieldIds, ", ") or "brak"

        print(string.format(
            "[ZywiSasiedzi] Sąsiad #%d: %s | Pola: [%s] | Łącznie: %.1f ha",
            neighbor.id,
            neighbor.name,
            fieldListStr,
            neighbor.totalAreaHa
        ))
    end

    print("[ZywiSasiedzi] ==========================================")
end
