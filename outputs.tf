output "app_vpc_id" {
  value = aws_vpc.app.id
}

output "shared_vpc_id" {
  value = aws_vpc.shared.id
}

output "nat_instance_id" {
  value = aws_instance.nat_instance.id
}

output "peering_id" {
  value = aws_vpc_peering_connection.peer.id
}
