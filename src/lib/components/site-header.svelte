<script lang="ts">
	import { RiMenuLine } from 'remixicon-svelte';
	import { Button } from '$lib/components/ui/button/index.js';
	import * as Sheet from '$lib/components/ui/sheet/index.js';
	import ThemeToggle from '$lib/components/theme-toggle.svelte';
	import OmarchyMark from '$lib/components/omarchy-mark.svelte';

	const navLinks = [
		{ href: 'https://omarchy.org/manual/making-your-own-theme/', label: 'Make your own theme' }
	];

	let menuOpen = $state(false);
</script>

<header class="sticky top-0 z-50 border-b border-border bg-background/90 backdrop-blur-lg">
	<div class="mx-auto flex h-14 max-w-6xl items-center gap-3 px-4 sm:px-6">
		<a href="/" class="flex shrink-0 items-center gap-2" aria-label="Omarchy Themes home">
			<OmarchyMark class="size-5 text-primary" />
			<span class="font-mono text-[15px] font-semibold tracking-tight text-foreground uppercase">
				Theme Marketplace
			</span>
		</a>

		<nav aria-label="Main" class="hidden items-center gap-1 sm:ml-4 sm:flex">
			{#each navLinks as link (link.href)}
				<Button variant="ghost" aria-label={link.label} href={link.href}>{link.label}</Button>
			{/each}
		</nav>

		<div class="ml-auto flex items-center gap-1.5">
			<ThemeToggle />
			<Button href="#submit" class="hidden sm:inline-flex">Submit a theme</Button>

			<Sheet.Root bind:open={menuOpen}>
				<Sheet.Trigger>
					{#snippet child({ props })}
						<Button {...props} variant="ghost" size="icon" aria-label="Menu" class="sm:hidden">
							<RiMenuLine class="size-5" />
						</Button>
					{/snippet}
				</Sheet.Trigger>
				<Sheet.Content side="right" class="w-72">
					<Sheet.Header>
						<Sheet.Title>Omarchy Themes</Sheet.Title>
					</Sheet.Header>
					<nav aria-label="Main" class="flex flex-col gap-1 px-4">
						{#each navLinks as link (link.href)}
							<a
								href={link.href}
								onclick={() => (menuOpen = false)}
								class="py-2.5 text-sm text-muted-foreground hover:text-foreground"
							>
								{link.label}
							</a>
						{/each}
						<Button href="#submit" onclick={() => (menuOpen = false)} class="mt-2">
							Submit a theme
						</Button>
					</nav>
				</Sheet.Content>
			</Sheet.Root>
		</div>
	</div>
</header>
