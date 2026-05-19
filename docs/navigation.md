# Navigation (go_router)

## Fichiers

- `lib/router/app_routes.dart` — chemins
- `lib/router/app_redirect.dart` — redirects (auth, langue, onboarding prestataire)
- `lib/router/app_router.dart` — arbre des routes
- `lib/navigation/app_navigation.dart` — API à utiliser dans les écrans

## Règles

- **Auth OK** → `AppNavigation.goHome(context)` (pas de `Welcome` sous la pile)
- **Déconnexion** → `AppNavigation.goWelcome(context)`
- **Accueil particulier** → `AppNavigation.goParticulierHome(context)`
- **Quitter le déroulement** → idem (favoris + `/particulier`)
- **Objets métier** (Prestataire, Prestation) → passer en `extra` sur `push` / `go`

## Particulier (exemple)

```
/particulier → HomeParticulier
/particulier/search → liste
/particulier/prestataires/:id → fiche (extra: Prestataire)
/particulier/prestataires/:id/confirm → confirmation (extra: ConfirmPrestationExtra)
/particulier/prestations/:id → déroulement (extra: Prestation)
```

Onglet Favoris / Demander : toujours `HomeContentProvider` sur `/particulier`.
