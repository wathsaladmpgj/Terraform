variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "az" {
  type    = string
  default = "ap-south-1a"
}

variable "app_vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "shared_vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}
