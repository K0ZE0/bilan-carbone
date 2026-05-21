# Customisations bilan-carbone — Reminder & Tracker

Ce doc liste TOUT ce qu'on devra modifier pour transformer le clone ABC en
notre propre instance SolutionsPlus (démo destinée aux experts métiers de La Coopération Agricole).
À mettre à jour au fur et à mesure.

> **Status global** : déploiement Coolify fonctionnel sur https://abc.santiago.contact (HTTPS OK, cert Let's Encrypt).
> Login possible avec comptes seed (`bc-admin-0@yopmail.com` / `password`).
> SMTP, design, accounts custom : à faire.

---

## 1. Comptes & authentification

### État actuel
- ~50 comptes test créés par le seed (`apps/bilan-carbone/prisma/seed/index.ts`)
- Tous emails en `@yopmail.com`
- **Passwords par convention** :
  - `cut-admin-test@yopmail.com` → `password` (seule exception)
  - `bc-<role>-<N>@yopmail.com` → `password-<N>` (ex: `bc-admin-0` → `password-0`)
  - `bc-cr-<role>-<N>@yopmail.com` → `password-<N>`
  - `<env>-env-<role>-<N>@yopmail.com` → vérifier le seed file (peut varier)
- Reset password ne marche pas (SMTP non configuré → cf. §4)

