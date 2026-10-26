locals {
  required_apis = toset([
    "iam.googleapis.com",
    "storage.googleapis.com"
  ])
}

resource "google_project_service" "apis" {
  for_each = local.required_apis

  service            = each.value
  disable_on_destroy = false
}