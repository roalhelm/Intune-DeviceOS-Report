# Intune Device OS Report - Handlungsempfehlungen

## Übersicht

Dieses Dokument erklärt die verschiedenen Handlungsempfehlungen im Spalte `RecommendedAction` des Device OS Reports und beschreibt, welche Aktionen basierend auf den Status-Kombinationen empfohlen werden.

---

## Spalten im Report

### Status-Spalten

| Spalte | Beschreibung |
|--------|--------------|
| **IntuneStatus** | Verwaltungsstatus in Microsoft Intune (Active, Retired, Wiped, etc.) |
| **EntraIDStatus** | Gerätestatus in Microsoft Entra ID (Enabled, Disabled, No Entra ID Link, etc.) |
| **DaysSinceLastCheckIn** | Anzahl der Tage seit dem letzten Check-in des Geräts in Intune |

---

## Handlungsempfehlungen (RecommendedAction)

### Aktive Geräte

#### **Keep Active**
- **Bedeutung:** Gerät ist aktiv und sollte weiter verwaltet werden
- **Bedingungen:**
  - IntuneStatus: `Active`
  - EntraIDStatus: `Enabled`
  - Letzter Check-in: < 30 Tage
- **Aktion:** Keine Aktion erforderlich

---

### Überwachung erforderlich

#### **Watch (>30 days inactive)**
- **Bedeutung:** Gerät ist über 30 Tage inaktiv
- **Bedingungen:**
  - Letzter Check-in: 30-60 Tage
- **Aktion:** Gerät beobachten, ggf. Benutzer kontaktieren

#### **Monitor (>60 days inactive)**
- **Bedeutung:** Gerät ist über 60 Tage inaktiv
- **Bedingungen:**
  - Letzter Check-in: 60-90 Tage
- **Aktion:** Genauer überwachen, Deaktivierung in Erwägung ziehen

#### **Consider Disabling (>90 days inactive)**
- **Bedeutung:** Gerät ist über 90 Tage nicht aktiv
- **Bedingungen:**
  - IntuneStatus: `Active`
  - EntraIDStatus: `Enabled`
  - Letzter Check-in: > 90 Tage
- **Aktion:** Deaktivierung stark empfohlen, mit IT/Benutzer klären

---

### Bereinigung erforderlich

#### **Disable in Entra ID**
- **Bedeutung:** Gerät wurde in Intune bereits retired/gelöscht, ist aber in Entra ID noch aktiv
- **Bedingungen:**
  - IntuneStatus: `Retired`, `Wiped`, `Retire Pending` oder `Wipe Pending`
  - EntraIDStatus: `Enabled`
- **Aktion:** Gerät in Entra ID deaktivieren oder löschen

#### **Clean up Intune**
- **Bedeutung:** Gerät ist in Entra ID deaktiviert, aber noch in Intune registriert
- **Bedingungen:**
  - EntraIDStatus: `Disabled`
  - Letzter Check-in: > 90 Tage
- **Aktion:** Gerät aus Intune entfernen (Retire/Delete)

#### **Retire from Intune**
- **Bedeutung:** Gerät ist in Entra ID deaktiviert, aber in Intune noch als aktiv markiert
- **Bedingungen:**
  - IntuneStatus: `Active`
  - EntraIDStatus: `Disabled`
- **Aktion:** Gerät in Intune retire/wipe durchführen

#### **Entra ID Missing - Clean up Intune**
- **Bedeutung:** Das Entra ID Geräteobjekt wurde gelöscht, aber Gerät existiert noch in Intune
- **Bedingungen:**
  - EntraIDStatus: `Entra ID Object Not Found`
  - AzureAdDeviceId ist vorhanden, aber Gerät in Entra ID nicht mehr existent
- **Aktion:** Gerät aus Intune entfernen

---

### Bereits inaktiv

