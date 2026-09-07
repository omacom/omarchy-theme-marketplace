<script lang="ts">
	import { RiHeartFill, RiHeartLine } from 'remixicon-svelte';
	import * as Card from '$lib/components/ui/card/index.js';
	import { Badge } from '$lib/components/ui/badge/index.js';
	import { Button } from '$lib/components/ui/button/index.js';
	import { cn } from '$lib/utils.js';
	import type { Theme } from '$lib/data/themes';

	let { theme }: { theme: Theme } = $props();

	let liked = $state(false);
	let likeCount = $derived(theme.likes + (liked ? 1 : 0));

	function toggleLike(event: MouseEvent) {
		event.preventDefault();
		liked = !liked;
	}
</script>

<Card.Root class="pt-0">
	<a
		href={theme.repo}
		class="group relative block focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring"
	>
		{#if theme.isNew}
			<Badge class="absolute top-2 left-2 z-10">New</Badge>
		{/if}
		<img
			src={theme.image}
			alt={`${theme.name} theme preview`}
			loading="lazy"
			class="aspect-video w-full border-b border-border object-cover transition-transform duration-300 ease-out group-hover:scale-105"
		/>
	</a>
	<Card.Content class="flex items-center justify-between gap-3">
		<div class="min-w-0">
			<a
				href={theme.repo}
				class="block truncate text-sm font-medium transition-colors hover:text-primary"
			>
				{theme.name}
			</a>
			<p class="truncate text-xs text-muted-foreground">by {theme.author}</p>
		</div>
		<Button
			variant="ghost"
			size="sm"
			onclick={toggleLike}
			aria-pressed={liked}
			aria-label={liked ? 'Unlike this theme' : 'Like this theme'}
			class={cn(
				'shrink-0 gap-1.5 px-1.5 text-muted-foreground hover:text-primary',
				liked && 'text-primary'
			)}
		>
			{#if liked}
				<RiHeartFill class="size-4" />
			{:else}
				<RiHeartLine class="size-4" />
			{/if}
			<span class="text-xs tabular-nums">{likeCount}</span>
		</Button>
	</Card.Content>
</Card.Root>
