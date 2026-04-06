-- ============================================================================
-- NeighborManager.lua — Zarządzanie sąsiadami i ich polami
-- Etap 3: Sąsiedzi odczytywani z gry (istniejący właściciele NPC pól)
-- ============================================================================

NeighborManager = {}

-- Sąsiedzi indeksowani po farmId (klucz = farmId, wartość = dane sąsiada)
NeighborManager.neighbors = {}

-- Lista sąsiadów jako tablica (do iteracji)
NeighborManager.neighborList = {}

-- Nazwy wirtualnych sąsiadów (używane gdy pole nie ma właściciela w grze)
NeighborManager.virtualNames = {
    "Jan Kowalski", "Anna Nowak", "Piotr Wiśniewski",
    "Maria Zielińska", "Tomasz Wójcik", "Ewa Kamińska",
    "Krzysztof Lewandowski", "Zofia Szymańska"
}

-- Maksymalna liczba pól na jednego wirtualnego sąsiada
NeighborManager.maxFieldsPerNeighbor = 4

--- Inicjalizuje NeighborManager — odkrywa sąsiadów z pól NPC
-- W FS25 niczyje pola (ownerFarmId == 0) nie mają właściciela NPC,
-- więc tworzymy wirtualnych sąsiadów i przypisujemy im te pola.
-- @param npcFields table — pola NPC z FieldScanner
function NeighborManager.init(npcFields)
    NeighborManager.neighbors = {}
    NeighborManager.neighborList = {}

    if npcFields == nil or #npcFields == 0 then
        print("[ZywiSasiedzi] Brak pól NPC — brak sąsiadów do odkrycia")
        return
    end

    -- Pola z istniejącym właścicielem NPC (farmId > 0, nie-gracz)
    local ownedFields = {}
    -- Pola niczyje (farmId == 0) — wymagają wirtualnego sąsiada
    local unownedFields = {}

    for _, fieldData in ipairs(npcFields) do
        local farmId = fieldData.ownerFarmId
        if farmId ~= nil and farmId > 0 then
            table.insert(ownedFields, fieldData)
        else
            table.insert(unownedFields, fieldData)
        end
    end

    -- 1) Rejestrujemy sąsiadów z istniejących farm NPC (jeśli jakieś są)
    for _, fieldData in ipairs(ownedFields) do
        local farmId = fieldData.ownerFarmId
        local neighbor = NeighborManager.neighbors[farmId]

        if neighbor == nil then
            local farmName = NeighborManager.getFarmName(farmId)
            neighbor = {
                farmId = farmId,
                name = farmName,
                fields = {},
                totalAreaHa = 0,
                isVirtual = false,
            }
            NeighborManager.neighbors[farmId] = neighbor
            table.insert(NeighborManager.neighborList, neighbor)
        end

        table.insert(neighbor.fields, fieldData)
        neighbor.totalAreaHa = neighbor.totalAreaHa + fieldData.areaHa
        fieldData.neighborFarmId = farmId
        fieldData.neighborName = neighbor.name
    end

    -- 2) Tworzymy wirtualnych sąsiadów dla niczyich pól
    if #unownedFields > 0 then
        local maxPerNeighbor = NeighborManager.maxFieldsPerNeighbor
        local nameIndex = 1

        -- Wirtualne farmId zaczynamy od 100, żeby nie kolidować z prawdziwymi
        local virtualFarmId = 100

        local currentNeighbor = nil
        local fieldsInCurrent = 0

        for _, fieldData in ipairs(unownedFields) do
            -- Twórz nowego sąsiada co maxPerNeighbor pól
            if currentNeighbor == nil or fieldsInCurrent >= maxPerNeighbor then
                local name = NeighborManager.virtualNames[nameIndex] or
                    string.format("Sąsiad #%d", nameIndex)
                nameIndex = nameIndex + 1

                currentNeighbor = {
                    farmId = virtualFarmId,
                    name = name,
                    fields = {},
                    totalAreaHa = 0,
                    isVirtual = true,
                }
                NeighborManager.neighbors[virtualFarmId] = currentNeighbor
                table.insert(NeighborManager.neighborList, currentNeighbor)
                virtualFarmId = virtualFarmId + 1
                fieldsInCurrent = 0
            end

            table.insert(currentNeighbor.fields, fieldData)
            currentNeighbor.totalAreaHa = currentNeighbor.totalAreaHa + fieldData.areaHa
            fieldData.neighborFarmId = currentNeighbor.farmId
            fieldData.neighborName = currentNeighbor.name
            fieldsInCurrent = fieldsInCurrent + 1
        end
    end

    -- Sortujemy listę sąsiadów po farmId dla czytelności
    table.sort(NeighborManager.neighborList, function(a, b) return a.farmId < b.farmId end)

    local realCount = #ownedFields > 0 and "tak" or "nie"
    print(string.format("[ZywiSasiedzi] Odkryto %d sąsiadów (%d pól NPC, %d pól niczyich przypisanych wirtualnym sąsiadom)",
        #NeighborManager.neighborList, #ownedFields, #unownedFields))
end

--- Pobiera nazwę farmy z gry po farmId
-- @param farmId number — identyfikator farmy
-- @return string — nazwa farmy/właściciela
function NeighborManager.getFarmName(farmId)
    if g_farmManager ~= nil then
        local farm = g_farmManager:getFarmById(farmId)
        if farm ~= nil and farm.name ~= nil then
            return farm.name
        end
    end

    -- Fallback gdy nie udało się pobrać nazwy
    return string.format("Farma #%d", farmId)
end

--- Zwraca sąsiada po farmId
-- @param farmId number — identyfikator farmy
-- @return table|nil — dane sąsiada lub nil
function NeighborManager.getNeighborByFarmId(farmId)
    return NeighborManager.neighbors[farmId]
end

--- Zwraca sąsiada przypisanego do danego pola
-- @param fieldId number — ID pola
-- @return table|nil — dane sąsiada lub nil
function NeighborManager.getNeighborByFieldId(fieldId)
    for _, neighbor in ipairs(NeighborManager.neighborList) do
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
    return NeighborManager.neighborList
end

--- Wypisuje raport o sąsiadach do konsoli
function NeighborManager.printReport()
    print("[ZywiSasiedzi] ==========================================")
    print("[ZywiSasiedzi]       RAPORT SĄSIADÓW")
    print("[ZywiSasiedzi] ==========================================")
    print(string.format("[ZywiSasiedzi] Liczba sąsiadów: %d", #NeighborManager.neighborList))
    print("[ZywiSasiedzi] ------------------------------------------")

    for _, neighbor in ipairs(NeighborManager.neighborList) do
        -- Zbieramy numery pól
        local fieldIds = {}
        for _, field in ipairs(neighbor.fields) do
            table.insert(fieldIds, tostring(field.fieldId))
        end

        local fieldListStr = #fieldIds > 0 and table.concat(fieldIds, ", ") or "brak"
        local typeStr = neighbor.isVirtual and "wirtualny" or "z gry"

        print(string.format(
            "[ZywiSasiedzi] %s (%s) | Pola: [%s] | Łącznie: %.1f ha",
            neighbor.name,
            typeStr,
            fieldListStr,
            neighbor.totalAreaHa
        ))
    end

    print("[ZywiSasiedzi] ==========================================")
end
