variable "common_tags" {
  type = map
  default = {
    Project     = "roboshop"
    Environment = "dev"
    Terraform   = true
  }
}

variable "project_name" {
  default = "roboshop"
}

variable "environment" {
  default = "dev"
}

variable "tags" {
  default = {
    Component = "catalogue"
  }
}

variable "zone_name" {
  type = string
  default = "rakeshintech.online"
}

variable "app_version" {
  
}