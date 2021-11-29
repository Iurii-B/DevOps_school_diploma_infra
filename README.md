**A repository for IaC and misc files. Not part of CI/CD.** <br />
<br />
Just online archive of IaC and miscellaneous files. Not all of them are in use. <br />
To deploy diploma infrastructure only 2 files are used - **terraform_complete.tf** and **versions.tf** <br />
<br />
Due to some Terraform or AWS issue in rare cases pods created during initial infrastructure deployment (from the image with "**init**" tag) can experience network connectivity problems. <br />
Just delete pods using *kubectl*. New pods will be created automatically and no more issues observed neither during application update nor during infrastructure adjustments. <br />
<br />
Building Docker image is part of CI/CD pipeline. Dockerfile in this repository is not in use and is just a replica of the file from the main repo.