### À faire
- [ ] Décider du modèle final : 1 admin propre OU plusieurs comptes test renommés
- [ ] Choisir un email principal (ex: `admin@santiago.contact` ou un email SolutionsPlus)
- [ ] Choisir un mot de passe fort
- [ ] Exécuter le SQL de renommage / création (commande à générer via `signPassword` de l'app)
- [ ] Documenter le compte de récupération dans un password manager

### Comment changer
**Approche 1 — UPDATE SQL ciblé** (rapide) :
```sql
-- Dans le terminal Coolify (sur le service Postgres)
UPDATE bilan_carbone.users 
SET email = 'admin@santiago.contact', 
    password = '<hash bcrypt>'
WHERE email = 'bc-admin-0@yopmail.com';
```
Pour générer le hash bcrypt :
```bash
# Dans le terminal Coolify (sur le service App)
cd /app/apps/bilan-carbone
node -e "require('./src/services/auth').signPassword('TON_PASSWORD').then(h => console.log(h))"
```

**Approche 2 — Repartir de 0 sans seed** (propre prod) :
- Mettre `RUN_SEED=false` dans Coolify env vars
- Re-deploy
- Créer 1 user manuellement via SQL avec ton email + password hash

---

## 2. Branding ABC → SolutionsPlus

Tout au long de l'app, il y a des références ABC (texts, liens, logos). À nettoyer.

### Liens externes (env vars Coolify)
Variables d'env actuellement pointées sur le site ABC — à modifier dans Coolify UI :

| Variable | Valeur actuelle | À mettre |
|---|---|---|
| `NEXT_PUBLIC_ABC_SITE` | `https://abc-transitionbascarbone.fr/` | Ton site / "" |
| `NEXT_PUBLIC_FORMATION_URL` | `https://abc-transitionbascarbone.fr/agir/se-former-au-bilan-carbone/` | À toi |
| `NEXT_PUBLIC_ACTORS_URL` | `https://abc-transitionbascarbone.fr/les-acteurs/annuaire-des-prestataires/` | À toi |
| `NEXT_PUBLIC_FAQ_LINK` | `https://abc-transitionbascarbone.fr/faq` | À toi |
| `NEXT_PUBLIC_CUT_FAQ_LINK` | idem | idem |
| `CONTACT_FORM_URL` | `https://abc-transitionbascarbone.fr/contact-et-hotline` | Ton URL contact |
| `CUT_CONTACT_FORM_URL` | idem | idem |
| `NEXT_PUBLIC_LICENSE_RENEWAL_LINK` | `https://abc-transitionbascarbone.fr/agir/adherer-a-labc` | À toi (ou retirer) |
| `NEXT_PUBLIC_SUPPORT_EMAIL` | `support@abc-transitionbascarbone.fr` | `support@santiago.contact` |
| `NEXT_PUBLIC_CUT_SUPPORT_EMAIL` | idem | idem |
| `NEXT_PUBLIC_CLICKSON_SUPPORT_EMAIL` | `pebc@clickson.eu` | À toi |
| `CONTACT_EMAIL` | `contact@associationbilancarbone.fr` | `contact@santiago.contact` |

### Textes hardcodés dans le code
Certains noms ABC sont sûrement dans les fichiers i18n :
- `apps/bilan-carbone/src/i18n/translations/fr/*.json`
- `apps/bilan-carbone/src/i18n/translations/en/*.json`

À grep :
```bash
grep -r "ABC\|Association.*Bilan.*Carbone\|bilan-carbone\|abc-transitionbascarbone" apps/bilan-carbone/src/i18n/
```

### Mentions légales / CGU / méthodologie
- `apps/bilan-carbone/public/` contient des PDFs (méthodologies, CGU)
- À remplacer par tes propres docs ou à retirer du code

### À faire
- [ ] Modifier les 12 env vars dans Coolify UI
- [ ] Grep + remplacer les mentions hardcodées dans i18n FR
- [ ] Décision : retirer ou rebrander la mention "Cap Carbone" / "TILT" / "CLICKSON" / "MIP"
  (ce sont les noms des outils ABC ; tu peux les garder, les renommer, ou n'activer qu'un seul environnement)

---

## 3. Design (couleurs, logo, fonts) ✅ PARTIEL (2026-05-21)

### Réalisé : palette + logo pour l'environnement BC

**Note sur la cartographie réelle des logos** (le doc initial pointait sur `public/logos/abc/logo_abc.png`,
qui est en fait le logo de l'environnement **TILT**, pas BC). Les vrais fichiers BC sont à la racine de `public/logos/`.

**Logo SolutionsPlus** (source : `logo_solutionsplus.png` 1831×1440, ratio ~1.27, fond transparent) :

| Emplacement | Avant | Après | Dim DOM | Code modifié |
|---|---|---|---|---|
| Header dashboard | `/logos/logo_bc_blanc_nospace.png` | `/logos/logo_solutionsplus.png` | 45×35 (au lieu de 100×35) | `src/components/base/Logo.tsx` DEFAULT |
| Login monogramme | `/logos/monogramme_BC_noir.png` | `/logos/logo_solutionsplus.png` | 400×400 (inchangé) | `src/components/pages/Public.tsx` |
| Login wordmark | `/logos/logo_BC_noir.png` | `/logos/logo_solutionsplus.png` | 173×136 (au lieu de 278×136) | `src/components/pages/Public.tsx` |

Les anciens PNG **sont conservés** dans `public/logos/` (`logo_bc_blanc_nospace.png`, `monogramme_BC_noir.png`,
`logo_BC_noir.png`) pour rollback facile — il suffit de revert les commits sur les .tsx.

**Palette `colors.css`** (`src/css/themes/base/colors.css`) — variables `--primary-*` rebasculées du bleu ABC `#346fef` vers le rouge SolutionsPlus `#C8202D`. Détail des 11 nuances et 2 vars dérivées (`--background-50`, `--border`) dans le commit. Cf. `memory/solutionsplus_brand.md`.

### Pas (encore) fait dans cette session
- [ ] Theme CUT (`src/css/themes/cut/colors.css`) — pas touché car CUT = environnement Cap Carbone non-prioritaire pour la démo
- [ ] MUI overrides dans `src/environments/*/theme/theme.ts` — non touché (utilise déjà les CSS vars en grande partie)
- [ ] Logo des environnements **TILT, CLICKSON, CUT** — conservés ABC car ils servent la démo
- [ ] Fonts custom (`src/app/layout.tsx`) — pas changées (Inter/standard Next.js, OK pour démo)
- [ ] Textes i18n (mentions "ABC", "Association Bilan Carbone" dans `src/i18n/translations/`) — **volontairement conservés** (décision validée 2026-05-21) : la démo doit montrer l'app ABC officielle aux experts métiers, donc on garde la marque "Bilan Carbone®" et les mentions ABC dans CGU/PDF méthodologie/textes légaux
- [ ] PDFs méthodologie dans `public/` (`methodologie_count.pdf`, etc.) — conservés ABC pour la même raison

### Rollback rapide
```bash
git revert <commit-rebrand-solutionsplus>
# Ou manuellement :
# - Logo.tsx : src '/logos/logo_bc_blanc_nospace.png', width 100, height 35
# - Public.tsx : srcs originales /logos/monogramme_BC_noir.png et /logos/logo_BC_noir.png + dims 278x136
# - colors.css : voir git diff
```

---

## 4. SMTP / envoi de mails

### État actuel
- Variables `MAIL_*` = placeholders → l'app croit envoyer des mails mais rien ne part
- "Mot de passe oublié" cassé
- Invitations cassées
- Notifications cassées

### Options
1. **n8n + Gmail OAuth** (déjà dispo dans ton VPS d'après STACK-KOZEO.md)
   - Modifier le code pour appeler ton webhook n8n au lieu de SMTP direct
   - Plus complexe (faut patcher l'app)
2. **Mailjet / SendGrid / Resend** — SMTP transactionnel classique
   - Resend : 3000/mois gratuit, doc claire, recommandé
   - Mailjet : 6000/mois gratuit
   - Configurer les variables `MAIL_HOST`, `MAIL_PORT`, `MAIL_USER`, `MAIL_PASSWORD` dans Coolify
3. **Gmail SMTP** avec un App Password
   - Plus rapide à setup mais moins propre que Resend

### À faire
- [ ] Décider du provider (Resend recommandé pour démarrer)
- [ ] Créer un compte + récupérer les creds SMTP
- [ ] Setup DNS si nécessaire (SPF/DKIM pour `santiago.contact`)
- [ ] Mettre à jour les env vars `MAIL_*` et `CUT_MAIL_*` dans Coolify
- [ ] Re-deploy l'app
- [ ] Tester un mot de passe oublié

---

## 5. HTTPS + cert Let's Encrypt ✅ DONE (2026-05-11)

### Réalisé
- App en HTTPS : `https://abc.santiago.contact` (redirect 80→443 actif)
- Cert Let's Encrypt valide (issuer `R13`, expire 2026-08-09)
- Le proxy de Coolify est **Traefik v3.6**, pas Caddy (le doc original disait Caddy par erreur)

### Procédure utilisée
1. Coolify → app `bilan-carbone` → champ Domains : `http://abc.santiago.contact` → `https://abc.santiago.contact`
   - Save → Traefik provisionne automatiquement le cert via le resolver `letsencrypt` (labels Traefik générés par Coolify : `traefik.http.routers.https-*.tls.certresolver=letsencrypt`)
   - Le redirect HTTP→HTTPS est aussi auto-généré (middleware `redirect-to-https`)
2. Coolify → app → Environment Variables : changer en `https://` :
   - `NEXTAUTH_URL`
   - `NEXT_API_URL` (oublié au premier passage → mixed content silencieux qui faisait Chrome flagger "Non sécurisé" en mode normal)
3. Redeploy de l'app

### Pièges rencontrés
- **Pendant le redeploy**, Traefik a brièvement loggé `Router defined multiple times with different configurations` — état transitoire (containers ancien + nouveau coexistent quelques secondes). Auto-résolu.
- **Coolify UI inaccessible un moment** : c'était un cache navigateur côté local (mauvais port tapé : 8801 au lieu de 8001). Le service tournait toujours.
- **Badge Chrome "Non sécurisé"** : persiste en mode normal à cause de l'historique du navigateur + extensions qui injectent du contenu non-CSP. En navigation privée, cadenas OK. Pas un vrai problème.

### Commandes de diag utiles (pour mémoire)
```bash
# Voir le cert servi
echo | openssl s_client -connect abc.santiago.contact:443 -servername abc.santiago.contact 2>/dev/null \
  | openssl x509 -noout -issuer -subject -dates

# Voir les labels Traefik sur l'app
docker inspect <container_app> --format '{{json .Config.Labels}}' | tr ',' '\n' | grep traefik

# Logs Traefik récents
docker logs coolify-proxy --since 5m 2>&1 | tail -50
```

---

## 6. Domaine final

### État actuel
- `abc.santiago.contact` (sous-domaine OVH provisoire)

### À faire
- [ ] Décider du domaine cible SolutionsPlus (ex: `bilan.solutionsplus.fr`, sous-domaine `lacooperationagricole.coop`, etc.)
- [ ] Ajouter l'enregistrement DNS chez OVH
- [ ] Ajouter le domaine dans Coolify (peut avoir plusieurs domaines)
- [ ] Mettre à jour `NEXTAUTH_URL`, `NEXT_API_URL`, `CONTACT_EMAIL` etc.
- [ ] Re-deploy
- [ ] Tester le nouveau domaine
- [ ] Optionnel : redirection HTTP 301 de l'ancien vers le nouveau

---

## 7. Stockage / S3

### État actuel
- Variables `SCW_*` = placeholders
- Features cassées : upload de fichiers, génération de PDFs, templates Excel, exports
- L'app affichera des erreurs sur les pages où ces features sont utilisées

### Options
- **Scaleway Object Storage** (français, RGPD friendly, recommandé pour rester local)
- **AWS S3** (si déjà compte AWS)
- **Cloudflare R2** (gratuit jusqu'à 10 GB)
- **MinIO self-hosted sur VPS** (si on veut tout self-host)

### À faire
- [ ] Décider du provider
- [ ] Créer un bucket
- [ ] Récupérer Access Key + Secret Key
- [ ] Uploader les templates ABC : `methodologie_count.pdf`, `report_template.docx`, `emission-factors-template.xlsx` (à récupérer du repo)
- [ ] Mettre à jour `SCW_*` dans Coolify
- [ ] Tester l'upload d'un fichier dans l'app

---

## 8. Service PDF (Gotenberg)

### État actuel
- `PDF_SERVICE_URL=http://gotenberg:3000` configuré
- Le container Gotenberg existe sur ton VPS (cf. STACK-KOZEO.md, déjà utilisé par n8n)
- Mais bilan-carbone ne le voit probablement pas (pas sur le bon Docker network)

### À faire
- [ ] Vérifier que le container Gotenberg est sur le réseau `coolify` (sinon le connecter)
- [ ] Tester un export PDF depuis l'app
- [ ] Configurer `PDF_SERVICE_API_SECRET` (générer un token random)

---

## 9. Facteurs d'émission (Base Empreinte, Légifrance, NegaOctet)

### État actuel
- BDD en place avec les schémas, mais **0 facteur d'émission**
- L'app marche mais aucun calcul possible
- Sources d'import déclarées (`BC_FE_SOURCES_IMPORT`) mais pas peuplées

### À faire
- [ ] Récupérer un dump des FE depuis ABC (eux ont une instance avec, peut-être qu'ils peuvent partager)
- [ ] OU lancer les scripts d'import manuellement :
  ```bash
  # Dans le terminal Coolify (service App)
  cd /app/apps/bilan-carbone
  npx tsx src/scripts/baseEmpreinte/getEmissionFactors.ts -n <version>
  npx tsx src/scripts/legifrance/getEmissionFactors.ts -n <version> -f <csv>
  ```
- [ ] Importer les actualités (CSV ABC ou les nôtres)
- [ ] Importer les CNC, Secten, etc. selon les modes utilisés

---

## 10. Dépendance upstream

### État actuel
- Notre branche : `K0ZE0/bilan-carbone:deploy/coolify-vps`
- Forké de `ABC-TransitionBasCarbone/bilan-carbone:develop` au commit `3569e1fb`
- 12 commits ajoutés (tous dans `deploy/` et un peu sur le code source)

### Stratégie de mise à jour
- ABC bouge **très vite** (~6000 commits, 346 issues ouvertes, ~10 PR/semaine)
- Pull `develop` régulièrement = beaucoup de conflits
- **Recommandation** : se figer sur un **tag stable** (le dernier était `2.7.0` en juin 2025)
- Ou `git fetch origin && git log origin/develop..HEAD` pour voir ce qu'on a en local par rapport à ABC

### À faire
- [ ] Décider de la stratégie : suivre `develop` ou se figer
- [ ] Si on se fige : `git checkout v2.7.0 -b deploy/coolify-vps-v2.7.0`
- [ ] Tester un merge depuis `develop` à un moment calme pour voir ce que ça donne

---

## 11. Optimisations de l'image Docker

### État actuel
- Image runtime ~1 GB (copie le node_modules complet)
- Build ~10-12 min sans cache, ~3 min avec cache Coolify

### À faire (deferred)
- [ ] Vérifier que le cache Coolify est bien actif (deploys sans `?force=true`)
- [ ] Passer à `yarn workspaces focus --production` pour slim node_modules → ~300 MB
- [ ] Splitter en 2 images : runtime (slim) + migration (fat, one-shot)
- [ ] Activer le `host.docker.internal` cache mount pour yarn (ne re-télécharge pas les packages)

---

## 12. Sauvegardes & DR (spécificités Hetzner)

### Pourquoi Hetzner change la donne
- **Snapshots Hetzner** (console → ton serveur → Snapshots) : copie disque complète,
  payante (~0.012 €/Go/mois). Bon AVANT une opération risquée. PAS un backup BDD
  (snapshot d'un VPS qui tourne = BDD en état potentiellement inconsistent).
- **Backups Hetzner** (option séparée du panneau, ~20% du coût VPS/mois) : tourne
  tous les jours, 7 versions glissantes. Filet de sécurité passif.
- **Cloud-init** : Hetzner supporte un script d'init au create. Idéal pour la
  migration vers un VPS d'entreprise futur — tu cliques "Créer", 5 min après
  tout est setup.
- **API Hetzner Cloud** : utilisable depuis Coolify (option "Hetzner Cloud" à
  l'install) pour piloter une flotte de VPS si on scale.

### À faire
- [ ] Cron `pg_dump` quotidien dans `/var/backups/bilan-pg-*.sql.gz`
- [ ] Rsync des dumps vers un Object Storage externe (Scaleway Object Storage
      ou Cloudflare R2 — pas Hetzner Storage Box pour découpler des backups)
- [ ] Activer optionnellement les Backups Hetzner sur le VPS (filet additionnel)
- [ ] Tester une restauration sur un VPS clone
- [ ] Écrire un script cloud-init pour la migration future (cf. `deploy/README-DEPLOY.md` §7)
- [ ] Procédure cloud-init : `apt install`, swap, Coolify install, restore dump, DNS

---

## Historique des decisions / changements

| Date | Décision / Action | Note |
|---|---|---|
| 2026-05-07 | Fork ABC → K0ZE0/bilan-carbone | Base : `3569e1fb` |
| 2026-05-07 | Premier deploy Coolify réussi | http://abc.santiago.contact |
| 2026-05-11 | HTTPS activé (cert Let's Encrypt) | §5 cochée ; `NEXTAUTH_URL` + `NEXT_API_URL` passés en `https://` |
| 2026-05-21 | Rebrand visuel SolutionsPlus (logo + palette `--primary-*` rouge) sur env BC uniquement | §3 partiel ; anciens PNG conservés ; textes i18n et PDFs ABC volontairement gardés (démo des experts) |
| _yyyy-mm-dd_ | _action_ | _note_ |
