const LITELLM_BUDGET_REFRESH_EVENT = 'litellm-budget:refresh';

export const dispatchLiteLLMBudgetRefresh = () => {
	if (typeof window === 'undefined') {
		return;
	}

	window.dispatchEvent(new CustomEvent(LITELLM_BUDGET_REFRESH_EVENT));
};

export { LITELLM_BUDGET_REFRESH_EVENT };
