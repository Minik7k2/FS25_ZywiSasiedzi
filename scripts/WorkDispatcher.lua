-- ============================================================================
-- WorkDispatcher.lua — Spawnowanie maszyn na polach sąsiadów
-- Etap 4: Traktor z narzędziem pojawia się na polu sąsiada
-- ============================================================================

WorkDispatcher = {}

-- Aktywne pojazdy sąsiadów (tablica rekordów spawnu)
WorkDispatcher.activeVehicles = {}

-- Maksymalna liczba jednoczesnych pojazdów
WorkDispatcher.maxActiveVehicles = 3

-- Zestawy pojazdów: traktor + narzędzie
-- Ścieżki XML odnoszą się do plików base game FS25
-- Można je nadpisać w xml/config.xml
WorkDispatcher.vehicleSets = {
    {
        name = "Uprawa",
        tractorXML = "data/vehicles/fendt/vario300/vario300.xml",
        implementXML = "data/vehicles/kuhn/cultimer300/cultimer300.xml",
    },
}

--- Inicjalizacja WorkDispatcher
function WorkDispatcher.init()
    WorkDispatcher.activeVehicles = {}
    WorkDispatcher.loadConfig()
    print("[ZywiSasiedzi] WorkDispatcher zainicjalizowany")
    print(string.format("[ZywiSasiedzi]   Zestawy pojazdów: %d", #WorkDispatcher.vehicleSets))
    print(string.format("[ZywiSasiedzi]   Max aktywnych: %d", WorkDispatcher.maxActiveVehicles))
end

--- Wczytuje konfigurację pojazdów z xml/config.xml
function WorkDispatcher.loadConfig()
    if ZywiSasiedzi.modDir == nil then
        print("[ZywiSasiedzi] OSTRZEŻENIE: brak modDir, pomijam config.xml")
        return
    end

    local configPath = ZywiSasiedzi.modDir .. "xml/config.xml"
    local xmlFile = loadXMLFile("ZywiSasiedzi_config", configPath)

    if xmlFile == nil or xmlFile == 0 then
        print("[ZywiSasiedzi] Nie znaleziono config.xml, używam domyślnych zestawów")
        return
    end

    -- Wczytaj ustawienia ogólne
    local maxVehicles = getXMLInt(xmlFile, "zywiSasiedzi.settings#maxConcurrentVehicles")
    if maxVehicles ~= nil and maxVehicles > 0 then
        WorkDispatcher.maxActiveVehicles = maxVehicles
    end

    -- Wczytaj zestawy pojazdów
    local sets = {}
    local i = 0
    while true do
        local key = string.format("zywiSasiedzi.vehicleSets.vehicleSet(%d)", i)
        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local name = getXMLString(xmlFile, key .. "#name") or string.format("Zestaw #%d", i + 1)
        local tractorXML = getXMLString(xmlFile, key .. "#tractorXML")
        local implementXML = getXMLString(xmlFile, key .. "#implementXML")

        if tractorXML ~= nil then
            table.insert(sets, {
                name = name,
                tractorXML = tractorXML,
                implementXML = implementXML,
            })
        end

        i = i + 1
    end

    delete(xmlFile)

    -- Jeśli znaleziono zestawy w configu, podmień domyślne
    if #sets > 0 then
        WorkDispatcher.vehicleSets = sets
        print(string.format("[ZywiSasiedzi] Wczytano %d zestawów pojazdów z config.xml", #sets))
    end
end

--- Spawnuje traktor z narzędziem na polu sąsiada
-- @param fieldData table — dane pola z FieldScanner
-- @param vehicleSetIndex number — indeks zestawu pojazdów (domyślnie 1)
-- @return boolean — true jeśli rozpoczęto ładowanie
function WorkDispatcher.spawnAtField(fieldData, vehicleSetIndex)
    if fieldData == nil then
        print("[ZywiSasiedzi] BŁĄD: brak danych pola do spawnu")
        return false
    end

    if g_currentMission == nil then
        print("[ZywiSasiedzi] BŁĄD: g_currentMission nie istnieje!")
        return false
    end

    -- Sprawdź limit aktywnych pojazdów
    if #WorkDispatcher.activeVehicles >= WorkDispatcher.maxActiveVehicles then
        print("[ZywiSasiedzi] Limit aktywnych pojazdów osiągnięty: " .. #WorkDispatcher.activeVehicles)
        return false
    end

    -- Sprawdź czy na tym polu nie ma już pojazdu
    for _, record in ipairs(WorkDispatcher.activeVehicles) do
        if record.fieldId == fieldData.fieldId then
            print(string.format("[ZywiSasiedzi] Na polu #%d już jest pojazd", fieldData.fieldId))
            return false
        end
    end

    local setIndex = vehicleSetIndex or 1
    local vehicleSet = WorkDispatcher.vehicleSets[setIndex]
    if vehicleSet == nil then
        print("[ZywiSasiedzi] BŁĄD: nieznany zestaw pojazdów: " .. tostring(setIndex))
        return false
    end

    -- Pozycja spawnu: środek pola
    local x = fieldData.posX or 0
    local z = fieldData.posZ or 0

    -- farmId sąsiada (dla własności pojazdu)
    local farmId = fieldData.neighborFarmId or 0

    print(string.format("[ZywiSasiedzi] Spawnuję '%s' na polu #%d (pos: %.0f, %.0f) dla farmId %d...",
        vehicleSet.name, fieldData.fieldId, x, z, farmId))

    -- Tworzymy rekord śledzenia
    local spawnRecord = {
        fieldId = fieldData.fieldId,
        fieldData = fieldData,
        vehicleSet = vehicleSet,
        tractor = nil,
        implement = nil,
        state = "loading_tractor", -- loading_tractor -> loading_implement -> attaching -> ready
        farmId = farmId,
        x = x,
        z = z,
    }

    table.insert(WorkDispatcher.activeVehicles, spawnRecord)

    -- Ładujemy traktor (asynchronicznie przez VehicleLoadingData)
    WorkDispatcher.loadVehicle(vehicleSet.tractorXML, x, z, farmId, spawnRecord, "onTractorLoaded")

    return true
end

--- Ładuje pojazd z pliku XML używając VehicleLoadingData (API FS25)
-- @param xmlFilename string — ścieżka do XML pojazdu
-- @param x number — pozycja X na mapie
-- @param z number — pozycja Z na mapie
-- @param farmId number — ID farmy właściciela
-- @param spawnRecord table — rekord spawnu (przekazywany do callbacka)
-- @param callbackName string — nazwa metody callback w WorkDispatcher
function WorkDispatcher.loadVehicle(xmlFilename, x, z, farmId, spawnRecord, callbackName)
    -- Sprawdzamy dostępność API
    if VehicleLoadingData == nil then
        print("[ZywiSasiedzi] BŁĄD: VehicleLoadingData niedostępne w tej wersji gry!")
        WorkDispatcher.removeSpawnRecord(spawnRecord)
        return
    end

    -- Tworzymy obiekt VehicleLoadingData
    local loadingData = VehicleLoadingData.new()

    -- Ustawiamy plik XML pojazdu
    loadingData:setFilename(xmlFilename)

    -- Pozycja: y=nil sprawia że FS25 sam pobierze wysokość terenu
    loadingData:setPosition(x, nil, z)

    -- Rotacja: 0 stopni
    loadingData:setRotation(0, 0, 0)

    -- Pojazd nie jest zapisywany w savegame (tymczasowy)
    loadingData:setIsSaved(false)

    -- Dodaj do fizyki (żeby pojazd był widoczny i interaktywny)
    loadingData:setAddToPhysics(true)

    -- Stan własności: OWNED (żeby sąsiad "posiadał" pojazd)
    if VehiclePropertyState ~= nil then
        loadingData:setPropertyState(VehiclePropertyState.OWNED)
    end

    -- Przypisz do farmy sąsiada
    loadingData:setOwnerFarmId(farmId)

    -- Nie rejestruj pojazdu (nie pojawi się w menu gracza)
    loadingData:setIsRegistered(false)

    print(string.format("[ZywiSasiedzi] Ładuję pojazd: %s", xmlFilename))

    -- Rozpocznij asynchroniczne ładowanie
    loadingData:load(
        function(vehicles, vehicleLoadState, args)
            -- Callback po załadowaniu
            WorkDispatcher[callbackName](vehicles, vehicleLoadState, args)
        end,
        nil,
        spawnRecord
    )
end

--- Callback po załadowaniu traktora
-- @param vehicles table — załadowane pojazdy
-- @param vehicleLoadState number — stan ładowania
-- @param spawnRecord table — rekord spawnu
function WorkDispatcher.onTractorLoaded(vehicles, vehicleLoadState, spawnRecord)
    -- Sprawdź stan ładowania
    if VehicleLoadingUtil ~= nil and vehicleLoadState ~= VehicleLoadingUtil.VEHICLE_LOAD_OK then
        print(string.format("[ZywiSasiedzi] BŁĄD ładowania traktora (stan: %s)",
            tostring(vehicleLoadState)))
        WorkDispatcher.removeSpawnRecord(spawnRecord)
        return
    end

    -- Pobierz załadowany pojazd (pierwszy z listy)
    local tractor = nil
    if vehicles ~= nil then
        if type(vehicles) == "table" then
            tractor = vehicles[1] or vehicles
        else
            tractor = vehicles
        end
    end

    if tractor == nil then
        print("[ZywiSasiedzi] BŁĄD: traktor nie został załadowany (nil)")
        WorkDispatcher.removeSpawnRecord(spawnRecord)
        return
    end

    spawnRecord.tractor = tractor
    spawnRecord.state = "loading_implement"

    print(string.format("[ZywiSasiedzi] Traktor załadowany na polu #%d: %s",
        spawnRecord.fieldId, tostring(tractor:getFullName and tractor:getFullName() or "?")))

    -- Jeśli zestaw ma narzędzie, ładujemy je obok traktora
    if spawnRecord.vehicleSet.implementXML ~= nil then
        -- Spawnujemy narzędzie nieco obok traktora (offset 5m w X)
        local implX = spawnRecord.x + 5
        local implZ = spawnRecord.z

        WorkDispatcher.loadVehicle(
            spawnRecord.vehicleSet.implementXML,
            implX, implZ,
            spawnRecord.farmId,
            spawnRecord,
            "onImplementLoaded"
        )
    else
        -- Brak narzędzia — traktor sam gotowy
        spawnRecord.state = "ready"
        print(string.format("[ZywiSasiedzi] Pojazd gotowy na polu #%d (bez narzędzia)",
            spawnRecord.fieldId))
    end
end

--- Callback po załadowaniu narzędzia
-- @param vehicles table — załadowane pojazdy
-- @param vehicleLoadState number — stan ładowania
-- @param spawnRecord table — rekord spawnu
function WorkDispatcher.onImplementLoaded(vehicles, vehicleLoadState, spawnRecord)
    -- Sprawdź stan ładowania
    if VehicleLoadingUtil ~= nil and vehicleLoadState ~= VehicleLoadingUtil.VEHICLE_LOAD_OK then
        print(string.format("[ZywiSasiedzi] BŁĄD ładowania narzędzia (stan: %s)",
            tostring(vehicleLoadState)))
        -- Traktor został załadowany, ale narzędzie nie — kontynuuj bez narzędzia
        spawnRecord.state = "ready"
        return
    end

    -- Pobierz załadowane narzędzie
    local implement = nil
    if vehicles ~= nil then
        if type(vehicles) == "table" then
            implement = vehicles[1] or vehicles
        else
            implement = vehicles
        end
    end

    if implement == nil then
        print("[ZywiSasiedzi] OSTRZEŻENIE: narzędzie nie załadowane, kontynuuję bez")
        spawnRecord.state = "ready"
        return
    end

    spawnRecord.implement = implement
    spawnRecord.state = "attaching"

    print(string.format("[ZywiSasiedzi] Narzędzie załadowane na polu #%d: %s",
        spawnRecord.fieldId, tostring(implement:getFullName and implement:getFullName() or "?")))

    -- Podepnij narzędzie do traktora
    WorkDispatcher.attachImplementToTractor(spawnRecord)
end

--- Podłącza narzędzie do traktora przez system AttacherJoints
-- @param spawnRecord table — rekord spawnu z traktorem i narzędziem
function WorkDispatcher.attachImplementToTractor(spawnRecord)
    local tractor = spawnRecord.tractor
    local implement = spawnRecord.implement

    if tractor == nil or implement == nil then
        print("[ZywiSasiedzi] BŁĄD: brak traktora lub narzędzia do podpięcia")
        spawnRecord.state = "ready"
        return
    end

    -- Sprawdź czy traktor ma spec_attacherJoints (system podpinania)
    if tractor.getAttacherJoints == nil then
        print("[ZywiSasiedzi] OSTRZEŻENIE: traktor nie ma attacherJoints, pomijam podpięcie")
        spawnRecord.state = "ready"
        return
    end

    -- Pobierz dostępne punkty zaczepienia traktora
    local joints = tractor:getAttacherJoints()
    if joints == nil or #joints == 0 then
        print("[ZywiSasiedzi] OSTRZEŻENIE: traktor nie ma punktów zaczepienia")
        spawnRecord.state = "ready"
        return
    end

    -- Sprawdź czy narzędzie ma inputAttacherJoints
    if implement.getInputAttacherJoints == nil then
        print("[ZywiSasiedzi] OSTRZEŻENIE: narzędzie nie ma inputAttacherJoints")
        spawnRecord.state = "ready"
        return
    end

    local inputJoints = implement:getInputAttacherJoints()
    if inputJoints == nil or #inputJoints == 0 then
        print("[ZywiSasiedzi] OSTRZEŻENIE: narzędzie nie ma punktów wejścia")
        spawnRecord.state = "ready"
        return
    end

    -- Szukamy pasującego połączenia (pierwszy kompatybilny joint)
    local bestJointIndex = nil
    local bestInputIndex = nil

    for jointIndex, joint in ipairs(joints) do
        for inputIndex, inputJoint in ipairs(inputJoints) do
            -- Sprawdź kompatybilność typów (jointType musi pasować)
            if joint.jointType ~= nil and inputJoint.jointType ~= nil then
                if joint.jointType == inputJoint.jointType then
                    bestJointIndex = jointIndex
                    bestInputIndex = inputIndex
                    break
                end
            end
        end
        if bestJointIndex ~= nil then
            break
        end
    end

    -- Fallback: użyj pierwszego dostępnego jointa
    if bestJointIndex == nil then
        bestJointIndex = 1
        bestInputIndex = 1
        print("[ZywiSasiedzi] Nie znaleziono pasującego jointa, próbuję pierwszy dostępny")
    end

    -- Podepnij narzędzie do traktora
    -- attachImplement(object, inputJointDescIndex, jointDescIndex, skipTrigger,
    --                 implementIndex, moveDown, loadFromSavegame, loadedFromSavegame)
    local success = pcall(function()
        tractor:attachImplement(implement, bestInputIndex, bestJointIndex, true, nil, true, false, false)
    end)

    if success then
        print(string.format("[ZywiSasiedzi] Narzędzie podpięte do traktora na polu #%d",
            spawnRecord.fieldId))
    else
        print(string.format("[ZywiSasiedzi] OSTRZEŻENIE: nie udało się podpiąć narzędzia na polu #%d",
            spawnRecord.fieldId))
    end

    spawnRecord.state = "ready"
end

--- Despawnuje pojazdy z danego pola
-- @param fieldId number — ID pola
-- @return boolean — true jeśli despawn się udał
function WorkDispatcher.despawnFromField(fieldId)
    local recordIndex = nil

    for i, record in ipairs(WorkDispatcher.activeVehicles) do
        if record.fieldId == fieldId then
            recordIndex = i
            break
        end
    end

    if recordIndex == nil then
        print(string.format("[ZywiSasiedzi] Brak pojazdów na polu #%d", fieldId))
        return false
    end

    local record = WorkDispatcher.activeVehicles[recordIndex]
    WorkDispatcher.cleanupRecord(record)
    table.remove(WorkDispatcher.activeVehicles, recordIndex)

    print(string.format("[ZywiSasiedzi] Pojazdy usunięte z pola #%d", fieldId))
    return true
end

--- Despawnuje wszystkie aktywne pojazdy
function WorkDispatcher.despawnAll()
    local count = #WorkDispatcher.activeVehicles

    for i = #WorkDispatcher.activeVehicles, 1, -1 do
        local record = WorkDispatcher.activeVehicles[i]
        WorkDispatcher.cleanupRecord(record)
    end

    WorkDispatcher.activeVehicles = {}
    print(string.format("[ZywiSasiedzi] Usunięto %d zestawów pojazdów", count))
end

--- Czyści pojazdy z rekordu spawnu (odłącza i usuwa)
-- @param record table — rekord spawnu
function WorkDispatcher.cleanupRecord(record)
    if record == nil then return end

    -- Najpierw odłącz narzędzie (jeśli podpięte)
    if record.tractor ~= nil and record.implement ~= nil then
        pcall(function()
            if record.tractor.getAttachedImplements ~= nil then
                local attachedImpls = record.tractor:getAttachedImplements()
                for _, impl in ipairs(attachedImpls or {}) do
                    if impl.object == record.implement then
                        record.tractor:detachImplement(impl)
                        break
                    end
                end
            end
        end)
    end

    -- Usuń narzędzie
    if record.implement ~= nil then
        pcall(function()
            if not record.implement.isDeleted then
                g_currentMission.vehicleSystem:removeVehicle(record.implement)
            end
        end)
        record.implement = nil
    end

    -- Usuń traktor
    if record.tractor ~= nil then
        pcall(function()
            if not record.tractor.isDeleted then
                g_currentMission.vehicleSystem:removeVehicle(record.tractor)
            end
        end)
        record.tractor = nil
    end
end

--- Usuwa rekord spawnu z listy aktywnych (bez cleanup pojazdów)
-- @param spawnRecord table — rekord do usunięcia
function WorkDispatcher.removeSpawnRecord(spawnRecord)
    for i, record in ipairs(WorkDispatcher.activeVehicles) do
        if record == spawnRecord then
            table.remove(WorkDispatcher.activeVehicles, i)
            return
        end
    end
end

--- Wypisuje status aktywnych pojazdów
function WorkDispatcher.printStatus()
    print("[ZywiSasiedzi] ==========================================")
    print("[ZywiSasiedzi]       STATUS POJAZDÓW")
    print("[ZywiSasiedzi] ==========================================")
    print(string.format("[ZywiSasiedzi] Aktywne pojazdy: %d / %d",
        #WorkDispatcher.activeVehicles, WorkDispatcher.maxActiveVehicles))

    if #WorkDispatcher.activeVehicles == 0 then
        print("[ZywiSasiedzi] Brak aktywnych pojazdów")
    else
        for _, record in ipairs(WorkDispatcher.activeVehicles) do
            local tractorName = "?"
            if record.tractor ~= nil and record.tractor.getFullName ~= nil then
                tractorName = record.tractor:getFullName()
            end

            local implName = "brak"
            if record.implement ~= nil and record.implement.getFullName ~= nil then
                implName = record.implement:getFullName()
            end

            print(string.format("[ZywiSasiedzi]   Pole #%d | Stan: %s | Traktor: %s | Narzędzie: %s",
                record.fieldId, record.state, tractorName, implName))
        end
    end

    print("[ZywiSasiedzi] ==========================================")
end

--- Listuje dostępne pojazdy w sklepie (do debugowania ścieżek XML)
function WorkDispatcher.listStoreVehicles()
    if g_storeManager == nil then
        print("[ZywiSasiedzi] BŁĄD: g_storeManager niedostępny")
        return
    end

    print("[ZywiSasiedzi] ==========================================")
    print("[ZywiSasiedzi]   POJAZDY DOSTĘPNE W SKLEPIE (pierwsze 20)")
    print("[ZywiSasiedzi] ==========================================")

    local items = g_storeManager:getItems()
    local count = 0

    if items ~= nil then
        for _, item in ipairs(items) do
            if item.xmlFilename ~= nil and count < 20 then
                -- Pokazuj tylko pojazdy (mają categoryName)
                local category = item.categoryName or ""
                if category ~= "" then
                    print(string.format("[ZywiSasiedzi]   %s | %s",
                        item.xmlFilename, category))
                    count = count + 1
                end
            end
        end
    end

    print(string.format("[ZywiSasiedzi] Wyświetlono %d pozycji", count))
    print("[ZywiSasiedzi] ==========================================")
end
