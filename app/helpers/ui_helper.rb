# Ports of the shadcn-svelte component class builders (button, badge, card, input) so the
# Rails views render the exact same markup and Tailwind classes as the SvelteKit app did.
module UiHelper
  BUTTON_BASE = "rounded-none border border-transparent cursor-pointer bg-clip-padding text-xs font-medium focus-visible:border-ring focus-visible:ring-1 focus-visible:ring-ring/50 active:not-aria-[haspopup]:translate-y-px aria-invalid:border-destructive aria-invalid:ring-1 aria-invalid:ring-destructive/20 dark:aria-invalid:border-destructive/50 dark:aria-invalid:ring-destructive/40 [&_svg:not([class*='size-'])]:size-4 group/button inline-flex shrink-0 items-center justify-center whitespace-nowrap transition-all outline-none select-none disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0"

  BUTTON_VARIANTS = {
    default: "bg-primary text-primary-foreground hover:bg-primary/80",
    outline: "border-border bg-background hover:bg-muted hover:text-foreground aria-expanded:bg-muted aria-expanded:text-foreground dark:border-input dark:bg-input/30 dark:hover:bg-input/50",
    secondary: "bg-secondary text-secondary-foreground hover:bg-[color-mix(in_oklch,var(--secondary),var(--foreground)_5%)] aria-expanded:bg-secondary aria-expanded:text-secondary-foreground",
    ghost: "hover:bg-muted hover:text-foreground aria-expanded:bg-muted aria-expanded:text-foreground dark:hover:bg-muted/50",
    destructive: "bg-destructive/10 text-destructive hover:bg-destructive/20 focus-visible:border-destructive/40 focus-visible:ring-destructive/20 dark:bg-destructive/20 dark:hover:bg-destructive/30 dark:focus-visible:ring-destructive/40",
    link: "text-primary underline-offset-4 hover:underline"
  }.freeze

  BUTTON_SIZES = {
    default: "h-8 gap-1.5 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2",
    xs: "h-6 gap-1 rounded-none px-2 text-xs has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 [&_svg:not([class*='size-'])]:size-3",
    sm: "h-7 gap-1 rounded-none px-2.5 has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 [&_svg:not([class*='size-'])]:size-3.5",
    lg: "h-9 gap-1.5 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2",
    icon: "size-8",
    icon_xs: "size-6 rounded-none [&_svg:not([class*='size-'])]:size-3",
    icon_sm: "size-7 rounded-none",
    icon_lg: "size-9"
  }.freeze

  BADGE_BASE = "h-5 gap-1 rounded-none border border-transparent px-2 py-0.5 text-xs font-medium transition-all has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 [&>svg]:size-3! group/badge inline-flex w-fit shrink-0 items-center justify-center overflow-hidden whitespace-nowrap transition-colors focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 [&>svg]:pointer-events-none"

  BADGE_VARIANTS = {
    default: "bg-primary text-primary-foreground [a]:hover:bg-primary/80",
    secondary: "bg-secondary text-secondary-foreground [a]:hover:bg-secondary/80",
    destructive: "bg-destructive/10 text-destructive focus-visible:ring-destructive/20 dark:bg-destructive/20 dark:focus-visible:ring-destructive/40 [a]:hover:bg-destructive/20",
    outline: "border-border text-foreground [a]:hover:bg-muted [a]:hover:text-muted-foreground",
    ghost: "hover:bg-muted hover:text-muted-foreground dark:hover:bg-muted/50",
    link: "text-primary underline-offset-4 hover:underline"
  }.freeze

  CARD_BASE = "group/card flex flex-col gap-(--card-spacing) overflow-hidden rounded-none bg-card py-(--card-spacing) text-xs/relaxed text-card-foreground ring-1 ring-foreground/10 [--card-spacing:--spacing(4)] has-data-[slot=card-footer]:pb-0 has-[>img:first-child]:pt-0 data-[size=sm]:[--card-spacing:--spacing(3)] data-[size=sm]:has-data-[slot=card-footer]:pb-0 *:[img:first-child]:rounded-none *:[img:last-child]:rounded-none"
  CARD_CONTENT = "px-(--card-spacing)"
  CARD_HEADER = "group/card-header @container/card-header grid auto-rows-min items-start gap-1 rounded-none px-(--card-spacing) has-data-[slot=card-action]:grid-cols-[1fr_auto] has-data-[slot=card-description]:grid-rows-[auto_auto] [.border-b]:pb-(--card-spacing)"
  CARD_TITLE = "font-heading text-sm font-medium group-data-[size=sm]/card:text-sm"
  CARD_DESCRIPTION = "text-xs/relaxed text-muted-foreground"

  INPUT_BASE = "h-8 w-full min-w-0 rounded-none border border-input bg-transparent px-2.5 py-1 text-xs transition-colors outline-none file:inline-flex file:h-6 file:border-0 file:bg-transparent file:text-xs file:font-medium file:text-foreground placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-1 focus-visible:ring-ring/50 disabled:pointer-events-none disabled:cursor-not-allowed disabled:bg-input/50 disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-1 aria-invalid:ring-destructive/20 md:text-xs dark:bg-input/30 dark:disabled:bg-input/80 dark:aria-invalid:border-destructive/50 dark:aria-invalid:ring-destructive/40"

  def button_class(variant: :default, size: :default, class: nil)
    extra = binding.local_variable_get(:class)
    [ BUTTON_BASE, BUTTON_VARIANTS.fetch(variant.to_sym), BUTTON_SIZES.fetch(size.to_sym), extra ].compact.join(" ")
  end

  # <button> or <a> styled like shadcn's Button. Pass `href:` for a link.
  def ui_button(text = nil, href: nil, variant: :default, size: :default, class: nil, **attrs, &block)
    extra = binding.local_variable_get(:class)
    classes = button_class(variant:, size:, class: extra)
    content = block ? capture(&block) : text
    if href
      link_to(content, href, { class: classes, data: { slot: "button" } }.deep_merge(attrs))
    else
      content_tag(:button, content, { type: "button", class: classes, data: { slot: "button" } }.deep_merge(attrs))
    end
  end

  def badge_class(variant: :default, class: nil)
    extra = binding.local_variable_get(:class)
    [ BADGE_BASE, BADGE_VARIANTS.fetch(variant.to_sym), extra ].compact.join(" ")
  end

  def ui_badge(text = nil, variant: :default, class: nil, **attrs, &block)
    extra = binding.local_variable_get(:class)
    content_tag(:span, block ? capture(&block) : text, { class: badge_class(variant:, class: extra), data: { slot: "badge" } }.deep_merge(attrs))
  end

  def card_class(size: :default, class: nil)
    extra = binding.local_variable_get(:class)
    [ CARD_BASE, extra ].compact.join(" ")
  end

  def ui_card(size: :default, class: nil, **attrs, &block)
    extra = binding.local_variable_get(:class)
    content_tag(:div, capture(&block), { class: card_class(size:, class: extra), data: { slot: "card", size: size } }.deep_merge(attrs))
  end

  def ui_card_content(class: nil, **attrs, &block)
    extra = binding.local_variable_get(:class)
    content_tag(:div, capture(&block), { class: [ CARD_CONTENT, extra ].compact.join(" "), data: { slot: "card-content" } }.deep_merge(attrs))
  end

  def ui_card_header(class: nil, **attrs, &block)
    extra = binding.local_variable_get(:class)
    content_tag(:div, capture(&block), { class: [ CARD_HEADER, extra ].compact.join(" "), data: { slot: "card-header" } }.deep_merge(attrs))
  end

  def ui_card_title(text = nil, class: nil, **attrs, &block)
    extra = binding.local_variable_get(:class)
    content_tag(:div, block ? capture(&block) : text, { class: [ CARD_TITLE, extra ].compact.join(" "), data: { slot: "card-title" } }.deep_merge(attrs))
  end

  def ui_card_description(text = nil, class: nil, **attrs, &block)
    extra = binding.local_variable_get(:class)
    content_tag(:p, block ? capture(&block) : text, { class: [ CARD_DESCRIPTION, extra ].compact.join(" "), data: { slot: "card-description" } }.deep_merge(attrs))
  end

  def input_class(class: nil)
    extra = binding.local_variable_get(:class)
    [ INPUT_BASE, extra ].compact.join(" ")
  end
end
