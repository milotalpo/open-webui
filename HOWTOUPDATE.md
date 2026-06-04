# Open WebUI (fork Carel) — Procedura di Deploy

## Prerequisiti

- Docker Desktop avviato su Windows
- Login GHCR eseguita: `echo "TUO_PAT" | docker login ghcr.io -u milotalpo --password-stdin`
- Accesso SSH alla VM: `ssh UTENTE@IP_VM`
- File `~/deploy-owui.sh` presente e configurato sulla VM

---

## A. Primo setup (una tantum)

```powershell
# Clona il fork
git clone https://github.com/milotalpo/open-webui.git
cd open-webui
git remote add upstream https://github.com/open-webui/open-webui.git
```

```bash
# Copia lo script di deploy sulla VM (una tantum)
scp deploy-owui.sh UTENTE@IP_VM:~/deploy-owui.sh
ssh UTENTE@IP_VM "chmod +x ~/deploy-owui.sh"
```

---

## B. Deploy dopo modifica ai sorgenti

### 1. Commit e push su GitHub

```powershell
# Dalla root del fork (open-webui/)
git add .
git commit -m "feat/fix: descrizione della modifica"
git push origin main
```

### 2. Rebuild e push immagine Docker

```powershell
# Dalla root del fork (open-webui/)
$REGISTRY = "ghcr.io/milotalpo/open-webui"
$TAG = (Get-Date -Format "yyyyMMddHHmm")

docker build -t "${REGISTRY}:${TAG}" -t "${REGISTRY}:latest" .
if ($LASTEXITCODE -ne 0) { Write-Host "✖ Build fallita" -ForegroundColor Red; exit 1 }

docker push "${REGISTRY}:${TAG}"
docker push "${REGISTRY}:latest"

Write-Host "✔ Push completato — tag: $TAG" -ForegroundColor Green
```

> ⚠️ Assicurati di essere nella directory `open-webui/` (dove si trova il `Dockerfile`) prima di eseguire la build.

### 3. Redeploy sulla VM

```powershell
ssh UTENTE@IP_VM "bash ~/deploy-owui.sh"
```

**Script da usare**:

```bash
#!/usr/bin/env bash
set -euo pipefail

REGISTRY="ghcr.io/milotalpo/open-webui"
CONTAINER="open-webui"
GHCR_USER="milotalpo"

echo "▶ [0/5] Stop container, rm e cleanup immagine vecchia con rmi"
if docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER}$"; then
  docker stop "$CONTAINER"
  docker rm "$CONTAINER"
fi
if docker images --format '{{.Repository}}:{{.Tag}}' | grep -Eq "^${REGISTRY}:latest$"; then
  docker rmi "$REGISTRY:latest"
fi

docker image prune -a -f

echo "▶ [1/4] Login GHCR"
echo "$GHCR_PAT" | docker login ghcr.io -u "$GHCR_USER" --password-stdin

echo "▶ [2/4] Pull ultima immagine"
docker pull "$REGISTRY:latest"

echo "▶ [3/4] Stop & remove container esistente"
docker stop "$CONTAINER" 2>/dev/null || true
docker rm   "$CONTAINER" 2>/dev/null || true

echo "▶ [4/4] Avvio nuovo container"
docker run -d \
  --name "$CONTAINER" \
  -p 3000:8080 \
  -v open-webui:/app/backend/data \
  --network owui-internal \
  --network searxng_default \
  --restart unless-stopped \
  #...
  "$REGISTRY:latest"

echo ""
echo "✔ Deploy completato"
docker ps --filter "name=$CONTAINER" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

---

## C. Aggiornamento da upstream (nuova versione di Open WebUI)

```powershell
# Dalla root del fork (open-webui/)
git fetch upstream
git rebase upstream/main
```

Se dopo il rebase `LiteLLMBudget.svelte` risulta mancante:

```powershell
git apply patches/litellm-budget-widget.patch
git add -A
git commit -m "chore: reapply litellm-budget-widget patch after rebase"
```

Poi prosegui con i passi **B.2** e **B.3**.

In alternativa usa lo script automatico:

```powershell
.\update-owui.ps1
ssh UTENTE@IP_VM "bash ~/deploy-owui.sh"
```

---

## D. Riferimenti

| Cosa | Valore |
|------|--------|
| Fork GitHub | `https://github.com/milotalpo/open-webui` |
| Registry GHCR | `ghcr.io/milotalpo/open-webui` |
| Container sulla VM | `open-webui` |
| Porta esposta | `3000` → `8080` |
| LiteLLM URL | `http://10.0.6.135:4000` |
| Open WebUI URL | `https://aibridge02.corp.carel.com` |

---

## E. Comandi utili sulla VM

```bash
# Verifica container in esecuzione
docker ps --filter "name=open-webui"

# Log in tempo reale
docker logs -f open-webui

# Riavvio rapido senza rebuild
docker restart open-webui

# Variabili d'ambiente del container attivo
docker inspect open-webui --format '{{range .Config.Env}}{{println .}}{{end}}'
```