<script lang="ts">
  import { onMount } from 'svelte';
  import { settings } from '$lib/stores';
  import { LITELLM_BUDGET_REFRESH_EVENT } from '$lib/utils/litellm-budget';

  const POLL_INTERVAL = 60_000;
  const DEFAULT_BORDER = 'rgba(148, 163, 184, 0.22)';

  type LiteLLMKeyInfo = {
    spend?: number | null;
    max_budget?: number | null;
    budget_duration?: string | null;
    budget_reset_at?: string | null;
  };

  let spend: number | null = null;
  let maxBudget: number | null = null;
  let budgetDuration: string | null = null;
  let budgetResetAt: string | null = null;
  let hasError = false;
  let connectionErrorMessage: string | null = null;

  let intervalId: ReturnType<typeof setInterval> | undefined;

  // Derive credentials from the first active direct connection (OpenAI-compatible endpoint).
  // The key is kept in the reactive variable and never written to logs or external state.
  $: directConn = ($settings as any)?.directConnections ?? null;
  $: apiKey = (directConn?.OPENAI_API_KEYS?.[0] ?? '') as string;
  $: liteLLMBaseUrl = ((directConn?.OPENAI_API_BASE_URLS?.[0] ?? '') as string).trim().replace(/\/$/, '');
  $: shouldRender = Boolean(apiKey && liteLLMBaseUrl);
  $: borderColor = getBorderColor(spend, maxBudget);
  $: badgeLabel = hasError ? 'n/a' : formatCurrency(spend, '-') + (maxBudget ? ` / ${formatCurrency(maxBudget)}` : '');
  $: resetLabel = formatDateTime(budgetResetAt);

  function resetState() {
    spend = null;
    maxBudget = null;
    budgetDuration = null;
    budgetResetAt = null;
    hasError = false;
    connectionErrorMessage = null;
  }

  function formatCurrency(value: number | null | undefined, fallback = 'Illimitato') {
    if (value === null || value === undefined) {
      return fallback;
    }

    return `${value.toFixed(2)} $`;
  }

  function formatDateTime(value: string | null) {
    if (!value) {
      return null;
    }

    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      return value;
    }

    return date.toLocaleString('it-IT');
  }

  function getBorderColor(spendValue: number | null, maxBudgetValue: number | null) {
    if (spendValue === null || maxBudgetValue === null || maxBudgetValue <= 0) {
      return DEFAULT_BORDER;
    }

    const ratio = spendValue / maxBudgetValue;

    if (ratio > 0.9) {
      return '#ef4444';
    }

    if (ratio >= 0.7) {
      return '#f59e0b';
    }

    return DEFAULT_BORDER;
  }

  async function fetchBudget() {
    if (!apiKey || !liteLLMBaseUrl) {
      resetState();
      console.debug('LiteLLMBudget: no direct connection credentials available; widget idle.');
      return;
    }

    console.debug('LiteLLMBudget: fetching budget info from', `${liteLLMBaseUrl}/key/info`);

    try {
      const response = await fetch(`${liteLLMBaseUrl}/key/info?key=${encodeURIComponent(apiKey)}`, {
        headers: {
          Authorization: `Bearer ${apiKey}`
        }
      });

      if (!response.ok) {
        throw new Error(`LiteLLM key info request failed: ${response.status}`);
      }

      const data = await response.json();
      const info: LiteLLMKeyInfo = data?.info ?? {};

      spend = typeof info.spend === 'number' ? info.spend : 0;
      maxBudget = typeof info.max_budget === 'number' ? info.max_budget : null;
      budgetDuration = info.budget_duration ?? null;
      budgetResetAt = info.budget_reset_at ?? null;
      hasError = false;
      connectionErrorMessage = null;
    } catch (error) {
      hasError = true;
      spend = null;
      maxBudget = null;
      budgetDuration = null;
      budgetResetAt = null;
      connectionErrorMessage = error instanceof Error ? error.message : 'Connection to LiteLLM was not possible.';
      console.error('Failed to fetch LiteLLM budget info:', error);
    }
  }

  function handleBudgetRefresh() {
    fetchBudget();
  }

  function startPolling() {
    if (intervalId) {
      clearInterval(intervalId);
    }

    if (!apiKey) {
      intervalId = undefined;
      return;
    }

    fetchBudget();
    intervalId = setInterval(fetchBudget, POLL_INTERVAL);
  }

  onMount(() => {
    console.debug('LiteLLMBudget mounted', {
      hasCredentials: Boolean(apiKey && liteLLMBaseUrl),
      shouldRender
    });

    startPolling();
    window.addEventListener(LITELLM_BUDGET_REFRESH_EVENT, handleBudgetRefresh);

    return () => {
      if (intervalId) {
        clearInterval(intervalId);
      }
      window.removeEventListener(LITELLM_BUDGET_REFRESH_EVENT, handleBudgetRefresh);
    };
  });

  // Re-run polling whenever the direct connection credentials change
  // (e.g. after settings are loaded or updated).
  $: {
    // eslint-disable-next-line @typescript-eslint/no-unused-expressions
    apiKey;
    // eslint-disable-next-line @typescript-eslint/no-unused-expressions
    liteLLMBaseUrl;
    if (typeof window !== 'undefined') {
      startPolling();
    }
  }
