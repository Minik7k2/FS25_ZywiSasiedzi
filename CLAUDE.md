# CLAUDE.md — Instrukcje dla Claude Code

## PROJEKT

Mod "Żywi Sąsiedzi" (FS25_ZywiSasiedzi) do Farming Simulator 25.
Dodaje wirtualnych sąsiadów-farmerów, którzy pracują maszynami na polach
nienależących do gracza. Wykorzystuje ISTNIEJĄCE systemy gry (AIJobFieldWork),
NIE piszemy własnego AI.

## ŚRODOWISKO PRACY

- Projekt: repozytorium Git, katalog główny = katalog moda
- Język skryptów: Lua (GIANTS Engine API)
- Konfiguracja: XML
- Docelowy folder gry: ~/Documents/My Games/FarmingSimulator2025/mods/FS25_ZywiSasiedzi/
  (user robi symlink z repo do tego folderu — zmiany widoczne od razu w grze)
- Po każdym etapie: commituj z opisem co zostało zrobione
- Tagi Git: po ukończeniu etapu taguj jako v0.1.0, v0.2.0 itd.

## ZASADY

1. Pracuj ETAPAMI — nie przechodź dalej bez zgody użytkownika
2. Twórz pliki bezpośrednio w strukturze projektu (NIE wyświetlaj kodu do kopiowania)
3. Po każdym etapie: `git add -A && git commit -m "Etap X: opis"`
4. Komentarze w kodzie PO POLSKU
5. Używaj TYLKO istniejących API gry — nie wymyślaj funkcji
6. Jeśli nie jesteś pewien czy API istnieje w FS25, powiedz to otwarcie
7. Wyjaśniaj kluczowe fragmenty kodu — użytkownik się uczy
8. Przed etapami 2-5: sklonuj i przeanalizuj odpowiednie źródła base game z GitHub

## STRUKTURA PROJEKTU

```
FS25_ZywiSasiedzi/           ← root repo = root moda
├── CLAUDE.md                 ← ten plik (instrukcje dla Claude Code)
├── README.md                 ← opis moda dla użytkowników/GitHub
├── .gitignore                ← *.zip, *.log, *.bak, /tmp/
├── modDesc.xml               ← metadane moda, wpisy skryptów
├── icon.dds                  ← ikona moda (256x256)
├── scripts/
│   ├── ZywiSasiedzi.lua      ← główny: ładowanie, zapis, update loop
│   ├── NeighborManager.lua   ← zarządzanie sąsiadami i ich polami
│   ├── FieldScanner.lua      ← skanowanie pól: właściciel, uprawy, stan
│   └── WorkDispatcher.lua    ← spawn maszyn + odpalanie AIJobFieldWork
├── xml/
│   └── config.xml            ← konfiguracja: sąsiedzi, maszyny, limity
└── l10n/
    ├── l10n_en.xml           ← tłumaczenia angielskie
    └── l10n_pl.xml           ← tłumaczenia polskie
```

## PLAN ETAPÓW

### ETAP 1: Szkielet moda
Cel: Mod ładuje się w grze i wypisuje komunikat w konsoli.

### ETAP 2: Skanowanie pól
Cel: Mod wykrywa pola i wypisuje raport w konsoli.

### ETAP 3: System sąsiadów
Cel: Wirtualni sąsiedzi z przypisanymi polami.

### ETAP 4: Spawnowanie maszyn
Cel: Na polu sąsiada pojawia się traktor z narzędziem.

### ETAP 5: Uruchomienie AI Worker (CORE)
Cel: Maszyna zaczyna sama pracować na polu.

### ETAP 6: Kalendarz i logika
Cel: Praca zależna od pory roku i pogody.

### ETAP 7: Polish i publikacja
Cel: Mod gotowy do udostępnienia.

## INFORMACJE TECHNICZNE

### Kluczowe API
- g_currentMission — sesja gry
- g_currentMission.environment — pogoda, pora roku
- g_farmlandManager — pola, właściciele
- g_fieldManager — uprawy, stan wzrostu
- g_currentMission.aiJobTypeManager — typy jobów AI
- g_currentModName — TYLKO podczas ładowania pliku! Zapisz do zmiennej.

### Ostrzeżenia
1. NIE pisz własnego pathfindingu — użyj AIJobFieldWork
2. Testuj z JEDNYM pojazdem, potem skaluj
3. ZAWSZE despawnuj maszyny po zakończeniu pracy
4. Sprawdzaj vehicle.isDeleted przed operacjami
5. Sprawdzaj g_currentMission ~= nil w callbackach async
6. Max 3-5 jednoczesnych maszyn (wydajność)
7. g_currentModName dostępne TYLKO podczas ładowania pliku
8. self:raiseActive() konieczne w onUpdate()
