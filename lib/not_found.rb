# Raised when a URL names something the catalog or the guide does not have.
# ApplicationController renders it as a 404.
NotFound = Class.new(StandardError)
