<script lang="ts">
	import RiMoreLine from 'remixicon-svelte/icons/more-line';
	import { cn, type WithElementRef, type WithoutChildren } from '$lib/utils.js';
	import type { HTMLAttributes } from 'svelte/elements';

	let {
		ref = $bindable(null),
		class: className,
		...restProps
	}: WithoutChildren<WithElementRef<HTMLAttributes<HTMLSpanElement>>> = $props();
</script>

<span
	bind:this={ref}
	aria-hidden="true"
	data-slot="pagination-ellipsis"
	class={cn(
		"flex size-8 items-center items-center justify-center justify-center [&_svg:not([class*='size-'])]:size-4",
		className
	)}
	{...restProps}
>
	<RiMoreLine />
	<span class="sr-only">More pages</span>
</span>
