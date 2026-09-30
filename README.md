# IdeaBox (“Idee”)

App iOS personale per raccogliere idee: testo, note vocali (con trascrizione in italiano) e post condivisi da Instagram, TikTok, YouTube, Safari e altre app tramite il foglio di condivisione.

- SwiftUI + SwiftData, iOS 17+
- Sincronizzazione iCloud (CloudKit, database privato) tra i tuoi dispositivi; app ed estensione condividono il database via App Group
- Trascrizione con Speech framework (on-device se disponibile)

## Avvio

Serve un Mac con Xcode 15+.

```sh
brew install xcodegen
xcodegen            # genera IdeaBox.xcodeproj da project.yml
open IdeaBox.xcodeproj
```

1. In `project.yml` imposta `DEVELOPMENT_TEAM` (o scegli il team in Xcode > Signing).
2. Se cambi il prefisso `com.vincenzo`, aggiorna anche l'App Group `group.com.vincenzo.ideabox` in `project.yml` e in `Shared/Persistence.swift`.
3. Esegui su un dispositivo reale: microfono e trascrizione funzionano male nel simulatore.

## Struttura

| Cartella | Contenuto |
|---|---|
| `Shared/` | Modelli, database, riconoscimento della fonte (usati da app ed estensione) |
| `App/` | Lista, dettaglio, registratore, riproduzione, trascrizione |
| `ShareExtension/` | “Salva in Idee” nel menu Condividi |

## Limiti noti

- Da Instagram arriva solo il **link** del post (non il video/immagine): iOS non li passa alle estensioni. Il titolo viene recuperato quando possibile, ma per i post privati o dietro login resta solo il link. Per questo c'è il campo nota nel momento della condivisione.
- iCloud: nel portale Apple Developer crea il container `iCloud.com.vincenzo.ideabox` (Xcode lo fa da solo con il Team impostato). Senza iCloud attivo l'app funziona in locale.
- Le note vocali sono salvate nel database (asset CloudKit), quindi contano nello spazio iCloud.
- Prima di pubblicare su TestFlight/App Store, porta `aps-environment` a `production` e distribuisci lo schema CloudKit dal CloudKit Console.
