<script lang="ts">
	import type { SVGAttributes } from 'svelte/elements';

	let { class: className, ...restProps }: SVGAttributes<SVGSVGElement> = $props();

	// Mirrors the banding on the real omarchy.org mark: a light crest at the
	// top fading to a dark base, built from --primary so it needs no extra
	// theme tokens and still follows light/dark mode.
	const bands = [
		['color-mix(in oklch, var(--primary) 55%, white)', 5],
		['color-mix(in oklch, var(--primary) 80%, white)', 2],
		['var(--primary)', 4],
		['color-mix(in oklch, var(--primary) 75%, black)', 3],
		['color-mix(in oklch, var(--primary) 50%, black)', 5]
	] as const;
	const totalRows = bands.reduce((sum, [, rows]) => sum + rows, 0);
	const stops = bands.reduce<{ list: { offset: number; color: string }[]; rows: number }>(
		({ list, rows }, [color, band]) => ({
			list: [
				...list,
				{ offset: rows / totalRows, color },
				{ offset: (rows + band) / totalRows, color }
			],
			rows: rows + band
		}),
		{ list: [], rows: 0 }
	).list;

	const uid = $props.id();
	const gradientId = `omarchy-mark-gradient-${uid}`;
</script>

<svg viewBox="0 0 1200 1200" fill="none" aria-hidden="true" class={className} {...restProps}>
	<defs>
		<linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
			{#each stops as stop, i (i)}
				<stop offset={stop.offset} stop-color={stop.color} />
			{/each}
		</linearGradient>
	</defs>
	<path
		fill-rule="evenodd"
		clip-rule="evenodd"
		fill={`url(#${gradientId})`}
		d="m1200 1200h-480v-80h400v-1040h-479.996v160h-400v720h720v-720h-80v-80h159.996v880h-400v160h-640v-1200h1200zm-1120-80h480v-80h-400l.004-400h-80.004zm0-560h80.004v-400h400v-80h-480.004z"
	/>
</svg>
