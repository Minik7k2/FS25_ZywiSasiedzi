-- ============================================================================
-- NeighborManager.lua — Zarządzanie sąsiadami i ich polami
-- Etap 3: Sąsiedzi odczytywani z gry (istniejący właściciele NPC pól)
-- ============================================================================

NeighborManager = {}

-- Sąsiedzi indeksowani po farmId (klucz = farmId, wartość = dane sąsiada)
NeighborManager.neighbors = {}

-- Lista sąsiadów jako tablica (do iteracji)
NeighborManager.neighborList = {}

--- Inicjalizuje NeighborManager — odkrywa sąsiadów z pól NPC
-- @param npcFields table — pola NPC z FieldScanner
function NeighborManager.init(npcFields)
    NeighborManager.neighbors = {}
    NeighborManager.neighborList = {}

    if npcFields == nil or #npcFields == 0 then
        print("[ZywiSasiedzi] Brak pól NPC — brak sąsiadów do odkrycia")
        return
    end

    -- Grupujemy pola po ownerFarmId — każdy unikalny farmId to jeden sąsiad
    for _, fieldData in ipairs(npcFields) do
        local farmId = fieldData.ownerFarmId

        if farmId ~= nil and farmId > 0 then
            local neighbor = NeighborManager.neighbors[farmId]

            if neighbor == nil then
                -- Nowy sąsiad — pobieramy nazwę z gry
                local farmName = NeighborManager.getFarmName(farmId)
                neighbor = {
                    farmId = farmId,
                    name = farmName,
                    fields = {},
                    totalAreaHa = 0,
                }
                NeighborManager.neighbors[farmId] = neighbor
                table.insert(NeighborManager.neighborList, neighbor)
            end

            -- Dodajemy pole do tego sąsiada
            table.insert(neighbor.fields, fieldData)
            neighbor.totalAreaHa = neighbor.totalAreaHa + fieldData.areaHa

            -- Oznaczamy pole — zapisujemy dane sąsiada
            fieldData.neighborFarmId = farmId
            fieldData.neighborName = neighbor.name
        end
    end

    -- Sortujemy listę sąsiadów po farmId dla czytelności
    table.sort(NeighborManager.neighborList, function(a, b) return a.farmId < b.farmId end)

    print(string.format("[ZywiSasiedzi] Odkryto %d sąsiadów z istniejących farm NPC",
        #NeighborManager.neighborList))
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

        print(string.format(
            "[ZywiSasiedzi] %s (farmId: %d) | Pola: [%s] | Łącznie: %.1f ha",
            neighbor.name,
            neighbor.farmId,
            fieldListStr,
            neighbor.totalAreaHa
        ))
    end

    print("[ZywiSasiedzi] ==========================================")
end
