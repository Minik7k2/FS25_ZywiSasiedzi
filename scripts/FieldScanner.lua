-- ============================================================================
-- FieldScanner.lua — Skanowanie pól: właściciel, uprawy, stan wzrostu
-- Etap 2: Mod wykrywa pola i wypisuje raport w konsoli
-- ============================================================================

FieldScanner = {}

--- Skanuje wszystkie pola na mapie i zwraca tablicę z danymi
-- @return table — lista pól z informacjami
function FieldScanner.scanAllFields()
    if g_fieldManager == nil then
        print("[ZywiSasiedzi] BŁĄD: g_fieldManager nie istnieje!")
        return {}
    end

    if g_farmlandManager == nil then
        print("[ZywiSasiedzi] BŁĄD: g_farmlandManager nie istnieje!")
        return {}
    end

    local fields = g_fieldManager:getFields()
    if fields == nil then
        print("[ZywiSasiedzi] BŁĄD: Brak pól na mapie!")
        return {}
    end

    local results = {}

    for fieldIndex, field in pairs(fields) do
        local fieldData = FieldScanner.scanField(field, fieldIndex)
        if fieldData ~= nil then
            table.insert(results, fieldData)
        end
    end

    -- Sortujemy po ID pola dla czytelności
    table.sort(results, function(a, b) return a.fieldId < b.fieldId end)

    return results
end

--- Skanuje pojedyncze pole i zwraca jego dane
-- @param field — obiekt pola z g_fieldManager
-- @return table|nil — dane pola lub nil jeśli błąd
function FieldScanner.scanField(field, fieldIndex)
    if field == nil then
        return nil
    end

    local fieldData = {}

    -- Podstawowe informacje o polu
    -- W FS25 obiekt pola nie ma property fieldId — ID to klucz w tablicy z getFields()
    fieldData.fieldId = fieldIndex or field.fieldId or 0
    fieldData.posX = field.posX or 0
    fieldData.posZ = field.posZ or 0

    -- Powierzchnia pola (w hektarach)
    if field.getAreaHa ~= nil then
        fieldData.areaHa = field:getAreaHa()
    else
        fieldData.areaHa = 0
    end

    -- Sprawdzanie właściciela przez farmland
    fieldData.ownerFarmId = 0
    fieldData.isPlayerOwned = false
    fieldData.isNpcOwned = true

    local farmland = field.farmland
    if farmland ~= nil then
        fieldData.farmlandId = farmland.id or 0

        -- Pobieramy farmId właściciela (0 = niczyje pole)
        if g_farmlandManager.getFarmlandOwner ~= nil then
            fieldData.ownerFarmId = g_farmlandManager:getFarmlandOwner(farmland.id) or 0
        end

        -- Sprawdzamy czy pole należy do gracza (farmId 1 = gracz w FS25)
        -- Pole jest gracza gdy ma właściciela z farmId > 0 (kupione przez jakąś farmę)
        if fieldData.ownerFarmId > 0 then
            -- Sprawdzamy czy to farma gracza
            local playerFarmId = 1 -- domyślne farmId gracza w FS25
            if g_currentMission ~= nil and g_currentMission.player ~= nil and g_currentMission.player.farmId ~= nil then
                playerFarmId = g_currentMission.player.farmId
            end

            if fieldData.ownerFarmId == playerFarmId then
                fieldData.isPlayerOwned = true
                fieldData.isNpcOwned = false
            end
        end
        -- Jeśli ownerFarmId == 0, pole jest niczyje — traktujemy jako NPC

        -- Cena pola
        fieldData.price = farmland.price or 0
    else
        fieldData.farmlandId = 0
        fieldData.price = 0
    end

    -- Informacje o uprawie — odczyt z mapy gęstości w pozycji pola
    fieldData.fruitTypeName = "brak"
    fieldData.fruitTypeIndex = 0
    fieldData.growthState = 0

    -- Używamy FSDensityMapUtil do odczytu danych o uprawie
    if FSDensityMapUtil ~= nil and FSDensityMapUtil.getFieldDataAtWorldPosition ~= nil then
        local x = fieldData.posX
        local z = fieldData.posZ
        -- getFieldDataAtWorldPosition zwraca: isOnField, fruitTypeIndex, growthState, sprayState, ...
        local isOnField, fruitTypeIndex, growthState = FSDensityMapUtil.getFieldDataAtWorldPosition(x, 0, z)

        if isOnField and fruitTypeIndex ~= nil and fruitTypeIndex > 0 then
            fieldData.fruitTypeIndex = fruitTypeIndex
            fieldData.growthState = growthState or 0

            -- Pobieramy nazwę uprawy
            if g_fruitTypeManager ~= nil then
                local fruitType = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
                if fruitType ~= nil then
                    fieldData.fruitTypeName = fruitType.name or "nieznana"
                end
            end
        end
    end

    return fieldData
end

--- Filtruje pola — zwraca tylko pola NIE należące do gracza
-- Te pola mogą być przypisane sąsiadom
-- @param allFields table — wynik z scanAllFields()
-- @return table — lista pól NPC
function FieldScanner.getNpcFields(allFields)
    local npcFields = {}

    for _, fieldData in ipairs(allFields) do
        if not fieldData.isPlayerOwned then
            table.insert(npcFields, fieldData)
        end
    end

    return npcFields
end

--- Filtruje pola — zwraca tylko pola gracza
-- @param allFields table — wynik z scanAllFields()
-- @return table — lista pól gracza
function FieldScanner.getPlayerFields(allFields)
    local playerFields = {}

    for _, fieldData in ipairs(allFields) do
        if fieldData.isPlayerOwned then
            table.insert(playerFields, fieldData)
        end
    end

    return playerFields
end

--- Wypisuje raport z skanowania pól do konsoli
-- @param allFields table — wynik z scanAllFields()
function FieldScanner.printReport(allFields)
    print("[ZywiSasiedzi] ==========================================")
    print("[ZywiSasiedzi]       RAPORT SKANOWANIA PÓL")
    print("[ZywiSasiedzi] ==========================================")
    print(string.format("[ZywiSasiedzi] Liczba pól na mapie: %d", #allFields))

    local npcFields = FieldScanner.getNpcFields(allFields)
    local playerFields = FieldScanner.getPlayerFields(allFields)

    print(string.format("[ZywiSasiedzi] Pola gracza: %d", #playerFields))
    print(string.format("[ZywiSasiedzi] Pola NPC (dla sąsiadów): %d", #npcFields))
    print("[ZywiSasiedzi] ------------------------------------------")

    for _, fd in ipairs(allFields) do
        local ownerStr = fd.isPlayerOwned and "GRACZ" or "NPC"
        print(string.format(
            "[ZywiSasiedzi] Pole #%d | %s | %.1f ha | Uprawa: %s (stan: %d) | Pos: %.0f, %.0f",
            fd.fieldId,
            ownerStr,
            fd.areaHa,
            fd.fruitTypeName,
            fd.growthState,
            fd.posX,
            fd.posZ
        ))
    end

    print("[ZywiSasiedzi] ==========================================")
end
