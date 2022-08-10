variable "prefix" {
  description = "The prefix which should be used for all resources in this template"
  default = "Prjct1"
}

variable "location" {
  description = "The Azure Region in which all resources should be created"
  default = "westeurope"
}

variable "username"{
  description = "The username for the template"
  default = "NazaLearn"
  }


variable "password"{
    description = "The password for the template:"
    default = "98S8SoB^b8Lw"
  }


variable "vm_names" {
  type = list(string)
  default = ["node-01", "node-02", "node-03"]
}
