# Specify environment variables for Unicorn or Passenger here
#
# The example below will tune garbage collection for REE and Ruby 1.9.x and higher 
 
default[:env_vars] = {
  RUBY_HEAP_MIN_SLOT: "10000",
  RUBY_HEAP_SLOTS_INCREMENT: "10000",
  RUBY_HEAP_SLOTS_GROWTH_FACTOR: "1.8",
  RUBY_GC_MALLOC_LIMIT: "8000000",
  RUBY_HEAP_FREE_MIN: "4096",
  GITHUB_CLIENT_ID: "72eba31b198ade53f1ba",
  GITHUB_CLIENT_SECRET: "192bb3a96a841e23b44b92349306498caaf63390",
  GOOGLE_CLIENT_ID: "511621111646-je723cn9c29tbf8b0hrro391fr3l70bp.apps.googleusercontent.com",
  GOOGLE_CLIENT_SECRET: "09U9_dBkA4uk_zHTk3DtBcOt",
  GOOGLE_ACCESS_TOKEN: "ya29.RwHY0olBYuDGmVEvjlDiuWBOGIo_GuUTZJRPFA3DGrYLBjRfywUDVV9syo_eEHZygmAdC3EgGGyugw",
  GOOGLE_REFRESH_TOKEN: "1/v3Oqo_ihq1Xk_0Ju9lQtH5N3-uDWIXBDGw4ltwyZ6qYMEudVrK5jSpoR30zcRFq6",
  GOOGLE_PARENT_FOLDER_ID: "0B79tk5OWtcuvfi1aQlpBR2VJY2FwNmdmbFhSZE9HNDluckNfbXczUzBscWVXZWphdTZOVTA"
}
