<script lang="ts">
	import { mode, toggleMode } from 'mode-watcher';
	import { RiMoonLine, RiSunLine } from 'remixicon-svelte';
	import { Button } from '$lib/components/ui/button/index.js';
</script>

<Button
	variant="ghost"
	size="icon"
	aria-label={mode.current === 'dark' ? 'Switch to light theme' : 'Switch to dark theme'}
	onclick={toggleMode}
>
	<RiSunLine
		class="h-[1.2rem] w-[1.2rem] scale-100 rotate-0 !transition-all dark:scale-0 dark:-rotate-90"
	/>

	<RiMoonLine
		class="absolute h-[1.2rem] w-[1.2rem] scale-0 rotate-90 !transition-all dark:scale-100 dark:rotate-0"
	/>
</Button>
