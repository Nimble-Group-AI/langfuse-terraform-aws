# GitHub OAuth Variables - values in secrets.tfvars (not committed to git)
variable "github_client_id" {
  description = "GitHub OAuth Client ID"
  type        = string
  sensitive   = true
}

variable "github_client_secret" {
  description = "GitHub OAuth Client Secret"
  type        = string
  sensitive   = true
}

module "langfuse" {
  source = "../.."

  domain = "nimble-obs.co.za"

  # Optional use a different name for your installation
  # e.g. when using the module multiple times on the same AWS account
  name = "langfuse"

  # Optional: Configure Langfuse
  use_encryption_key = true # Enable encryption for sensitive data stored in Langfuse

  # Optional: Configure the VPC
  vpc_cidr               = "10.0.0.0/16"
  use_single_nat_gateway = false # Using a single NAT gateway decreases costs, but is less resilient

  # Optional: Configure the Kubernetes cluster
  kubernetes_version         = "1.32"
  fargate_profile_namespaces = ["kube-system", "langfuse", "default"]

  # Optional: Configure the database instances
  postgres_instance_count = 2
  postgres_min_capacity   = 0.5
  postgres_max_capacity   = 2.0

  # Optional: Configure the cache
  cache_node_type      = "cache.t4g.small"
  cache_instance_count = 2

  # Optional: Configure Langfuse Helm chart version
  langfuse_helm_chart_version = "1.5.0"

  # Security: Restrict access to specific IP addresses
  # Only your IP can access Langfuse - blocks everyone else at load balancer
  ingress_inbound_cidrs = [
    "41.164.31.186/32",  # Your current IP
    # Add more IPs as needed:
    # "41.0.0.0/8",        # Entire South African IP range (less secure)
    # "10.20.30.0/24",     # Your company VPN range
  ]

  # Security: Require invitation for signup
  # Users can only sign up if they receive an invitation from an admin
  additional_env = [
    {
      name  = "LANGFUSE_REQUIRE_INVITATION_FOR_SIGNUP"
      value = "true"
    },
    {
      name  = "NEXT_PUBLIC_SIGN_UP_DISABLED"
      value = "false"
    },
    {
      name  = "AUTH_DISABLE_USERNAME_PASSWORD"
      value = "true"
    },
    # GitHub OAuth Configuration
    {
      name  = "AUTH_GITHUB_CLIENT_ID"
      value = var.github_client_id
    },
    {
      name  = "AUTH_GITHUB_CLIENT_SECRET"
      value = var.github_client_secret
    },
    {
      name  = "AUTH_GITHUB_ALLOW_ACCOUNT_LINKING"
      value = "true"
    }
  ]
}

provider "aws" {
  region  = "us-east-1" # Change this to your preferred AWS region
  profile = "erin"      # Use your AWS SSO profile
}

provider "kubernetes" {
  host                   = module.langfuse.cluster_host
  cluster_ca_certificate = module.langfuse.cluster_ca_certificate
  token                  = module.langfuse.cluster_token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.langfuse.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.langfuse.cluster_host
    cluster_ca_certificate = module.langfuse.cluster_ca_certificate
    token                  = module.langfuse.cluster_token

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.langfuse.cluster_name]
    }
  }
}
