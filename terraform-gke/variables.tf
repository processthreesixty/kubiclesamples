variable "project_id" {
  description = "The project ID where the GKE cluster will be created"
  default     = "processthreesixtydemo"
}

variable "region" {
  description = "The region where the GKE cluster will be created"
  default     = "europe-west2"
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  default     = "gcp-cluster"
}

variable "machine_type" {
  description = "The machine type to use for nodes"
  default     = "e2-medium"
}

variable "node_count" {
  description = "The number of nodes in the node pool"
  default     = 1
}

variable "google_credentials_file" {
  description = "/home/kubicle/.config/gcloud/application_default_credentials.json"
  type        = string
}
