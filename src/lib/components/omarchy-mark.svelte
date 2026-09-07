<script lang="ts">
	import type { SVGAttributes } from 'svelte/elements';

	let { class: className, ...restProps }: SVGAttributes<SVGSVGElement> = $props();
</script>

<svg viewBox="0 0 1200 1200" fill="none" aria-hidden="true" class={className} {...restProps}>
	<path
		fill-rule="evenodd"
		clip-rule="evenodd"
		fill="currentColor"
		d="m1200 1200h-480v-80h400v-1040h-479.996v160h-400v720h720v-720h-80v-80h159.996v880h-400v160h-640v-1200h1200zm-1120-80h480v-80h-400l.004-400h-80.004zm0-560h80.004v-400h400v-80h-480.004z"
	/>
</svg>
