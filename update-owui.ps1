# Esecuzione futura ad ogni aggiornamento di OWUI:
# .\update-owui.ps1
# oppure con tag manuale:
# .\update-owui.ps1 -Tag "20240601-hotfix"

# update-owui.ps1
param([string]$Tag = (Get-Date -Format "yyyyMMddHHmm"))

$REGISTRY = "ghcr.io/milotalpo/open-webui"
$PATCH = "patches/litellm-budget-widget.patch"

Write-Host "▶ [1/5] Fetch upstream"
git fetch upstream

Write-Host "▶ [2/5] Rebase su upstream/main"
git rebase upstream/main
if ($LASTEXITCODE -ne 0) {
    Write-Host "✖ Rebase fallito — risolvi i conflitti e riesegui" -ForegroundColor Red
    exit 1
}

Write-Host "▶ [3/5] Verifica patch"
if (-not (Test-Path "src/lib/components/layout/LiteLLMBudget.svelte")) {
    Write-Host "  ⚠ LiteLLMBudget.svelte mancante, riapplico patch..."
    git apply $PATCH
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✖ Patch non applicabile — aggiorna manualmente il componente" -ForegroundColor Red
        exit 1
    }
    git add -A
    git commit -m "chore: reapply litellm-budget-widget patch after rebase"
}

Write-Host "▶ [4/5] Build immagine Docker → ${REGISTRY}:${Tag}"
docker build -t "${REGISTRY}:${Tag}" -t "${REGISTRY}:latest" .
if ($LASTEXITCODE -ne 0) { Write-Host "✖ Build fallita" -ForegroundColor Red; exit 1 }

Write-Host "▶ [5/5] Push su GHCR"
docker push "${REGISTRY}:${Tag}"
docker push "${REGISTRY}:latest"

Write-Host ""
Write-Host "✔ Completato — tag: $Tag" -ForegroundColor Green
Write-Host "  Sulla VM esegui: ssh UTENTE@IP_VM '~/deploy-owui.sh'"