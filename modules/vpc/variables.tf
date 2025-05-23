
variable "region" {
  type = string
}

variable "cidr_block" {
  type = string
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "azs" {
  type = list(string)
}
