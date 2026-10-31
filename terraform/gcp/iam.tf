moved {
  from = google_project_service.apis["iam.googleapis.com"]
  to   = google_project_service.iam_api
}

resource "google_project_service" "iam_api" {
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}