</script>

{#if shouldRender}
  <div class="budget-wrap">
    <div
      class="litellm-badge {hasError ? 'is-error' : ''}"
      style={`border-color: ${hasError ? DEFAULT_BORDER : borderColor};`}
      role="status"
      aria-label="Budget LiteLLM"
    >
      <span class="amount">{badgeLabel}</span>
    </div>

    <div class="tooltip" role="tooltip">
      {#if hasError}
        <div class="row single-line">
          <span class="label">Stato</span>
          <span class="value">Connessione non disponibile</span>
        </div>
        <div class="message">
          {connectionErrorMessage ?? 'Connection to LiteLLM was not possible.'}
        </div>
      {:else}
        <div class="row"><span class="label">Consumi</span><span class="value">{formatCurrency(spend, '–')}</span></div>
        <div class="row"><span class="label">Budget max</span><span class="value">{formatCurrency(maxBudget)}</span></div>
        {#if budgetDuration}
          <div class="row"><span class="label">Periodo</span><span class="value">{budgetDuration}</span></div>
        {/if}
        {#if resetLabel}
          <div class="row"><span class="label">Reset</span><span class="value">{resetLabel}</span></div>
        {/if}
      {/if}
    </div>
  </div>
{/if}

<style>
  .budget-wrap {
    position: relative;
    display: inline-flex;
    align-items: center;
  }

  .litellm-badge {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 4.5rem;
    height: 2rem;
    padding: 0.3rem 0.65rem;
    border-radius: 9999px;
    border: 1px solid var(--badge-border, rgba(148, 163, 184, 0.22));
    background: rgba(255, 255, 255, 0.72);
    color: rgb(17, 24, 39);
    backdrop-filter: blur(10px);
    white-space: nowrap;
    transition: border-color 0.2s ease, background-color 0.2s ease;
  }

  :global(.dark) .litellm-badge {
    background: rgba(17, 24, 39, 0.72);
    color: rgb(229, 231, 235);
  }

  .litellm-badge.is-error {
    border-color: rgba(148, 163, 184, 0.35) !important;
    background: rgba(148, 163, 184, 0.14);
    color: rgb(100, 116, 139);
  }

  :global(.dark) .litellm-badge.is-error {
    background: rgba(71, 85, 105, 0.22);
    color: rgb(148, 163, 184);
  }

  .amount {
    font-size: 0.75rem;
    font-weight: 600;
    line-height: 1;
  }

  .tooltip {
    position: absolute;
    right: 0;
    top: calc(100% + 0.55rem);
    display: none;
    min-width: 13rem;
    padding: 0.65rem 0.8rem;
    border-radius: 0.85rem;
    border: 1px solid rgba(148, 163, 184, 0.2);
    background: rgba(255, 255, 255, 0.96);
    color: rgb(17, 24, 39);
    box-shadow: 0 16px 40px rgba(15, 23, 42, 0.18);
    z-index: 40;
  }

  :global(.dark) .tooltip {
    background: rgba(17, 24, 39, 0.96);
    color: rgb(229, 231, 235);
    border-color: rgba(71, 85, 105, 0.55);
    box-shadow: 0 16px 40px rgba(0, 0, 0, 0.35);
  }

  .budget-wrap:hover .tooltip,
  .budget-wrap:focus-within .tooltip {
    display: block;
  }

  .row {
    display: flex;
    justify-content: space-between;
    gap: 0.75rem;
    font-size: 0.75rem;
    line-height: 1.35;
  }

  .row + .row {
    margin-top: 0.3rem;
  }

  .label {
    color: rgb(100, 116, 139);
  }

  :global(.dark) .label {
    color: rgb(148, 163, 184);
  }

  .value {
    text-align: right;
    font-weight: 600;
  }

  .single-line {
    align-items: flex-start;
  }

  .message {
    margin-top: 0.45rem;
    font-size: 0.75rem;
    line-height: 1.35;
    color: rgb(71, 85, 105);
  }

  :global(.dark) .message {
    color: rgb(148, 163, 184);
  }
</style>