<script lang="ts">
	import * as Card from '$lib/components/ui/card/index.js';

	const stats = [
		{ label: 'Themes published', value: '214' },
		{ label: 'Total installs', value: '86.2k' },
		{ label: 'Theme authors', value: '97' },
		{ label: 'New this month', value: '12' }
	];
</script>

<section id="figures" class="border-t border-border">
	<div class="mx-auto max-w-6xl px-4 py-12 sm:px-6 lg:py-24">
		<div class="grid grid-cols-2 gap-4 lg:grid-cols-4">
			{#each stats as stat (stat.label)}
				<Card.Root>
					<Card.Content class="flex flex-col gap-1.5">
						<span class="font-heading text-3xl font-semibold text-primary">{stat.value}</span>
						<span class="text-[13px] text-muted-foreground">{stat.label}</span>
					</Card.Content>
				</Card.Root>
			{/each}
		</div>
	</div>
</section>
