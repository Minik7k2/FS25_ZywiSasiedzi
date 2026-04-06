# FS25_ZywiSasiedzi — Żywi Sąsiedzi

Mod do **Farming Simulator 25** dodający wirtualnych sąsiadów-farmerów, którzy pracują maszynami na polach nienależących do gracza.

## Funkcje

- Wirtualni sąsiedzi z przypisanymi polami
- Sąsiedzi pracują maszynami (orka, siew, żniwa) korzystając z systemu AI gry
- Prace zależne od pory roku i pogody
- Konfiguracja przez XML

## Instalacja

1. Pobierz mod (ZIP lub sklonuj repo)
2. Umieść folder `FS25_ZywiSasiedzi` w katalogu modów:
   - Windows: `Dokumenty/My Games/FarmingSimulator2025/mods/`
   - Lub utwórz symlink do repozytorium (dla developerów)
3. Włącz mod w menedżerze modów w grze

## Dla developerów

### Symlink (Windows, CMD jako administrator)
```cmd
mklink /D "%USERPROFILE%\Documents\My Games\FarmingSimulator2025\mods\FS25_ZywiSasiedzi" "C:\sciezka\do\repo\FS25_ZywiSasiedzi"
```

### Developer Mode
Edytuj `Dokumenty/My Games/FarmingSimulator2025/game.xml`:
```xml
<development>
    <controls>true</controls>
</development>
```

### Komendy konsolowe (klawisz ~)
- `zsTest` — testowa komenda, sprawdza czy mod działa
- `zsStatus` — wyświetla status moda

## Status

- [x] Etap 1: Szkielet moda
- [x] Etap 2: Skanowanie pól
- [ ] Etap 3: System sąsiadów
- [ ] Etap 4: Spawnowanie maszyn
- [ ] Etap 5: AI Worker
- [ ] Etap 6: Kalendarz i logika
- [ ] Etap 7: Polish i publikacja

## Licencja

Wszelkie prawa zastrzeżone.
