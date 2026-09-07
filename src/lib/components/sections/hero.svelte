<script lang="ts">
	import { RiSearchLine } from 'remixicon-svelte';
	import { Input } from '$lib/components/ui/input/index.js';
	import OmarchyWordmark from '$lib/components/brand/omarchy-wordmark.svelte';
	import { themes } from '$lib/data/themes';

	let { query = $bindable('') }: { query?: string } = $props();
</script>

<section
	id="home"
	class="relative flex flex-col items-center overflow-hidden border-b border-border px-6 py-14 text-center"
>
	<div
		class="pointer-events-none absolute inset-0 opacity-40"
		style="background: radial-gradient(60% 50% at 50% 0%, color-mix(in oklch, var(--primary) 18%, transparent), transparent 70%);"
		aria-hidden="true"
	></div>

	<div class="relative flex w-full max-w-lg flex-col items-center">
		<OmarchyWordmark label="Omarchy" class="mb-2 h-12 w-auto text-primary sm:h-24" />
		<h1 class="text-xs font-medium tracking-[0.18em] text-primary uppercase sm:text-sm">
			Community Themes
		</h1>

		<p class="mt-4 max-w-md text-[15px] leading-relaxed text-muted-foreground">
			Choose from <span class="text-primary">{themes.length}</span> community-created themes for Omarchy.
		</p>

		<div class="relative mt-6 w-full">
			<RiSearchLine
				class="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground"
			/>
			<Input
				bind:value={query}
				placeholder="Search themes…"
				class="h-11 pl-9"
				aria-label="Search themes"
			/>
		</div>
	</div>
</section>
