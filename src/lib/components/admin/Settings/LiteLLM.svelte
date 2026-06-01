<script lang="ts">
	import { toast } from 'svelte-sonner';
	import { onMount, getContext } from 'svelte';
	import { getLiteLLMConfig, setLiteLLMConfig } from '$lib/apis/configs';
	import { getBackendConfig } from '$lib/apis';
	import { config } from '$lib/stores';

	import Switch from '$lib/components/common/Switch.svelte';
	import Tooltip from '$lib/components/common/Tooltip.svelte';

	const i18n = getContext('i18n');

	export let saveSettings: Function;

	let LITELLM_BASE_URL = '';
	let ENABLE_LITELLM_BUDGET_DISPLAY = true;

	const saveHandler = async () => {
		const res = await setLiteLLMConfig(localStorage.token, {
			LITELLM_BASE_URL,
			ENABLE_LITELLM_BUDGET_DISPLAY
		}).catch((err) => {
			toast.error(err);
			return null;
		});

		if (res) {
			toast.success($i18n.t('LiteLLM settings saved successfully'));
			// Refresh backend config so the widget picks up the new values immediately
			const backendConfig = await getBackendConfig();
			if (backendConfig) {
				config.set(backendConfig);
			}
			saveSettings();
		}
	};

	onMount(async () => {
		const res = await getLiteLLMConfig(localStorage.token).catch(() => null);
		if (res) {
			LITELLM_BASE_URL = res.LITELLM_BASE_URL ?? '';
			ENABLE_LITELLM_BUDGET_DISPLAY = res.ENABLE_LITELLM_BUDGET_DISPLAY ?? true;
		}
	});
</script>

<form
	class="flex flex-col h-full justify-between text-sm"
	on:submit|preventDefault={saveHandler}
>
	<div class="overflow-y-scroll scrollbar-hidden h-full">
		<div class="mb-3">
			<div class="mt-0.5 mb-2.5 text-base font-medium">{$i18n.t('LiteLLM Budget Widget')}</div>

			<hr class="border-gray-100/30 dark:border-gray-850/30 my-2" />

			<div class="mb-4">
				<div class="flex justify-between items-center mb-1">
					<div class="font-medium">{$i18n.t('Enable Budget Display Widget')}</div>
					<Tooltip
						content={$i18n.t(
							'Show a spend/budget pill in the navbar for users who have a LiteLLM API key assigned.'
						)}
					>
						<Switch
							bind:state={ENABLE_LITELLM_BUDGET_DISPLAY}
						/>
					</Tooltip>
				</div>
				<div class="text-xs text-gray-500 mt-1">
					{$i18n.t(
						'When enabled, users with a LiteLLM API key will see their current spend vs. budget in the top navigation bar.'
					)}
				</div>
			</div>

			<hr class="border-gray-100/30 dark:border-gray-850/30 my-4" />

			<div class="mb-2.5">
				<div class="font-medium mb-1">{$i18n.t('LiteLLM Proxy Base URL')}</div>
				<div class="flex w-full">
					<input
						class="w-full rounded-lg py-2 px-4 text-sm bg-gray-50 dark:text-gray-300 dark:bg-gray-850 outline-hidden"
						type="url"
						placeholder="http://localhost:4000"
						bind:value={LITELLM_BASE_URL}
					/>
				</div>
				<div class="text-xs text-gray-500 mt-1">
					{$i18n.t(
						'Base URL of your LiteLLM proxy server. Used to fetch per-user spend data. Leave empty to disable.'
					)}
				</div>
			</div>
		</div>
	</div>

	<div class="flex justify-end pt-3 text-sm font-medium">
		<button
			class="px-3.5 py-1.5 text-sm font-medium bg-black hover:bg-gray-900 text-white dark:bg-white dark:text-black dark:hover:bg-gray-100 transition rounded-full"
			type="submit"
		>
			{$i18n.t('Save')}
		</button>
	</div>
</form>
