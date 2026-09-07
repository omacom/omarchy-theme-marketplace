<script lang="ts">
	import { Pagination as PaginationPrimitive } from 'bits-ui';
	import RiArrowLeftSLine from 'remixicon-svelte/icons/arrow-left-s-line';
	import { buttonVariants } from '$lib/components/ui/button/index.js';
	import { cn } from '$lib/utils.js';

	let {
		ref = $bindable(null),
		class: className,
		...restProps
	}: PaginationPrimitive.PrevButtonProps = $props();
</script>

<PaginationPrimitive.PrevButton
	bind:ref
	aria-label="Go to previous page"
	class={cn(buttonVariants({ variant: 'ghost', size: 'default' }), 'pl-1.5!', className)}
	{...restProps}
>
	<RiArrowLeftSLine data-icon="inline-start" />
	<span class="cn-pagination-previous-text hidden sm:block">Previous</span>
</PaginationPrimitive.PrevButton>
