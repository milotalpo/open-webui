git add `
  backend/open_webui/config.py `
  backend/open_webui/main.py `
  src/lib/stores/index.ts `
  src/lib/components/layout/LiteLLMBudget.svelte `
  src/lib/components/chat/Navbar.svelte `
  src/lib/components/channel/Navbar.svelte

git commit -m "feat: add LiteLLM budget widget to navbar (env-driven via LITELLM_BASE_URL)"
git push origin main