# Ondelette 🌊

> Une *ondelette* est une petite onde localisée — le terme d'analyse du signal qui a donné son logo à l'app. (Anciennement « Parler ».)

Dictée vocale native pour macOS, dans l'esprit de [Wispr Flow](https://wisprflow.ai) : tu maintiens une touche, tu parles, le texte corrigé est collé dans l'app active.

- **Transcription 100 % locale** — Whisper large-v3-turbo (WhisperKit, CoreML, langue forcée) par défaut, Parakeet V3 (FluidAudio) en option ultra-rapide. Aucun audio n'est envoyé en ligne.
- **Correction GPT** (~1 s) via ta clé API OpenAI : ponctuation, hésitations supprimées, homophones réparés, vocabulaire personnel respecté. Si l'API échoue, le texte brut est collé — la dictée n'est jamais perdue.
- **Push-to-talk** : maintenir ⌥ droite (configurable ⌘ droite / Fn) · **double-appui** = dictée longue verrouillée · **Échap** = annuler.
- **Fenêtre principale** avec sidebar : Accueil (stats d'usage), Historique des dictées, Dictionnaire (vocabulaire personnalisé en pastilles), Réglages.
- **HUD Liquid Glass** : pilule sombre avec forme d'onde vivante pendant la dictée.
- Choix du micro (avec esquive automatique des micros Bluetooth pour ne pas dégrader le son des écouteurs), coupure du son pendant la dictée, normalisation du gain (chuchotement), presse-papiers restauré après collage, clé API dans le Trousseau.

## Prérequis

- macOS 26+ (Tahoe) sur Apple Silicon.
- Xcode Command Line Tools (`xcode-select --install`).
- Une clé API OpenAI (facultative — uniquement pour la correction).

## Compilation & installation

```bash
./build.sh            # compile et produit build/Parler.app
./build.sh --install  # compile, installe dans /Applications et relance
```

Le script signe avec ta première identité « Apple Development » disponible (signature stable → les autorisations persistent entre rebuilds), sinon en ad hoc.

## Premier lancement

1. **Micro** : accepte la demande d'accès.
2. **Accessibilité** : Réglages Système → Confidentialité et sécurité → Accessibilité → ajoute Parler (nécessaire pour la touche globale et le collage ⌘V). L'app réessaie automatiquement toutes les 3 s, pas besoin de relancer.
3. Le modèle Whisper (~1,6 Go) se télécharge automatiquement, puis est optimisé pour la puce neuronale (plusieurs minutes, une seule fois — statut visible dans le menu).
4. Menu (onde) → Réglages → colle ta clé API `sk-…`.

## Architecture

| Fichier | Rôle |
|---|---|
| `AppDelegate.swift` | Orchestration : barre de menus, machine à états de dictée |
| `HotkeyManager.swift` | Touche globale + Échap (CGEventTap) |
| `AudioRecorder.swift` | Capture micro (AVCaptureSession) → Float32 mono 16 kHz |
| `Transcriber.swift` | Whisper (WhisperKit) / Parakeet (FluidAudio), normalisation du gain |
| `Corrector.swift` | Correction via API OpenAI (reasoning_effort none, vocabulaire, langue forcée) |
| `Paster.swift` | Collage ⌘V simulé + restauration du presse-papiers |
| `HUD.swift` | Pilule Liquid Glass avec forme d'onde |
| `SettingsWindow.swift` | Fenêtre principale (sidebar : Accueil, Historique, Dictionnaire, Réglages) |
| `HistoryStore.swift` | Historique persistant des dictées + statistiques |
| `OutputMuter.swift` | Coupure/restauration du son pendant la dictée |
| `AudioDevices.swift` | Énumération CoreAudio des micros |
| `MenuBarIcon.swift` | Glyphe vectoriel de la barre de menus |

## Notes

- Les modèles vivent dans `~/Documents/huggingface` (Whisper) et `~/Library/Application Support/FluidAudio` (Parakeet).
- L'historique est stocké en local : `~/Library/Application Support/Ondelette/history.json`.
- Compilé sans projet Xcode : Swift Package Manager + bundle manuel (voir `build.sh`).
