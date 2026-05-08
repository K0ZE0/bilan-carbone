# Customisations bilan-carbone — Reminder & Tracker

Ce doc liste TOUT ce qu'on devra modifier pour transformer le clone ABC en
notre propre instance Kozeo. À mettre à jour au fur et à mesure.

> **Status global** : déploiement Coolify fonctionnel sur http://abc.santiago.contact (HTTP).
> Login possible avec comptes seed (`bc-admin-0@yopmail.com` / `password`).
> HTTPS, SMTP, design, accounts custom : à faire.

---

## 1. Comptes & authentification

### État actuel
- ~50 comptes test créés par le seed (`apps/bilan-carbone/prisma/seed/index.ts`)
- Tous emails en `@yopmail.com`
- Mot de passe pour TOUS : `password`
- Reset password ne marche pas (SMTP non configuré → cf. §3)

### À faire
- [ ] Décider du modèle final : 1 admin propre OU plusieurs comptes test renommés
- [ ] Choisir un email principal (ex: `kozeo@santiago.contact` ou autre)
- [ ] Choisir un mot de passe fort
- [ ] Exécuter le SQL de renommage / création (commande à générer via `signPassword` de l'app)
- [ ] Documenter le compte de récupération dans un password manager

### Comment changer
**Approche 1 — UPDATE SQL ciblé** (rapide) :
```sql
-- Dans le terminal Coolify (sur le service Postgres)
UPDATE bilan_carbone.users 
SET email = 'kozeo@santiago.contact', 
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

## 2. Branding ABC → Kozeo

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

## 3. Design (couleurs, logo, fonts)

**Bonne nouvelle** : c'est super propre chez ABC, tout est centralisé.

### Logo
2 fichiers PNG à remplacer :
```
apps/bilan-carbone/public/logos/abc/logo_abc.png         ← logo principal (header)
apps/bilan-carbone/public/logos/abc/logo_abc_base.png    ← logo base (footer ?)
```
**Conserve les mêmes dimensions** (à vérifier visuellement). Si tu veux un SVG c'est encore mieux mais il faut chercher où chaque PNG est référencé.

Drapeaux i18n : pas à changer (`public/logos/FR.svg`, `GB.svg`, etc.) — utilisés pour les langues.

### Couleurs
Toutes les couleurs sont des CSS variables dans :
```
apps/bilan-carbone/src/css/themes/base/colors.css
apps/bilan-carbone/src/css/themes/cut/colors.css   ← env Cap Carbone (différent)
```

Variables principales à modifier (palette `--primary-*` de 50 à 950) :
```css
:root {
  --primary-50: #ebf2ff;    /* lightest */
  --primary-500: #346fef;   /* MAIN brand color */
  --primary-700: #0045bd;   /* darker */
  --primary-900: #00163d;   /* darkest */
  ...
}
```

→ **C'est tout**. Tu changes les hex, ça change partout via CSS vars.

Outils utiles pour générer une palette cohérente :
- https://uicolors.app/create
- https://palettte.app/

### Fonts
Le repo utilise `next/font` (auto-import). Les fonts sont déclarées dans `apps/bilan-carbone/src/app/layout.tsx` ou similaire. À chercher si on veut changer.

### MUI Theme
MUI overrides dans `apps/bilan-carbone/src/environments/*/theme/theme.ts` (TILT a son propre thème par exemple).

### À faire
- [ ] Définir la palette Kozeo (au moins `--primary-500` et 2-3 nuances)
- [ ] Préparer les 2 PNG du logo (versions principale + footer)
- [ ] Remplacer les PNG dans `public/logos/abc/`
- [ ] Modifier `colors.css` (base + cut si on garde l'env CUT)
- [ ] Optionnel : changer la font dans `layout.tsx`

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

## 5. HTTPS + cert Let's Encrypt

### État actuel
- App accessible en HTTP : `http://abc.santiago.contact`
- Caddy configuré dans Coolify mais cert non généré
- Browser affiche "no available server" si on tente HTTPS directement

### Causes possibles
- Caddy attend un trafic HTTPS pour amorcer ACME challenge
- Ou problème de config réseau Caddy / domaine

### À faire
- [ ] Vérifier les logs Caddy : `docker logs coolify-proxy | grep -iE 'acme|santiago|cert'`
- [ ] Force HTTPS dans Coolify settings de l'app (`is_force_https_enabled`)
- [ ] Tester `curl -kIv https://abc.santiago.contact/`
- [ ] Si échec persistant : configurer Caddy explicitement avec ACME
- [ ] Vérifier `NEXTAUTH_URL` est bien `https://...` après mise en place

---

## 6. Domaine final

### État actuel
- `abc.santiago.contact` (sous-domaine OVH provisoire)

### À faire
- [ ] Décider du domaine cible Kozeo (ex: `bilan.kozeo.fr`, `carbone.santiago.contact`, etc.)
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

## 12. Sauvegardes & DR

### À faire
- [ ] Cron de dump Postgres quotidien (à définir l'emplacement)
- [ ] Rsync des dumps vers un Object Storage externe (Scaleway / S3)
- [ ] Tester une restauration sur un VPS clone
- [ ] Documenter la procédure de migration vers nouveau VPS (déjà ébauchée dans `deploy/README-DEPLOY.md` §7)

---

## Historique des decisions / changements

| Date | Décision / Action | Note |
|---|---|---|
| 2026-05-07 | Fork ABC → K0ZE0/bilan-carbone | Base : `3569e1fb` |
| 2026-05-07 | Premier deploy Coolify réussi | http://abc.santiago.contact |
| _yyyy-mm-dd_ | _action_ | _note_ |
