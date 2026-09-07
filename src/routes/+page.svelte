<script lang="ts">
	import Hero from '$lib/components/hero.svelte';
	import ThemeGallery from '$lib/components/theme-gallery.svelte';
	import SubmitSteps from '$lib/components/submit-steps.svelte';
	import Stats from '$lib/components/stats.svelte';

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
