# Déploiement bilan-carbone sur VPS via Coolify

Ce dossier contient tout ce qu'il faut pour héberger l'app bilan-carbone sur un
VPS via Coolify (PaaS self-hosted), avec migration future facilitée vers un
autre VPS du même type.

## TL;DR — ce que contient `deploy/`

| Fichier | Rôle |
|---|---|
| `Dockerfile` | Build multi-stage (Next.js standalone + Prisma + tsx pour seed) |
| `entrypoint.sh` | Migrations + seed optionnel + start serveur |
| `docker-compose.prod.yml` | Stack prête à tester localement (app + Postgres + maildev) |
| `.env.production.example` | Template des ~30 variables d'env requises |
| `README-DEPLOY.md` | Ce fichier — procédure complète |

`.dockerignore` est à la racine du repo.

---

## 1. Pré-requis

### Sur ta machine locale (pour test image avant push)
- Docker Desktop / Docker Engine + Compose plugin

### Sur le VPS cible
- Ubuntu / Debian récent
- Au moins 2 GB RAM libres (build) — l'app tournante consomme ~1.5 GB
- Ports 80 + 443 libres (pour Traefik/Let's Encrypt)
- Un port libre pour l'UI Coolify (par défaut 8000 — utiliser 8001 ici)
- Un sous-domaine pointant vers l'IP du VPS (ex: `abc.santiago.contact`)

### Côté DNS (chez OVH)
1. Manager OVH → Web Cloud → Noms de domaine → `santiago.contact`
2. Onglet **Zone DNS** → **Ajouter une entrée** → type **A**
3. Sous-domaine: `abc` · Cible: `<IP_DU_VPS>` · TTL: 3600
4. Vérifier après quelques minutes: `nslookup abc.santiago.contact`

> ⚠️ Tant que le DNS ne résout pas vers ton VPS, Let's Encrypt échouera.

---

## 2. Test local de l'image (recommandé avant Coolify)

```bash
# Depuis la racine du repo
cp deploy/.env.production.example deploy/.env.production
# → éditer deploy/.env.production: NEXTAUTH_SECRET, ADMIN_PASSWORD, etc.

# Premier lancement (avec seed)
RUN_SEED=true docker compose -f deploy/docker-compose.prod.yml up --build

# Lancements suivants (sans seed)
docker compose -f deploy/docker-compose.prod.yml up
```

App: http://localhost:3000 — Maildev: http://localhost:1080

> Le premier build prend 5-10 min (les 3 paquets publicodes se compilent).
> Pendant le build, ~3 GB de RAM peuvent être utilisés temporairement.

Pour tout arrêter et nettoyer (y compris la BDD):
```bash
docker compose -f deploy/docker-compose.prod.yml down -v
```

---

## 3. Préparer le VPS

### 3.1 Snapshot avant tout
Va chez ton hébergeur et fais un snapshot complet du VPS. **Filet de sécurité.**

### 3.2 Ajouter du swap (filet pour les pics)
```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
free -h   # vérifier que le swap est bien actif
```

### 3.3 Vérifier les ports
```bash
ss -tlnp | grep -E ':(80|443|8000|8001|22222)\b'
```
- 80 / 443 doivent être libres (pour Traefik)
- 8000 peut être pris (LEANN dans notre cas) — on installe Coolify sur 8001
- 22222 (SSH proxy Coolify) doit être libre

### 3.4 Installer Coolify
```bash
curl -fsSL https://coolify.io/install.sh | sudo env COOLIFY_APP_PORT=8001 bash
```
Une fois fini: ouvre `http://<IP_VPS>:8001` → crée le compte admin → tu arrives
sur le dashboard Coolify.

---

## 4. Configuration dans Coolify

### 4.1 Connecter GitHub
Settings → Sources → GitHub → suivre l'OAuth flow → autoriser sur ton fork du
repo bilan-carbone (la branche déployable est celle qui contient le dossier
`deploy/`).

### 4.2 Créer le service Postgres
1. New Resource → Database → PostgreSQL 17
2. Nom: `bilan-postgres`
3. User: `bilancarbone` · Password: générer · DB: `bilancarbone`
4. **Important — schémas Prisma**: après création, ouvre le terminal Postgres
   dans Coolify et exécute:
   ```sql
   CREATE SCHEMA IF NOT EXISTS bilan_carbone;
   CREATE SCHEMA IF NOT EXISTS common;
   ```
   (Le schéma `public` existe par défaut.)
5. Note la connexion string interne — elle ressemble à
   `postgresql://bilancarbone:PWD@bilan-postgres:5432/bilancarbone`
6. Ajouter `?options=-c search_path=public,bilan_carbone,common` à la fin

### 4.3 Créer le service Maildev (optionnel, pour test)
New Resource → Application → Docker Image
- Image: `maildev/maildev:latest`
- Port: 1080 (UI) — protège-le derrière Traefik avec basic auth
- SMTP port 1025 reste interne, accessible aux autres services par son nom

> Pour la prod réelle, remplace par un SMTP transactionnel (Mailjet, SendGrid…)
> et mets ses credentials dans `MAIL_*`.

### 4.4 Créer le service App
1. New Resource → Application → Public Repository (ou ton GitHub source)
2. URL du repo (ton fork) · Branch: `deploy/coolify-vps`
3. Build Pack: **Dockerfile**
4. Dockerfile location: `deploy/Dockerfile`
5. Build context: `.` (racine du repo)
6. Port: 3000

### 4.5 Variables d'environnement
Dans l'onglet Environment Variables du service App, copier-coller
`deploy/.env.production.example` puis remplir/écraser:

**Variables critiques à régler**:
- `POSTGRES_PRISMA_URL` → la string interne du Postgres + le `?options=...`
- `NEXTAUTH_SECRET` → `openssl rand -base64 32`
- `NEXTAUTH_URL` → `https://abc.santiago.contact`
- `ADMIN_PASSWORD` → mot de passe fort
- `PDF_JWT_SECRET` → `openssl rand -base64 32`
- `CRON_SECRET` → token aléatoire
- `RUN_SEED=true` (uniquement pour le 1er déploiement)

### 4.6 Domaine + HTTPS
Dans l'onglet Domains du service App:
- Domain: `abc.santiago.contact`
- Generate SSL: oui (Let's Encrypt)

Coolify configure Traefik automatiquement. Au premier deploy, le certificat
HTTPS est généré.

### 4.7 Limites mémoire
Dans l'onglet Resource Limits:
- App: 1500 MB
- Postgres: 512 MB

---

## 5. Premier déploiement

1. Click **Deploy** dans Coolify
2. Suivre les logs de build (5-10 min la première fois)
3. Une fois "Healthy" → ouvre `https://abc.santiago.contact`
4. Connexion en admin avec l'email seed et `ADMIN_PASSWORD`
5. **IMPORTANT**: retire `RUN_SEED=true` des env vars (ou mets `false`),
   sinon le seed re-tourne à chaque restart

---

## 6. Importer les facteurs d'émission (étape métier)

L'app est vide en facteurs d'émission après seed (juste un admin). Pour avoir
des calculs réels, il faut importer Base Empreinte / Légifrance. Depuis le
terminal du container (Coolify → service App → Terminal):

```bash
cd /app/apps/bilan-carbone
# Adapte les paramètres selon les CSV que tu as
npx tsx src/scripts/baseEmpreinte/getEmissionFactors.ts -n <version>
```

Voir `apps/bilan-carbone/README.md` pour les autres scripts d'import.

---

## 7. Migration vers un nouveau VPS — checklist 30 min

### Sur l'ancien VPS
```bash
# Dump Postgres
docker exec bilan-postgres pg_dump -U bilancarbone bilancarbone > /tmp/bilan-$(date +%F).sql.gz
scp /tmp/bilan-*.sql.gz toi@nouveau-vps:/tmp/
```

### Sur le nouveau VPS
1. Snapshot
2. Ajouter swap (cf. §3.2)
3. Installer Coolify (cf. §3.4)
4. Connecter le même GitHub source
5. Créer Postgres → restaurer le dump:
   ```bash
   docker exec -i <new-pg-container> psql -U bilancarbone bilancarbone < /tmp/bilan-XXXX.sql.gz
   ```
6. Re-créer le service App avec le même Dockerfile + mêmes env vars
   (exporter/importer les env vars depuis l'UI Coolify)
7. **Avant** le premier deploy: mettre `RUN_MIGRATIONS=false` (la BDD est déjà à jour)
8. Bascule DNS: changer le A record OVH vers la nouvelle IP
9. Vérifier — terminer

---

## 8. Sauvegardes (à mettre en place une fois en prod)

Cron simple sur le VPS (host, hors Coolify):
```bash
# /etc/cron.daily/bilan-pg-backup
#!/bin/sh
docker exec bilan-postgres pg_dump -U bilancarbone bilancarbone \
  | gzip > /var/backups/bilan-$(date +\%F).sql.gz
find /var/backups -name 'bilan-*.sql.gz' -mtime +14 -delete
```
+ rsync hebdo vers un stockage externe (Scaleway Object Storage par ex).

---

## 9. Dépannage

| Symptôme | Cause probable | Fix |
|---|---|---|
| Build échoue à `prisma generate` | `.env` manquant en build stage | Le Dockerfile copie `.env.dist` automatiquement — vérifier qu'il est présent dans le repo |
| `NEXTAUTH_URL is not set` au démarrage | Env var non transmise à Coolify | Re-vérifier l'onglet Environment Variables |
| `connect ECONNREFUSED postgres:5432` | DNS interne pas encore prêt au start | L'entrypoint attend le healthcheck Postgres — vérifier que le service Postgres est `Healthy` avant l'app |
| Login impossible après seed | Email admin par défaut inconnu | Voir `apps/bilan-carbone/prisma/seed/index.ts` pour l'email du compte créé |
| `Cannot find module './generated/prisma/...'` | `prisma generate` n'a pas tourné | Bug du Dockerfile — relire la stage `builder`, vérifier que `db:generate` est bien exécuté |
| Cert HTTPS échoue | DNS pas propagé / port 80 bloqué | `dig abc.santiago.contact` doit retourner l'IP, et `curl -I http://abc.santiago.contact` doit répondre depuis Traefik |
| OOM kill du container | Limite mémoire trop basse | Augmenter à 2 GB dans Coolify, ou ajouter du swap |

---

## 10. Branche & maintenance

- Branche actuelle: `deploy/coolify-vps`
- Pour pull les nouveautés upstream sans casser le déploiement:
  ```bash
  git fetch origin
  git checkout deploy/coolify-vps
  git merge origin/develop  # gère les conflits, surtout sur package.json/yarn.lock
  ```
- **Recommandé**: freeze sur un tag stable (ex: `v2.7.0`) plutôt que de suivre
  `develop` qui bouge en permanence (~6000 commits, équipe ABC très active).