#### **Already Inactive**
- **Bedeutung:** Gerät ist sowohl in Intune als auch in Entra ID deaktiviert/retired
- **Bedingungen:**
  - IntuneStatus: `Retired`, `Wiped`, `Retire Pending` oder `Wipe Pending`
  - EntraIDStatus: `Disabled` oder `Entra ID Object Not Found`
- **Aktion:** Optional: Endgültig aus beiden Systemen löschen (falls Aufbewahrungsfristen erfüllt)

---

### Spezialfälle

#### **MDM Only - Review**
- **Bedeutung:** Gerät ist nur per MDM registriert, ohne Entra ID Verknüpfung
- **Bedingungen:**
  - EntraIDStatus: `No Entra ID Link`
  - Keine AzureAdDeviceId vorhanden
- **Aktion:** Prüfen, ob dies beabsichtigt ist (z.B. Workplace Join, BYOD-Geräte)

#### **Not in Intune - Review**
- **Bedeutung:** Gerät wurde in der Abfrage nicht in Intune gefunden
- **Bedingungen:**
  - Gerät existiert nicht in Intune
- **Aktion:** Prüfen, ob Gerät registriert werden sollte oder Eintrag in CSV veraltet ist

#### **Review Required**
- **Bedeutung:** Unklare Statuskombination, manuelle Prüfung erforderlich
- **Bedingungen:**
  - Keine der anderen Regeln trifft zu
  - Ungewöhnliche Statuskombination
- **Aktion:** Manuell prüfen und entsprechende Maßnahmen ergreifen

---

## Entra ID Status - Bedeutungen

| Status | Bedeutung |
|--------|-----------|
| **Enabled** | Gerät ist in Entra ID aktiviert |
| **Disabled** | Gerät ist in Entra ID deaktiviert |
| **No Entra ID Link** | Gerät hat keine Verknüpfung zu Entra ID (z.B. MDM-only, Workplace Join) |
| **Entra ID Object Not Found** | AzureAdDeviceId existiert, aber Geräteobjekt wurde aus Entra ID gelöscht |
| **Error** | Fehler beim Abrufen des Entra ID Status |
| **Not found** | Gerät nicht in Intune gefunden |

---

## Intune Status - Bedeutungen

| Status | Bedeutung |
|--------|-----------|
| **Active** | Gerät wird aktiv verwaltet |
| **Retire Pending** | Außerbetriebnahme wurde eingeleitet |
| **Retired** | Gerät wurde außer Betrieb genommen |
| **Wipe Pending** | Löschung wurde eingeleitet |
| **Wiped** | Gerät wurde gelöscht |
| **Not found** | Gerät nicht in Intune gefunden |

---

## Workflow-Empfehlung

1. **Report ausführen** und CSV-Datei öffnen
2. **Nach RecommendedAction sortieren/filtern**
3. **Prioritäten setzen:**
   - Zuerst: Geräte mit "Disable in Entra ID", "Retire from Intune", "Clean up Intune"
   - Dann: Geräte mit ">90 days inactive"
   - Danach: Geräte mit ">60 days inactive"
4. **Validierung:** Vor Deaktivierung mit IT-Team/Benutzer abklären
5. **Dokumentation:** Änderungen protokollieren

---

## Empfohlene Aufbewahrungsfristen

- **Aktive Geräte:** Unbegrenzt
- **30-60 Tage inaktiv:** Weiter überwachen
- **60-90 Tage inaktiv:** Vorbereitung zur Deaktivierung
- **> 90 Tage inaktiv:** Deaktivieren/Entfernen
- **Retired/Wiped:** 30-90 Tage Aufbewahrung in Logs, dann löschen

---

## Berechtigungen

Für das Abrufen der Daten benötigt das Skript folgende Microsoft Graph Berechtigungen:

- `DeviceManagementConfiguration.Read.All` - Intune Konfiguration lesen
- `DeviceManagementManagedDevices.Read.All` - Intune Geräte lesen
- `Device.Read.All` - Entra ID Gerätestatus lesen

---

## Version

Dieses Dokument gilt für OSVersionReport.ps1 Version 1.2 (2026-01-13)
