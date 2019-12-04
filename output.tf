output "ids" {
  description = "InstanceId of the newly created NetApp Data Broker"
  value = aws_spot_fleet_request.DataBrokerSpotFleetRequest.id
}