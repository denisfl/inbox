# Pagy Configuration
# See https://ddnexus.github.io/pagy/docs/api/pagy

# Default items per page
Pagy::OPTIONS[:limit] = 20

# Max items per page (for user override via params[:limit])
Pagy::OPTIONS[:client_max_limit] = 100

# Navigation bar slots
Pagy::OPTIONS[:slots] = 7
