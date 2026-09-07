<script lang="ts">
	import { Button } from '$lib/components/ui/button/index.js';
	import * as Pagination from '$lib/components/ui/pagination/index.js';
	import ThemeCard from '$lib/components/theme/theme-card.svelte';
	import { themes, type ThemeColor } from '$lib/data/themes';

	let { query = '' }: { query?: string } = $props();

	const perPage = 12;
	let page = $state(1);

	type Filter = 'featured' | 'all' | 'dark' | 'light' | ThemeColor;

	const colorFilters: { key: ThemeColor; label: string; swatch: string }[] = [
		{ key: 'blue', label: 'Blue', swatch: '#7aa2f7' },
		{ key: 'green', label: 'Green', swatch: '#9ece6a' },
		{ key: 'purple', label: 'Purple', swatch: '#bb9af7' },
		{ key: 'orange', label: 'Orange', swatch: '#ff9e64' },
		{ key: 'pink', label: 'Pink', swatch: '#f5bde6' },
		{ key: 'teal', label: 'Teal', swatch: '#2ac3de' },
		{ key: 'gray', label: 'Gray', swatch: '#9099b2' }
	];

	let activeFilter = $state<Filter>('featured');

	let filtered = $derived(
		themes
			.filter((theme) => {
				if (activeFilter === 'featured') return theme.featured === true;
				if (activeFilter === 'all') return true;
				if (activeFilter === 'dark' || activeFilter === 'light') return theme.mode === activeFilter;
				return theme.color === activeFilter;
			})
			.filter((theme) =>
				query.trim() ? theme.name.toLowerCase().includes(query.trim().toLowerCase()) : true
			)
	);

	$effect(() => {
		// Reset to the first page whenever the result set changes.
		void filtered;
		page = 1;
	});

	let paginated = $derived(filtered.slice((page - 1) * perPage, page * perPage));
</script>

<section id="themes" class="mx-auto max-w-6xl px-4 pt-10 pb-20 sm:px-6">
	<div class="flex flex-wrap items-center justify-between gap-4">
		<div class="flex flex-wrap items-center gap-2">
			<Button
				size="sm"
				variant={activeFilter === 'featured' ? 'default' : 'outline'}
				onclick={() => (activeFilter = 'featured')}
			>
				Featured
			</Button>
			<Button
				size="sm"
				variant={activeFilter === 'all' ? 'default' : 'outline'}
				onclick={() => (activeFilter = 'all')}
			>
				All
			</Button>
			<Button
				size="sm"
				variant={activeFilter === 'dark' ? 'default' : 'outline'}
				onclick={() => (activeFilter = 'dark')}
			>
				Dark
			</Button>
			<Button
				size="sm"
				variant={activeFilter === 'light' ? 'default' : 'outline'}
				onclick={() => (activeFilter = 'light')}
			>
				Light
			</Button>

			<span class="mx-1 h-5 w-px bg-border" aria-hidden="true"></span>

			{#each colorFilters as filter (filter.key)}
				<Button
					size="sm"
					variant={activeFilter === filter.key ? 'default' : 'outline'}
					onclick={() => (activeFilter = filter.key)}
					class="gap-1.5"
				>
					<span class="size-2.5 rounded-full" style:background-color={filter.swatch}></span>
					{filter.label}
				</Button>
			{/each}
		</div>

		<span class="text-sm whitespace-nowrap text-muted-foreground">{filtered.length} themes</span>
	</div>

	{#if filtered.length}
		<div class="mt-8 grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
			{#each paginated as theme (theme.slug)}
				<ThemeCard {theme} />
			{/each}
		</div>

		{#if filtered.length > perPage}
			<Pagination.Root count={filtered.length} {perPage} bind:page class="mt-10">
				{#snippet children({ pages, currentPage })}
					<Pagination.Content>
						<Pagination.Item>
							<Pagination.PrevButton />
						</Pagination.Item>
						{#each pages as p (p.key)}
							{#if p.type === 'ellipsis'}
								<Pagination.Item>
									<Pagination.Ellipsis />
								</Pagination.Item>
							{:else}
								<Pagination.Item>
									<Pagination.Link page={p} isActive={currentPage === p.value}>
										{p.value}
									</Pagination.Link>
								</Pagination.Item>
							{/if}
						{/each}
						<Pagination.Item>
							<Pagination.NextButton />
						</Pagination.Item>
					</Pagination.Content>
				{/snippet}
			</Pagination.Root>
		{/if}
	{:else}
		<p class="mt-10 text-sm text-muted-foreground">No themes match your filters.</p>
	{/if}
</section>
