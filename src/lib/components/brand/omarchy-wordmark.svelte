<script lang="ts">
	let { class: className, label }: { class?: string; label?: string } = $props();

	// Mirrors the banding on the real omarchy.org wordmark: a light crest at
	// the top fading to a dark base, built from --primary so it needs no
	// extra theme tokens and still follows light/dark mode.
	const bands = [
		['color-mix(in oklch, var(--primary) 55%, white)', 5],
		['color-mix(in oklch, var(--primary) 80%, white)', 2],
		['var(--primary)', 4],
		['color-mix(in oklch, var(--primary) 75%, black)', 3],
		['color-mix(in oklch, var(--primary) 50%, black)', 5]
	] as const;
	const totalRows = bands.reduce((sum, [, rows]) => sum + rows, 0);
	const stops = bands.reduce<{ css: string[]; rows: number }>(
		({ css, rows }, [color, band]) => {
			const pct = (n: number) => ((n / totalRows) * 100).toFixed(3);
			return {
				css: [...css, `${color} ${pct(rows)}%`, `${color} ${pct(rows + band)}%`],
				rows: rows + band
			};
		},
		{ css: [], rows: 0 }
	).css;
	const wordmarkGradient = `linear-gradient(to bottom, ${stops.join(', ')})`;
</script>

<div
	role={label ? 'img' : undefined}
	aria-label={label}
	aria-hidden={label ? undefined : true}
	class={className}
	style:aspect-ratio="4131 / 950"
	style:background-color="currentColor"
	style:background-image={wordmarkGradient}
	style:mask-image="url(/brand/omarchy-wordmark.svg)"
	style:mask-repeat="no-repeat"
	style:mask-size="100% 100%"
	style:mask-mode="alpha"
	style:-webkit-mask-image="url(/brand/omarchy-wordmark.svg)"
	style:-webkit-mask-repeat="no-repeat"
	style:-webkit-mask-size="100% 100%"
></div>
