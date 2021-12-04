resource "aws_db_instance" "database1" {
    engine = "mariadb"
    engine_version = "10.4.13"
    instance_class = "db.t2.medium"
    name = "database1"
    identifier = "database1"
    username = var.db_username
    password = var.db_password
    parameter_group_name = "default.mariadb10.4"
    db_subnet_group_name = aws_db_subnet_group.database1-subnet-group.name
    vpc_security_group_ids = [aws_security_group.tf_sg1.id]
    publicly_accessible = true
    skip_final_snapshot = true
    allocated_storage = 20
    auto_minor_version_upgrade = false
}

resource "time_sleep" "wait_20s" {
  create_duration = "20s"
  depends_on = [module.vpc.database_subnets]
}

data "aws_subnet_ids" "subnet_ids" {
    vpc_id = module.vpc.vpc_id
    depends_on = [time_sleep.wait_20s]  # Wait to ensure that subnets are ready
    tags = {
      Name = "database-subnets-tag"
    }
}

resource "aws_db_subnet_group" "database1-subnet-group" {
    name = "database1"
    subnet_ids = data.aws_subnet_ids.subnet_ids.ids
}
