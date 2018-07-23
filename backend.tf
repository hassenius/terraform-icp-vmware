terraform {
  backend "artifactory" {
    username = "admin"
    password = "letmein"
    url      = "http://172.16.50.189:32563/artifactory"
    repo     = "lightsaber"
    subpath  = "icp-vmware"
  }
}