# Conditional GET (HTTP Caching)

## stale? vs fresh_when

| Method | Use When |
|--------|----------|
| `stale?` | You have custom response logic (respond_to, special rendering) |
| `fresh_when` | Default template rendering is fine |

## stale? Patterns

```ruby
class ProductsController < ApplicationController
  def show
    @product = Product.find(params[:id])

    if stale?(@product)
      respond_to do |format|
        format.html
        format.json { render json: @product }
      end
    end
  end

  # With explicit options
  def show
    @product = Product.find(params[:id])

    if stale?(
      last_modified: @product.updated_at.utc,
      etag: @product.cache_key_with_version,
      public: true  # Allow CDN/proxy caching
    )
      respond_to do |format|
        format.html
        format.json { render json: @product }
      end
    end
  end
end
```

## fresh_when Patterns

```ruby
class ProductsController < ApplicationController
  # Simplest form — pass the record
  def show
    @product = Product.find(params[:id])
    fresh_when @product
  end

  # For collections — uses max updated_at
  def index
    @products = Product.all
    fresh_when @products
  end

  # With explicit options
  def show
    @product = Product.find(params[:id])
    fresh_when(
      last_modified: @product.published_at.utc,
      etag: @product,
      public: false  # Private (default) — only browser caches
    )
  end
end
```

## http_cache_forever

For truly static content:

```ruby
class PagesController < ApplicationController
  def terms
    http_cache_forever(public: true) do
      render
    end
  end
end
```

**Warning:** Browsers and proxies will cache indefinitely. The only way to invalidate is changing the URL or user clearing their cache.

## Strong vs Weak ETags

Rails generates **weak ETags** by default (prefixed with `W/`). Weak ETags mean "semantically equivalent" — the response may differ in whitespace or encoding but the content is the same.

```ruby
# Weak ETag (default) — good for most cases
fresh_when etag: @product

# Strong ETag — exact byte-for-byte match required
# Use for: Range requests, CDNs that require strong ETags (Akamai)
fresh_when strong_etag: @product

# Set directly on response
response.strong_etag = response.body
```

## Public vs Private Caching

```ruby
# Private (default) — only the user's browser caches
fresh_when @product  # Cache-Control: private

# Public — CDNs and proxies can cache too
fresh_when @product, public: true  # Cache-Control: public

# Set cache control headers directly
expires_in 1.hour, public: true
expires_in 30.minutes, public: true, stale_while_revalidate: 60
expires_now  # Cache-Control: no-cache
```

## Testing Conditional GET

```ruby
class ProductsControllerTest < ActionDispatch::IntegrationTest
  test "returns 304 for unchanged resource" do
    product = products(:widget)

    # First request — full response
    get product_path(product)
    assert_response :success
    etag = response.headers["ETag"]
    last_modified = response.headers["Last-Modified"]

    # Second request with ETag — 304
    get product_path(product), headers: { "HTTP_IF_NONE_MATCH" => etag }
    assert_response :not_modified

    # Second request with Last-Modified — 304
    get product_path(product), headers: { "HTTP_IF_MODIFIED_SINCE" => last_modified }
    assert_response :not_modified
  end

  test "returns 200 after resource update" do
    product = products(:widget)

    get product_path(product)
    etag = response.headers["ETag"]

    product.update!(name: "New Name")

    get product_path(product), headers: { "HTTP_IF_NONE_MATCH" => etag }
    assert_response :success
  end
end
```
