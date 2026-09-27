# Perceptual colour maths for palette search, in OKLab (Björn Ottosson): the straight-line distance
# between two colours tracks how different they look. About 0.02 is the smallest visible step.
module Color
  HEX = /\A#?(\h{6})\z/

  module_function

  # "#rrggbb" (or "rrggbb") → "#rrggbb" lowercased, or nil.
  def normalize(input)
    (m = HEX.match(input.to_s.strip)) && "##{m[1].downcase}"
  end

  # "#rrggbb" → frozen [L, a, b].
  def oklab(hex)
    r, g, b = hex.delete_prefix("#").scan(/../).map { |c| linear(c.to_i(16) / 255.0) }
    l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    [
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    ].freeze
  end

  def distance(p, q)
    Math.sqrt((p[0] - q[0])**2 + (p[1] - q[1])**2 + (p[2] - q[2])**2)
  end

  def linear(c) = c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4
end
