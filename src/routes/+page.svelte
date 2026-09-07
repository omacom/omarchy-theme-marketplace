<script lang="ts">
	import Hero from '$lib/components/sections/hero.svelte';
	import ThemeGallery from '$lib/components/sections/theme-gallery.svelte';
	import SubmitSteps from '$lib/components/sections/submit-steps.svelte';
	import Stats from '$lib/components/sections/stats.svelte';

	let query = $state('');
</script>

<svelte:head>
	<title>Omarchy Themes — the Omarchy theme marketplace</title>
	<meta
		name="description"
		content="Browse, preview, and install color themes for Omarchy. A community marketplace built on top of the Omarchy Linux desktop."
	/>
</svelte:head>

<Hero bind:query />
<ThemeGallery {query} />
<SubmitSteps />
<Stats />
