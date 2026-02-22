# Pagy Configuration
# See https://ddnexus.github.io/pagy/docs/api/pagy

# Default items per page
Pagy::DEFAULT[:limit] = 20

# Max items per page (for user override via params[:limit])
Pagy::DEFAULT[:max_limit] = 100

# Metadata for frontend (count, page, etc.)
Pagy::DEFAULT[:metadata] = [:count, :page, :limit, :pages]

# Pagy items
Pagy::DEFAULT[:size] = 7  # [1, gap, 4, 5, 6, gap, 10] total 7 items

# Pagy is faster without i18n
# If you want to use i18n, uncomment this:
# require 'pagy/extras/i18n'

# Enable overflow mode (what to do if page > last_page)
# :empty_page (default) - Return empty results
# :last_page - Return last page
# :exception - Raise Pagy::OverflowError
Pagy::DEFAULT[:overflow] = :last_page

# Enable Pagy trim (remove empty pages from nav)
require 'pagy/extras/trim'

# Enable Pagy standalone (for use without view helpers)
# require 'pagy/extras/standalone'
