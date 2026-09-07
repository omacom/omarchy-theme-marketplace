<script lang="ts">
	let { class: className, label }: { class?: string; label?: string } = $props();
</script>

<div
	role={label ? 'img' : undefined}
	aria-label={label}
	aria-hidden={label ? undefined : true}
	class={className}
	style:aspect-ratio="4131 / 950"
	style:background-color="currentColor"
	style:mask-image="url(/brand/omarchy-wordmark.svg)"
	style:mask-repeat="no-repeat"
	style:mask-size="100% 100%"
	style:mask-mode="alpha"
	style:-webkit-mask-image="url(/brand/omarchy-wordmark.svg)"
	style:-webkit-mask-repeat="no-repeat"
	style:-webkit-mask-size="100% 100%"
></div>
