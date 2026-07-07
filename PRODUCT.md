# Parler

## Register

product — app UI native macOS (barre de menus + fenêtre de réglages + HUD). Le design sert l'usage, il ne se met pas en avant.

## Utilisateurs & usage

Charles (et à terme d'autres utilisateurs Mac exigeants) : dictée vocale quotidienne dans n'importe quelle app macOS. Scène : bureau, Mac mini M4 + micro sur pied, sessions courtes et fréquentes (5 s à 2 min), souvent en musique. L'app doit être invisible jusqu'au moment de dicter, puis irréprochablement claire sur son état (écoute / transcription / correction / collé).

## Objectif produit

Niveau SuperWhisper : dictée locale (Whisper large-v3-turbo, français forcé), correction GPT (~1 s), collage automatique. Zéro perte de dictée, zéro ambiguïté d'état.

## Personnalité de marque

Sobre, précise, native macOS 26/27 (Liquid Glass) : matériaux translucides système, profondeur discrète, SF Symbols, animations courtes en ease-out. L'app doit sembler faire partie du système, pas posée dessus.

## Anti-références

- Fenêtres utilitaires grises « Catalina » (formulaires plats sans hiérarchie).
- Surcharge glassmorphique décorative : le verre est le matériau des surfaces système (HUD, panneaux), pas un vernis sur chaque contrôle.
- Tout ce qui fait « app Electron » : paddings uniformes, gris neutres sans teinte, absence de vibrancy.

## Principes de design

1. États avant ornement : chaque phase de dictée est lisible en une demi-seconde (icône + couleur + libellé).
2. Matériaux système (NSVisualEffectView / .ultraThinMaterial) plutôt que couleurs opaques simulées.
3. Accent unique (teinte système) ; le rouge est réservé à l'enregistrement.
4. Animations ≤ 250 ms, ease-out, jamais de rebond.
