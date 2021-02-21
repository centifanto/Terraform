output "vpc_id"{
    value = aws_vpc.Main.id
}

#SOUTH subnets
output "subnet_south-1"{
    value = aws_subnet.SOUTH-1.id
}
output "subnet_south-2"{
    value = aws_subnet.SOUTH-2.id
}
output "subnet_south-3"{
    value = aws_subnet.SOUTH-3.id
}
output "subnet_south-4"{
    value = aws_subnet.SOUTH-4.id
}

#NORTH subnets
output "subnet_north-1"{
    value = aws_subnet.NORTH-1.id
}
output "subnet_north-2"{
    value = aws_subnet.NORTH-2.id
}
output "subnet_north-3"{
    value = aws_subnet.NORTH-3.id
}
output "subnet_north-4"{
    value = aws_subnet.NORTH-4.id
}


output "default-aws-sg"{
    value = aws_security_group.Default-AWS.id
}

output "openvpn-sg"{
    value = aws_security_group.OpenVPN.id
}

